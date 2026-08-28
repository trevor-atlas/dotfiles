/**
 * Unit tests for the GitHub-notifications producer's PURE core. Run with:
 *   bun test
 *
 * Only the two pure functions are exercised here — the real decision logic:
 *   - `normalizeNotifications`: raw `gh api /notifications` JSON → `GithubEvent[]`
 *     (field mapping, `kind` derivation, browser-URL derivation, tolerance to
 *     malformed input);
 *   - `selectNew`: dedup/baseline selection keyed on `id:updatedAt`.
 *
 * The thin IO (`fetchNotifications`, which shells out to `gh`) is deliberately
 * NOT unit-tested — same policy as `zoomWindowTitles` in `callDetector.ts`.
 * Fixtures ship inline so a test is a readable spec of one notification shape.
 */
import { test, expect } from 'bun:test';
import {
  normalizeNotifications,
  selectNew,
  seenKey,
  serializeSeen,
  parseSeen,
  pruneSeen,
  type GithubEvent,
} from './githubEvents';

/** A well-formed personal-host notification (review requested on a PR). */
const reviewRequestedPr = {
  id: '1001',
  reason: 'review_requested',
  updated_at: '2024-01-02T12:00:00Z',
  subject: {
    title: 'Fix the flaky test',
    url: 'https://api.github.com/repos/octo/repo/pulls/42',
    type: 'PullRequest',
  },
  repository: { full_name: 'octo/repo', html_url: 'https://github.com/octo/repo' },
};

test('normalizeNotifications: maps every field and derives kind + browser url (PR review)', () => {
  const [event] = normalizeNotifications([reviewRequestedPr], 'trevor-atlas');
  expect(event).toEqual({
    id: '1001',
    account: 'trevor-atlas',
    host: 'github.com',
    kind: 'review_requested',
    reason: 'review_requested',
    repo: 'octo/repo',
    subjectType: 'PullRequest',
    title: 'Fix the flaky test',
    url: 'https://github.com/octo/repo/pull/42',
    updatedAt: '2024-01-02T12:00:00Z',
  });
});

test('normalizeNotifications: mention on an Issue → kind mentioned, /issues/ url', () => {
  const [event] = normalizeNotifications([
    {
      id: '1002',
      reason: 'mention',
      updated_at: '2024-01-03T09:30:00Z',
      subject: {
        title: 'Where is this configured?',
        url: 'https://api.github.com/repos/octo/repo/issues/7',
        type: 'Issue',
      },
      repository: { full_name: 'octo/repo', html_url: 'https://github.com/octo/repo' },
    },
  ]);
  expect(event?.kind).toBe('mentioned');
  expect(event?.subjectType).toBe('Issue');
  expect(event?.url).toBe('https://github.com/octo/repo/issues/7');
});

test('normalizeNotifications: assign → kind assigned', () => {
  const [event] = normalizeNotifications([
    { ...reviewRequestedPr, id: '1003', reason: 'assign' },
  ]);
  expect(event?.kind).toBe('assigned');
});

test('normalizeNotifications: coarse fallback by subject.type (comment/subscribed)', () => {
  const events = normalizeNotifications([
    { ...reviewRequestedPr, id: '1004', reason: 'comment', subject: { ...reviewRequestedPr.subject } },
    {
      id: '1005',
      reason: 'subscribed',
      updated_at: '2024-01-04T00:00:00Z',
      subject: { title: 'A tracked issue', url: 'https://api.github.com/repos/octo/repo/issues/9', type: 'Issue' },
      repository: { full_name: 'octo/repo', html_url: 'https://github.com/octo/repo' },
    },
  ]);
  expect(events.map((e) => e.kind)).toEqual(['pr_activity', 'issue_activity']);
});

test('normalizeNotifications: unknown reason + unknown subject.type → other', () => {
  const [event] = normalizeNotifications([
    {
      id: '1006',
      reason: 'ci_activity',
      updated_at: '2024-01-05T00:00:00Z',
      subject: { title: 'CI run', url: 'https://api.github.com/repos/octo/repo/check_suites/3', type: 'CheckSuite' },
      repository: { full_name: 'octo/repo', html_url: 'https://github.com/octo/repo' },
    },
  ]);
  expect(event?.kind).toBe('other');
  // Only PR/Issue subjects get a clean browser URL; anything else stays null.
  expect(event?.url).toBeNull();
});

test('normalizeNotifications: a non-github.com host derives its own host + browser url', () => {
  const [event] = normalizeNotifications([
    {
      id: '2001',
      reason: 'review_requested',
      updated_at: '2024-02-01T10:00:00Z',
      subject: {
        title: 'Enterprise change',
        url: 'https://ghe.example.com/api/v3/repos/team/repo/pulls/7',
        type: 'PullRequest',
      },
      repository: { full_name: 'team/repo', html_url: 'https://ghe.example.com/team/repo' },
    },
  ]);
  expect(event?.host).toBe('ghe.example.com');
  expect(event?.url).toBe('https://ghe.example.com/team/repo/pull/7');
});

