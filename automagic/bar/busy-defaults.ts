/**
 * Busy Defaults: activate one of the BUSY Bar's built-in modes programmatically.
 *
 * Thin, typed wrapper around the {@link @busy-app/busy-lib!BusyBar} HTTP client. It hands
 * a stored profile to the timer and lets the bar render its own built-in mode —
 * it never draws anything itself, so other apps can render over it.
 *
 * Modes:
 *   - `'busy'`   → the BUSY profile, as configured on the bar (slot `busy`).
 *   - a theme    → the CUSTOM profile, themed with that name (slot `custom`).
 *     Theme names are validated against what stock firmware ships, so a typo
 *     fails up front instead of silently leaving the bar on its default.
 *   - `stop()`         → stop the running session (releases the display).
 *   - `playTheme()`    → render a built-in animation theme (e.g. `'nyan_cat'`).
 *
 * If you hold a started mode, you can release it later — but only if the bar is
 * still running that exact mode (times advance, identity doesn't). If you switch
 * modes on the bar, or another tool takes over, release leaves that session alone.
 *
 * The module also re-exports the reusable display/bitmap primitives from
 * `./display` (PNG encoding, pixel buffers, full-frame image streaming) and the
 * nyan-cat renderer, so new themes can be added without reinventing those parts.
 */
import { BusyBar } from '@busy-app/busy-lib';
import type {
  BusyProfile,
  BusyProfileSlot,
  BusySnapshot,
  BusySnapshotSetParams,
  BusyBarConfig,
} from '@busy-app/busy-lib';
import { NyanCatPlayer } from './nyan-cat';

export const APP = 'busy-defaults';

/** Built-in animation themes the module can render on the display. */
export const ANIMATION_THEMES = ['nyan_cat'] as const;
export type AnimationTheme = (typeof ANIMATION_THEMES)[number];

/** Options for {@link BusyDefaults.playTheme}. */
export interface PlayThemeOptions {
  /** Target frames per second (default 12.5). */
  fps?: number;
  /** Abort when this signal fires (e.g. SIGINT) to stop and clear the display. */
  signal?: AbortSignal;
  /** Stop after this many milliseconds (in addition to any `signal`). */
  durationMs?: number;
}

/** Themes stock firmware ships, plus control words. */
export const KNOWN_THEMES = [
  'busy',
  'keep_out',
  'dnd',
  'meeting',
  'on_call',
  'lunch',
  'back_soon',
  'booked',
  'flow',
  'chill_time',
  'on_air',
  'coding',
  'low_social_battery',
] as const;

export type Theme = (typeof KNOWN_THEMES)[number];

/**
 * Every theme the app can show, stock firmware themes plus built-in animation
 * themes — treated as one cohesive set. `'nyan_cat'` is an animation; the rest
 * run the stored BUSY/CUSTOM profile with that theme.
 */
export const THEMES: (Theme | AnimationTheme)[] = [
  ...KNOWN_THEMES,
  ...ANIMATION_THEMES,
];
export type AnyTheme = Theme | AnimationTheme;
export type Mode = AnyTheme | 'off';

/** Union of the bar's two built-in profile slots. Kept for clarity. */
export type Slot = BusyProfileSlot;

/** A snapshot that can be sent to the timer. */
export type SnapshotBody = BusySnapshot['snapshot'];

/** Options used to reach a particular bar. See {@link @busy-app/busy-lib!BusyBarConfig}. */
export interface BusyDefaultsOptions {
  /** Bar address. Defaults to the lib default (the USB-Ethernet bridge). */
  addr?: string;
  /** Alias for `addr`; kept for parity with the original CLI naming. */
  host?: string;
  /** HTTP access password, if the bar requires one. */
  HTTPAccessPassword?: string;
  /** Bearer token for the BUSY proxy. */
  token?: string;
  /** Per-request timeout in ms (default: the lib's 3000). */
  timeout?: number;
}

/** What actually lives in the mode the bar is running. */
interface RunningSpec {
  type: string;
  card_id?: string;
  theme: string;
}

/** What the display currently looks like, and the draw priority a theme faces. */
export interface SessionStatus {
  /** Snapshot discriminator (`NOT_STARTED`, `SIMPLE`, `INTERVAL`, `INFINITE`). */
  type: string;
  /** Whether an active work session owns the screen. */
  running: boolean;
  /** Theme currently applied on the bar. */
  theme: string;
  /** Effective priority an idle (priority-10) draw must beat, or null if unknown. */
  priority: number | null;
  /** Human-readable verdict. */
  display: string;
}

/** A human-readable summary of a stored profile. */
export interface ProfileSummary {
  slot: Slot;
  title: string;
  timer: string;
  theme: string;
  toString(): string;
}

