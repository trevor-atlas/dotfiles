/**
 * Unit tests for the Runtime registry — the component lifecycle used by the
 * daemon's top-level wiring. Run with:
 *   bun test
 *
 * Excludes OS, BUSY Bar, and AppleScript (they're injected as fakes here),
 * and asserts the contract the daemon relies on:
 *   - producers are stopped before subscribers;
 *   - `stopAll()` is idempotent;
 *   - a component that fails to stop doesn't halt the others;
 *   - a Board (when injected) gets a row per registered descriptor, and the
 *     reporter handed into `start` writes that row;
 *   - with NO board, `start` still receives a safe no-op reporter.
 */
import { test, expect } from 'bun:test';
import { createEventBus } from './eventBus';
import { createBoard, type Reporter } from './board';
import { Runtime, type Stoppable } from './runtime';
import type { ProducerDescriptor, SubscriberDescriptor } from './poll';

function fake(order: string[], name: string, fail = false): Stoppable {
  return {
    stop: async () => {
      order.push(name);
      if (fail) throw new Error(`${name} failed`);
    },
  };
}

/** Build a producer descriptor whose `start` returns the given stoppable. */
function producer(
  name: string,
  handle: Stoppable,
): ProducerDescriptor<unknown, string> {
  return {
    name,
    start: () => ({ getCurrentState: () => null, stop: handle.stop, done: Promise.resolve() }),
  };
}

/** Build a subscriber descriptor whose `start` returns the given stoppable. */
function subscriber(name: string, handle: Stoppable): SubscriberDescriptor<string> {
  return { name, start: () => ({ stop: handle.stop }) };
}

test('Runtime: stops producers before subscribers (lanes, not registration order)', async () => {
  const runtime = new Runtime(createEventBus<string>());
  const order: string[] = [];
  // Register the subscriber FIRST, producers after — cleanup must still do
  // producers then subscribers.
  runtime.registerSubscriber(subscriber('subscriber', fake(order, 'subscriber')));
  runtime.registerProducer(producer('producer-a', fake(order, 'producer-a')));
  runtime.registerProducer(producer('producer-b', fake(order, 'producer-b')));

  await runtime.stopAll();
  expect(order).toEqual(['producer-a', 'producer-b', 'subscriber']);
});

test('Runtime: stopAll is idempotent (double shutdown stops once)', async () => {
  const runtime = new Runtime(createEventBus<string>());
  let calls = 0;
  runtime.registerProducer(producer('p', { stop: async () => { calls++; } }));

  await runtime.stopAll();
  await runtime.stopAll();
  expect(calls).toBe(1);
});

test("Runtime: a failing stop doesn't halt the others, but surfaces an error", async () => {
  const runtime = new Runtime(createEventBus<string>());
  const order: string[] = [];
  runtime.registerProducer(producer('a', fake(order, 'a', true)));
  runtime.registerProducer(producer('b', fake(order, 'b')));

  await expect(runtime.stopAll()).rejects.toThrow();
  // b still got stopped even though a threw.
  expect(order).toEqual(['a', 'b']);
});

test('Runtime: registration is chainable (register returns the runtime)', () => {
  const runtime = new Runtime(createEventBus<string>());
  expect(runtime.registerProducer(producer('p', { stop: async () => {} }))).toBe(runtime);
  expect(runtime.registerSubscriber(subscriber('s', { stop: async () => {} }))).toBe(runtime);
});

test('Runtime: with a Board, registering adds rows of the right kind/name', () => {
  const board = createBoard();
  const runtime = new Runtime(createEventBus<string>(), board);

  runtime.registerProducer(producer('call detector', { stop: async () => {} }));
  runtime.registerSubscriber(subscriber('busy bar', { stop: async () => {} }));

  const snapshot = board.snapshot();
  expect(snapshot.map((r) => ({ kind: r.kind, name: r.name }))).toEqual([
    { kind: 'producer', name: 'call detector' },
    { kind: 'subscriber', name: 'busy bar' },
  ]);
});

test('Runtime: the reporter handed into start writes that component\u2019s row', () => {
  const board = createBoard();
  const runtime = new Runtime(createEventBus<string>(), board);

  runtime.registerProducer({
    name: 'call detector',
    start: (_bus, report: Reporter) => {
      report('call: zoom');
      return { getCurrentState: () => null, stop: async () => {}, done: Promise.resolve() };
    },
  });

  const row = board.snapshot().find((r) => r.name === 'call detector');
  expect(row?.value).toBe('call: zoom');
});

test('Runtime: with no board, start still gets a safe no-op reporter (no rows, no throw)', () => {
  const runtime = new Runtime(createEventBus<string>());
  let received: Reporter | null = null;

  runtime.registerProducer({
    name: 'call detector',
    start: (_bus, report: Reporter) => {
      received = report;
      return { getCurrentState: () => null, stop: async () => {}, done: Promise.resolve() };
    },
  });

  expect(typeof received).toBe('function');
  // Calling the no-op reporter must not throw.
  expect(() => received!('anything')).not.toThrow();
});
