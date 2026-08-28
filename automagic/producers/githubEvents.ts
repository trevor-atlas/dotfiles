/**
 * githubEvents: a producer that surfaces GitHub activity relevant to the user.
 *
 * Same shape as `callDetector.ts`: a self-contained polled source that owns its
 * own `pollEvery` cadence, normalises what it reads into typed events, publishes
 * them to the shared bus, logs the transitions, and reports a terse live status
 * to its board row.
 *
 * There is no per-user GitHub webhook, so — with NO new GitHub App / OAuth — we
 * poll the notifications REST API through the already-authenticated `gh` CLI for
 * EACH github.com account the user has (personal + the work EMU account). Both
 * accounts live on github.com; we fetch each with its own token via
 * `gh auth token --user`, so the active `gh` account is never disturbed, then
 * normalise and publish. Low latency isn't needed (a ~5-minute cadence is fine),
 * so this is a plain deadline poll like the rest.
 *
 * The design mirrors `callDetector.ts`: a PURE core (`normalizeNotifications`,
 * `selectNew` — exported and unit-tested) split from thin IO
 * (`fetchNotifications`, which shells out to `gh` and is not unit-tested). The
 * normalised `GithubEvent` is deliberately plain + serialisable so downstream
 * local tools can reuse it without importing any of this producer's wiring.
 *
 * READ-ONLY: we only ever GET `/notifications`; nothing here ever marks a thread
 * as read.
 */
import { spawnSync } from 'bun';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import type { SystemEvent } from '../events/systemEvents';
import { pollEvery, type ProducerDescriptor } from '../core/poll';
import { log } from '../core/logSink';

/** How often we poll GitHub notifications (its own cadence). Editable. */
const GITHUB_POLL_MS = 5 * 60_000;

/**
 * The github.com accounts the user has authenticated in `gh` (personal + work
 * EMU). Each is polled with its own token via `gh auth token --user`, so the
 * active `gh` account is never touched. Editable.
 */
const GITHUB_ACCOUNTS = ['trevor-atlas', 'tatlas_hubspot'] as const;

/**
 * `participating=true` = only threads that directly involve the user (mentions,
 * review requests, assignments, things they authored), not everything they
 * merely watch. Editable — flip to widen the net.
 */
const GITHUB_PARTICIPATING = true;

/**
 * Cap on the persisted "already emitted" cursor so it can't grow without bound
 * on a long-lived daemon. When exceeded, the oldest keys are dropped (a dropped
 * thread that later reappears re-fires once — a rare, acceptable cost). Editable.
 */
const SEEN_CAP = 2000;

/**
 * Where the "already emitted" cursor is persisted, so a restart re-emits only
 * genuine deltas (including anything that arrived while the daemon was down)
 * instead of replaying the backlog or silently dropping it. Honors
 * `$XDG_STATE_HOME`, else `~/.local/state`.
 */
const SEEN_PATH = join(
  process.env.XDG_STATE_HOME || join(process.env.HOME || '.', '.local', 'state'),
  'automagic',
  'github-seen.json',
);

/**
 * The coarse, downstream-facing normalisation of a notification. Kept small and
 * documented on purpose: automations decide what to do off `kind`, not off the
 * raw `reason` × `subject.type` matrix.
 *   - `review_requested` — you were asked to review;
 *   - `mentioned`        — you were @-mentioned;
 *   - `assigned`         — you were assigned;
 *   - `pr_activity`      — other movement on a pull request;
 *   - `issue_activity`   — other movement on an issue;
 *   - `other`            — anything else (CI, releases, …).
 */
export type GithubEventKind =
  | 'review_requested'
  | 'mentioned'
  | 'assigned'
  | 'pr_activity'
  | 'issue_activity'
  | 'other';

/**
 * A normalised GitHub notification — a plain, serialisable object carrying just
 * what a local automation needs to decide whether to act. No classes, no `gh`
 * types leaking through. `url` is a browser link (not the API URL) or null when
 * one can't be derived; `account` says which of the user's gh accounts surfaced
 * it (personal vs. work), and `host` is the repo's host (github.com today).
 */
export type GithubEvent = {
  id: string;
  account: string;
  host: string;
  kind: GithubEventKind;
  reason: string;
  repo: string;
  subjectType: string;
  title: string;
  url: string | null;
  updatedAt: string;
};

/** The producer's own tiny state, surfaced through `getCurrentState`. */
export type GithubState = { lastPolledAt: number | null; seenCount: number };

/* -------------------------------------------------------------------------- */
/* Pure core (unit-tested)                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Parse a raw `gh api /notifications` payload (a JSON string or an already-
 * parsed array) into `GithubEvent[]`. Pure and tolerant: malformed or missing
 * fields never throw — a bad item is skipped, a missing scalar defaults to `''`
 * (or `null` for `url`). A non-array payload (e.g. a `{ "message": … }` error
 * body) yields `[]`.
 */