/** Handle to a held mode; release it to hand the display back. */
export interface HeldMode {
  /** The slot the mode was started from. */
  slot: Slot;
  /** Theme override that was applied (or the stored one). */
  theme: string | null;
  /**
   * Ask the bar to stop the mode. Releases only if the running mode is still
   * the one we started; otherwise it's a no-op that reports the switch.
   */
  release(options?: RequestOptionsLike): Promise<string>;
}

/** Per-request knobs forwarded to the underlying HTTP client. */
export interface RequestOptionsLike {
  timeout?: number;
  signal?: AbortSignal;
}

/** Options for {@link BusyDefaults.cycle}. */
export interface CycleOptions {
  /** How long each theme stays up in ms (default 5000). */
  durationMs?: number;
  /** Abort to end the cycle early (stops + clears the display). */
  signal?: AbortSignal;
  /** Nyan-cat fps when an animation theme is shown (default 12.5). */
  fps?: number;
  /** Called with each theme as it starts. */
  onTheme?: (theme: AnyTheme) => void;
}

/** Small pause between themes so the transition is visible. */
const GAP_MS = 400;

/** True if `mode` is one of the built-in animation themes. */
export function isAnimationTheme(mode: string): mode is AnimationTheme {
  return (ANIMATION_THEMES as readonly string[]).includes(mode);
}

/**
 * Map a mode onto `(slot, theme override)`. `null` theme = keep the stored one.
 */
export function resolveMode(mode: Exclude<Mode, 'off' | AnimationTheme>): {
  slot: Slot;
  theme: string | null;
} {
  if (mode === 'busy') return { slot: 'busy', theme: null };
  return { slot: 'custom', theme: mode };
}

/**
 * Turn a stored profile into a snapshot that starts it from the top.
 */
export function snapshotFor(profile: BusyProfile, theme?: string | null): SnapshotBody {
  const settings = profile.timer_settings;
  const kind = settings.type;
  const snap: Record<string, unknown> = {
    type: kind,
    card_id: profile.id,
    is_paused: false,
  };

  if (kind === 'SIMPLE') {
    snap['time_left_ms'] = settings.total_time_ms;
  } else if (kind === 'INTERVAL') {
    snap['current_interval'] = 0;
    snap['current_interval_time_total_ms'] = settings.interval_work_ms;
    snap['current_interval_time_left_ms'] = settings.interval_work_ms;
    snap['interval_settings'] = settings;
  } else if (kind !== 'INFINITE') {
    throw new Error(`unsupported timer type in profile: ${kind}`);
  }

  // busy_bar_settings rides along with every snapshot; theme lives in there.
  const bar = { ...profile.busy_bar_settings };
  if (theme) bar.theme = theme;
  snap['busy_bar_settings'] = bar;

  return snap as SnapshotBody;
}

/** A NOT_STARTED snapshot that reuses whatever busy_bar_settings are running. */
export function stopSnapshot(current: BusySnapshot): SnapshotBody {
  const bar = current.snapshot.busy_bar_settings;
  return { type: 'NOT_STARTED', busy_bar_settings: bar };
}

/**
 * Does the bar still run the mode we started? Times advance, identity doesn't.
 * A NOT_STARTED snapshot has no card_id, so it can never be "ours".
 */
export function isStillOurs(
  current: BusySnapshot['snapshot'],
  started: SnapshotBody,
): boolean {
  const cur = specOf(current);
  const beg = specOf(started);
  return cur.type === beg.type && cur.card_id === beg.card_id && cur.theme === beg.theme;
}

/** Project a snapshot onto just the bits that identify a mode. */
function specOf(snapshot: BusySnapshot['snapshot']): RunningSpec {
  const s = snapshot as BusySnapshot['snapshot'] & { card_id?: string };
  return {
    type: s.type,
    card_id: s.card_id,
    theme: s.busy_bar_settings.theme,
  };
}

/** Human-readable description of a stored profile. */
export function describe(profile: BusyProfile, theme?: string | null): string {
  const settings = profile.timer_settings;
  let detail = settings.type.toLowerCase();
  if (settings.type === 'SIMPLE') {
    detail += ` ${Math.floor(settings.total_time_ms / 60000)}min`;
  } else if (settings.type === 'INTERVAL') {
    detail +=
      ` ${Math.floor(settings.interval_work_ms / 60000)}/` +
      `${Math.floor(settings.interval_rest_ms / 60000)}min ` +
      `x${settings.interval_work_cycles_count}`;
  }
  return (
    `'${profile.title}'  timer=${detail}  ` +
    `theme=${theme ?? profile.busy_bar_settings.theme}`
  );
}

export class BusyDefaults {
  readonly bar: BusyBar;

