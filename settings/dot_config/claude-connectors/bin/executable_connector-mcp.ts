#!/usr/bin/env bun
/**
 * stdio <-> HTTP MCP shim for Anthropic-hosted claude.ai connectors.
 *
 * Lets any local MCP client (pi, Cursor, MCP Inspector) talk to a claude.ai
 * connector such as Slack or Google Drive, without running Claude Code.
 *
 *     connector-mcp.ts slack
 *     connector-mcp.ts <installedServerId>
 *
 * Reads JSON-RPC from stdin, forwards to the Anthropic MCP gateway, writes
 * responses to stdout. Aliases resolve via ../connectors.json; raw UUIDs work
 * even with no registry.
 *
 * See ../README.md for the design and troubleshooting notes.
 */

import {
  ConnectorError,
  PROXY_BASE,
  accessToken,
  augmentToolsListResult,
  expandFileArgs,
  httpPost,
  loadRegistry,
  resolve,
} from "../lib/common.ts";

function log(msg: string): void {
  process.stderr.write(`[connector-mcp] ${msg}\n`);
}

function emit(obj: unknown): void {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function parseSse(raw: string): Array<Record<string, any>> {
  // Pull JSON-RPC payloads out of an SSE (or plain JSON) response body.
  const out: Array<Record<string, any>> = [];
  for (let line of raw.split(/\r?\n/)) {
    line = line.trim();
    if (line.startsWith("data:")) {
      line = line.slice(5).trim();
    }
    if (line.startsWith("{")) {
      try {
        out.push(JSON.parse(line));
      } catch {
        // ignore non-JSON lines
      }
    }
  }
  return out;
}

async function usage(): Promise<number> {
  let known: string;
  try {
    known = Object.keys((await loadRegistry()).servers).sort().join(", ");
  } catch {
    known = "(run: claude-connectors sync)";
  }
  log(`usage: connector-mcp.ts <alias|server-id>\n  known aliases: ${known}`);
  return 2;
}

async function main(): Promise<number> {
  if (Bun.argv.length < 3) {
    return usage();
  }

  let serverId: string;
  try {
    serverId = await resolve(Bun.argv[2]);
  } catch (exc) {
    log(exc instanceof Error ? exc.message : String(exc));
    return 1;
  }

  const url = `${PROXY_BASE}/${serverId}`;
  // One session id for the life of the process; the gateway keys state on it.
  const sessionId = process.env.MCP_CLIENT_SESSION_ID || crypto.randomUUID();

  async function handle(rawLine: string): Promise<void> {
    const line = rawLine.trim();
    if (!line) {
      return;
    }

    let msg: any;
    try {
      msg = JSON.parse(line);
    } catch {
      log(`skipping non-JSON line: ${line.slice(0, 80)}`);
      return;
    }

    // Notifications have no id and expect no response.
    const isRequest =
      typeof msg === "object" && msg !== null && msg.id !== undefined && msg.id !== null;

    // Expand virtual file-path arguments (textContentFile/base64ContentFile)
    // before forwarding, so callers needn't inline whole files into arguments.
    if (
      msg?.method === "tools/call" &&
      msg.params?.arguments !== null &&
      typeof msg.params?.arguments === "object" &&
      !Array.isArray(msg.params.arguments)
    ) {
      try {
        msg.params.arguments = await expandFileArgs(msg.params.arguments);
      } catch (exc) {
        const message = exc instanceof Error ? exc.message : String(exc);
        log(`file-arg expansion failed: ${message}`);
        if (isRequest) {
          emit({ jsonrpc: "2.0", id: msg.id, error: { code: -32000, message } });
        }
        return;
      }
    }

    let raw: string;
    try {
      raw = await httpPost(url, msg, {
        // Token fetched per-request so long-lived sessions survive expiry
        // without a restart.
        Authorization: `Bearer ${await accessToken()}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        // Undocumented but mandatory: gateway 400s without it.
        "X-Mcp-Client-Session-Id": sessionId,
      });
    } catch (exc) {
      const message = exc instanceof Error ? exc.message : String(exc);
      log(`upstream error: ${message}`);
      if (isRequest) {
        emit({
          jsonrpc: "2.0",
          id: msg.id,
          error: { code: -32000, message },
        });
      }
      return;
    }

    for (const payload of parseSse(raw)) {
      // Advertise the virtual *File keys in tools/list inputSchemas so clients
      // discover the convention. Additive and defensive; other payloads pass
      // through unchanged.
      emit(augmentToolsListResult(payload));
    }
  }

  const decoder = new TextDecoder();
  let buffer = "";
  for await (const chunk of Bun.stdin.stream()) {
    buffer += decoder.decode(chunk, { stream: true });
    let idx: number;
    while ((idx = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 1);
      await handle(line);
    }
  }
  if (buffer.length) {
    await handle(buffer);
  }

  return 0;
}

try {
  process.exit(await main());
} catch (exc) {
  // Client went away mid-write (EPIPE) or interrupted; nothing useful to say.
  const code = (exc as NodeJS.ErrnoException)?.code;
  if (code === "EPIPE" || code === "ERR_STREAM_DESTROYED") {
    process.exit(0);
  }
  if (exc instanceof ConnectorError) {
    log(exc.message);
    process.exit(1);
  }
  throw exc;
}
