# busybar

This is a set of modular, type-checked TypeScript/Bun modules that drive a
physical **BUSY Bar** (`@busy-app/busy-lib`): activate built-in BUSY modes,
render built-in animation themes (e.g. Nyan Cat), cycle through every theme, and
react to live video calls on the host machine.

```
bun install
```

## Module map

Modules are grouped by role. `main.ts` stays at the root; every `*.test.ts`
lives beside the source it covers.

**`core/`** — domain-agnostic runtime + reporting substrate

| File | Purpose |
|------|---------|
| `core/eventBus.ts` | The **dumb bus** — `EventBus<T>`: receive + broadcast only, no domain knowledge, no filtering, no replay. Plus `createEventBus()` for isolated test buses. |
| `core/poll.ts` | Shared deadline-driven schedule (`pollEvery`) plus the producer/subscriber descriptor types (`ProducerDescriptor` / `SubscriberDescriptor`) and `ProducerHandle<TState>` (`getCurrentState` / `stop` / `done`). A producer owns its own schedule; the caller just hands it the bus. |
| `core/runtime.ts` | Registry + orderly shutdown. Takes the bus (and an optional `Board`) in its constructor; `registerProducer`/`registerSubscriber` take self-naming descriptors, add a board row, and start each component with the bus + that row's reporter. `stopAll()` stops **producers then subscribers** (two lanes), isolating failures. |
| `core/actor.ts` | The **dumb actor** — `startActor(bus, onEvent)`: subscribe to the bus + `stop()` detaches. Generic, knows nothing about themes/calls/bar. |
| `core/board.ts` | Observable board model — ordered producer/subscriber rows, each with a live status string a component overwrites through its own `Reporter`. `snapshot()`/`subscribe()` feed the TUI; imports nothing else. |
| `core/logSink.ts` | Shared bounded log ring (`logSink`) — components `log()` here instead of `console.log`, and the TUI subscribes to render the log pane. `setMirror()` toggles console echo (off once Ink mounts). |

**`events/`** — the shared event vocabulary

| File | Purpose |
|------|---------|
| `events/systemEvents.ts` | **System-event vocabulary + shared bus** — the generic `systemBus` (typed `EventBus`), carrying call state (`call_started` / `call_ended` / `call_state_changed`) and GitHub activity (`github_event`) as today's `SystemEvent` union. No logic beyond the contract. |

**`producers/`** — sources that poll and publish

| File | Purpose |
|------|---------|
| `producers/callDetector.ts` | **Call source** — a self-scheduled *producer* descriptor `{ name, start }`: the runtime binds a board reporter to its row, then `start(bus, report)` runs a `pollEvery` loop (its own cadence) reading window titles (AppleScript), classifies via the pure `classifyCall`, and on change publishes `call_started` / `call_ended` / `call_state_changed` while reporting its state through the injected reporter. Logs its own transitions. |
| `producers/githubEvents.ts` | **GitHub source** — a *producer* descriptor polling the GitHub notifications API via the `gh` CLI for **both of the user's github.com accounts** (personal + work EMU), each fetched with its own token so the active `gh` account is never switched (~5-min cadence, **no new GitHub App**). Pure `normalizeNotifications` + `selectNew` (dedup by account+thread+`updatedAt`) split from thin `gh` IO. The *already-emitted* cursor is **persisted** (`$XDG_STATE_HOME/automagic/github-seen.json`, size-capped) so restarts emit only genuine deltas — including activity that arrived while the daemon was down — and never re-fire; the very first run baselines the backlog without publishing. Publishes `github_event`; degrades gracefully when an account is unauthed. |

**`subscribers/`** — consumers that react to events

| File | Purpose |
|------|---------|
| `subscribers/busyAutomation.ts` | **The bar subscriber** — `startBarActor(bus, report, { host, HTTPAccessPassword })` subscribes to the bus (via the dumb actor), reads events, and reacts — today by showing/releasing a call theme on the bar (only-if-ours) — reporting its status through the injected reporter. Calls are just the reaction it currently has, not what it is. |

**`bar/`** — the BUSY-bar device domain (drawing + themes)

| File | Purpose |
|------|---------|
| `bar/busy-defaults.ts` | `BusyDefaults` — typed wrapper over the bar's HTTP client: profiles, snapshots, run/release, `playTheme`, `cycle`, `status`. Re-exports the shared display + nyan primitives. |
| `bar/display.ts` | Reusable display core: a minimal **PNG encoder**, pixel-buffer helpers, and `BitmapStreamer` (upload + stream full-frame bitmaps as images). Not nyan-specific — any future theme reuses it. |
| `bar/nyan-cat.ts` | The **Nyan Cat** animation theme: palette, geometry, pure `renderFrame`, and a `NyanCatPlayer` that streams frames through `BitmapStreamer`. |

