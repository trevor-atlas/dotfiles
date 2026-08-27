/**
 * Runtime: a tiny registry + orderly shutdown for the daemon's components.
 *
 * It owns the shared bus and has two lanes for cleanup order:
 *   - producers (sources that poll/publish) — stopped first, so no new events
 *     are emitted while the actor is shutting down;
 *   - actor (the consumer holding the bar) — stopped last, releasing the display.
 *
 * The runtime does NOT control scheduling — each producer owns its own cadence
 * (see `callDetector.ts` / `poll.ts`). It only instantiates components against
 * the shared bus on registration, and stops them in lane order on `stopAll()`.
 *
 * ```ts
 * const runtime = new Runtime(systemBus);
 * runtime.registerProducers(callDetector);
 * runtime.registerActor((bus) => startActor(bus, theme.onEvent));
 * await runtime.stopAll(); // producers, then the actor
 * ```
 */

import type { EventBus } from './eventBus';

export interface Stoppable {
  /** Stop this component and wait for it to wind down. */
  stop(): Promise<void>;
}

export class Runtime<TEvent> {
  private readonly producers: Stoppable[] = [];
  private readonly actors: Stoppable[] = [];
  private stopping = false;

  constructor(readonly bus: EventBus<TEvent>) {}

  /** Register one or more producer factories; each is started against the shared bus. Returns `this`. */
  registerProducers<P extends (bus: EventBus<TEvent>) => Stoppable>(...factories: P[]): this {
    this.producers.push(...factories.map((f) => f(this.bus)));
    return this;
  }

  /** Register the (single) actor factory; started against the shared bus. Returns `this`. */
  registerActor<A extends (bus: EventBus<TEvent>) => Stoppable>(factory: A): this {
    this.actors.push(factory(this.bus));
    return this;
  }

  /** Whether a shutdown has been initiated. */
  get isStopped(): boolean {
    return this.stopping;
  }

  /**
   * Stop every registered component — producers first, then the actor — awaiting
   * each in order. A component that throws doesn't halt the rest; if any failed,
   * the first error (or an AggregateError) is re-thrown. Idempotent: a second
   * call returns immediately.
   */
  async stopAll(): Promise<void> {
    if (this.stopping) return;
    this.stopping = true;

    const errors: unknown[] = [];
    for (const component of [...this.producers, ...this.actors]) {
      try {
        await component.stop();
      } catch (err) {
        errors.push(err);
      }
    }

    if (errors.length === 1) throw errors[0];
    if (errors.length > 1) {
      throw new AggregateError(errors, `${errors.length} components failed to stop`);
    }
  }
}
