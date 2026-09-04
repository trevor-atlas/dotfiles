---
name: pr-review-multi
description: Multi-agent PR review — orchestrates parallel subagents that review the diff by chunk and by concern, then reconciles findings and posts a GitHub review. Use when user says "multi-agent review", "parallel review", or wants a thorough multi-perspective code review of a PR. Falls back to pr-review if the Agent tool is unavailable.
---

# Multi-Agent PR Review

Orchestrate parallel subagents that review a PR from multiple angles, then reconcile their findings into a single GitHub review.

## Prerequisites

This skill uses the `Agent` tool to dispatch subagents. If `Agent` is not available, fall back to the `pr-review` skill (single-agent mode).

## On Skill Load

Determine the entry point — do NOT ask what to do:

1. **PR URL or number provided** → use it
2. **On a feature branch** with a diff against `main`/`master` → suggest `pr-self-review` instead, but proceed if they insist
3. **Neither** → ask for a PR URL or number

## Step 1: Fetch PR Context

```bash
# Internal HubSpot repos (git.hubteam.com):
GH_HOST=git.hubteam.com gh pr view <N> -R <OWNER/REPO> --json title,body,files,additions,deletions,headRefName,baseRefName
GH_HOST=git.hubteam.com gh pr diff <N> -R <OWNER/REPO>

# github.com repos — drop GH_HOST:
gh pr view <N> -R <OWNER/REPO> --json title,body,files,additions,deletions
gh pr diff <N> -R <OWNER/REPO>
```

If `gh pr diff` fails (HTTP 406, diff too large), work from the file list and fetch individual files.

## Step 2: Chunk the Diff

Read the diff. Group hunks into 3–5 **logical groups** — semantic buckets like "auth middleware", "DB migration", "test updates". Record each group's label and which files/lines it covers.

Write a one-paragraph **PR summary** of what the PR does.

## Step 3: Dispatch Wave 1 — Chunk Reviewers

Spawn one `pr-reviewer` subagent per chunk, all in a **single message** for parallelism. Use `run_in_background: true`.

**Always set `max_turns`** — this is the single most important guard against runaway subagents. Without it, subagents default to *unlimited* turns and can chase references across the whole codebase for an hour. Use:
- `max_turns: 12` for small chunks (≤ ~150 diff lines)
- `max_turns: 18` for medium chunks
- `max_turns: 25` for large chunks (cap — split the chunk instead of going higher)

For each chunk, the prompt is:

```
Review chunk "<LABEL>" of PR #<N> in <OWNER/REPO>.

## PR Summary
<one paragraph>

## Your Chunk (diff hunks)
<paste only the diff hunks for this chunk>

## Logical Groups
<list all group labels — pick the matching one for each finding>

## Investigation budget
You have a strict turn budget. Spend it on the highest-value checks only:
- At most 2-3 targeted source reads/greps to confirm a suspected issue.
- Do NOT recursively trace call chains, follow every import, or read whole files
  beyond the changed region. If a concern needs more than ~3 lookups to confirm,
  report it as `flag_investigate` with what you checked and move on.
- Prefer findings you can assert from the diff itself.

Return findings as a JSON array. If nothing found, return [].
```

## Step 4: Dispatch Wave 2 — Concern Reviewers

**Sizing decision — skip Wave 2 for small PRs.** If the total diff is ≤ ~200 lines or ≤ 3 files, the chunk reviewers in Wave 1 already cover the PR well — skip Wave 2 entirely and go to Step 5. Running 4 more full-diff subagents on a tiny PR is pure waste and the most common cause of long wall-clock times.

For larger PRs, spawn one `pr-reviewer` subagent per concern area, all in a **single message**. Use `run_in_background: true`.

**Set `max_turns: 20`** on each concern reviewer (cap at 25). Concern reviewers get the full diff, so they have more to process — but the same turn-budget discipline applies: a few targeted lookups, not open-ended exploration.

