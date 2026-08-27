/**
 * main: top-level wiring for the call-automation daemon.
 *
 * Composes the decoupled pieces over the shared `systemBus` on a `Runtime`:
 *   - the call detector (a producer that owns its own poll cadence) publishes
 *     call events;
 *   - the bar actor (`startBarActor`) subscribes to the bus, reads events, and
 *     reacts — today by showing/releasing a bar theme on call-state changes.
 *
 * The runtime owns shutdown: on SIGINT/SIGTERM it stops the producer (halts its
 * poll loop, no new events) *then* the actor (releases the bar). No manual
 * `await detector.done` / `await actor.stop()` plumbing here.
 *
 * Usage:
 *   bun main.ts [--host 192.168.50.85]
 */
import { parseArgs } from 'util';
import { systemBus } from './systemEvents';
import { Runtime } from './runtime';
import { startBarActor } from './busyAutomation';
import callDetector from './callDetector';

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    host: { type: 'string', default: '192.168.50.85' },
    access: { type: 'string', default: '8700494362' },
  },
});

const runtime = new Runtime(systemBus);

// Subscribe/start the actor BEFORE the producer starts polling. The producer's
// first tick runs synchronously on registration (see `pollEvery`), so if we
// registered it first it would publish `call_state_changed` (and `call started`)
// before the bar actor was listening — the initial full-state event would be
// missed and, since the producer only republishes on a change, the bar would
// stay dark for the whole meeting.
//
// Shutdown order is independent of this: `stopAll()` always stops producers
// before actors ([...producers, ...actors]), so the bar is still released last.
runtime.registerActor((bus) =>
  startBarActor(bus, {
    host: values.host,
    HTTPAccessPassword: values.access,
  }),
);
runtime.registerProducers(callDetector);

let shuttingDown = false;
const shutdown = async (code: number): Promise<void> => {
  if (shuttingDown) return;
  shuttingDown = true;
  try {
    await runtime.stopAll();
    console.log('call automation stopped.');
  } catch (err) {
    console.error('error during shutdown:', err);
  }
  process.exit(code);
};

process.once('SIGINT', () => {
  console.log('\nstopping…');
  void shutdown(0);
});
process.once('SIGTERM', () => void shutdown(0));

console.log('🚀 call automation is listening for Zoom meeting windows...');
console.log(`\tbar ${values.host}  (Ctrl-C to stop)\n`);