**`ui/`** — the Ink TUI board view

| File | Purpose |
|------|---------|
| `ui/ui.tsx` | Ink view — `renderBoard(board, logSink, { onExit })` renders **Producers**/**Subscribers** sections + a log pane. Pure reader; `exitOnCtrlC: false` with a raw-mode guard so non-TTY stdin never throws. |

**root / `scratch/`**

| File | Purpose |
|------|---------|
| `main.ts` | Daemon entry: constructs the `Board` + shared `logSink`, injects the board into the `Runtime`, registers the descriptors (`registerSubscriber`/`registerProducer`), and mounts the Ink board (`renderBoard`). Ink owns the terminal lifecycle; `q`/Ctrl-C runs an orderly `shutdown`. |
| `scratch/testappdetector.ts` | Probe which window titles any app exposes (aids writing detectors). Not part of the app. |

### Runtime & types
- **Bun** (`bun.lock`, `@types/bun`). Run scripts with `bun run <file>.ts`.
- **`typescript@^5`**, strict config: `strict`, `noUncheckedIndexedAccess`,
  `verbatimModuleSyntax`, `noFallthroughCasesInSwitch`. `bunx tsc --noEmit` is clean.
- **`@busy-app/busy-lib@~0.17.0`** — the typed HTTP client used by `BusyDefaults`,
  so no raw HTTP for profiles/snapshots/assets/display.
- **`ink@^5` + `react@^18`** — the live TUI board (`ui.tsx`) that `bun main.ts`
  renders (`@types/react` for the JSX types).

## The BUSY Bar

The bar at `192.168.50.85` uses an HTTP access token `8700494362` (sent via the
client's `HTTPAccessPassword`). The default is baked into every command; override
with `--host` / the `bar` option.

Display model (from the bar's OpenAPI spec):
- System app priority levels: stub/poweroff = `0`, any built-in app = `10`,
  active BUSY/CUSTOM work session = `90`. Draw API accepts `1–100` (default `50`).
- A draw is accepted when its priority `>=` the currently running system app's.
- **Just setting a theme never takes the screen from an active work session.**

Design philosophy inherited from the Python originals — **never preempt the
display**: the wrappers skip a draw (or leave a release alone) when a
higher-priority app owns the screen, rather than rudely interrupt it.

## Live TUI board

`bun main.ts` runs the daemon and renders a live Ink board of the registered
producers and subscribers with their current status, plus a log pane of recent
lines. Ink owns the terminal; `q` or Ctrl-C stops the daemon, releases the bar,
and restores the terminal cleanly.

```bash
bun main.ts                    # live board; --host 192.168.50.85 by default
bun main.ts --host 127.0.0.1   # emulator / Wi-Fi bar
```

## Themes

A single unified list, `THEMES`, holds the stock firmware profiles **and** the
built-in animation themes as peers:

- **Stock profile themes** (`KNOWN_THEMES`): `busy`, `keep_out`, `dnd`,
  `meeting`, `on_call`, `lunch`, `back_soon`, `booked`, `flow`, `chill_time`,
  `on_air`, `coding`, `low_social_battery`.
- **Animation themes** (`ANIMATION_THEMES`): `nyan_cat`.

Profile themes run the stored BUSY/CUSTOM profile with that theme via
`BusyDefaults.run()`. Animation themes render via `BusyDefaults.playTheme()`
(which streams frames and always clears the display on stop/error).

```ts
import { BusyDefaults, THEMES } from './busy-defaults';
const busy = new BusyDefaults({ host: '192.168.50.85', HTTPAccessPassword: '8700494362' });

for (const theme of THEMES) { /* ... */ }

