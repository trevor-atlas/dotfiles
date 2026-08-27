/**
 * Unit tests for the dumb actor (`startActor`). Run with:
 *   bun test
 *
 * Uses a fake in-memory bus, so no OS, bar, or AppleScript is involved. The
 * actor is pure plumbing: subscription lifecycle only — the bar theme behavior
 * (which needs the bar) is verified by the live daemon smoke test.
 */
import { test, expect } from 'bun:test';
import { createEventBus } from './eventBus';
import { startActor } from './actor';

test('startActor: calls onEvent for every event, stops on stop()', async () => {
  const bus = createEventBus<string>();
  const seen: string[] = [];
  const actor = startActor(bus, (e) => { seen.push(e); });

  bus.publish('a');
  bus.publish('b');
  await sleep(5);
  expect(seen).toEqual(['a', 'b']);

  await actor.stop();

  bus.publish('c');
  await sleep(5);
  expect(seen).toEqual(['a', 'b']); // no longer hears after stop
});

test('startActor: supports async handlers', async () => {
  const bus = createEventBus<string>();
  const seen: string[] = [];
  startActor(bus, async (e) => {
    await sleep(2);
    seen.push(e);
  });

  bus.publish('a');
  await sleep(10);
  expect(seen).toEqual(['a']);
});

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
