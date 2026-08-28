/**
 * githubEvents: a producer that surfaces GitHub activity relevant to the user.
 *
 * Same shape as `callDetector.ts`: a self-contained polled source that owns its
 * own `pollEvery` cadence, normalises what it reads into typed events, publishes
 * them to the shared bus, logs the transitions, and reports a terse live status
 * to its board row.
 *
 * There is no per-user GitHub webhook, so — with NO new GitHub App / OAuth — we
 * poll the notifications REST API through the already-authenticated `gh` CLI on
 * BOTH hosts the user has (personal `github.com` and the HubSpot enterprise
 * server `git.hubteam.com`), normalise, and publish. Low latency isn't needed
 * (a ~5-minute cadence is fine), so this is a plain deadline poll like the rest.
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
import type { SystemEvent } from './systemEvents';
import { pollEvery, type ProducerDescriptor } from './poll';
import { log } from './logSink';

/** How often we poll GitHub notifications (its own cadence). Editable. */
const GITHUB_POLL_MS = 5 * 60_000;

/** The hosts the user has `gh` authenticated for. Editable. */
const GITHUB_HOSTS = ['github.com', 'git.hubteam.com'] as const;

/**
 * `participating=true` = only threads that directly involve the user (mentions,
 * review requests, assignments, things they authored), not everything they
 * merely watch. Editable — flip to widen the net.
 */
const GITHUB_PARTICIPATING = true;

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
 * one can't be derived; `host` distinguishes personal vs. enterprise.
 */
export type GithubEvent = {
  id: string;
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
export function normalizeNotifications(rawJson: string | unknown[]): GithubEvent[] {
  const out: GithubEvent[] = [];
  for (const item of toArray(rawJson)) {
    const event = normalizeOne(item);
    if (event) out.push(event);
  }
  return out;
}

/**
 * Split `events` into the ones not yet seen (`fresh`) and the advanced cursor
 * (`nextSeen`). Pure. Keyed on `id:updatedAt` so a thread only re-fires once it
 * has genuinely new activity (a newer `updatedAt`); `nextSeen` is a superset of
 * `seen` plus every key in this batch.
 */
export function selectNew(
  events: GithubEvent[],
  seen: ReadonlySet<string>,
): { fresh: GithubEvent[]; nextSeen: Set<string> } {
  const nextSeen = new Set(seen);
  const fresh: GithubEvent[] = [];
  for (const event of events) {
    const key = `${event.id}:${event.updatedAt}`;
    if (nextSeen.has(key)) continue;
    nextSeen.add(key);
    fresh.push(event);
  }
  return { fresh, nextSeen };
}

/** One raw notification → `GithubEvent`, or null if it has no usable thread id. */
function normalizeOne(item: unknown): GithubEvent | null {
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
 * Fetch a host's participating notifications via the authenticated `gh` CLI.
 * Returns `[]` on ANY failure (gh missing, host not authed, network error,
 * non-zero exit, non-JSON) — never throws. READ-ONLY: only a GET.
 */
function fetchNotifications(host: string): unknown[] {
  try {
    const participating = GITHUB_PARTICIPATING ? 'true' : 'false';
    const proc = spawnSync([
      'gh',
      'api',
      '--hostname',
      host,
      `/notifications?participating=${participating}&all=false`,
      '--paginate',
    ]);
    if (!proc.success) return [];
    const parsed = JSON.parse(proc.stdout.toString());
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/* -------------------------------------------------------------------------- */
/* Producer descriptor                                                        */
/* -------------------------------------------------------------------------- */

/**
 * The GitHub-notifications producer as a self-naming, self-reporting descriptor
 * (see `callDetector.ts`). The first tick SEEDS the baseline into `seen`
 * WITHOUT publishing — so the whole unread backlog isn't replayed on startup —
 * then every later tick publishes only genuinely-new threads.
 */
export const githubEventDetector: ProducerDescriptor<GithubState, SystemEvent> = {
  name: 'github events',
  start: (bus, report) => {
    let seen = new Set<string>();
    let lastPolledAt: number | null = null;
    let seeded = false;

    // Fetch + normalise both hosts; a host that returns nothing is skipped by
    // the natural empty flatMap (no special-casing needed).
    const collect = (): GithubEvent[] =>
      GITHUB_HOSTS.flatMap((host) => normalizeNotifications(fetchNotifications(host)));

    const tick = () => {
      const events = collect();
      lastPolledAt = Date.now();

      if (!seeded) {
        // Baseline: absorb everything currently unread, publish nothing.
        seen = selectNew(events, seen).nextSeen;
        seeded = true;
        report(seen.size ? `idle · ${seen.size} tracked` : 'idle');
        return;
      }

      const { fresh, nextSeen } = selectNew(events, seen);
      seen = nextSeen;

      for (const event of fresh) {
        bus.publish({ type: 'github_event', event });
        log(`github: ${event.kind} ${event.repo} · ${event.title}`);
      }

      report(statusFor(fresh, lastPolledAt));
    };

    // Report the initial state; the first tick runs synchronously below and
    // overwrites it the moment it has seeded the baseline.
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
