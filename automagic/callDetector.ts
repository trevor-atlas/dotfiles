/**
 * callDetector: the call source (currently Zoom only). A *producer*: given the
 * bus, it runs a `pollEvery` loop on its own cadence, reads Zoom's window titles
 * via AppleScript, and when whether a call is live changes it publishes events to
 * the bus and updates its current state.
 *
 * A producer owns its whole lifecycle and schedule — the caller just hands it the
 * bus (`(bus) => handle`). It also logs the transitions it emits, so the daemon
 * wiring doesn't manually subscribe to the bus to surface them.
 *
 * This is the template for future sources (mic audio, a calendar feed, …): their
 * own `pollEvery` loop + plain `bus.publish` on the shared bus.
 */
import { spawnSync } from 'bun';
import type { EventBus } from './eventBus';
import type { SystemEvent, CallState } from './systemEvents';
import { pollEvery, type Producer, type ProducerHandle } from './poll';

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

const callDetector: Producer<CallState, SystemEvent> = (bus: EventBus<SystemEvent>) => {
  let currentApp: CallApp | null = null;

  const tick = () => {
    const app = classifyCall(zoomWindowTitles());
    if (app === currentApp) return;

    if (currentApp !== null) {
      bus.publish({ type: 'call_ended', app: currentApp });
      console.log('call ended');
    }
    if (app !== null) {
      bus.publish({ type: 'call_started', app });
      console.log('call started');
    }
    bus.publish({ type: 'call_state_changed', app });

    currentApp = app;
  };

  const loop = pollEvery(CALL_POLL_MS, tick);
  return {
    getCurrentState: () => ({ app: currentApp }),
    stop: loop.stop,
    done: loop.done,
  };
};

export default callDetector;
