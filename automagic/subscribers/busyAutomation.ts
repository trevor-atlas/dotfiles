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
 * the subscriber reads events and does stuff; calls are one kind of event. It
 * reuses the dumb `startActor` primitive for the actual subscription.
 *
 * The only input is where the bar lives; the call→theme map is a plain constant.
 */
import { BusyDefaults } from '../bar/busy-defaults';
import { startActor } from '../core/actor';
import type { Actor } from '../core/actor';
import type { EventBus } from '../core/eventBus';
import type { SystemEvent } from '../events/systemEvents';
import type { Reporter } from '../core/board';

/**
 * Start the busy-bar subscriber on `bus`: subscribe to events and react —
 * currently by showing a theme while a call is live and releasing when it ends.
 * Reflects its status through the injected {@link Reporter}. Returns an
 * {@link Actor stop}. Internal state is deliberately simple: track the current
 * hold so `stop()` and shutdown release only what we started.
 */
export function startBarActor(
  bus: EventBus<SystemEvent>,
  report: Reporter,
  bar: ConstructorParameters<typeof BusyDefaults>[0],
): Actor {
  const busy = new BusyDefaults(bar || {});
  busy.playTheme('nyan_cat');
  let hold: import('../bar/busy-defaults').HeldMode | null = null;
  report('waiting');

  const showMeeting = async (): Promise<void> => {
    if (hold) return;
    hold = await busy.run('meeting');
    report('showing: meeting');
  };

  const release = async (): Promise<void> => {
    const current = hold;
    hold = null;
    await current?.release().catch(() => {});
    report('idle');
  };

  const onEvent = async (event: SystemEvent): Promise<void> => {
    if (event.type === 'call_state_changed') {
      if (event.app === null) return release();
      return showMeeting();
    }

    /** Theme to show while a call is live */
    if (event.type === 'call_started') return showMeeting();

    if (event.type === 'call_ended') return release();
  };

  const actor = startActor(bus, onEvent);

  return {
    async stop(): Promise<void> {
      await actor.stop();
      const current = hold;
      hold = null;
      await current?.release().catch(() => {});
      report('idle');
    },
  };
}
