#!/usr/bin/env bun
// api docs https://docs.busy.app/bar/dev/http-api
//
// CLI front-end for the reusable `BusyDefaults` module.
//
//   bun run index.ts --mode busy                 # BUSY profile
//   bun run index.ts --mode on_air               # CUSTOM profile, theme on_air
//   bun run index.ts --mode nyan_cat             # built-in nyan-cat animation
//   bun run index.ts --list                      # show stored profiles
//   bun run index.ts --mode off                  # stop the session
//   bun run index.ts --mode coding --host 127.0.0.1:8080  # emulator / Wi-Fi bar
//   bun run index.ts --status                      # what owns the display right now
//   bun run index.ts --cycle --duration 5000       # show every theme, 5s each, then stop
import {
  BusyDefaults,
  APP,
  THEMES,
  KNOWN_THEMES,
  isAnimationTheme,
  type AnimationTheme,
  type Theme,
} from './busy-defaults';

const args = Bun.argv.slice(2);

function flag(name: string): string | undefined {
  const i = args.lastIndexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}
function has(name: string): boolean {
  return args.includes(name);
}

const host = flag('--host') ?? '192.168.50.85';
const mode = flag('--mode') ?? 'busy';
const list = has('--list');
const status = has('--status');
const cycle = has('--cycle');
const duration = Number(flag('--duration') ?? 5000);

const busy = new BusyDefaults({ host, HTTPAccessPassword: '8700494362' });

// Signal → the SIGINT/SIGTERM we watch to release a held mode.
const release = new AbortController();
for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.on(sig, () => release.abort());
}

if (list) {
  for (const summary of await busy.list()) {
    console.log(String(summary));
  }
  process.exit(0);
}

if (status) {
  const s = await busy.status();
  console.log(`session type:  ${s.type}`);
  console.log(`running:       ${s.running ? 'yes' : 'no'}`);
  console.log(`theme:         ${s.theme}`);
  console.log(`priority:      ${s.priority === null ? 'unknown' : s.priority}`);
  console.log(`display:       ${s.display}`);
  process.exit(0);
}

if (mode === 'off') {
  await busy.stop();
  console.log(`${APP} → ${host}  session stopped`);
  process.exit(0);
}

if (cycle) {
  console.log(
    `${APP} → ${host}  cycling ${THEMES.length} themes, ${duration / 1000}s each  (Ctrl-C to stop)`,
  );
  const shown = await busy
    .cycle({ durationMs: duration, signal: release.signal, onTheme: (t) => console.log(`  ${t}`) })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
  console.log(`done: ${shown.join(', ')}`);
  process.exit(0);
}

if (isAnimationTheme(mode)) {
  const theme = mode satisfies AnimationTheme;
  console.log(`${APP} → ${host}  animating ${theme}  (Ctrl-C to stop)`);
  const result = await busy
    .playTheme(theme, { fps: 12.5, signal: release.signal })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
  console.log(`\n${result}`);
  process.exit(0);
}

if (!KNOWN_THEMES.includes(mode as Theme)) {
  console.error(
    `unknown mode '${mode}' — expected one of: ${KNOWN_THEMES.join(', ')}`,
  );
  process.exit(1);
}

const handle = await busy.run(mode as Theme);
console.log(
  `${APP} → ${host}  started ${handle.slot}: ${handle.theme}  (Ctrl-C to release)`,
);

try {
  const result = await busy.holdAndRelease(handle, release.signal);
  console.log(`\n${result}`);
} catch (err) {
  console.error(err);
  process.exit(1);
}
