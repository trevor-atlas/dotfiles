#!/usr/bin/env bun
/**
 * handy-pi — dictate with Handy (https://handy.computer) and pipe the transcript
 * straight into a new pi session.
 *
 * Handy already handles recording natively (push-to-talk is enabled), stores every
 * transcription in a SQLite history DB, and can be toggled with Unix signals:
 *   SIGUSR2 -> toggle transcription
 *   SIGUSR1 -> toggle transcription with post-processing
 * (see https://handy.computer/docs/cli#signal-control)
 *
 * This script drives that flow:
 *   start  -> snapshot the latest history row id, then signal Handy to begin recording
 *   stop   -> signal Handy to stop, wait for the new row, then hand the text to pi
 *   toggle -> start if idle, stop if a session is in progress (uses the state file)
 *
 * Designed for a Hammerspoon push-to-talk binding: key-down runs `start`,
 * key-up runs `stop`. See scripts/handy-pi.hammerspoon.lua.
 *
 * Usage:
 *   handy-pi start [--post]
 *   handy-pi stop  [--print] [--terminal <ghostty|kitty|terminal>] [--cwd <dir>]
 *   handy-pi toggle [--post] [--print] [--terminal ...] [--cwd ...]
 *   handy-pi record [...]        # convenience: start, wait for Enter, stop (TTY use)
 *
 * Env overrides:
 *   HANDY_PI_TERMINAL   default terminal for interactive pi (ghostty|kitty|terminal)
 *   HANDY_PI_CWD        working dir pi launches in (default: $HOME)
 *   HANDY_PI_BIN        path to the pi binary (default: resolved via login shell)
 */

import { Database } from 'bun:sqlite';
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';

const HANDY_DB = join(
  homedir(),
  'Library/Application Support/com.pais.handy/history.db',
);
const STATE_DIR = join(tmpdir(), 'handy-pi');
const STATE_FILE = join(STATE_DIR, 'state.json');
const MSG_FILE = join(STATE_DIR, 'last-msg.txt');

interface State {
  baselineId: number;
  signal: 'USR1' | 'USR2';
  startedAt: number;
}

type Opts = {
  post: boolean;
  print: boolean;
  terminal: string;
  cwd: string;
};

function die(msg: string): never {
  console.error(`handy-pi: ${msg}`);
  process.exit(1);
}

function ensureStateDir(): void {
  if (!existsSync(STATE_DIR)) mkdirSync(STATE_DIR, { recursive: true });
}

function parseOpts(argv: string[]): Opts {
  const opts: Opts = {
    post: false,
    print: false,
    terminal: process.env.HANDY_PI_TERMINAL ?? 'ghostty',
    cwd: process.env.HANDY_PI_CWD ?? homedir(),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--post') opts.post = true;
    else if (a === '--print' || a === '-p') opts.print = true;
    else if (a === '--terminal') opts.terminal = argv[++i] ?? opts.terminal;
    else if (a === '--cwd') opts.cwd = argv[++i] ?? opts.cwd;
    else die(`unknown flag: ${a}`);
  }
  return opts;
}

function openDb(): Database {
  if (!existsSync(HANDY_DB)) die(`Handy history DB not found at ${HANDY_DB}`);
  return new Database(HANDY_DB, { readonly: true });
}

function maxId(db: Database): number {
  const row = db
    .query('SELECT COALESCE(MAX(id), 0) AS id FROM transcription_history')
    .get() as { id: number };
  return row.id;
}

/** Toggle Handy recording via signal. Handles both `handy` and `Handy` names. */
function signalHandy(signal: 'USR1' | 'USR2'): void {
  const names = ['handy', 'Handy'];
  let ok = false;
  for (const name of names) {
    const res = spawnSync('pkill', [`-${signal}`, '-x', name], {
      stdio: 'ignore',
    });
    if (res.status === 0) {
      ok = true;
      break;
    }
  }
  if (!ok) die('could not signal Handy — is it running?');
}

function readState(): State | null {
  if (!existsSync(STATE_FILE)) return null;
  try {
    return JSON.parse(readFileSync(STATE_FILE, 'utf8')) as State;
  } catch {
    return null;
  }
}

function writeState(state: State | null): void {
  ensureStateDir();
  if (state === null) {
    writeFileSync(STATE_FILE, '');
    return;
  }
  writeFileSync(STATE_FILE, JSON.stringify(state));
}

function doStart(opts: Opts): void {
  ensureStateDir();
  const db = openDb();
  const baselineId = maxId(db);
  db.close();
  const signal: State['signal'] = opts.post ? 'USR1' : 'USR2';
  writeState({ baselineId, signal, startedAt: Date.now() });
  signalHandy(signal);
  console.error(`handy-pi: recording… (baseline id ${baselineId})`);
}

/** Poll the history DB until a row newer than baseline shows up with text. */
async function waitForTranscript(
  baselineId: number,
  timeoutMs = 30_000,
): Promise<string> {
  const deadline = Date.now() + timeoutMs;
  const db = openDb();
  try {
    while (Date.now() < deadline) {
      const row = db
        .query(
          `SELECT transcription_text AS text, post_processed_text AS pp
           FROM transcription_history
           WHERE id > ?
           ORDER BY id DESC LIMIT 1`,
        )
        .get(baselineId) as { text: string; pp: string | null } | null;
      if (row) {
        const text = (row.pp && row.pp.trim() ? row.pp : row.text) ?? '';
        if (text.trim()) return text.trim();
      }
      await Bun.sleep(150);
    }
  } finally {
    db.close();
  }
  die('timed out waiting for Handy to produce a transcript');
}

