---
name: "ic-orchestrator"
description: "Run multi-round research/implementation projects as a technical lead: decompose into discrete IC tasks, delegate to parallel IC subagents, verify with separate review agents, iterate until every phase is SHIPPABLE."
version: 4
---
## When to Use
When the user asks you to act as a technical lead / DRI orchestrating several rounds of research and implementation, explicitly says to delegate rather than do the work yourself, or hands you a multi-phase task with a required review loop. Also useful for any large task where you must protect your context and enforce a verification gate per phase.

## Orchestrator Discipline
Your job is direction, not implementation. Maintain the task list, write briefs, dispatch agents, read their reports, decide verdicts, iterate rounds — nothing else.

**Own the task list — it is your map of the work.** You decide what happens and in what order:
- Keep one running list across all phases, each task with a status: queued → dispatched (to which IC) → in review → SHIPPABLE → done.
- Sequence by dependencies and critical path: nothing starts before its blockers are SHIPPABLE.
- Update the list every time a report or verdict lands: mark done, re-prioritize, and fold re-briefs and follow-ups in as new tasks.
- The task list is how you track progress without reading files — reports update it; never check the tree to see where things stand.

- Directing, not doing, is the line — not "no commands." Tracking commands are part of the job, run them freely: git status/tag, gh issue list/view/close/comment/relabel.
- What you never do is the work itself: no reading source files to check on ICs, no re-running gates or probes — that is what reports and reviewers are for. If a report is thin, send it back, or fold the question into the next review brief — don't go look yourself.
- Every source file you read and every gate you re-run duplicates subagent work and burns the context this skill exists to protect.
- Your direct-inspection list is small: review verdicts, git status/tag, gh tickets, the user's approval. Everything else delegates.

## Task Tracking
Two modes, decided up front — what differs is where the durable layer lives. The Discipline rules above apply in both; these are the storage mechanics.

**Mode A — file list (default, no tickets).** You maintain the list yourself: in-context is fine, mirror it to a file if you want a durable record. Single writer: ICs and reviewers report to you; you update it. Nothing else to add — the Discipline bullets above are the full rules.

**Mode B — GitHub tickets (work is ticket-driven).** Tickets already exist — any size, not yours to size. They are the durable layer; your list is the operational layer built on top.
- Ingest once up front: `timeout 30s gh issue list --state open --jq ...` — number, title, labels only.
- Tickets and tasks do not map 1:1 — decompose freely; tag each task with its source ticket. Tickets are the unit of user-visible work; tasks are the unit of dispatch.
- You are the single writer to tickets: ICs and reviewers report to you, you mutate tickets; agents never touch them — same clobbering logic as the git rules.
- Update tickets only at meaningful points: close (with a summary comment) when every task it spawned is SHIPPABLE; comment or relabel when blocked or needs input. No churn per task.
- gh ticket ops are task-list ops, so they sit in your whitelist: ingest (`issue list/view`) and updates (`close/comment/relabel`) — always timeout-wrapped and `--jq`-narrowed.

## Procedure
1. **Decompose the project into phases, then into discrete IC tasks.** Each task must be small enough to finish in one round and scoped to specific files, with no (or minimal) overlap with other ICs' file scope. Define the phase's acceptance criteria up front — what done means plus the cheap, re-runnable checks (build/typecheck/lint) that prove it — as the condition for the phase to be SHIPPABLE. If the work arrived as GitHub tickets, ingest them first (see Task Tracking) and tag each task with its source ticket. Load every task into your task list with a status before dispatching anything.
2. **Dispatch ICs in parallel, one background agent per task**, each with a self-contained brief (see IC Brief template below). Warn that other agents may work in the same repo and that file conflicts are expected — resolving them by reporting, not clobbering.
3. **Collect results, then review independently — adversarially.** Do not trust IC summaries: dispatch a separate review agent (see Review Brief template below), briefed with the original task definition (TASK/SCOPE/ACCEPTANCE from the IC brief or source ticket) and the IC's report, that re-runs the acceptance checks itself, tries to break the IC's claims against the real tree, and hunts the 80% tells the report won't mention.
4. **Gate the phase on the review verdict.** Advance only when the reviewer returns SHIPPABLE. If NOT SHIPPABLE, fold the findings into a re-brief (or relaunch the IC with clearer instructions) and re-review before proceeding. Update the task list after every verdict.
5. **Ship the final phase:** record a tag/rollback point, finalize docs with implementation record + follow-ups, and get the user's explicit approval before the delivery action (push).

## IC Brief Template
Fill the variable fields per task; the rules block goes in every prompt verbatim.

