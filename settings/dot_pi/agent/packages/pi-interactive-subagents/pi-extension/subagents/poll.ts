/**
 * Shared subagent exit-polling.
 *
 * The poll loop is multiplexer-agnostic — only the terminal read differs
 * between surfaces — so it lives here and each surface module (tmux.ts,
 * herdr.ts) feeds it its own `readScreenAsync`. Errors raised by the reader
 * (pane destroyed, CLI failure) are caught inside the loop and never leak:
 * the loop keeps polling until the `.exit` sidecar or terminal sentinel
 * appears, or the caller aborts.
 */
import { existsSync, readFileSync, rmSync } from "node:fs";

export interface PollResult {
  /** How the subagent exited */
  reason: "done" | "sentinel" | "error";
  /** Shell exit code (from sentinel). 0 for file-based exits. */
  exitCode: number;
  /** Error message if reason is "error" (auto-retry exhausted, provider overload, etc.) */
  errorMessage?: string;
}

export interface PollOptions {
  interval: number;
  sessionFile?: string;
  sentinelFile?: string;
  onTick?: (elapsed: number) => void;
}

/**
 * Interpret an `.exit` sidecar payload (written by the error path in
 * subagent-done.ts). Centralized so both the fast and slow paths in
 * pollForExit decode the payload the same way. Clean completions write no
 * sidecar and are detected via the terminal sentinel instead.
 *
 * Note: ask_question does NOT write a `.exit` sidecar — it keeps the session
 * open and signals the parent via a separate `.ask` file (see deliverPendingQuestion).
 */
export function interpretExitSidecar(data: any): PollResult {
  if (data?.type === "error") {
    const errorMessage =
      typeof data.errorMessage === "string" && data.errorMessage.trim() !== ""
        ? data.errorMessage
        : "Subagent exited with stopReason=error (no errorMessage in sidecar).";
    return { reason: "error", exitCode: 1, errorMessage };
  }
  return { reason: "done", exitCode: 0 };
}

/**
 * Poll until the subagent exits. Checks for a `.exit` sidecar file first
 * (written by the error path), falling back to the terminal sentinel for
 * clean-completion and crash detection.
 */
export async function pollForExit(
  readScreenAsync: (surface: string, lines?: number) => Promise<string>,
  surface: string,
  signal: AbortSignal,
  options: PollOptions,
): Promise<PollResult> {
  const start = Date.now();

  for (;;) {
    if (signal.aborted) {
      throw new Error("Aborted while waiting for subagent to finish");
    }

    // Fast path: check for .exit sidecar file (written by the error path)
    if (options.sessionFile) {
      try {
        const exitFile = `${options.sessionFile}.exit`;
        if (existsSync(exitFile)) {
          const data = JSON.parse(readFileSync(exitFile, "utf-8"));
          rmSync(exitFile, { force: true });
          return interpretExitSidecar(data);
        }
      } catch {}
    }

    // Check Claude sentinel file (written by plugin Stop hook)
    if (options.sentinelFile) {
      try {
        if (existsSync(options.sentinelFile)) {
          return { reason: "sentinel", exitCode: 0 };
        }
      } catch {}
    }

    // Slow path: read terminal screen for sentinel (crash detection)
    try {
      const screen = await readScreenAsync(surface, 5);
      const match = screen.match(/__SUBAGENT_DONE_(\d+)__/);
      if (match) {
        return { reason: "sentinel", exitCode: parseInt(match[1], 10) };
      }
    } catch {
      // Surface may have been destroyed — check if .exit file appeared in the meantime
      if (options.sessionFile) {
        try {
          const exitFile = `${options.sessionFile}.exit`;
          if (existsSync(exitFile)) {
            const data = JSON.parse(readFileSync(exitFile, "utf-8"));
            rmSync(exitFile, { force: true });
            return interpretExitSidecar(data);
          }
        } catch {}
      }
    }

    const elapsed = Math.floor((Date.now() - start) / 1000);
    options.onTick?.(elapsed);

    await new Promise<void>((resolve, reject) => {
      if (signal.aborted) return reject(new Error("Aborted"));
      const timer = setTimeout(() => {
        signal.removeEventListener("abort", onAbort);
        resolve();
      }, options.interval);
      function onAbort() {
        clearTimeout(timer);
        reject(new Error("Aborted"));
      }
      signal.addEventListener("abort", onAbort, { once: true });
    });
  }
}
