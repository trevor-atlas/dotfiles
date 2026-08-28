/**
 * main: top-level wiring for the call-automation daemon + live TUI.
 *
 * Composes the decoupled pieces over the shared `systemBus` on a `Runtime`, and
 * mounts the Ink board that renders their live status:
 *   - the call detector (a producer that owns its own poll cadence) publishes
 *     call events and reports its state to its board row;
 *   - the bar subscriber (`startBarActor`) reads events off the bus and reacts —
 *     today by showing/releasing a bar theme on call-state changes — reporting
 *     to its own row;
 *   - the board + shared `logSink` feed the Ink view (`renderBoard`), which owns
 *     the terminal lifecycle: `q`/Ctrl-C triggers `onExit`.
 *
 * Ink owns the screen; the runtime owns resources. `shutdown()` stops the
 * producer (halts polling) then the subscriber (releases the bar), then unmounts
 * the view. After the view exits we re-enable console output and print a final
 * line. No manual bus subscription or `detector.done` plumbing here.
 *
 * Usage:
 *   bun main.ts [--host 192.168.50.85]
 */
import { parseArgs } from 'util';
import { systemBus } from './events/systemEvents';
import { Runtime } from './core/runtime';
import { startBarActor } from './subscribers/busyAutomation';
import { callDetector } from './producers/callDetector';
import { githubEventDetector } from './producers/githubEvents';
import { Board } from './core/board';
import { logSink, log } from './core/logSink';
import { renderBoard } from './ui/ui';

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    host: { type: 'string', default: '192.168.50.85' },
    access: { type: 'string', default: '8700494362' },
  },
});

const board = new Board();

// Ink now owns the screen — the log pane shows these lines, so stop mirroring
// them to the raw console (which Ink would otherwise capture and garble).
logSink.setMirror(false);

const runtime = new Runtime(systemBus, board);

// Subscribe/start the subscriber BEFORE the producer starts polling. The
// producer's first tick runs synchronously on registration (see `pollEvery`),
// so if we registered it first it would publish `call_state_changed` (and
// `call started`) before the bar subscriber was listening — the initial
// full-state event would be missed and, since the producer only republishes on
// a change, the bar would stay dark for the whole meeting.
//
// Shutdown order is independent of this: `stopAll()` always stops producers
// before subscribers ([...producers, ...subscribers]), so the bar is released last.
runtime.registerSubscriber({
  name: 'busy bar',
  start: (bus, report) =>
    startBarActor(bus, report, {
      host: values.host,
      HTTPAccessPassword: values.access,
    }),
});
runtime.registerProducer(callDetector);
runtime.registerProducer(githubEventDetector);

log(`call automation started · bar ${values.host} · press q or Ctrl-C to stop`);

const ui = renderBoard(board, logSink, {
  onExit: () => {
    void shutdown(0);
  },
});

let shuttingDown = false;
let exitCode = 0;

// Ink owns the lifecycle; the runtime owns resources. Guarded so a signal and a
// Ctrl-C (or two signals) can't double-run teardown.
async function shutdown(code: number): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  exitCode = code;
  try {
    await runtime.stopAll();
  } catch (err) {
    log(`error during shutdown: ${err}`);
  }
  ui.unmount();
}

// Backstops only — Ink handles Ctrl-C via `onExit` while mounted; these cover
// SIGTERM and a SIGINT that arrives before/after the view is listening.
process.on('SIGINT', () => void shutdown(0));
process.on('SIGTERM', () => void shutdown(0));

await ui.waitUntilExit();

// The view is down — restore console output and end the process. The poll loop's
// timers keep the event loop alive, so exit explicitly.
logSink.setMirror(true);
console.log('call automation stopped.');
process.exit(exitCode);
