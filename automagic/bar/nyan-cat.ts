/**
 * Nyan cat: pop-tart cat with a rainbow trail and twinkling stars.
 *
 * A built-in animation theme for the BUSY Bar. Each frame is composed into a
 * single 72x16 bitmap and pushed as one image element via the reusable
 * `BitmapStreamer` from `./display`. The cat is ~65 rects; drawing them
 * individually would cost ~3.6 ms each (~4 fps on real hardware), while one
 * full-frame image is a flat ~50 ms, so it runs smooth.
 *
 * This file holds only what makes nyan *nyan*: the palette and the per-frame
 * composition (stars, rainbow, cat). Bitmap handling, PNG encoding, upload and
 * clear all live in `./display` so other themes can reuse them.
 */
import { blankBuffer, fillRect } from './display';
import type { RGB } from './display';

import type { BusyBar } from '@busy-app/busy-lib';
import { BitmapStreamer } from './display';

export const APP = 'nyan-cat';
export const W = 72;
export const H = 16;

// --- palette (colors as (r, g, b)) ---------------------------------------

export const CRUST: RGB = [0xff, 0xcc, 0x99];
export const FROSTING: RGB = [0xff, 0x99, 0xff];
export const SPRINKLE: RGB = [0xdd, 0x33, 0x88];
export const GRAY: RGB = [0x99, 0x99, 0x99];
export const BLACK: RGB = [0x00, 0x00, 0x00];
export const CHEEK: RGB = [0xff, 0x99, 0x99];
export const STAR: RGB = [0xff, 0xff, 0xff];
export const RAINBOW: RGB[] = [
  [0xff, 0x00, 0x00],
  [0xff, 0x99, 0x00],
  [0xff, 0xff, 0x00],
  [0x33, 0xff, 0x00],
  [0x00, 0x99, 0xff],
  [0x66, 0x33, 0xff],
];

/** Pop-tart body top-left. */
export const CX = 44;
/** Pop-tart body top y. */
export const BY = 3;
/** Head top-left (overlaps the body's right side). */
export const HX = CX + 9;
export const HY = 5;
/** Rainbow stops before the tail so the gray tail reads. */
export const TRAIL_END = CX - 5;

// --- stars (drawn first: they twinkle behind the rainbow and the cat) --------

interface Star {
  x: number;
  y: number;
  p: number;
}

const STARFIELD: Star[] = [
  { x: 8, y: 3, p: 0 },
  { x: 26, y: 13, p: 2 },
  { x: 46, y: 1, p: 1 },
  { x: 66, y: 11, p: 3 },
];

function tickStars(buf: RGB[], stars: Star[] = STARFIELD, rand: () => number = Math.random): void {
  for (const s of stars) {
    s.x -= 3;
    s.p = (s.p + 1) % 4;
    if (s.x < -2) {
      s.x = W + Math.floor(rand() * 11);
      s.y = 1 + Math.floor(rand() * (H - 2));
    }
    const { x, y, p } = s;
    switch (p) {
      case 0:
        fillRect(buf, W, H, x, y, 1, 1, STAR);
        break;
      case 1:
        fillRect(buf, W, H, x - 1, y, 3, 1, STAR);
        fillRect(buf, W, H, x, y - 1, 1, 3, STAR);
        break;
      case 2:
        fillRect(buf, W, H, x - 2, y, 5, 1, STAR);
        fillRect(buf, W, H, x, y - 2, 1, 5, STAR);
        break;
      default:
        for (const [dx, dy] of [[-2, 0], [2, 0], [0, -2], [0, 2]] as [number, number][]) {
          fillRect(buf, W, H, x + dx, y + dy, 1, 1, STAR);
        }
    }
  }
}

// --- rainbow trail: 6 bands of 2px, wiggling in 8px blocks ----------------

function rainbow(buf: RGB[], phase: number): void {
  for (let band = 0; band < RAINBOW.length; band++) {
    const color = RAINBOW[band]!;
    const y = 2 + band * 2;
    let x = 0;
    while (x < TRAIL_END) {
      const w = Math.min(8, TRAIL_END - x);
      const off = ((x >> 3) + phase) & 1;
      fillRect(buf, W, H, x, y + off, w, 2, color);
      x += w;
    }
  }
}