  constructor(options: BusyDefaultsOptions = {}) {
    const config: BusyBarConfig = {
      addr: options.addr ?? options.host,
      HTTPAccessPassword: options.HTTPAccessPassword,
      token: options.token,
      timeout: options.timeout,
    };
    this.bar = new BusyBar(config);
  }

  /** Fetch a stored profile. */
  async getProfile(slot: Slot): Promise<BusyProfile> {
    return this.bar.BusyProfileGet({ slot });
  }

  /** Fetch the current snapshot (what the timer is doing right now). */
  async getSnapshot(): Promise<BusySnapshot> {
    return this.bar.BusySnapshotGet();
  }

  /**
   * Summarize the display-owning state, including the effective draw priority
   * an idle (priority 10) theme would face. `priority` is inferred from the
   * snapshot per the device model, not read from the API:
   *   - active work session (running SIMPLE/INTERVAL/INFINITE)   → 90
   *   - nothing started / paused                                  → screens free (10 wins)
   *   - unknown type                                               → null
   */
  async status(): Promise<SessionStatus> {
    const snap = await this.getSnapshot();
    const s = snap.snapshot;
    const running =
      s.type !== 'NOT_STARTED' && !('is_paused' in s ? s.is_paused : true);
    const priority = running ? 90 : 10; // active work session owns the screen at 90; otherwise a 10 wins
    return {
      type: s.type,
      running,
      theme: s.busy_bar_settings.theme,
      priority,
      display: running ? 'busy (priority-90 work session owns the screen)' : 'free for a priority-10 draw',
    };
  }

  /** Push a snapshot; the bar runs the timer from this state. */
  async setSnapshot(snapshot: SnapshotBody): Promise<void> {
    await this.bar.BusySnapshotSet(makeSetParams(snapshot));
  }

  /** List the stored profiles (useful for exploring the bar). */
  async list(): Promise<ProfileSummary[]> {
    const slots: Slot[] = ['busy', 'custom'];
    const rows = await Promise.all(slots.map((slot) => this.fetchSummary(slot)));
    return rows;
  }

  private async fetchSummary(slot: Slot): Promise<ProfileSummary> {
    const profile = await this.getProfile(slot);
    const label = describe(profile);
    return {
      slot,
      title: profile.title,
      timer: timerSummary(profile.timer_settings.type),
      theme: profile.busy_bar_settings.theme,
      toString: () => `${slot.padEnd(7)} ${label}`,
    };
  }

  /**
   * Stop the running session — releases the display.
   *
   * Reuses whatever busy_bar_settings are currently running, since a
   * NOT_STARTED snapshot still needs them.
   */
  async stop(): Promise<void> {
    const current = await this.getSnapshot();
    await this.setSnapshot(stopSnapshot(current));
  }

  /**
   * Start a mode and run it until told to release.
   *
   * @param mode  `'busy'`, `'off'`, or a theme name.
   * @returns A {@link HeldMode} you can call `.release()` on. For `'off'` it
   *          resolves immediately with a no-op handle.
   */
  async run(
    mode: Mode,
    options?: RequestOptionsLike,
  ): Promise<HeldMode> {
    if (mode === 'off') {
      await this.stop();
      return makeNoopHandle(mode);
    }
    if (isAnimationTheme(mode)) {
      throw new Error(
        `'${mode}' is an animation theme — use playTheme('${mode}') to render it`,
      );
    }

    const { slot, theme } = resolveMode(mode);
    const profile = await this.getProfile(slot);
    const started = snapshotFor(profile, theme);
    await this.setSnapshot(started);

    return makeHoldHandle(this, started, { slot, theme }, options);
  }

  /**
   * Play a built-in animation theme on the display until the (optional) signal
   * fires, then clear it back off the screen. Each frame is rendered as a
   * full-screen image, so the cat can run smoothly without per-rect draws.
   *
   * @param theme A key from {@link ANIMATION_THEMES}.
   * @param options `fps` pacing and an `AbortSignal` to stop + clear.
   * @returns A short status string once rendering stops.
   */
  async playTheme(theme: AnimationTheme, options: PlayThemeOptions = {}): Promise<string> {
    const fps = options.fps ?? 12.5;
    const frameMs = 1000 / fps;
    const signal = options.signal;
    const player = new NyanCatPlayer(this.bar);

    await new Promise<void>((resolve, reject) => {
      let stopped = signal?.aborted ?? false;
      const deadline = options.durationMs ? Date.now() + options.durationMs : null;
      const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

      const loop = async () => {
        while (!stopped && !(deadline !== null && Date.now() >= deadline)) {
          const t0 = Date.now();
          await player.drawFrame();
          const dt = Date.now() - t0;
          if (dt < frameMs) await sleep(frameMs - dt);
        }
      };
      const onAbort = () => {
        if (stopped) return;
        stopped = true;
        resolve(undefined);
      };
      signal?.addEventListener('abort', onAbort, { once: true });
      // Resolve on the duration timer too, so a timed run doesn't hang waiting.
      if (deadline !== null) setTimeout(onAbort, deadline - Date.now());
      loop().then(resolve, reject);
    });

    // Always hand the display back, even if the loop errored mid-run.
    try {
      await player.clear();
    } catch {
      // Swallow: nothing left the screen under our app name.
    }
    return 'stopped.';
  }

