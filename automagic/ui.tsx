/**
 * ui: the Ink (React) terminal view for the daemon. It renders the observable
 * {@link Board} as two named-row sections — producers and subscribers — with a
 * log pane below fed by the shared {@link LogSink}. All presentation lives here
 * (padding, bold headers, dim log lines); the board model stays a plain string
 * per row.
 *
 * The view is a pure reader: it never mutates the board or sink, only mirrors
 * their `snapshot()` and re-renders on `subscribe()`. Exit is caller-owned —
 * {@link renderBoard} mounts with `exitOnCtrlC: false` and calls `opts.onExit`
 * on `q`/Ctrl-C, so the daemon decides how to tear down. Input is guarded so a
 * non-TTY stdin (tests, sandboxes) never throws "Raw mode is not supported".
 *
 * ```ts
 * const ui = renderBoard(board, logSink, { onExit: () => ui.unmount() });
 * await ui.waitUntilExit();
 * ```
 */

import React, { useEffect, useState } from 'react';
import { Box, Text, render, useInput, useStdin } from 'ink';
import { Board, type BoardRow } from './board';
import { LogSink } from './logSink';

/** Width of the name column so row values line up. */
const NAME_WIDTH = 16;
/** Number of trailing log lines shown in the pane. */
const LOG_LINES = 10;

function Section({ title, rows }: { title: string; rows: readonly BoardRow[] }) {
  return (
    <Box flexDirection="column">
      <Text bold>{title}</Text>
      {rows.map((row, i) => (
        <Box key={i}>
          <Text>{row.name.padEnd(NAME_WIDTH)}</Text>
          <Text>{row.value}</Text>
        </Box>
      ))}
    </Box>
  );
}

function App({
  board,
  logSink,
  onExit,
}: {
  board: Board;
  logSink: LogSink;
  onExit: () => void;
}) {
  const [rows, setRows] = useState<readonly BoardRow[]>(board.snapshot());
  const [lines, setLines] = useState<readonly string[]>(logSink.snapshot());
  const { isRawModeSupported } = useStdin();

  useEffect(() => board.subscribe(() => setRows(board.snapshot())), [board]);
  useEffect(() => logSink.subscribe(() => setLines(logSink.snapshot())), [logSink]);

  useInput(
    (input, key) => {
      if (input === 'q' || (key.ctrl && input === 'c')) onExit();
    },
    // Coerce to a strict boolean: Ink's isRawModeSupported is stdin.isTTY, which
    // is `undefined` (not `false`) on a non-TTY stdin, and useInput only skips
    // raw mode when isActive === false — undefined would still throw.
    { isActive: Boolean(isRawModeSupported) },
  );

  const producers = rows.filter((r) => r.kind === 'producer');
  const subscribers = rows.filter((r) => r.kind === 'subscriber');
  const tail = lines.slice(-LOG_LINES);

  return (
    <Box flexDirection="column">
      <Section title="Producers" rows={producers} />
      <Section title="Subscribers" rows={subscribers} />
      <Text dimColor>{'─'.repeat(NAME_WIDTH + 8)}</Text>
      {tail.map((line, i) => (
        <Text key={i} dimColor>
          {line}
        </Text>
      ))}
    </Box>
  );
}

/**
 * Mount the terminal view. Exit stays caller-owned (`exitOnCtrlC: false`); the
 * returned handles let the daemon await teardown or unmount imperatively.
 */
export function renderBoard(
  board: Board,
  logSink: LogSink,
  opts: { onExit: () => void },
): { waitUntilExit: () => Promise<void>; unmount: () => void } {
  const instance = render(<App board={board} logSink={logSink} onExit={opts.onExit} />, {
    exitOnCtrlC: false,
  });
  return { waitUntilExit: instance.waitUntilExit, unmount: instance.unmount };
}