const handle = await busy.run('meeting'); // holds a mode
await handle.release();                   // releases only if it's still ours
```

### Nyan Cat
72×16 inner frame. Palette + geometry + composition are isolated in `nyan-cat.ts`;
`NyanCatPlayer` pushes each rendered frame through `BitmapStreamer` (a filename
ring of 4 assets dodges the bar's asset-lock). The cat bobs, stars twinkle, and
the rainbow trails behind. Frames were verified rendering correctly (1:1 and
upscaled) in a preview tool during development.

## Call automation

Detect a live video call on this Mac and set the bar theme accordingly. `bun
main.ts` mounts the live TUI board (Producers/Subscribers rows + a log pane);
`q` or Ctrl-C stops it and releases the bar.

```bash
bun main.ts                    # live board; --host 192.168.50.85 by default
```

Call automation is a set of decoupled pieces, bridged by a **shared, dumb bus**
that is *not* call-specific — call events are just today's vocabulary on it:

1. **The bus** (`eventBus.ts`): a pure pub/sub transport. It only receives and
   broadcasts — no domain types, no filtering, no state/replay. One shared
   instance (`systemBus` in `systemEvents.ts`) is the whole contract: any
   producer publishes to it, and any number of consumers subscribe and react
   however they like (call detection is just one). `createEventBus()` makes
   isolated buses for tests.
2. **Detector / source** (`callDetector.ts`): a *producer* `(bus) => handle` that runs its own `pollEvery` schedule, reads system state, and publishes call events — `call_started` / `call_ended` deltas **plus** `call_state_changed` full state. It knows nothing about the bar. Adding a future source (mic audio, calendar, screen state) is another self-contained producer that publishes to the same bus on *its own* cadence.
3. **Dumb actor** (`actor.ts`): `startActor(bus, onEvent)` — subscribes to the bus and feeds every event to `onEvent`; `stop()` detaches. Generic, knows nothing about themes/calls/bar, so it can drive any behavior.
4. **Bar subscriber** (`busyAutomation.ts`): the bar side reads the bus and does stuff. `startBarActor(bus, { host, httpPassword })` subscribes (via the dumb `startActor`) and today reacts to `call_state_changed` — `{ app: 'zoom' }` → `run(CALL_THEME)`, `{ app: null }` → release; only releases what it started. That reaction is what it currently does, not what it *is*: it's a bus-reading subscriber, and call theming is one reaction among any. It knows nothing about *how* calls are detected.
5. **Runtime** (`runtime.ts`): owns the shared bus and orderly shutdown. Producers are registered separately from the subscriber; `stopAll()` stops producers first (no new events), then the subscriber (releases the bar).

Detectors share only one bit of machinery — the deadline-driven schedule
`pollEvery()` (`poll.ts`) — borrowed by each self-contained source so none
reimplements the loop. Everything else (the `read()`, the classification, the
publishing) is local to the source that owns it.

**Current state** is kept out of the dumb bus (no replay baked in), but seeding a
late consumer doesn't need a producer reach-back either: the producer already
publishes the *full* state (`call_state_changed`) on every transition, so any
consumer on the bus converges within one poll after subscribing. A consumer that
boots mid-call sees the theme as soon as the producer's next full-state tick
lands (in the daemon's single wiring tick, that's the first poll) — no separate
snapshot read from the producer.

Each piece is **individually testable** (`bun test`): the bus is pure pub/sub;
the decision logic is the pure `classifyCall` fed window titles directly (no
AppleScript); both are asserted in `systemEvents.test.ts`.

The only bar-related decision lives in the subscriber's theme map (`appThemes`), defaulting to `zoom → meeting`.

- **Detection details** (`callDetector.ts`): a `pollEvery` loop reads Zoom's window titles via AppleScript and, when the call state changes, publishes the events. A call is "live" when a `Zoom Meeting` window is open (vs. the always-present `Zoom Workplace`).
- The detector is a self-naming **`ProducerDescriptor`** (`callDetector: ProducerDescriptor<CallState, SystemEvent>`) from `poll.ts` — `{ name, start }`, owning its own cadence. Future sources (mic, calendar) share the same descriptor shape and borrow the same loop.
- **Poll loop is deadline-driven**, not `setInterval` — each poll is scheduled from the previous poll's start time, so system sleep or a clock jump can't cause a burst of stale ticks.
- Both halves reuse the "only release if still ours" rule, so the subscriber never stomps a mode another tool started. `stop()`/Ctrl-C releases cleanly.
- **Probe signals** before trusting a new app:
  ```bash
  bun run testappdetector.ts zoom      # ["Zoom Workplace", "Zoom Meeting"]
  ```

### Verified live
Started the daemon against a real on-call Zoom → detected `Zoom Meeting`, showed
the `meeting` theme, and released cleanly when stopped.

## Adding a theme
1. Add render logic in a new `mytheme.ts`, composing against the shared
   `display.ts` primitives (`BitmapStreamer`, `encodePng`, `blankBuffer`,
   `fillRect`).
2. Register it in `ANIMATION_THEMES` (if it's an animation the caller streams)
   or `KNOWN_THEMES` (if it's a stored profile theme).
3. `BusyDefaults.playTheme()` / `run()` picks it up automatically.
