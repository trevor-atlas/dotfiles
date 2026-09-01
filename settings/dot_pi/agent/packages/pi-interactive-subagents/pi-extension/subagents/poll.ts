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
  reason: "done" | "sentinel" | "error" | "vanished";
  /** Shell exit code (from sentinel). 0 for file-based exits, -1 for a vanished pane. */
  exitCode: number;
  /** Error message if reason is "error" (auto-retry exhausted, provider overload, etc.) */
  errorMessage?: string;
}

export interface PollOptions {
  interval: number;
  sessionFile?: string;
  sentinelFile?: string;
  onTick?: (elapsed: number) => void;
  /**
   * Optional liveness probe for the pane/surface. When a terminal read fails
   * and neither an `.exit` sidecar nor a completion sentinel is present, the
   * loop uses this to distinguish a transient CLI error from a pane that was
   * destroyed out-of-band (e.g. the user manually closed/killed it). Returning
   * `false` for two consecutive checks resolves the poll with reason
   * "vanished" so the watcher can tear down and stop showing it as running.
   */
  surfaceExists?: (surface: string) => boolean | Promise<boolean>;
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
  // Consecutive confirmations that the surface no longer exists. Requiring two
  // adds a small grace window so we never misreport a pane that is mid-teardown
  // after a clean exit (those are caught earlier via sentinel/.exit anyway).
  let missingChecks = 0;

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
      // A successful read proves the pane is alive; clear any pending vanish.
      missingChecks = 0;
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

      // No exit signal and the read failed — the pane may have been closed
      // out-of-band (manual kill). Probe liveness; two consecutive "gone"
      // results resolve the poll so the watcher removes it from the running
      // set and the parent's widget stops showing it as active.
      if (options.surfaceExists) {
        let gone = false;
        try {
          gone = !(await options.surfaceExists(surface));
        } catch {
          gone = false;
        }
        if (gone) {
          missingChecks += 1;
          if (missingChecks >= 2) {
            return { reason: "vanished", exitCode: -1 };
          }
        } else {
          missingChecks = 0;
        }
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
