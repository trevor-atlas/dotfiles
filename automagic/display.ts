/**
 * Display primitives: reusable building blocks for anything that draws to a
 * BUSY Bar screen — bitmap pixel buffers, PNG encoding, asset upload, and
 * full-frame image streaming.
 *
 * The BUSY Bar render API draws *elements* (text, image, animation, ...). The
 * fastest way to animate is to compose a full frame off-device as a bitmap,
 * PNG-encode it, and push it as a single image element — that's what these
 * helpers support. Composing whole frames here is dramatically cheaper than
 * issuing many small draw calls per element.
 */
import type { BusyBar } from '@busy-app/busy-lib';

import { deflateSync } from 'node:zlib';

// ---------------------------------------------------------------------------
// Bitmap types & pixel-buffer helpers
// ---------------------------------------------------------------------------

/** An RGB triple. X?8 bit. */
export type RGB = [number, number, number];

/** A row-major pixel buffer of width × height entries. */
export type PixelBuffer = RGB[];

export const BLACK: RGB = [0x00, 0x00, 0x00];

/** Allocate a blank (black) pixel buffer of the given dimensions. */
export function blankBuffer(width: number, height: number): PixelBuffer {
  return new Array<RGB>(width * height).fill(BLACK);
}

/**
 * Fill a solid 1-color rect into a pixel buffer, clipped to the buffer bounds.
 * Rect coordinates are in pixels relative to the buffer's top-left.
 */
export function fillRect(
  buf: PixelBuffer,
  width: number,
  height: number,
  x: number,
  y: number,
  w: number,
  h: number,
  rgb: RGB,
): void {
  const x0 = Math.max(0, x);
  const y0 = Math.max(0, y);
  const x1 = Math.min(width, x + w);
  const y1 = Math.min(height, y + h);
  for (let yy = y0; yy < y1; yy++) {
    const base = yy * width;
    for (let xx = x0; xx < x1; xx++) {
      buf[base + xx] = rgb;
    }
  }
}

// ---------------------------------------------------------------------------
// PNG encoding
// ---------------------------------------------------------------------------

/**
 * Encode a flat width×height list of (r, g, b) into a minimal RGBA PNG
 * `Uint8Array`. IDAT uses zlib/default deflate (RFC 1950 — the same stream
 * Python's `zlib.compress` and the BUSY Bar renderer expect).
 */
export function encodePng(pixels: PixelBuffer, width: number, height: number): Uint8Array {
  const raw = new Uint8Array(height * (1 + width * 4));
  let p = 0;
  for (let y = 0; y < height; y++) {
    raw[p++] = 0; // filter type: None
    const base = y * width;
    for (let x = 0; x < width; x++) {
      const [r, g, b] = pixels[base + x]!;
      raw[p++] = r;
      raw[p++] = g;
      raw[p++] = b;
      raw[p++] = 255; // opaque alpha
    }
  }

  const ihdr = new Uint8Array(13);
  const dv = new DataView(ihdr.buffer);
  dv.setUint32(0, width);
  dv.setUint32(4, height);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type: RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  const idat = deflateSync(raw, { level: 6 });

  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  return concatBytes([
    Uint8Array.from(sig),
    chunk(tagAscii('IHDR'), ihdr),
    chunk(tagAscii('IDAT'), idat),
    chunk(tagAscii('IEND'), new Uint8Array(0)),
  ]);
}