  /**
   * Cycle through every theme in {@link THEMES}, showing each one for
   * `durationMs`, then stop the session. Animation themes (e.g. `nyan_cat`)
   * and stock profile themes are all treated as peers.
   *
   * @param options.durationMs How long each theme stays up (default 5000).
   * @param options.signal      Abort to end the cycle early (stops + clears).
   * @param options.onTheme     Hook called with the theme name as each starts.
   * @returns The list of themes shown, in order.
   */
  async cycle(options: CycleOptions = {}): Promise<AnyTheme[]> {
    const durationMs = options.durationMs ?? 5000;
    const signal = options.signal;
    const shown: AnyTheme[] = [];

    for (const theme of THEMES) {
      if (signal?.aborted) break;
      options.onTheme?.(theme);

      let handle: HeldMode | null = null;
      if (isAnimationTheme(theme)) {
        await this.playTheme(theme, { fps: options.fps, signal, durationMs });
      } else {
        handle = await this.run(theme, { signal });
        await sleep(durationMs, signal);
        await handle.release();
      }
      shown.push(theme);

      // Small gap between themes so the change is noticeable.
      if (!signal?.aborted) await sleep(GAP_MS, signal);
    }

    // Stop on end: hand the display back to the timer.
    await this.stop().catch(() => {});
    return shown;
  }

  /**
   * Wait until the given signal fires, then release the held mode if the bar
   * is still running it. Convenience for one-shot CLI-style usage.
   */
  async holdAndRelease(handle: HeldMode, signal: AbortSignal): Promise<string> {
    if (signal.aborted) return await handle.release();
    return await new Promise<string>((resolve, reject) => {
      signal.addEventListener(
        'abort',
        () => {
          handle.release().then(resolve, reject);
        },
        { once: true },
      );
    });
  }
}

// --------------------------------------------------------------------------
// shared display / bitmap abstractions (reusable beyond running profiles)
// --------------------------------------------------------------------------

export {
  encodePng,
  blankBuffer,
  fillRect,
  drawBitmap,
  clearDisplay,
  isLowPriorityDraw,
  BitmapStreamer,
} from './display';
export type { RGB, PixelBuffer, PushedFrame, StreamOptions } from './display';

// --------------------------------------------------------------------------
// nyan-cat theme re-exports
// --------------------------------------------------------------------------

export {
  NyanCat,
  NyanCatPlayer,
  W as NYAN_W,
  H as NYAN_H,
  APP as NYAN_APP,
} from './nyan-cat';

// --------------------------------------------------------------------------
// internals
// --------------------------------------------------------------------------

/** Sleep for `ms`, resolving early if the signal fires. */
function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (signal?.aborted) return resolve();
    const t = setTimeout(resolve, ms);
    signal?.addEventListener('abort', () => {
      clearTimeout(t);
      resolve();
    }, { once: true });
  });
}

function makeSetParams(snapshot: SnapshotBody): BusySnapshotSetParams {
  return {
    snapshot,
    snapshot_timestamp_ms: Date.now(),
  };
}

function timerSummary(type: string): string {
  return type.toLowerCase();
}

function makeNoopHandle(_mode: Mode): HeldMode {
  return {
    slot: 'custom',
    theme: null,
    release: async () => 'session was already stopped',
  };
}

function makeHoldHandle(
  client: BusyDefaults,
  started: SnapshotBody,
  meta: { slot: Slot; theme: string | null },
  options?: RequestOptionsLike,
): HeldMode {
  return {
    slot: meta.slot,
    theme: meta.theme,
    release: () => releaseIfOurs(client, started, options),
  };
}

async function releaseIfOurs(
  client: BusyDefaults,
  started: SnapshotBody,
  options?: RequestOptionsLike,
): Promise<string> {
  try {
    const current = (await client.getSnapshot()).snapshot;
    if (isStillOurs(current, started)) {
      await client.setSnapshot({
        type: 'NOT_STARTED',
        busy_bar_settings: current.busy_bar_settings,
      });
      return 'released.';
    }
    return 'mode changed elsewhere; left it running.';
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return `could not release the mode: ${msg}`;
  }
}