// --- the cat: layered rects, later writes draw on top of earlier ones -------

function cat(buf: RGB[], phase: number): void {
  const bob = phase; // body bobs 1px down every other beat
  const by = BY + bob;
  const hy = HY + bob;

  // tail (flips up/down against the bob)
  fillRect(buf, W, H, CX - 2, by + 5, 2, 2, GRAY);
  fillRect(buf, W, H, CX - 4, phase === 0 ? by + 3 : by + 7, 2, 2, GRAY);

  // legs stay planted; a 1px x-shuffle suggests the gallop
  for (const lx of [CX + 1, CX + 5, CX + 10, CX + 14]) {
    fillRect(buf, W, H, lx + bob, 13, 2, 2, GRAY);
  }

  // pop-tart body (inset top/bottom rows fake the rounded corners)
  fillRect(buf, W, H, CX + 1, by, 12, 1, CRUST);
  fillRect(buf, W, H, CX, by + 1, 14, 8, CRUST);
  fillRect(buf, W, H, CX + 1, by + 9, 12, 1, CRUST);
  fillRect(buf, W, H, CX + 1, by + 1, 12, 8, FROSTING);
  for (const [sx, sy] of [[2, 2], [6, 3], [3, 5], [7, 6], [5, 7]] as [number, number][]) {
    fillRect(buf, W, H, CX + sx, by + sy, 1, 1, SPRINKLE);
  }

  // head + ears
  fillRect(buf, W, H, HX + 1, hy, 8, 1, GRAY);
  fillRect(buf, W, H, HX, hy + 1, 10, 6, GRAY);
  fillRect(buf, W, H, HX + 1, hy + 7, 8, 1, GRAY);
  fillRect(buf, W, H, HX + 1, hy - 2, 1, 1, GRAY);
  fillRect(buf, W, H, HX + 1, hy - 1, 2, 1, GRAY);
  fillRect(buf, W, H, HX + 8, hy - 2, 1, 1, GRAY);
  fillRect(buf, W, H, HX + 7, hy - 1, 2, 1, GRAY);

  // face: eyes, cheeks, smile
  fillRect(buf, W, H, HX + 2, hy + 2, 1, 1, BLACK);
  fillRect(buf, W, H, HX + 7, hy + 2, 1, 1, BLACK);
  fillRect(buf, W, H, HX + 1, hy + 4, 1, 1, CHEEK);
  fillRect(buf, W, H, HX + 8, hy + 4, 1, 1, CHEEK);
  fillRect(buf, W, H, HX + 2, hy + 4, 1, 1, BLACK);
  fillRect(buf, W, H, HX + 6, hy + 4, 1, 1, BLACK);
  fillRect(buf, W, H, HX + 3, hy + 5, 3, 1, BLACK);
}

// --- renderer -------------------------------------------------------------

/**
 * Renders nyan-cat frames into pixel buffers. Composition is pure and
 * side-effect-free apart from the internal frame counter, so it's easy to test
 * or drive frame-by-frame.
 */
export class NyanCat {
  private frameNo = 0;

  /**
   * Compose the next animation frame (advancing animation state) into a fresh
   * buffer and return it. Cheap enough to call whenever you need a frame.
   */
  renderFrame(): RGB[] {
    const phase = Math.floor(this.frameNo / 3) % 2;
    this.frameNo += 1;
    const buf = blankBuffer(W, H);
    tickStars(buf);
    rainbow(buf, phase);
    cat(buf, phase);
    return buf;
  }
}

/**
 * Push one nyan-cat frame to a bar's display and advance the animation. Wraps a
 * {@link BitmapStreamer} so upload/clear/release behavior is shared.
 */
export class NyanCatPlayer {
  private readonly cat = new NyanCat();
  private readonly streamer: BitmapStreamer;

  constructor(bar: BusyBar, appName: string = APP) {
    this.streamer = new BitmapStreamer(bar, appName, W, H);
  }

  /** Compose and push the next frame. */
  async drawFrame(): Promise<void> {
    await this.streamer.push(this.cat.renderFrame());
  }

  /** Release the display (clear this app's elements). */
  async clear(): Promise<void> {
    await this.streamer.clear();
  }
}