Default concern areas (drop any that clearly don't apply; add "Performance" for DB-heavy changes, "Concurrency" for threading code):

- **Correctness** — logic errors, off-by-ones, null handling, race conditions
- **Security** — injection, auth/authz, sensitive data exposure, insecure config
- **Error handling** — missing error handling, swallowed exceptions, broken contracts
- **Test coverage** — are changes adequately tested? Untested edge cases?

For each concern, the prompt is:

```
Review PR #<N> in <OWNER/REPO> for <CONCERN> issues only.

## PR Summary
<one paragraph>

## Full Diff
<entire diff>

Focus: <concern-specific guidance>. Ignore other concern areas — other
subagents cover those.

## Investigation budget
Strict turn budget — spend it on the highest-value checks for <CONCERN> only:
- At most 2-3 targeted source reads/greps to confirm a suspected issue.
- Do NOT recursively trace call chains or read whole files outside the changed
  region. If a concern needs more than ~3 lookups to confirm, report it as
  `flag_investigate` with what you checked and move on.
- Prefer findings you can assert from the diff itself.

Return findings as a JSON array. If nothing found, return [].
```

## Step 5: Collect Results

Use `get_subagent_result` with `wait: true` for each subagent, or wait for completion notifications. Parse the JSON array from each subagent's return value.

If a subagent's output isn't clean JSON, extract the JSON array from the text (it may be wrapped in markdown fences or prose).

## Step 6: Reconcile

Merge all findings from all subagents, then:

1. **Cross-subagent dedup** — same file + adjacent line + semantically same issue → keep the one with the richer description / better suggested fix, drop the other. When in doubt, keep both — users can dismiss noise, but can't recover a demoted finding.
2. **Existing PR thread dedup** — fetch review threads and skip findings that restate resolved/open threads on the same file + line:
```bash
GH_HOST=<host> gh api graphql -f query='
query { repository(owner: "<OWNER>", name: "<REPO>") {
  pullRequest(number: <N>) {
    reviewThreads(first: 100) { nodes { isResolved isOutdated path line
      comments(first: 1) { nodes { body } } } } } } }'
```
3. **Severity cap** — if > 50 findings, cap by severity: promote `bug_high` + `bug_low` first, then `flag_investigate`, demote `flag_info` last.

## Step 7: Write the Review Message

Determine the recommendation from **open** findings:
- Any `bug_high` open → **REQUEST_CHANGES**
- Any `bug_low` or `flag_investigate` open (no `bug_high`) → **COMMENT**
- Only `flag_info` or nothing → **APPROVE**

Compose a 1–3 sentence top-level message whose **tone matches the recommendation**. See [../pr-review/REFERENCE.md](../pr-review/REFERENCE.md) for tone guidance. The #1 failure mode: upbeat "looks good!" language paired with REQUEST_CHANGES.

## Step 8: Present Findings and Confirm Before Posting

Present the reconciled findings to the user in a clear, readable format. Do NOT post anything yet.

### Format for the user

```
Multi-agent review — <N> subagents (<chunk> chunk reviewers + <concern> concern reviewers).
<review message>

Findings:

1. <description> (<severity>)
   <path>:<line_start>-<line_end> — <one-line detail>
   Suggested fix: <suggested_fix>

2. ...
```

Then ask the user:

> Ready to post this review as <APPROVE|COMMENT|REQUEST_CHANGES> with <N> inline comments. Should I post it, or would you like to adjust anything?

Wait for the user's response. They may want to:
- Approve posting as-is
- Remove specific findings
- Edit a finding's description or severity
- Change the recommendation
- Add their own findings
- Cancel entirely

Only proceed to Step 9 when the user explicitly confirms.

## Step 9: Post the Review

Post each finding as an **inline review comment** on its specific file + line, and the review message as the **top-level review body**. This keeps findings anchored to the code they're about, not jumbled in one block.

### 9a. Submit the review with the top-level message

```bash
# APPROVE / COMMENT:
GH_HOST=<host> gh pr review <N> -R <OWNER/REPO> --<approve|comment> --body-file - <<'EOF'
<review message>
EOF

# REQUEST_CHANGES:
GH_HOST=<host> gh pr review <N> -R <OWNER/REPO> --request-changes --body-file - <<'EOF'
<review message>
EOF
```

### 9b. Post each finding as an inline comment on its line

For each finding that has a `path` and `line_start`, post it as a review comment anchored to that line:

```bash
GH_HOST=<host> gh api repos/<OWNER/REPO>/pulls/<N>/comments \
  -f body="**<severity>** — <description>

Suggested fix: <suggested_fix>" \
  -F line=<line_end> \
  -F path="<path>" \
  -F side=RIGHT
```

For findings **without** a path/line (general/architectural concerns), append them to the top-level review body instead of posting as inline comments.

**Always use `--body-file` with a heredoc** for the review body — never `--body` — to avoid shell escaping issues with backticks and quotes.

## Step 10: Report

Summarize for the user: how many subagents ran, findings by severity, the recommendation, how many inline comments were posted, and a link to the posted review.
