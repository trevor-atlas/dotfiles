/**
 * Unit tests for the bounded observable log buffer (`LogSink`). Run with:
 *   bun test
 *
 * Every test uses `createLogSink` for an isolated instance, so tests never
 * share state. Assertions observe external behavior only (snapshot, subscribe
 * notifications, console mirroring) — never private fields.
 */
import { test, expect } from 'bun:test';
import { createLogSink } from './logSink';

test('append adds a line; snapshot returns lines oldest-first', () => {
  const sink = createLogSink();
  sink.setMirror(false);

  sink.append('first');
  sink.append('second');
  sink.append('third');

  expect(sink.snapshot()).toEqual(['first', 'second', 'third']);
});

test('the ring is bounded: oldest lines drop, newest are retained', () => {
  const cap = 3;
  const sink = createLogSink(cap);
  sink.setMirror(false);

  for (const line of ['a', 'b', 'c', 'd', 'e']) {
    sink.append(line);
  }

  expect(sink.snapshot()).toEqual(['c', 'd', 'e']);
  expect(sink.snapshot().length).toBe(cap);
});

test('subscribe fires on append; unsubscribe stops further notifications', () => {
  const sink = createLogSink();
  sink.setMirror(false);

  let count = 0;
  const unsub = sink.subscribe(() => { count += 1; });

  sink.append('one');
  sink.append('two');
  expect(count).toBe(2);

  unsub();
  sink.append('three');
  expect(count).toBe(2);
});

test('mirror off: append does not call console.log', () => {
  const sink = createLogSink();
  sink.setMirror(false);

  const captured: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => { captured.push(String(args[0])); };
  try {
    sink.append('silent');
  } finally {
    console.log = original;
  }

  expect(captured).toEqual([]);
});

test('mirror on (default): append writes the line via console.log', () => {
  const sink = createLogSink();

  const captured: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => { captured.push(String(args[0])); };
  try {
    sink.append('loud');
  } finally {
    console.log = original;
  }

  expect(captured).toEqual(['loud']);
});
