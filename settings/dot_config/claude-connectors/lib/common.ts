/**
 * Shared helpers for the claude-connectors tools (Bun/TypeScript port).
 *
 * Everything here deals with two facts about the environment:
 *
 * 1. The claude.ai account token lives in the macOS keychain, in the same item
 *    Claude Code uses. We read AND write that item so the two stay in sync.
 * 2. This machine sits behind TLS interception, so bundled CA stores (including
 *    Bun's native `fetch`) reject certs that `curl` (which trusts the system
 *    keychain) accepts. Every outbound HTTPS call therefore goes through `curl`.
 */

import { join, resolve as pathResolve, extname } from "path";
import { homedir } from "os";

// Anchored at the canonical runtime location rather than relative to this
// file: under chezmoi's symlink mode these sources are symlinked out of the
// dotfiles tree, so `import.meta.dir` can point into the source repo. The
// generated (and git-ignored) connectors.json always lives at the real path.
const CONFIG_DIR = join(homedir(), ".config", "claude-connectors");
export const REGISTRY = join(CONFIG_DIR, "connectors.json");

export const KEYCHAIN_SERVICE = "Claude Code-credentials";
// Public OAuth client id for Claude Code, extracted from the shipped binary.
export const CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
export const TOKEN_URL = "https://platform.claude.com/v1/oauth/token";
export const API_BASE = "https://api.anthropic.com";
export const PROXY_BASE = "https://mcp-proxy.anthropic.com/v1/mcp";

// Refresh this far ahead of actual expiry.
export const REFRESH_SKEW_MS = 5 * 60 * 1000;

export class ConnectorError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConnectorError";
  }
}

// ---------------------------------------------------------------------------
// HTTPS via curl
// ---------------------------------------------------------------------------

export async function httpPost(
  url: string,
  payload: string | unknown,
  headers: Record<string, string>,
  timeout = 120,
): Promise<string> {
  const args = ["curl", "-sS", "--max-time", String(timeout), "-X", "POST", url];
  for (const [key, value] of Object.entries(headers)) {
    args.push("-H", `${key}: ${value}`);
  }
  args.push("--data-binary", "@-");

  const body = typeof payload === "string" ? payload : JSON.stringify(payload);
  const proc = Bun.spawn(args, { stdin: "pipe", stdout: "pipe", stderr: "pipe" });
  proc.stdin.write(body);
  await proc.stdin.end();

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (exitCode !== 0) {
    throw new ConnectorError(stderr.trim() || `curl exited ${exitCode}`);
  }
  return stdout;
}

// ---------------------------------------------------------------------------
// Keychain + token refresh
// ---------------------------------------------------------------------------

