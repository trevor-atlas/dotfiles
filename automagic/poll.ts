/**
 * poll: the one bit of machinery that every poll-based detector shares — a
 * deadline-driven scheduled loop that calls a poll function on a fixed cadence.
 *
 * The cadence is deadline-based, not `setInterval`: each tick is scheduled from
 * the previous tick's *start time*, and on wake the timeout is recomputed
 * against wall-clock. This avoids the `setInterval` failure modes on a machine
 * that sleeps or whose clock jumps — no drift, and no burst of stale ticks on
 * wake (overdue ⇒ run once and reschedule).
 *
 * Detectors (call windows, mic audio, a calendar feed, …) each remain fully
 * self-contained: they own their own `read()` and event publishing, and only
 * borrow this scheduling loop for the common part.
 *
 * ```ts
 * const loop = pollEvery(3000, async () => { …publish… });
 * // … use loop.stop() / await loop.done …
 * ```
 */

import type { EventBus } from './eventBus';
import type { Reporter } from './board';
import { log } from './logSink';

export interface PollLoop {
  /** Stop the loop and wait for it to unwind. */
  stop(): Promise<void>;
  /** Resolves once the loop has wound down (signal fired or `stop()`). */
  done: Promise<void>;
}

/**
 * The handle a *producer* (a polled source that publishes to a bus) returns:
 * its current state, plus the lifecycle of its poll loop. Generic over the
 * state shape so producers aren't tied to one domain.
 */
export interface ProducerHandle<TState> {
  /** Current state, as last sampled by the loop. */
  getCurrentState(): TState;
  /** Stop the loop and wait for it to unwind. */
  stop(): Promise<void>;
  /** Resolves once the loop has wound down (signal fired or `stop()`). */
  done: Promise<void>;
}

/**
 * A self-naming, self-reporting producer registration. `name` is the display
 * name (known before `start` runs, so the runtime can create the board row and
 * bind its reporter first); `start` is the old producer factory plus an injected
 * {@link Reporter} the component uses to publish its current status.
 */
export interface ProducerDescriptor<TState, TEvent> {
  name: string;
  start: (bus: EventBus<TEvent>, report: Reporter) => ProducerHandle<TState>;
}

/**
 * A self-naming, self-reporting subscriber registration: `name` plus a `start`
 * that builds an {@link Actor} against the bus and reports its status via the
 * injected {@link Reporter}.
 */
export interface SubscriberDescriptor<TEvent> {
  name: string;
  start: (bus: EventBus<TEvent>, report: Reporter) => import('./actor').Actor;
}

/**
 * Run `poll()` immediately (first tick), then again every `intervalMs` on a
 * deadline based on each tick's start time, until stopped. Errors thrown by
 * `poll()` are logged and the loop continues (a bad read shouldn't kill the
 * daemon).
 */
export function pollEvery(
  intervalMs: number,
  poll: () => void | Promise<void>,
): PollLoop {
  const internal = new AbortController();

  const runner = (async () => {
    // First tick immediately, then on a fixed deadline cadence.
    if (internal.signal.aborted) return;
    let startedAt = Date.now();
    let pollNow = true;

    while (true) {
      if (internal.signal.aborted) break;

      if (pollNow) {
        try {
          await poll();
        } catch (err) {
          log(`[poll] error: ${(err as Error).message}`);
        }
        pollNow = false;
        startedAt = Date.now();
        continue;
      }

      // Wait until the next deadline (or abort), then tick again.
      const deadline = startedAt + intervalMs;
      const wait = new Promise<void>((resolve) => {
        let timer: ReturnType<typeof setTimeout> | null = null;
        const fire = () => {
          if (timer) clearTimeout(timer);
          resolve();
        };
        timer = setTimeout(fire, deadline - Date.now());
        internal.signal.addEventListener('abort', fire, { once: true });
      });
      await wait;
      if (internal.signal.aborted) break;
      pollNow = true;
    }
  })();

  return {
    async stop() {
      internal.abort();
      await runner;
    },
    done: runner,
  };
}
