/**
 * Unit tests for the decoupled event-bus + classification pieces. Run with:
 *   bun test
 *
 * Each piece is exercised in isolation (no BUSY Bar, no AppleScript):
 *   - the dumb bus: publish → broadcast to subscribers, unsubscribe works;
 *   - the pure classifier: title sets → call app (the real decision logic).
 */
import { test, expect } from 'bun:test';
import { createEventBus } from './eventBus';
import type { SystemEvent } from './systemEvents';
import { classifyCall } from './callDetector';

test('bus: publishes to all subscribers, unsubscribe removes', async () => {
  const bus = createEventBus<SystemEvent>();
  const a: string[] = [];
  const b: string[] = [];

  const unsubA = bus.subscribe((e) => { a.push(e.type); });
  bus.subscribe((e) => { b.push(e.type); });

  bus.publish({ type: 'call_started', app: 'zoom' });
  await sleep(5);
  expect(a).toEqual(['call_started']);
  expect(b).toEqual(['call_started']);

  unsubA();
  bus.publish({ type: 'call_ended', app: 'zoom' });
  await sleep(5);
  expect(a).toEqual(['call_started']); // A no longer hears
  expect(b).toEqual(['call_started', 'call_ended']);
});

test('classifyCall: maps zoom window titles to in-call / idle', () => {
  // zoom in a call (a Zoom Meeting window is open) vs. idle (Workplace only).
  expect(classifyCall(['Zoom Workplace', 'Zoom Meeting'])).toBe('zoom');
  expect(classifyCall(['Zoom Workplace'])).toBeNull();
  // lowercase / arbitrary casing is still matched.
  expect(classifyCall(['zoom meeting'])).toBe('zoom');
  // unrelated windows / nothing.
  expect(classifyCall(['Visual Studio Code'])).toBeNull();
  expect(classifyCall([])).toBeNull();
});

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
