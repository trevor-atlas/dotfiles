/**
 * Unit tests for the Runtime registry — the component lifecycle used by the
 * daemon's top-level wiring. Run with:
 *   bun test
 *
 * Excludes OS, BUSY Bar, and AppleScript (they're injected as fakes here),
 * and asserts only the shutdown contract the daemon relies on:
 *   - producers are stopped before the actor;
 *   - `stopAll()` is idempotent;
 *   - a component that fails to stop doesn't halt the others.
 */
import { test, expect } from 'bun:test';
import { createEventBus } from './eventBus';
import { Runtime, type Stoppable } from './runtime';

function fake(order: string[], name: string, fail = false): Stoppable {
  return {
    stop: async () => {
      order.push(name);
      if (fail) throw new Error(`${name} failed`);
    },
  };
}

test('Runtime: stops producers before the actor (lanes, not registration order)', async () => {
  const runtime = new Runtime(createEventBus<string>());
  const order: string[] = [];
  // Register the actor FIRST, producers after — cleanup must still do producers then actor.
  runtime.registerActor(() => fake(order, 'actor'));
  runtime.registerProducers(() => fake(order, 'producer-a'), () => fake(order, 'producer-b'));

  await runtime.stopAll();
  expect(order).toEqual(['producer-a', 'producer-b', 'actor']);
});

test('Runtime: stopAll is idempotent (double shutdown stops once)', async () => {
  const runtime = new Runtime(createEventBus<string>());
  let calls = 0;
  runtime.registerProducers(() => ({ stop: async () => { calls++; } }));

  await runtime.stopAll();
  await runtime.stopAll();
  expect(calls).toBe(1);
});

test("Runtime: a failing stop doesn't halt the others, but surfaces an error", async () => {
  const runtime = new Runtime(createEventBus<string>());
  const order: string[] = [];
  runtime.registerProducers(
    () => fake(order, 'a', true),
    () => fake(order, 'b'),
  );

  await expect(runtime.stopAll()).rejects.toThrow();
  // b still got stopped even though a threw.
  expect(order).toEqual(['a', 'b']);
});

test('Runtime: registration is chainable (register returns the runtime)', () => {
  const runtime = new Runtime(createEventBus<string>());
  expect(runtime.registerProducers(() => ({ stop: async () => {} }))).toBe(runtime);
});