export async function keychainRead(): Promise<Record<string, any>> {
  const proc = Bun.spawn(
    ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
    { stdout: "pipe", stderr: "pipe" },
  );
  const [stdout, , exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (exitCode !== 0) {
    throw new ConnectorError(
      `could not read keychain item '${KEYCHAIN_SERVICE}'. Is Claude Code logged in?`,
    );
  }
  try {
    return JSON.parse(stdout);
  } catch (exc) {
    throw new ConnectorError(`keychain item is not valid JSON: ${exc}`);
  }
}

export async function keychainWrite(blob: unknown): Promise<void> {
  const proc = Bun.spawn(
    [
      "security", "add-generic-password", "-U",
      "-s", KEYCHAIN_SERVICE,
      "-a", KEYCHAIN_SERVICE,
      "-w", JSON.stringify(blob),
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  const exitCode = await proc.exited;
  if (exitCode !== 0) {
    const stderr = await new Response(proc.stderr).text();
    throw new ConnectorError(stderr.trim() || `security add-generic-password exited ${exitCode}`);
  }
}

async function refresh(refreshToken: string): Promise<Record<string, any>> {
  const body = await httpPost(
    TOKEN_URL,
    {
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: CLIENT_ID,
    },
    { "Content-Type": "application/json" },
    30,
  );
  try {
    return JSON.parse(body);
  } catch (exc) {
    throw new ConnectorError(`unexpected token response: ${body.slice(0, 200)}`);
  }
}

export async function accessToken(): Promise<string> {
  const blob = await keychainRead();
  const oauth = blob.claudeAiOauth ?? {};
  const token: string | undefined = oauth.accessToken;
  const expiresAt: number = oauth.expiresAt ?? 0;
  const nowMs = Date.now();

  if (token && expiresAt - REFRESH_SKEW_MS > nowMs) {
    return token;
  }

  const refreshToken: string | undefined = oauth.refreshToken;
  if (!refreshToken) {
    throw new ConnectorError("token expired and no refreshToken present; run: claude /login");
  }

  let fresh: Record<string, any>;
  try {
    fresh = await refresh(refreshToken);
  } catch (exc) {
    // Still nominally valid? Prefer using it over hard-failing.
    if (exc instanceof ConnectorError && token && expiresAt > nowMs) {
      return token;
    }
    throw exc;
  }

  if (!("access_token" in fresh)) {
    if (token && expiresAt > nowMs) {
      return token;
    }
    throw new ConnectorError(
      `refresh failed (${fresh.error ?? JSON.stringify(fresh)}); run: claude /login`,
    );
  }

  oauth.accessToken = fresh.access_token;
  if (fresh.refresh_token) {
    oauth.refreshToken = fresh.refresh_token;
  }
  if (fresh.expires_in) {
    oauth.expiresAt = Math.floor(nowMs + fresh.expires_in * 1000);
  }
  blob.claudeAiOauth = oauth;
  await keychainWrite(blob);
  return oauth.accessToken;
}

// ---------------------------------------------------------------------------
// Registry (alias -> server id), generated by `claude-connectors sync`
// ---------------------------------------------------------------------------

export async function orgUuid(): Promise<string> {
  const claudeJson = join(homedir(), ".claude.json");
  let data: Record<string, any>;
  try {
    data = JSON.parse(await Bun.file(claudeJson).text());
  } catch (exc) {
    throw new ConnectorError(`could not read ${claudeJson}: ${exc}`);
  }
  const account = data.oauthAccount ?? {};
  const uuid: string | undefined = account.organizationUuid;
  if (!uuid) {
    throw new ConnectorError("no organizationUuid in ~/.claude.json; run: claude /login");
  }
  return uuid;
}

export async function fetchConnectors(): Promise<Array<Record<string, any>>> {
  const url = `${API_BASE}/api/oauth/organizations/${await orgUuid()}/mcp/connectors/list`;
  const body = await httpPost(
    url,
    {},
    {
      Authorization: `Bearer ${await accessToken()}`,
      "Content-Type": "application/json",
    },
    30,
  );
  let data: Record<string, any>;
  try {
    data = JSON.parse(body);
  } catch (exc) {
    throw new ConnectorError(`unexpected registry response: ${body.slice(0, 200)}`);
  }
  if (!("results" in data)) {
    throw new ConnectorError(`registry error: ${JSON.stringify(data)}`);
  }
  return data.results;
}

export function slugify(name: string): string {
  const out = [...name].map((c) => (/[a-zA-Z0-9]/.test(c) ? c.toLowerCase() : "-"));
  let slug = out.join("");
  while (slug.includes("--")) {
    slug = slug.replace(/--/g, "-");
  }
  return slug.replace(/^-+/, "").replace(/-+$/, "");
}

export interface RegistryEntry {
  id: string;
  name: string;
}
export interface Registry {
  _comment?: string;
  servers: Record<string, RegistryEntry>;
}

export async function loadRegistry(): Promise<Registry> {
  const file = Bun.file(REGISTRY);
  if (!(await file.exists())) {
    throw new ConnectorError(`${REGISTRY} not found. Run: claude-connectors sync`);
  }
  return JSON.parse(await file.text());
}

export async function resolve(alias: string): Promise<string> {
  // Raw UUIDs pass straight through, so the shim works without a registry.
  if (alias.length === 36 && (alias.split("-").length - 1) === 4) {
    return alias;
  }
  const registry = await loadRegistry();
  const servers = registry.servers ?? {};
  if (alias in servers) {
    return servers[alias].id;
  }
  const known = Object.keys(servers).sort().join(", ") || "(none)";
  throw new ConnectorError(
    `unknown connector '${alias}'. Known: ${known}\n` +
      `Re-sync with: claude-connectors sync`,
  );
}

// ---------------------------------------------------------------------------
// Virtual file-path arguments
//
// So callers don't have to inline (and shell-escape) an entire file's contents
// into tool arguments. Any tool taking textContent / base64Content (e.g.
// Drive's create_file and update_file) can instead be given a *File sibling
// key pointing at a path; we read it and substitute the real argument before
// the JSON-RPC leaves this process.
// ---------------------------------------------------------------------------

// Minimal extension -> MIME map for inferring contentMimeType when a file arg
// is used and the caller didn't set one. Unknown extensions are left unset.
const EXT_MIME: Record<string, string> = {
  ".md": "text/markdown",
  ".txt": "text/plain",
  ".csv": "text/csv",
  ".json": "application/json",
  ".html": "text/html",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
};

function resolveUserPath(p: string): string {
  // Expand a leading ~, resolve relative paths against the working directory.
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return join(homedir(), p.slice(2));
  return pathResolve(process.cwd(), p);
}

/**
 * Expand virtual file-path arguments on a shallow copy of `args`:
 *   textContentFile  -> textContent   (UTF-8)
 *   base64ContentFile -> base64Content (base64 of raw bytes)
 * If a *File key is used and contentMimeType is absent, infer it from the
 * file extension. Passing both a *File key and its inline counterpart, or a
 * missing/unreadable file, throws a ConnectorError. The caller's object is
 * never mutated.
 */
export async function expandFileArgs(
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const out: Record<string, unknown> = { ...args };
  let usedFileKey = false;
  let lastPath = "";

  if (typeof out.textContentFile === "string") {
    if (out.textContent !== undefined) {
      throw new ConnectorError("pass either textContent or textContentFile, not both");
    }
    const p = resolveUserPath(out.textContentFile);
    lastPath = p;
    const file = Bun.file(p);
    if (!(await file.exists())) {
      throw new ConnectorError(`textContentFile not found: ${p}`);
    }
    try {
      out.textContent = await file.text();
    } catch (exc) {
      throw new ConnectorError(`could not read textContentFile ${p}: ${exc}`);
    }
    delete out.textContentFile;
    usedFileKey = true;
  }

  if (typeof out.base64ContentFile === "string") {
    if (out.base64Content !== undefined) {
      throw new ConnectorError("pass either base64Content or base64ContentFile, not both");
    }
    const p = resolveUserPath(out.base64ContentFile);
    lastPath = p;
    const file = Bun.file(p);
    if (!(await file.exists())) {
      throw new ConnectorError(`base64ContentFile not found: ${p}`);
    }
    try {
      out.base64Content = Buffer.from(await file.arrayBuffer()).toString("base64");
    } catch (exc) {
      throw new ConnectorError(`could not read base64ContentFile ${p}: ${exc}`);
    }
    delete out.base64ContentFile;
    usedFileKey = true;
  }

  if (usedFileKey && out.contentMimeType === undefined) {
    const mime = EXT_MIME[extname(lastPath).toLowerCase()];
    if (mime) {
      out.contentMimeType = mime;
    }
  }

  return out;
}

// ---------------------------------------------------------------------------
// Advertise the file-path convention in tools/list responses
//
// The shim rewrites outgoing tools/call, but tools/list flows back unchanged,
// so the virtual *File keys are invisible in the advertised inputSchema. This
// augments those responses so pi/the model discovers them without knowing the
// convention ahead of time. Purely additive and defensive: any unexpected
// shape leaves the payload untouched.
// ---------------------------------------------------------------------------

const TEXT_CONTENT_FILE_PROP = {
  type: "string",
  description:
    "Path to a local UTF-8 text file whose contents populate `textContent`. " +
    "Pass this INSTEAD of `textContent` to avoid inlining large files into the " +
    "request. A leading `~` is expanded and relative paths resolve against the " +
    "caller's working directory. When `contentMimeType` is omitted it is " +
    "inferred from the file extension (for example .md, .csv, .json, .html, " +
    ".pdf, .png).",
} as const;

const BASE64_CONTENT_FILE_PROP = {
  type: "string",
  description:
    "Path to a local file whose bytes are base64-encoded to populate " +
    "`base64Content`. Pass this INSTEAD of `base64Content` to avoid inlining " +
    "large/binary files. Path/`~`/relative and contentMimeType-inference rules " +
    "match `textContentFile`.",
} as const;

function isPlainObject(v: unknown): v is Record<string, any> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/**
 * Augment a JSON-RPC payload in place: for every tool in `result.tools` whose
 * inputSchema advertises `textContent` / `base64Content`, add the sibling
 * `textContentFile` / `base64ContentFile` string property (unless already
 * present) and note the option in the tool description. Never adds the new
 * keys to `required`, never alters existing properties, never touches tools
 * lacking both content keys, and never throws — on any unexpected shape the
 * payload is returned unchanged. Returns the same object for convenience.
 */
export function augmentToolsListResult(payload: unknown): unknown {
  try {
    if (!isPlainObject(payload)) return payload;
    const tools = (payload as any).result?.tools;
    if (!Array.isArray(tools)) return payload;

    for (const tool of tools) {
      if (!isPlainObject(tool)) continue;
      const schema = tool.inputSchema;
      if (!isPlainObject(schema)) continue;
      const props = schema.properties;
      if (!isPlainObject(props)) continue;

      const added: string[] = [];
      if ("textContent" in props && !("textContentFile" in props)) {
        props.textContentFile = { ...TEXT_CONTENT_FILE_PROP };
        added.push("textContentFile");
      }
      if ("base64Content" in props && !("base64ContentFile" in props)) {
        props.base64ContentFile = { ...BASE64_CONTENT_FILE_PROP };
        added.push("base64ContentFile");
      }

      if (added.length) {
        const note =
          ` You can also pass \`${added.join("`/`")}\` with a local file path ` +
          "instead of inlining content.";
        tool.description = (typeof tool.description === "string" ? tool.description : "") + note;
      }
    }
  } catch {
    // Purely additive: never let augmentation break the response.
  }
  return payload;
}
