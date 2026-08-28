/**
 * Runtime: a tiny registry + orderly shutdown for the daemon's components.
 *
 * It owns the shared bus and has two lanes for cleanup order:
 *   - producers (sources that poll/publish) — stopped first, so no new events
 *     are emitted while the subscribers are shutting down;
 *   - subscribers (consumers, e.g. the one holding the bar) — stopped last,
 *     releasing the display.
 *
 * Components register as self-naming DESCRIPTORS `{ name, start }`. Because the
 * name is known before `start` runs, the runtime can create the board row and
 * bind that row's {@link Reporter} BEFORE calling `start`. When a {@link Board}
 * is present, registering adds a row (of the right kind) and passes that row's
 * reporter into `start`; when absent, `report` is a safe no-op and no rows are
 * created (headless tests and the current daemon keep working unchanged).
 *
 * The runtime does NOT control scheduling — each producer owns its own cadence
 * (see `callDetector.ts` / `poll.ts`). It only instantiates components against
 * the shared bus on registration, and stops them in lane order on `stopAll()`.
 *
 * ```ts
 * const runtime = new Runtime(systemBus);
 * runtime.registerSubscriber({ name: 'busy bar', start: (bus, report) => startBarActor(bus, report, bar) });
 * runtime.registerProducer(callDetector);
 * await runtime.stopAll(); // producers, then subscribers
 * ```
 */

import type { EventBus } from './eventBus';
import { Board } from './board';
import type { ProducerDescriptor, SubscriberDescriptor } from './poll';

export interface Stoppable {
  /** Stop this component and wait for it to wind down. */
  stop(): Promise<void>;
}

export class Runtime<TEvent> {
  private readonly producers: Stoppable[] = [];
  private readonly subscribers: Stoppable[] = [];
  private stopping = false;

  constructor(readonly bus: EventBus<TEvent>, private readonly board?: Board) {}

  /**
   * Register one producer descriptor: create its board row (if a board is
   * present), then start it against the shared bus with that row's reporter.
   * Chainable — returns `this`.
   */
  registerProducer<TState>(descriptor: ProducerDescriptor<TState, TEvent>): this {
    const report = this.board ? this.board.addRow('producer', descriptor.name) : () => {};
    this.producers.push(descriptor.start(this.bus, report));
    return this;
  }

  /**
   * Register one subscriber descriptor: create its board row (if a board is
   * present), then start it against the shared bus with that row's reporter.
   * Multiple subscribers are allowed. Chainable — returns `this`.
   */
  registerSubscriber(descriptor: SubscriberDescriptor<TEvent>): this {
    const report = this.board ? this.board.addRow('subscriber', descriptor.name) : () => {};
    this.subscribers.push(descriptor.start(this.bus, report));
    return this;
  }

  /** Whether a shutdown has been initiated. */
  get isStopped(): boolean {
    return this.stopping;
  }

  /**
   * Stop every registered component — producers first, then subscribers —
   * awaiting each in order. A component that throws doesn't halt the rest; if
   * any failed, the first error (or an AggregateError) is re-thrown. Idempotent:
   * a second call returns immediately.
   */
  async stopAll(): Promise<void> {
    if (this.stopping) return;
    this.stopping = true;

    const errors: unknown[] = [];
    for (const component of [...this.producers, ...this.subscribers]) {
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