test('normalizeNotifications: missing subject.url → url is null, other fields survive', () => {
  const [event] = normalizeNotifications([
    {
      id: '3001',
      reason: 'author',
      updated_at: '2024-03-01T00:00:00Z',
      subject: { title: 'No API url here', url: null, type: 'PullRequest' },
      repository: { full_name: 'octo/repo', html_url: 'https://github.com/octo/repo' },
    },
  ]);
  expect(event?.url).toBeNull();
  expect(event?.title).toBe('No API url here');
  expect(event?.kind).toBe('pr_activity');
});

test('normalizeNotifications: empty array → empty result', () => {
  expect(normalizeNotifications([])).toEqual([]);
});

test('normalizeNotifications: accepts a raw JSON string', () => {
  const events = normalizeNotifications(JSON.stringify([reviewRequestedPr]));
  expect(events.map((e) => e.id)).toEqual(['1001']);
});

test('normalizeNotifications: tolerates malformed input without throwing', () => {
  expect(normalizeNotifications('not json at all')).toEqual([]);
  // A non-array JSON payload is not a notifications list.
  expect(normalizeNotifications('{"message":"Not Found"}')).toEqual([]);
  // Items missing an id, or that aren't objects, are skipped — good ones survive.
  const mixed = normalizeNotifications([
    null,
    'garbage',
    { reason: 'mention' }, // no id → skipped
    reviewRequestedPr,
  ]);
  expect(mixed.map((e) => e.id)).toEqual(['1001']);
});

test('selectNew: first-seen items are fresh and accumulate into nextSeen', () => {
  const events = normalizeNotifications(
    [reviewRequestedPr, { ...reviewRequestedPr, id: '1002', updated_at: '2024-01-02T12:00:00Z' }],
    'me',
  );
  const { fresh, nextSeen } = selectNew(events, new Set());
  expect(fresh.map((e) => e.id)).toEqual(['1001', '1002']);
  expect(nextSeen.has('me:1001:2024-01-02T12:00:00Z')).toBe(true);
  expect(nextSeen.has('me:1002:2024-01-02T12:00:00Z')).toBe(true);
});

test('selectNew: already-seen items are filtered out', () => {
  const events = normalizeNotifications([reviewRequestedPr], 'me');
  const seen = new Set(['me:1001:2024-01-02T12:00:00Z']);
  const { fresh, nextSeen } = selectNew(events, seen);
  expect(fresh).toEqual([]);
  expect(nextSeen).toEqual(seen);
});

test('selectNew: same id with a newer updated_at re-fires', () => {
  const older: GithubEvent[] = normalizeNotifications([reviewRequestedPr], 'me');
  const { nextSeen: afterFirst } = selectNew(older, new Set());

  const newer = normalizeNotifications(
    [{ ...reviewRequestedPr, updated_at: '2024-01-02T18:45:00Z' }],
    'me',
  );
  const { fresh, nextSeen } = selectNew(newer, afterFirst);

  expect(fresh.map((e) => e.updatedAt)).toEqual(['2024-01-02T18:45:00Z']);
  // The cursor keeps both the old and the new key.
  expect(nextSeen.has('me:1001:2024-01-02T12:00:00Z')).toBe(true);
  expect(nextSeen.has('me:1001:2024-01-02T18:45:00Z')).toBe(true);
});

test('seenKey: namespaces by account so the two accounts never collide', () => {
  const [a] = normalizeNotifications([reviewRequestedPr], 'trevor-atlas');
  const [b] = normalizeNotifications([reviewRequestedPr], 'tatlas_hubspot');
  expect(seenKey(a!)).toBe('trevor-atlas:1001:2024-01-02T12:00:00Z');
  expect(seenKey(b!)).toBe('tatlas_hubspot:1001:2024-01-02T12:00:00Z');
  expect(seenKey(a!)).not.toBe(seenKey(b!));
});

test('selectNew: the same thread id under two accounts is not deduped away', () => {
  const events = [
    ...normalizeNotifications([reviewRequestedPr], 'trevor-atlas'),
    ...normalizeNotifications([reviewRequestedPr], 'tatlas_hubspot'),
  ];
  const { fresh } = selectNew(events, new Set());
  expect(fresh.map((e) => e.account)).toEqual(['trevor-atlas', 'tatlas_hubspot']);
});

test('parseSeen / serializeSeen: round-trip and tolerate junk', () => {
  const seen = new Set(['me:1:t1', 'me:2:t2']);
  expect(parseSeen(serializeSeen(seen))).toEqual(seen);
  // Tolerant: bad JSON, a non-array, and non-string entries never throw.
  expect(parseSeen('not json')).toEqual(new Set());
  expect(parseSeen('{"nope":true}')).toEqual(new Set());
  expect(parseSeen('["ok", 42, null, "ok2"]')).toEqual(new Set(['ok', 'ok2']));
});

test('pruneSeen: keeps the most-recent `cap` keys, drops the oldest', () => {
  const seen = new Set(['a', 'b', 'c', 'd']); // insertion order = oldest→newest
  expect(pruneSeen(seen, 10)).toEqual(seen); // under cap: unchanged
  expect([...pruneSeen(seen, 2)]).toEqual(['c', 'd']); // over cap: newest kept
});