```
TASK: <one sentence — the discrete deliverable>
SCOPE: <files/dirs this IC owns; note expected overlap with other agents>
ACCEPTANCE: <what done means + the exact commands that prove it, e.g. "build passes clean: pnpm build && pnpm typecheck">
FILES: <every path you touch, one per line — the reviewer narrows to this list>
UNFINISHED: <anything not done, or "none">

RULES (append verbatim to every IC prompt):
- Include a timeout on every shell command: curl -m 10 / timeout 30s; never curl SSE endpoints without -m (replay-then-tail streams forever); no pty/interactive commands; abandon any command that blocks >120s and note it.
- Never run git stash, git checkout, git restore, git clean, or git commit.
- Other agents may be working in this repo. Stay in your SCOPE; if another agent's file overlaps yours, report it instead of overwriting.
- Your work will be reviewed adversarially by a separate agent: expect your claims to be probed with edge cases and checked against the real tree. Self-check your ACCEPTANCE before reporting done, and make FILES complete and accurate — the reviewer cross-checks it against the tree.
- Feature or bugfix tasks: follow the tdd skill (read ~/.agents/skills/tdd/SKILL.md) — red → green in vertical slices, tests through public seams, keep the tests as part of the deliverable. Pure docs, research, or config work does not need tests.
```

## Review Brief Template
Fill per phase; the reviewer must be independent of the IC that did the work.

```
PHASE: <what was supposed to ship this round>
TASK BRIEF: <the original task definition — TASK, SCOPE, ACCEPTANCE from the IC brief or source ticket; paste verbatim>
IC CLAIMS: <paste the IC's report>
ATTACK (the report is optimistic — find where it's wrong):
- Read the TASK BRIEF first: judge the IC against the assignment, not against its own claims.
- Cross-check the IC's FILES list against the tree first: every listed path actually changed, and nothing changed that isn't listed. That list narrows your review — then go through it file-by-file.
- Re-run the acceptance checks from the TASK BRIEF yourself, then try to break them: feed the changed code inputs the IC didn't test — edge cases, error paths, empty/absent states, the failure branch.
- Hunt the 80% tells in the listed files: stubs, TODO/FIXME left behind, commented-out code, hardcoded values, swallowed exceptions, happy-path-only logic.
- Read acceptance semantically: a green build is not done. Does the code actually do what the TASK BRIEF's ACCEPTANCE says, or does it merely compile?
- Scope both directions beyond the list: files touched that the TASK BRIEF didn't authorize (drift) AND behaviors the TASK BRIEF required that are missing.
- If the tree looks unexpectedly clean, check git stash list before concluding nothing changed.
VERDICT: SHIPPABLE or NOT SHIPPABLE, with the specific gaps. Cite at least one probe you ran per acceptance criterion. Never rubber-stamp the IC's self-report.
```

## Pitfalls
- **`git stash` hides every workstream at once.** ICs and reviewers may run it mid-verification to "clean the tree", hiding EVERY workstream's changes in one snapshot (seen 2026-08-22: three parallel ICs all stashed; one `git stash pop` restored all of it, but had the stash been dropped the round would have been lost). The ban is in the template for a reason — keep it in every prompt, and if an agent claims edits but the tree looks clean, check `git stash list` before assuming loss.
- **A stuck agent blocks the round.** Long runtime + few tool calls + no progress usually means a blocked command. steer_subagent to abort the blocking command instead of waiting; if it stays stuck, stop it and relaunch with clearer instructions rather than letting it hang again.
- **Reviewers rubber-stamp.** A review that reads the IC's summary and says "looks good" is not verification. The Review Brief forces an adversarial pass — re-running acceptance checks, probing untested paths, and hunting the 80% tells against the real tree. Never accept a summary-only verdict.
- **Green gates ≠ done.** Acceptance commands passing proves the code builds and lints — not that it does what "done" means. A verdict citing only command output is shallow; demand the reviewer's own probes and semantic evidence.
- **ICs stop at 80%.** Vague acceptance criteria invite premature completion — "understanding reached" reads as done. Make ACCEPTANCE an exact command that either passes or fails, and demand its output in the report.
- **The orchestrator becomes the IC.** The driver dives into source files or re-runs gates itself "just to check", duplicating subagent work and burning the context the whole design protects. Tell: if you're about to read a source file or re-run a gate to verify an IC's claim, that's a delegation signal — send the report back or fold it into the next review brief instead.
- **Tickets lie.** When the durable layer (GitHub) drifts from the operational layer (your list), the user reads tickets and sees open issues for shipped work. Every SHIPPABLE verdict closes its source ticket in the same round; a blocked task gets a comment at the moment it blocks, not later.

## Verification
1. Every phase has an independent review verdict (SHIPPABLE) before the next phase starts.
2. Review agents re-ran the acceptance checks, attacked the claims with their own probes, and verified file scope against the brief — never against the IC's summary.
3. Final state: task list shows every task SHIPPABLE/done, clean tree, tag/rollback point recorded, docs finalized with implementation record + follow-ups, user approved the delivery action (push). In ticket mode, every completed ticket is closed with a summary comment.
