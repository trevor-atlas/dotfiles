/**
 * eventBus: the dumb bus. It only receives events and broadcasts them — it has
 * no idea what an event means, carries no domain types, and does no filtering,
 * state-tracking, or replay. The simplest pub/sub transport you can have.
 *
 * Producers call `publish(event)`; consumers call `subscribe(fn)` and filter by
 * `event.type` themselves. Delivery is fire-and-forget (handlers are not
 * awaited) so a slow consumer never blocks a producer.
 *
 * One instance is the whole contract — share a single bus across the app so any
 * detector can publish and any consumer can subscribe. Use {@link createEventBus}
 * to make fresh buses for tests.
 *
 * ```ts
 * const bus = createEventBus<SystemEvent>();
 * const unsub = bus.subscribe((e) => { if (e.type === 'call_started') … });
 * bus.publish({ type: 'call_started', app: 'zoom' });
 * ```
 *
 * This module intentionally imports nothing from the rest of the project, so it
 * is trivially testable in isolation.
 */

export type SystemEventHandler<T> = (event: T) => void | Promise<void>;

export class EventBus<T> {
  private readonly subscribers = new Set<SystemEventHandler<T>>();

  /** Broadcast an event to every current subscriber. */
  publish(event: T): void {
    for (const handler of [...this.subscribers]) {
      Promise.resolve()
        .then(() => handler(event))
        .catch((err) => {
          console.error(`[event-bus] handler error: ${(err as Error).message}`);
        });
    }
  }

  /** Register a handler for all events. Returns an unsubscribe function. */
  subscribe(handler: SystemEventHandler<T>): () => void {
    this.subscribers.add(handler);
    return () => {
      this.subscribers.delete(handler);
    };
  }

  /** Number of active subscribers (useful in tests). */
  get subscriberCount(): number {
    return this.subscribers.size;
  }

  /** Drop all subscribers (tests / teardown). */
  clear(): void {
    this.subscribers.clear();
  }
}

/** Construct a fresh, isolated bus (tests, or feature-local use). */
export function createEventBus<T>(): EventBus<T> {
  return new EventBus<T>();
}
