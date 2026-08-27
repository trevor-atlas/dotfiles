/**
 * board: the observable model behind the terminal UI. It holds an ordered list
 * of named rows split across two kinds — producers and subscribers — where each
 * row carries a single live status string that its component overwrites.
 *
 * A component calls {@link Board.addRow} once to claim a row and gets back a
 * {@link Reporter}: a write-handle bound to THAT row. Every call replaces that
 * row's value wholesale (no appending, no structure) and notifies listeners.
 * Row identity is the returned reporter captured at add time, never the name —
 * so two rows sharing a name stay independent.
 *
 * The board is the single writer: {@link Board.snapshot} hands out readonly rows
 * so the view can render but not mutate. All presentation (filtering by kind,
 * color, layout) lives in the view, not here. Use {@link createBoard} for fresh
 * boards in tests.
 *
 * ```ts
 * const board = createBoard();
 * const report = board.addRow('producer', 'zoom');
 * board.subscribe(() => render(board.snapshot()));
 * report('active'); // that row's value becomes 'active', listeners fire
 * ```
 *
 * This module intentionally imports nothing from the rest of the project, so it
 * is trivially testable in isolation.
 */

export type RowKind = 'producer' | 'subscriber';

/** The write-handle a component uses to overwrite its row's value. */
export type Reporter = (value: string) => void;

export interface BoardRow {
  readonly kind: RowKind;
  readonly name: string;
  readonly value: string;
}

/** Initial placeholder value for a freshly added row (U+2026). */
const PLACEHOLDER = '…';

export class Board {
  private readonly rows: BoardRow[] = [];
  private readonly listeners = new Set<() => void>();

  /**
   * Append a row and return a reporter bound to it. Calling the reporter
   * replaces only that row's value and notifies subscribers.
   */
  addRow(kind: RowKind, name: string): Reporter {
    const index = this.rows.length;
    this.rows.push({ kind, name, value: PLACEHOLDER });
    return (value: string) => {
      this.rows[index] = { kind, name, value };
      this.notify();
    };
  }

  /** Register a change listener. Returns an unsubscribe function. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** All rows in insertion order across both kinds (view filters by kind). */
  snapshot(): readonly BoardRow[] {
    return [...this.rows];
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** Construct a fresh, isolated board (tests, or feature-local use). */
export function createBoard(): Board {
  return new Board();
}
