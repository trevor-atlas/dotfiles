/**
 * herdr surface layer — run subagent panes inside herdr (https://herdr.dev).
 *
 * Mirrors the tmux surface API (tmux.ts) so index.ts stays multiplexer
 * agnostic; mux.ts dispatches between the two. Panes are identified by herdr
 * pane ids (e.g. `w1:p4`).
 *
 * CLI notes:
 *  - herdr prints JSON for most commands; failures arrive as
 *    {"error":{code,message}} with a non-zero exit status. parseHerdrJson
 *    converts those into Error with the server's message so nothing raw
 *    leaks into the pi session.
 *  - pane split supports only right/down directions; the extension only
 *    ever asks for right, so left/up throw a clear error.
 *  - pane run submits text plus Enter atomically and honors bracketed paste;
 *    long launch commands still go through a script file (sendLongCommand)
 *    to dodge line-wrap corruption, exactly like tmux.
 *  - pane read --source visible returns plain text (ANSI stripped), which is
 *    what the shared exit poller greps for the __SUBAGENT_DONE_ sentinel.
 */
import { execFile, execFileSync } from "node:child_process";
import { promisify } from "node:util";
import { writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { pollForExit as pollForExitCore, type PollOptions, type PollResult } from "./poll.ts";
import { shellEscape } from "./tmux.ts";

const execFileAsync = promisify(execFile);

// ── Availability ──

const commandAvailability = new Map<string, boolean>();

function hasCommand(command: string): boolean {
  if (commandAvailability.has(command)) {
    return commandAvailability.get(command)!;
  }

  let available = false;
  try {
    execFileSync("sh", ["-c", `command -v ${command}`], { stdio: "ignore" });
    available = true;
  } catch {
    available = false;
  }

  commandAvailability.set(command, available);
  return available;
}

/**
 * True when running inside herdr with the herdr binary on PATH.
 * HERDR_ENV / HERDR_SOCKET_PATH / HERDR_PANE_ID are set by herdr in every
 * process it spawns (same gates the official pi integration uses).
 */
export function isHerdrAvailable(): boolean {
  return (
    process.env.HERDR_ENV === "1" &&
    !!process.env.HERDR_SOCKET_PATH &&
    !!process.env.HERDR_PANE_ID &&
    hasCommand("herdr")
  );
}

export function herdrSetupHint(): string {
  return "Start pi inside herdr (`herdr`, then run `pi`).";
}

function requireHerdr(): void {
  if (!isHerdrAvailable()) {
    throw new Error(`herdr is required for subagents. ${herdrSetupHint()}`);
  }
}

// ── herdr CLI helpers ──

/**
 * Parse a herdr CLI JSON response. Throws a plain Error carrying the
 * server's own message on {"error":...} payloads and on non-JSON output, so
 * callers can surface a clean explanation to the agent.
 */
function parseHerdrJson(raw: string): any {
  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Error("herdr returned no output.");
  }
  let data: any;
  try {
    data = JSON.parse(trimmed);
  } catch {
    throw new Error(`herdr returned non-JSON output: ${raw.slice(0, 200)}`);
  }
  if (data?.error) {
    const message =
      typeof data.error.message === "string" && data.error.message !== ""
        ? data.error.message
        : data.error.code ?? "unknown herdr error";
    throw new Error(`herdr: ${message}`);
  }
  return data;
}

// ── Pane layout ──

/**
 * herdr splits the target pane in half with --ratio 0.5. Repeated splits
 * halve the newest pane, so parallel subagents drift like tmux without its
 * even-horizontal rebalance; keeping panes perfectly even is left to the
 * user (zoom/focus) for now.
 */
const SUBAGENT_HERDR_SPLIT_RATIO = "0.5";

// ── Surface primitives ──

/**
 * Create a new pane for a subagent: a right split off the parent pi's pane
 * (--current, which is HERDR_PANE_ID when the extension runs inside herdr),
 * so new panes follow the agent rather than the user's focus. herdr leaves
 * focus unchanged on split.
 *
 * Returns the new pane id (e.g. `w1:p4`).
 */
export function createSurface(name: string): string {
  void name; // herdr panes are not named; the pi process inside shows its own title.
  return createSurfaceSplit(name, "right");
}

/**
 * Create a new split from an optional source pane. herdr only supports
 * `right` and `down` splits — `left`/`up` throw. Without a source pane,
 * splits the calling pane (`--current`).
 */