export function normalizeNotifications(
  rawJson: string | unknown[],
  account = '',
): GithubEvent[] {
  const out: GithubEvent[] = [];
  for (const item of toArray(rawJson)) {
    const event = normalizeOne(item, account);
    if (event) out.push(event);
  }
  return out;
}

/**
 * The dedup key for one event: account + thread + `updatedAt`. Exported so the
 * persisted cursor and the tests share exactly one definition.
 */
export function seenKey(event: GithubEvent): string {
  return `${event.account}:${event.id}:${event.updatedAt}`;
}

/**
 * Split `events` into the ones not yet seen (`fresh`) and the advanced cursor
 * (`nextSeen`). Pure. Keyed by {@link seenKey} (account + thread + `updatedAt`)
 * so a thread only re-fires once it has genuinely new activity (a newer
 * `updatedAt`) and the two accounts can't collide; `nextSeen` is a superset of
 * `seen` plus every key in this batch.
 */
export function selectNew(
  events: GithubEvent[],
  seen: ReadonlySet<string>,
): { fresh: GithubEvent[]; nextSeen: Set<string> } {
  const nextSeen = new Set(seen);
  const fresh: GithubEvent[] = [];
  for (const event of events) {
    const key = seenKey(event);
    if (nextSeen.has(key)) continue;
    nextSeen.add(key);
    fresh.push(event);
  }
  return { fresh, nextSeen };
}

/** Serialise the cursor to a JSON array of keys (newest last). Pure. */
export function serializeSeen(seen: ReadonlySet<string>): string {
  return JSON.stringify([...seen]);
}

/**
 * Parse a persisted cursor (a JSON array of string keys) back into a Set. Pure
 * and tolerant: malformed JSON, a non-array, or non-string entries yield an
 * empty (or filtered) Set — never throws.
 */
export function parseSeen(json: string): Set<string> {
  try {
    const parsed = JSON.parse(json);
    if (!Array.isArray(parsed)) return new Set();
    return new Set(parsed.filter((k): k is string => typeof k === 'string'));
  } catch {
    return new Set();
  }
}

/**
 * Bound the cursor to at most `cap` keys, dropping the oldest (Sets preserve
 * insertion order, so the retained tail is the most recent). Pure.
 */
export function pruneSeen(seen: ReadonlySet<string>, cap: number): Set<string> {
  if (seen.size <= cap) return new Set(seen);
  return new Set([...seen].slice(seen.size - cap));
}

/** One raw notification → `GithubEvent`, or null if it has no usable thread id. */
function normalizeOne(item: unknown, account: string): GithubEvent | null {
  if (!item || typeof item !== 'object') return null;
  const o = item as Record<string, unknown>;

  const id = str(o.id);
  if (!id) return null;

  const subject = obj(o.subject);
  const repository = obj(o.repository);

  const reason = str(o.reason);
  const subjectType = str(subject.type);
  const repo = str(repository.full_name);
  const host = hostOf(str(repository.html_url));

  return {
    id,
    account,
    host,
    kind: classifyKind(reason, subjectType),
    reason,
    repo,
    subjectType,
    title: str(subject.title),
    url: browserUrl(host, repo, subjectType, subject.url),
    updatedAt: str(o.updated_at),
  };
}

/** Derive the coarse `kind` from the notification `reason` × `subject.type`. */
function classifyKind(reason: string, subjectType: string): GithubEventKind {
  switch (reason) {
    case 'review_requested':
      return 'review_requested';
    case 'mention':
      return 'mentioned';
    case 'assign':
      return 'assigned';
  }
  if (subjectType === 'PullRequest') return 'pr_activity';
  if (subjectType === 'Issue') return 'issue_activity';
  return 'other';
}

/**
 * Turn the API `subject.url` into a browser link, host-aware for both personal
 * and enterprise. Only PR/Issue subjects map cleanly; anything else (or a
 * missing url / number) yields null.
 */
function browserUrl(
  host: string,
  repo: string,
  subjectType: string,
  subjectUrl: unknown,
): string | null {
  const url = str(subjectUrl);
  if (!host || !repo || !url) return null;
  const segment =
    subjectType === 'PullRequest' ? 'pull' : subjectType === 'Issue' ? 'issues' : null;
  if (!segment) return null;
  const number = url.match(/(\d+)\/?$/);
  if (!number) return null;
  return `https://${host}/${repo}/${segment}/${number[1]}`;
}

