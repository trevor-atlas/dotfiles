/**
 * Surface dispatcher — picks the active terminal multiplexer backend for
 * subagent panes and exposes a single multiplexer-agnostic API to index.ts.
 *
 * Backend selection:
 *   - PI_SUBAGENT_MUX=herdr|tmux forces a backend (the chosen multiplexer
 *     must actually be running, else subagents are unavailable);
 *   - otherwise auto-detect: herdr first (HERDR_ENV=1 + socket + pane +
 *     binary), then tmux (TMUX + binary).
 *
 * All calls delegate to the active backend (herdr.ts / tmux.ts). Errors from
 * the backends are plain Error with a human-readable message; tool handlers
 * in index.ts convert them into graceful results, never thrown into the pi
 * session.
 */
import * as herdr from "./herdr.ts";
import * as tmux from "./tmux.ts";
import { pollForExit as pollForExitCore, type PollOptions, type PollResult } from "./poll.ts";

export type MuxBackend = "herdr" | "tmux";

function muxPreference(): MuxBackend | null {
  const pref = (process.env.PI_SUBAGENT_MUX ?? "").trim().toLowerCase();
  return pref === "herdr" || pref === "tmux" ? pref : null;
}

/** Resolve the active backend, or null when no supported multiplexer is running. */
export function getMuxBackend(): MuxBackend | null {
  const pref = muxPreference();
  if (pref === "herdr") return herdr.isHerdrAvailable() ? "herdr" : null;
  if (pref === "tmux") return tmux.isTmuxAvailable() ? "tmux" : null;

  if (herdr.isHerdrAvailable()) return "herdr";
  if (tmux.isTmuxAvailable()) return "tmux";
  return null;
}

export function isMuxAvailable(): boolean {
  return getMuxBackend() !== null;
}

export function muxName(): string {
  return getMuxBackend() ?? "none";
}

export function muxSetupHint(): string {
  const pref = muxPreference();
  if (pref === "herdr") return herdr.herdrSetupHint();
  if (pref === "tmux") return tmux.muxSetupHint();
  return "Start pi inside herdr (`herdr`, then run `pi`) or tmux (`tmux new -A -s pi 'pi'`).";
}

function requireBackend(): typeof tmux | typeof herdr {
  const backend = getMuxBackend();
  if (backend === "herdr") return herdr;
  if (backend === "tmux") return tmux;
  throw new Error(`No supported terminal multiplexer found. ${muxSetupHint()}`);
}

// ── Surface primitives (delegated) ──

export function createSurface(name: string): string {
  return requireBackend().createSurface(name);
}

export function createSurfaceSplit(
  name: string,
  direction: "left" | "right" | "up" | "down",
  fromSurface?: string,
): string {
  return requireBackend().createSurfaceSplit(name, direction, fromSurface);
}

export function sendCommand(surface: string, command: string): void {
  requireBackend().sendCommand(surface, command);
}

export function sendLongCommand(
  surface: string,
  command: string,
  options?: { scriptPath?: string; scriptPreamble?: string },
): string {
  return requireBackend().sendLongCommand(surface, command, options);
}

export function readScreen(surface: string, lines = 50): string {
  return requireBackend().readScreen(surface, lines);
}

export async function readScreenAsync(surface: string, lines = 50): Promise<string> {
  return requireBackend().readScreenAsync(surface, lines);
}

export function closeSurface(surface: string): void {
  requireBackend().closeSurface(surface);
}

export function pollForExit(
  surface: string,
  signal: AbortSignal,
  options: PollOptions,
): Promise<PollResult> {
  return pollForExitCore(requireBackend().readScreenAsync, surface, signal, options);
}

export { shellEscape } from "./tmux.ts";