export function createSurfaceSplit(
  name: string,
  direction: "left" | "right" | "up" | "down",
  fromSurface?: string,
): string {
  void name;
  requireHerdr();

  if (direction !== "right" && direction !== "down") {
    throw new Error(`herdr only supports right/down splits, got "${direction}".`);
  }

  const args = ["pane", "split", "--direction", direction];
  if (fromSurface) {
    args.push("--pane", fromSurface);
  } else {
    args.push("--current");
  }
  args.push("--ratio", SUBAGENT_HERDR_SPLIT_RATIO);

  let out: string;
  try {
    out = execFileSync("herdr", args, { encoding: "utf8" });
  } catch (error: any) {
    throw new Error(
      `Failed to create herdr pane: ${error?.stderr?.trim() || error?.message || String(error)}`,
    );
  }

  const paneId = parseHerdrJson(out)?.result?.pane?.pane_id;
  if (typeof paneId !== "string" || paneId === "") {
    throw new Error(`Unexpected herdr pane split output: ${out.slice(0, 200)}`);
  }
  return paneId;
}

/**
 * Send a command string to a pane and execute it. `pane run` submits the
 * text plus Enter atomically and honors bracketed paste. Long commands
 * should go through sendLongCommand (script file) to avoid line-wrap
 * corruption.
 */
export function sendCommand(surface: string, command: string): void {
  requireHerdr();
  try {
    execFileSync("herdr", ["pane", "run", surface, command], { encoding: "utf8" });
  } catch (error: any) {
    throw new Error(
      `Failed to run command in herdr pane ${surface}: ${error?.stderr?.trim() || error?.message || String(error)}`,
    );
  }
}

/**
 * Send a long command to a pane by writing it to a script file first.
 * This avoids terminal line-wrapping issues that break commands exceeding the
 * pane's column width when sent character-by-character via sendCommand.
 *
 * By default the script is written to a temp directory, but callers can pass a
 * stable path (for example under session artifacts) so the exact invocation is
 * preserved for debugging.
 *
 * Returns the script path.
 */
export function sendLongCommand(
  surface: string,
  command: string,
  options?: { scriptPath?: string; scriptPreamble?: string },
): string {
  const scriptPath =
    options?.scriptPath ??
    join(
      tmpdir(),
      "pi-subagent-scripts",
      `cmd-${Date.now()}-${Math.random().toString(16).slice(2, 8)}.sh`,
    );
  mkdirSync(dirname(scriptPath), { recursive: true });

  const scriptParts = ["#!/bin/bash"];
  if (options?.scriptPreamble) {
    scriptParts.push(options.scriptPreamble.trimEnd());
  }
  scriptParts.push(command);

  writeFileSync(scriptPath, scriptParts.join("\n") + "\n", {
    mode: 0o755,
  });
  sendCommand(surface, `bash ${shellEscape(scriptPath)}`);
  return scriptPath;
}

/**
 * Read the visible screen contents of a pane (sync). herdr strips ANSI
 * escapes by default; `visible` is the live terminal snapshot (the `recent`
 * scrollback source returned empty in testing).
 */
export function readScreen(surface: string, lines = 50): string {
  requireHerdr();
  try {
    return execFileSync(
      "herdr",
      ["pane", "read", surface, "--source", "visible", "--lines", String(Math.max(1, lines))],
      { encoding: "utf8" },
    );
  } catch (error: any) {
    throw new Error(
      `Failed to read herdr pane ${surface}: ${error?.stderr?.trim() || error?.message || String(error)}`,
    );
  }
}

/**
 * Read the visible screen contents of a pane (async).
 */
export async function readScreenAsync(surface: string, lines = 50): Promise<string> {
  requireHerdr();
  try {
    const { stdout } = await execFileAsync(
      "herdr",
      ["pane", "read", surface, "--source", "visible", "--lines", String(Math.max(1, lines))],
      { encoding: "utf8" },
    );
    return stdout;
  } catch (error: any) {
    throw new Error(
      `Failed to read herdr pane ${surface}: ${error?.stderr?.trim() || error?.message || String(error)}`,
    );
  }
}

/**
 * Close a pane.
 */
export function closeSurface(surface: string): void {
  requireHerdr();
  try {
    execFileSync("herdr", ["pane", "close", surface], { encoding: "utf8" });
  } catch (error: any) {
    throw new Error(
      `Failed to close herdr pane ${surface}: ${error?.stderr?.trim() || error?.message || String(error)}`,
    );
  }
}

// ── Exit polling ──

export type { PollResult, PollOptions } from "./poll.ts";

/**
 * Poll until the subagent exits, reading the herdr pane for the terminal
 * sentinel. See poll.ts for the shared loop.
 */
export function pollForExit(
  surface: string,
  signal: AbortSignal,
  options: PollOptions,
): Promise<PollResult> {
  return pollForExitCore(readScreenAsync, surface, signal, options);
}
