/**
 * busyAutomation: the busy-bar actor — subscribes to the bus, reads events, and
 * does stuff in reaction.
 *
 * The bus (`systemBus`) is generic: it carries events, and any consumer can
 * react however it likes. This module is the bar side: it subscribes and turns
 * events into bar behavior. Today the only behavior it knows is *calls* — on
 * `call_state_changed` (the producer's authoritative full state) it shows or
 * releases a theme on the BUSY Bar, using `BusyDefaults`' "only release if still
 * ours" rule so it never stomps a mode another tool started.
 *
 * That call→theme behavior is just what it currently does, not what it *is* —
 * the actor reads events and does stuff; calls are one kind of event. It reuses
 * the dumb `startActor` for the actual subscription.
 *
 * The only input is where the bar lives; the call→theme map is a plain constant.
 */
import { BusyDefaults } from './busy-defaults';
import { startActor } from './actor';
import type { Actor } from './actor';
import type { EventBus } from './eventBus';
import type { SystemEvent } from './systemEvents';

/**
 * Start the busy-bar actor on `bus`: subscribe to events and react — currently
 * by showing a theme while a call is live and releasing when it ends. Returns an
 * {@link Actor stop}. Internal state is deliberately simple: track the current
 * hold so `stop()` and shutdown release only what we started.
 */
export function startBarActor(
  bus: EventBus<SystemEvent>,
  bar: ConstructorParameters<typeof BusyDefaults>[0],
): Actor {
  const busy = new BusyDefaults(bar || {});
  busy.playTheme('nyan_cat');
  let hold: import('./busy-defaults').HeldMode | null = null;

  const onEvent = async (event: SystemEvent): Promise<void> => {
    if (event.type === 'call_state_changed') {
      if (event.app === null) {
        const current = hold;
        hold = null;
        await current?.release().catch(() => {});
        return;
      }
      if (hold) return;
      hold = await busy.run('meeting');
      return;
    }

    /** Theme to show while a call is live */
    if (event.type === 'call_started') {
      if (hold) return;
      hold = await busy.run('meeting');
      return;
    }

    if (event.type === 'call_ended') {
      const current = hold;
      hold = null;
      await current?.release().catch(() => {});
      return;
    }
  };

  const actor = startActor(bus, onEvent);

  return {
    async stop(): Promise<void> {
      await actor.stop();
      const current = hold;
      hold = null;
      await current?.release().catch(() => {});
    },
  };
}
