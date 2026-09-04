# agent skills — `~/.agents/skills`

Canonical, harness-agnostic skills root. Every agent harness on this machine
(pi, Claude Code, etc.) reads skills from `~/.agents/skills/`, so user-authored
skills live here once instead of being duplicated per harness.

This repo directory (`settings/dot_agents/`) is chezmoi's source of truth for
`~/.agents/`. Static files are symlinked (mode = symlink), so edits to a deployed
skill edit the repo and vice versa.

## What's here

- `skills/` — one subdirectory per skill (`SKILL.md` + optional support files),
  symlinked into `~/.agents/skills/`. Consolidates **all** skills for this machine:
  the user-authored pi skills (moved here from `settings/dot_pi/agent/skills/`)
  and the previously pi-local / Showrunner skills (`build`, `plan`, `scout`, etc.).

## Boundaries

- **Repo-managed (chezmoi symlink):** everything under `skills/` — ~/.pi/agent/skills
  is intentionally empty now; all skills are symlinked into `~/.agents/skills/` from
  this directory.
- **Not repo-managed:** `~/.agents/.skill-lock.json` and any skill dir present in
  `~/.agents/skills/` but absent from `skills/` here — those are installed by an
  external skills tool (github-plugin lockfile format) and live only on this machine.

## Adding a skill

1. Add the skill directory under `settings/dot_agents/skills/<name>/` (in this repo).
2. `chezmoi apply ~/.agents/skills` to symlink it into the canonical location.
3. Any harness (pi included) picks it up automatically from `~/.agents/skills/`.