function resolvePi(): string {
  if (process.env.HANDY_PI_BIN) return process.env.HANDY_PI_BIN;
  // hs.task runs with a minimal PATH; resolve pi via a login shell.
  const res = spawnSync('zsh', ['-lc', 'command -v pi'], { encoding: 'utf8' });
  const found = res.stdout?.trim();
  if (found) return found;
  for (const p of ['/opt/homebrew/bin/pi', '/usr/local/bin/pi']) {
    if (existsSync(p)) return p;
  }
  return 'pi';
}

/** Open a fresh terminal window running an interactive pi seeded with the text. */
function launchInteractivePi(text: string, opts: Opts): void {
  ensureStateDir();
  writeFileSync(MSG_FILE, text);
  // Read the message from a file inside the launched shell to dodge all quoting.
  const inner = `cd ${shq(opts.cwd)}; exec pi "$(cat ${shq(MSG_FILE)})"`;

  let cmd: string;
  let args: string[];
  switch (opts.terminal) {
    case 'ghostty':
      cmd = 'open';
      args = ['-na', 'Ghostty', '--args', '-e', 'zsh', '-lc', inner];
      break;
    case 'kitty':
      cmd = 'open';
      args = ['-na', 'kitty', '--args', 'zsh', '-lc', inner];
      break;
    case 'terminal': {
      const osa = `tell application "Terminal" to do script ${JSON.stringify(
        `zsh -lc ${shq(inner)}`,
      )}\ntell application "Terminal" to activate`;
      cmd = 'osascript';
      args = ['-e', osa];
      break;
    }
    default:
      die(`unknown terminal: ${opts.terminal} (use ghostty|kitty|terminal)`);
  }
  const child = spawn(cmd, args, { detached: true, stdio: 'ignore' });
  child.unref();
  console.error(`handy-pi: launched pi in ${opts.terminal}`);
}

/** Run pi non-interactively, copy the reply to the clipboard, and notify. */
function runPrintPi(text: string, opts: Opts): void {
  const pi = resolvePi();
  const res = spawnSync(pi, ['-p', text], {
    cwd: opts.cwd,
    encoding: 'utf8',
    env: { ...process.env, PATH: `/opt/homebrew/bin:/usr/local/bin:${process.env.PATH ?? ''}` },
  });
  const out = (res.stdout ?? '').trim();
  if (out) process.stdout.write(out + '\n');
  if (res.stderr?.trim()) process.stderr.write(res.stderr);
  // Best-effort clipboard + notification so it's usable from a hotkey (no TTY).
  if (out) {
    const pb = spawn('pbcopy', { stdio: ['pipe', 'ignore', 'ignore'] });
    pb.stdin.end(out);
    notify('pi reply copied to clipboard', out.slice(0, 200));
  }
}

function notify(title: string, body: string): void {
  const osa = `display notification ${JSON.stringify(body)} with title ${JSON.stringify(title)}`;
  spawnSync('osascript', ['-e', osa], { stdio: 'ignore' });
}

/** Minimal POSIX single-quote escaping. */
function shq(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

async function doStop(opts: Opts): Promise<void> {
  const state = readState();
  const baselineId = state?.baselineId ?? 0;
  const signal = state?.signal ?? (opts.post ? 'USR1' : 'USR2');
  signalHandy(signal);
  writeState(null);
  const text = await waitForTranscript(baselineId);
  console.error(`handy-pi: transcript (${text.length} chars): ${truncate(text, 80)}`);
  if (opts.print) runPrintPi(text, opts);
  else launchInteractivePi(text, opts);
}

function truncate(s: string, n: number): string {
  return s.length > n ? s.slice(0, n) + '…' : s;
}

function isRecording(): boolean {
  const state = readState();
  return state !== null && Number.isFinite(state.baselineId);
}

async function main(): Promise<void> {
  const [cmd, ...rest] = process.argv.slice(2);
  const opts = parseOpts(rest);

  switch (cmd) {
    case 'start':
      doStart(opts);
      break;
    case 'stop':
      await doStop(opts);
      break;
    case 'toggle':
      if (isRecording()) await doStop(opts);
      else doStart(opts);
      break;
    case 'record': {
      // Convenience for terminal use: start, wait for Enter, stop.
      doStart(opts);
      process.stderr.write('Recording… press Enter to stop.\n');
      await new Promise<void>((resolve) => {
        process.stdin.resume();
        process.stdin.once('data', () => resolve());
      });
      await doStop(opts);
      break;
    }
    case undefined:
    case '-h':
    case '--help':
      console.log(
        [
          'Usage:',
          '  handy-pi start  [--post]',
          '  handy-pi stop   [--print] [--terminal <ghostty|kitty|terminal>] [--cwd <dir>]',
          '  handy-pi toggle [--post] [--print] [--terminal ...] [--cwd ...]',
          '  handy-pi record [...]   # start, wait for Enter, stop (TTY use)',
        ].join('\n'),
      );
      break;
    default:
      die(`unknown command: ${cmd} (try --help)`);
  }
}

main();