function tagAscii(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

function chunk(tag: Uint8Array, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(4 + tag.length + data.length + 4);
  const dv = new DataView(out.buffer);
  dv.setUint32(0, data.length);
  out.set(tag, 4);
  out.set(data, 4 + tag.length);
  dv.setUint32(4 + tag.length + data.length, crc32(out.subarray(4, 4 + tag.length + data.length)));
  return out;
}

function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    c ^= bytes[i]!;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? (c >>> 1) ^ 0xedb88320 : c >>> 1;
    }
  }
  return c ^ 0xffffffff;
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, b) => n + b.length, 0);
  const out = new Uint8Array(total);
  let p = 0;
  for (const b of parts) {
    out.set(b, p);
    p += b.length;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Asset upload + full-frame drawing (via @busy-app/busy-lib)
// ---------------------------------------------------------------------------

/** Options for pushing bitmaps to a bar's display. */
export interface StreamOptions {
  /** Element id used on the display (default `'frame'`). */
  elementId?: string;
  /** Draw priority. The API default is 50 — higher than any built-in app (10),
   *  lower than an active work session (90). */
  priority?: number;
}

/**
 * The bar rejected a draw because a higher-priority app owns the display
 * (HTTP 409, "Not drawn due to low priority") — e.g. an active BUSY work
 * session (priority 90) while we draw at the default 50. Never an error for us
 * to retry or throw on; it just means our frame won't be shown right now.
 */
export function isLowPriorityDraw(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'status' in err &&
    (err as { status: number }).status === 409
  );
}

/**
 * Uploads a pixel buffer as a PNG asset under `appName` and draws it as one
 * full-screen image element.
 *
 * @returns The filename it was stored under, in case you need it.
 */
export async function drawBitmap(
  bar: BusyBar,
  appName: string,
  filename: string,
  pixels: PixelBuffer,
  width: number,
  height: number,
  options: StreamOptions = {},
): Promise<string> {
  const elementId = options.elementId ?? 'frame';
  const priority = options.priority ?? 50;
  const png = encodePng(pixels, width, height);

  await bar.AssetsUpload({
    application_name: appName,
    file: filename,
    data: new Blob([png], { type: 'application/octet-stream' }),
  });

  try {
    await bar.DisplayDraw({
      application_name: appName,
      priority,
      elements: [
        {
          id: elementId,
          type: 'image',
          path: filename,
          x: 0,
          y: 0,
          display: 'front',
          opacity: 100,
        } as const,
      ],
    });
  } catch (err) {
    // A higher-priority app owns the display right now (e.g. an active BUSY
    // work session at priority 90). We never want to take the screen from it,
    // so skip this frame instead of failing the whole animation.
    if (isLowPriorityDraw(err)) return filename;
    throw err;
  }

  return filename;
}

/** Remove the display elements a given app drew, releasing the screen. */
export async function clearDisplay(bar: BusyBar, appName: string): Promise<void> {
  await bar.DisplayClear({ application_name: appName });
}

/** What a {@link BitmapStreamer} hands back for a pushed frame. */
export interface PushedFrame {
  /** The filename this frame was stored under. */
  filename: string;
  /** The pixel buffer that was pushed. */
  buffer: PixelBuffer;
}

/**
 * A thin reusable abstraction over the "upload a frame, then draw it"
 * sequence, tuned for animation.
 *
 * The device briefly locks an asset while a draw reads it, so re-uploading the
 * same name too soon returns HTTP 508. This therefore rotates through a small
 * ring of filenames for you.
 */
export class BitmapStreamer {
  private readonly elementId: string;
  private readonly priority: number;
  private frameNo = 0;

  constructor(
    private readonly bar: BusyBar,
    readonly appName: string,
    readonly width: number,
    readonly height: number,
    private readonly filenameRing = 4,
    options: StreamOptions = {},
  ) {
    this.elementId = options.elementId ?? 'frame';
    this.priority = options.priority ?? 50;
  }

  get displayApp(): string {
    return this.appName;
  }

  /**
   * Render-and-push one frame. You compose `/pixels` yourself; this PNG-encodes
   * it, uploads it under the next ring filename, and draws it on screen.
   */
  async push(pixels: PixelBuffer): Promise<PushedFrame> {
    const filename = `frame${this.frameNo % this.filenameRing}.png`;
    await drawBitmap(
      this.bar,
      this.appName,
      filename,
      pixels,
      this.width,
      this.height,
      { elementId: this.elementId, priority: this.priority },
    );
    this.frameNo += 1;
    return { filename, buffer: pixels };
  }

  /** Delete this app's display elements, releasing the screen. */
  async clear(): Promise<void> {
    await clearDisplay(this.bar, this.appName).catch(() => {});
  }
}
