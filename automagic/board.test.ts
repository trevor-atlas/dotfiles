/**
 * Unit tests for the observable board model (`createBoard`). Run with:
 *   bun test
 *
 * The board is pure in-memory state: no OS, bar, or bus is involved. Tests
 * assert external behavior only — via reporters, subscribe, and snapshot — and
 * never reach into private fields. A fresh board per test keeps them isolated.
 */
import { test, expect } from 'bun:test';
import { createBoard } from './board';

test('addRow: returns a working reporter; fresh row is the placeholder', () => {
  const board = createBoard();
  const report = board.addRow('producer', 'zoom');

  expect(typeof report).toBe('function');
  expect(board.snapshot()).toEqual([{ kind: 'producer', name: 'zoom', value: '…' }]);
});

test('reporter updates its own row and leaves others unchanged', () => {
  const board = createBoard();
  const reportA = board.addRow('producer', 'zoom');
  board.addRow('subscriber', 'bar');

  reportA('active');

  expect(board.snapshot()).toEqual([
    { kind: 'producer', name: 'zoom', value: 'active' },
    { kind: 'subscriber', name: 'bar', value: '…' },
  ]);
});

test('two rows with the same name are independent', () => {
  const board = createBoard();
  const first = board.addRow('producer', 'dup');
  const second = board.addRow('producer', 'dup');

  first('one');

  expect(board.snapshot()).toEqual([
    { kind: 'producer', name: 'dup', value: 'one' },
    { kind: 'producer', name: 'dup', value: '…' },
  ]);

  second('two');

  expect(board.snapshot()).toEqual([
    { kind: 'producer', name: 'dup', value: 'one' },
    { kind: 'producer', name: 'dup', value: 'two' },
  ]);
});

test('snapshot preserves insertion order and each row kind', () => {
  const board = createBoard();
  board.addRow('subscriber', 'first');
  board.addRow('producer', 'second');
  board.addRow('subscriber', 'third');

  expect(board.snapshot().map((r) => [r.kind, r.name])).toEqual([
    ['subscriber', 'first'],
    ['producer', 'second'],
    ['subscriber', 'third'],
  ]);
});

test('subscribe fires on report; unsubscribe stops notifications', () => {
  const board = createBoard();
  const report = board.addRow('producer', 'zoom');
  let calls = 0;
  const unsubscribe = board.subscribe(() => { calls += 1; });

  report('a');
  expect(calls).toBe(1);

  report('b');
  expect(calls).toBe(2);

  unsubscribe();
  report('c');
  expect(calls).toBe(2);
});
