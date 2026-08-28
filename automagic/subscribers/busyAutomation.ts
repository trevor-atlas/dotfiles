/**
 * busyAutomation: the busy-bar actor — subscribes to the bus, reads events, and
 * does stuff in reaction.
 *
 * The bus (`systemBus`) is generic: it carries events, and any consumer can
 * react however it likes. This module is the bar side: it subscribes and turns
 * events into bar behavior. Its two jobs:
 *
 *   1. Idle animation. When nothing else is going on, nyan-cat plays
 *      continuously — it's the default display. `playTheme` loops forever, so it
 *      is run UNAWAITED under an `AbortController` (awaiting it would hang the
 *      whole app) and is supervised: a transient bar timeout no longer kills it
 *      for good — the loop backs off and restarts, so the animation self-heals.
 *   2. Calls. On `call_state_changed` (the producer's authoritative full state)
 *      it pauses the idle animation and shows the `meeting` theme, then resumes
 *      nyan when the call ends. Pausing first is what keeps the two from
 *      fighting over the display.
 *
 * The bar is a physical device on the network, so a single request timing out
 * is normal and non-fatal. Every bar call here is wrapped: a timeout becomes a
 * quiet one-line log (deduped per failure streak), never an unhandled rejection.
 *
 * The only input is where the bar lives; the call→theme map is a plain constant.
 */
import { BusyDefaults } from '../bar/busy-defaults';
import { startActor } from '../core/actor';
import type { Actor } from '../core/actor';
import type { EventBus } from '../core/eventBus';
import type { SystemEvent } from '../events/systemEvents';
import type { Reporter } from '../core/board';
import { log } from '../core/logSink';

/** How long to wait before restarting the idle animation after a bar error. */
const NYAN_RETRY_MS = 5000;

/**
 * Start the busy-bar subscriber on `bus`: play nyan-cat as the idle animation,
 * and while a call is live show the `meeting` theme instead. Reflects its status
 * through the injected {@link Reporter}. Returns an {@link Actor stop} that both
 * detaches the subscription and hands the display back.
 */
export function startBarActor(
  bus: EventBus<SystemEvent>,
  report: Reporter,
  bar: ConstructorParameters<typeof BusyDefaults>[0],
): Actor {
  const busy = new BusyDefaults(bar || {});
  let hold: import('../bar/busy-defaults').HeldMode | null = null;

  // Idle-animation supervisor. `nyan` is the live cancel handle; `nyanDone`
  // resolves once the loop (and its final display clear) has fully stopped, so
  // callers can await a clean handoff before drawing something else.
  let nyan: AbortController | null = null;
  let nyanDone: Promise<void> = Promise.resolve();
  let barFailing = false;

  const runNyanLoop = async (signal: AbortSignal): Promise<void> => {
    while (!signal.aborted) {
      try {
        // Resolves only when the signal aborts; rejects on a bar error.
        await busy.playTheme('nyan_cat', { signal });
        barFailing = false;
      } catch (err) {
        if (!barFailing) {
          barFailing = true;
          log(`busy bar: idle animation interrupted (${errMsg(err)}); retrying`);
        }
        await sleep(NYAN_RETRY_MS, signal);
      }
    }
  };

  const startNyan = (): void => {
    if (nyan) return;
    const ctrl = new AbortController();
    nyan = ctrl;
    nyanDone = runNyanLoop(ctrl.signal);
  };

  const stopNyan = async (): Promise<void> => {
    if (!nyan) return;
    nyan.abort();
    nyan = null;
    await nyanDone; // wait for the loop + its display clear to finish
  };

  const showMeeting = async (): Promise<void> => {
    if (hold) return;
    await stopNyan(); // pause the idle animation so the two don't fight
    try {
      hold = await busy.run('meeting');
      report('showing: meeting');
    } catch (err) {
      log(`busy bar: could not show meeting (${errMsg(err)})`);
      startNyan(); // don't get stuck blank — resume idle
      report('idle');
    }
  };

  const release = async (): Promise<void> => {
    const current = hold;
    hold = null;
    try {
      await current?.release();
    } catch {
      // Best-effort: nothing to hand back if the release itself timed out.
    }
    startNyan(); // resume the idle animation
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
  startNyan();
  report('idle');

  return {
    async stop(): Promise<void> {
      await actor.stop();
      await stopNyan();
      const current = hold;
      hold = null;
      try {
        await current?.release();
      } catch {
        // Best-effort on shutdown.
      }
      report('idle');
    },
  };
}

/**
 * A short, single-line message from any thrown value (incl. a DOMException
 * TimeoutError or a stray HTML error body). Whitespace is collapsed and the
 * result is capped so no error can flood the log region.
 */
function errMsg(err: unknown): string {
  const raw =
    err && typeof err === 'object' && 'message' in err
      ? String((err as { message: unknown }).message)
      : String(err);
  const oneLine = raw.replace(/\s+/g, ' ').trim();
  return oneLine.length > 120 ? `${oneLine.slice(0, 117)}…` : oneLine;
}

/** Sleep for `ms`, resolving early if `signal` aborts. */
function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (signal.aborted) return resolve();
    const t = setTimeout(resolve, ms);
    signal.addEventListener(
      'abort',
      () => {
        clearTimeout(t);
        resolve();
      },
      { once: true },
    );
  });
}
