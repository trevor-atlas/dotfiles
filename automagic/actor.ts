/**
 * actor: the dumbest possible bus consumer.
 *
 * Owns exactly two things: subscribe to the bus, and on `stop()` unsubscribe.
 * It knows nothing about themes, calls, or the bar — it just hands every event
 * to an injected handler and provides a shutdown hook.
 *
 * The actual behavior (e.g. "show this bar theme") is a separate piece that the
 * wiring passes in as `onEvent`. This one is generic so it can drive any actor.
 */
import type { EventBus } from './eventBus';

export interface Actor {
  /** Detach the subscription (and let the handler wind down). */
  stop(): Promise<void>;
}

/**
 * Subscribe `onEvent` to every event on `bus`. Returns an {@link Actor} whose
 * `stop()` detaches the subscription. Fully generic over the event type.
 */
export function startActor<TEvent>(
  bus: EventBus<TEvent>,
  onEvent: (event: TEvent) => void | Promise<void>,
): Actor {
  const unsubscribe = bus.subscribe((event) => {
    void onEvent(event);
  });

  return {
    async stop(): Promise<void> {
      unsubscribe();
    },
  };
}