/** Coerce unknown → array of items to normalise; never throws. */
function toArray(rawJson: string | unknown[]): unknown[] {
  if (Array.isArray(rawJson)) return rawJson;
  try {
    const parsed = JSON.parse(rawJson);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/** A string field, coerced from string/number; anything else → ''. */
function str(v: unknown): string {
  if (typeof v === 'string') return v;
  if (typeof v === 'number') return String(v);
  return '';
}

/** A nested object field; anything else → an empty record. */
function obj(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
}

/** Hostname of a browser URL (e.g. `repository.html_url`); '' if unparseable. */
function hostOf(htmlUrl: string): string {
  try {
    return new URL(htmlUrl).host;
  } catch {
    return '';
  }
}

/* -------------------------------------------------------------------------- */
/* Thin IO (not unit-tested, like `zoomWindowTitles`)                         */
/* -------------------------------------------------------------------------- */

/**
 * Fetch one account's participating notifications from github.com via the `gh`
 * CLI, using that account's own token (`gh auth token --user`) injected as
 * `GH_TOKEN` so the active `gh` account is never switched. Returns `[]` on ANY
 * failure (gh missing, account not authed, network error, non-zero exit,
 * non-JSON) — never throws. READ-ONLY: only a GET.
 */
function fetchNotifications(account: string): unknown[] {
  try {
    const tokenProc = spawnSync([
      'gh',
      'auth',
      'token',
      '--user',
      account,
      '--hostname',
      'github.com',
    ]);
    if (!tokenProc.success) return [];
    const token = tokenProc.stdout.toString().trim();
    if (!token) return [];

    const participating = GITHUB_PARTICIPATING ? 'true' : 'false';
    const proc = spawnSync(
      [
        'gh',
        'api',
        '--hostname',
        'github.com',
        `/notifications?participating=${participating}&all=false`,
        '--paginate',
      ],
      { env: { ...process.env, GH_TOKEN: token } },
    );
    if (!proc.success) return [];
    const parsed = JSON.parse(proc.stdout.toString());
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Load the persisted "already emitted" cursor. Returns the Set plus whether a
 * file existed — on the very first run (no file) the producer baselines instead
 * of emitting the whole backlog. Never throws (missing/unreadable → empty).
 */
function loadSeen(): { seen: Set<string>; existed: boolean } {
  try {
    return { seen: parseSeen(readFileSync(SEEN_PATH, 'utf8')), existed: true };
  } catch {
    return { seen: new Set(), existed: false };
  }
}

/**
 * Persist the cursor (mkdir + write). Soft-warns on failure; the daemon keeps
 * running from the in-memory Set.
 */
function saveSeen(seen: ReadonlySet<string>): void {
  try {
    mkdirSync(dirname(SEEN_PATH), { recursive: true });
    writeFileSync(SEEN_PATH, serializeSeen(seen));
  } catch (err) {
    log(`github: could not persist cursor: ${(err as Error).message}`);
  }
}

/* -------------------------------------------------------------------------- */
/* Producer descriptor                                                        */
/* -------------------------------------------------------------------------- */

/**
 * The GitHub-notifications producer as a self-naming, self-reporting descriptor
 * (see `callDetector.ts`). The "already emitted" cursor is persisted to disk, so
 * across restarts it emits only genuine deltas — anything new (including while
 * the daemon was down) fires exactly once, and nothing already emitted re-fires.
 * On the very first run (no persisted cursor) it baselines the current backlog
 * without publishing, so first launch doesn't dump history.
 */
export const githubEventDetector: ProducerDescriptor<GithubState, SystemEvent> = {
  name: 'github events',
  start: (bus, report) => {
    const restored = loadSeen();
    let seen = restored.seen;
    let lastPolledAt: number | null = null;
    // A restored cursor means we're already primed — emit deltas immediately.
    // Only the very first run (no file) baselines the backlog without emitting.
    let seeded = restored.existed;

    // Fetch + normalise every account; one that returns nothing is skipped by
    // the natural empty flatMap (no special-casing needed).
    const collect = (): GithubEvent[] =>
      GITHUB_ACCOUNTS.flatMap((account) =>
        normalizeNotifications(fetchNotifications(account), account),
      );

    const tick = () => {
      const events = collect();
      lastPolledAt = Date.now();

      if (!seeded) {
        // First run ever: absorb the current backlog into the cursor and persist
        // it, but publish nothing.
        seen = pruneSeen(selectNew(events, seen).nextSeen, SEEN_CAP);
        seeded = true;
        saveSeen(seen);
        report(seen.size ? `idle · ${seen.size} tracked` : 'idle');
        return;
      }

      const { fresh, nextSeen } = selectNew(events, seen);
      seen = pruneSeen(nextSeen, SEEN_CAP);

      for (const event of fresh) {
        bus.publish({ type: 'github_event', event });
        log(`github: [${event.account}] ${event.kind} ${event.repo} · ${event.title}`);
      }
      if (fresh.length) saveSeen(seen);

      report(statusFor(fresh, lastPolledAt));
    };

    // Report the initial state; the first tick runs synchronously below.
    report('idle');

    const loop = pollEvery(GITHUB_POLL_MS, tick);
    return {
      getCurrentState: () => ({ lastPolledAt, seenCount: seen.size }),
      stop: loop.stop,
      done: loop.done,
    };
  },
};

/** Terse board status: new-count + poll time, or an idle marker. */
function statusFor(fresh: GithubEvent[], polledAt: number): string {
  const time = hhmm(polledAt);
  return fresh.length ? `${fresh.length} new · ${time}` : `idle · ${time}`;
}

/** `HH:MM` local time for the board status. */
function hhmm(ms: number): string {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
