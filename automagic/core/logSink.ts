/**
 * logSink: a bounded, observable buffer of recent log lines. It only stores the
 * last `cap` lines and tells subscribers when that buffer changed — it knows
 * nothing about *why* a line was logged or who will render it.
 *
 * Components call `append(line)` instead of `console.log` directly; the future
 * TUI calls `subscribe(fn)` to re-render and `snapshot()` to read the current
 * lines (oldest first). Console mirroring defaults ON so logs stay visible on
 * the plain console before the TUI mounts; the daemon calls `setMirror(false)`
 * once the TUI owns the screen.
 *
 * One shared instance (`logSink`) is the app-wide contract — like `systemBus`
 * in `systemEvents.ts`. Use {@link createLogSink} to make isolated sinks for
 * tests, and {@link log} as a shorthand for the shared sink.
 *
 * ```ts
 * const unsub = logSink.subscribe(() => render(logSink.snapshot()));
 * log('daemon started');
 * ```
 *
 * This module intentionally imports nothing from the rest of the project, so it
 * is trivially testable in isolation.
 */

export class LogSink {
  private readonly lines: string[] = [];
  private readonly listeners = new Set<() => void>();
  private mirror = true;

  constructor(private readonly cap: number = 200) {}

  /**
   * Append a line: keep at most `cap` lines (drop the oldest when full), notify
   * subscribers, and — when mirroring is on — also write it via `console.log`.
   */
  append(line: string): void {
    this.lines.push(line);
    if (this.lines.length > this.cap) {
      this.lines.splice(0, this.lines.length - this.cap);
    }
    if (this.mirror) {
      console.log(line);
    }
    for (const listener of [...this.listeners]) {
      listener();
    }
  }

  /** Register a change listener (fires once per append). Returns unsubscribe. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Current buffered lines, oldest first. */
  snapshot(): readonly string[] {
    return [...this.lines];
  }

  /** Toggle console mirroring (the daemon turns it off once the TUI mounts). */
  setMirror(enabled: boolean): void {
    this.mirror = enabled;
  }
}

/** Construct a fresh, isolated sink (tests, or feature-local use). */
export function createLogSink(cap?: number): LogSink {
  return new LogSink(cap);
}

/**
 * The shared, application-wide sink. Every component appends here; the TUI
 * subscribes here. Like `systemBus` in `systemEvents.ts`.
 */
export const logSink: LogSink = new LogSink();

/** Append a line to the shared {@link logSink}. */
export function log(line: string): void {
  logSink.append(line);
}
