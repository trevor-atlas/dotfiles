/**
 * callDetector: the call source (currently Zoom only). A *producer*: given the
 * bus, it runs a `pollEvery` loop on its own cadence, reads Zoom's window titles
 * via AppleScript, and when whether a call is live changes it publishes events to
 * the bus and updates its current state.
 *
 * A producer owns its whole lifecycle and schedule — the runtime hands `start`
 * the bus and a bound `report` handle. It also logs the transitions it emits, so
 * the daemon wiring doesn't manually subscribe to the bus to surface them.
 *
 * This is the template for future sources (mic audio, a calendar feed, …): their
 * own `pollEvery` loop + plain `bus.publish` on the shared bus.
 */
import { spawnSync } from 'bun';
import type { SystemEvent, CallState } from './systemEvents';
import { pollEvery, type ProducerDescriptor } from './poll';
import { log } from './logSink';

/** How often the call detector samples window titles (its own cadence). */
const CALL_POLL_MS = 3000;

/** The call apps we (currently) understand. Extend this union to add more. */
export type CallApp = 'zoom';

/**
 * Recognise a live call from window titles. Pure.
 *
 * Zoom joins a call by opening a "Zoom Meeting" window (vs. the always-present
 * "Zoom Workplace" window when idle).
 */
export function classifyCall(windowTitles: Iterable<string>): CallApp | null {
  return [...windowTitles].some((t) => t.toLowerCase().includes('zoom meeting'))
    ? 'zoom'
    : null;
}

/** Zoom's window titles, via AppleScript. Empty if Zoom isn't running. */
function zoomWindowTitles(): string[] {
  const appleScript = `
    tell application "System Events"
      try
        set theProcess to first process whose name contains "zoom"
        tell theProcess to return name of every window
      on error
        return ""
      end try
    end tell
  `;
  const proc = spawnSync(['osascript', '-e', appleScript]);
  const output = proc.stdout.toString().trim();
  if (!output || output.includes('error')) return [];
  return output
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

/**
 * The call detector as a self-naming, self-reporting producer descriptor. The
 * runtime binds a board reporter to this component's row before `start` runs;
 * `start` reflects the live call state through `report` and publishes events.
 */
export const callDetector: ProducerDescriptor<CallState, SystemEvent> = {
  name: 'call detector',
  start: (bus, report) => {
    let currentApp: CallApp | null = null;

    const tick = () => {
      const app = classifyCall(zoomWindowTitles());
      if (app === currentApp) return;

      if (currentApp !== null) {
        bus.publish({ type: 'call_ended', app: currentApp });
        log('call ended');
      }
      if (app !== null) {
        bus.publish({ type: 'call_started', app });
        log('call started');
      }
      bus.publish({ type: 'call_state_changed', app });

      currentApp = app;
      report(app === null ? 'idle' : `call: ${app}`);
    };

    // Report the initial state; the first tick runs synchronously below and
    // will overwrite this the moment it observes a live call.
    report('idle');

    const loop = pollEvery(CALL_POLL_MS, tick);
    return {
      getCurrentState: () => ({ app: currentApp }),
      stop: loop.stop,
      done: loop.done,
    };
  },
};
