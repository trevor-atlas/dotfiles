# pi config — `~/.pi/agent`

Landing points for pi (the terminal coding harness). This repo (`settings/dot_pi/agent/`)
is chezmoi's source of truth for `~/.pi/agent/`. Static files are symlinked; templates
are rendered; edits to deployed files edit the repo and vice versa.

## Directory map

| Path (repo → `~/.pi/agent/`) | What | How it loads |
|---|---|---|
| `extensions/*.ts`, `extensions/<dir>/index.ts` | Standalone pi extensions | Auto-discovered from `~/.pi/agent/extensions/` |
| `packages/` | Pi packages (bundled extension + resources) | Loaded only via the `packages` list in `settings.json` |
| `skills/` | Agent skills | Auto-discovered from `~/.pi/agent/skills/` |
| `scripts/` (`measure-context.ts`) | User scripts | Referenced directly by path in configs |
| `models.json.tmpl` → `models.json` | Provider/model config; injects `*_API_KEY` env | Rendered chezmoi template — never commit raw keys |
| `modify_settings.json` → `settings.json` | `packages`, `defaultModel/Provider`, theme, etc. | chezmoi modify-template; regenerate with `chezmoi apply ~/.pi/agent/settings.json` |

## Management boundaries (what to touch vs leave)

- **Repo-managed** (edit in `settings/dot_pi/agent/`; changes meet `~/.pi/agent/` via symlink):
  extensions, packages, skills, scripts, the two templates.
- **herdr-managed** — `extensions/herdr-agent-state.ts`. Do NOT edit; herdr overwrites it
  on reinstall. Put your own hooks beside it, not in it.
- **pi-local / auto-generated, NOT in this repo** — `auth.json`, `models-store.json`,
  `sessions/`, `npm/`, `bin/`, and any skill not listed under `settings/dot_pi/agent/skills/`
  (e.g. the Showrunner set: `build`, `scout`, `plan`, `everything`, …). These are installed
  by herdr/pi themselves and should not be committed here.
- Compare `ls settings/dot_pi/agent/skills/` vs `ls ~/.pi/agent/skills/` to see the split;
  only the former is tracked.

## `extensions/` wiring — the non-obvious bit

- Extensions in `~/.pi/agent/extensions/` auto-load via `*.ts` (top level) or `*/index.ts`
  (one subdir deep). A nested entry (e.g. `pi-interactive-subagents/pi-extension/subagents/index.ts`)
  will NOT auto-discover — it must be added to the `extensions` array in `settings.json`,
  or shipped as a package in the `packages` list.
- Import aliases: pi 0.84.x's extension loader maps both `@earendil-works/pi-coding-agent`/`pi-tui`
  and the legacy `@mariozechner/pi-coding-agent`/`pi-tui` to bundled modules, so extensions using
  either namespace load fine. `@sinclair/typebox` is available too.
- Reload extensions with `/reload` in a pi session.

## Current extensions / packages

- `extensions/prompt-snippets/` — `/snippets` command + `alt+s`; snippet `.md` files in its `snippets/` dir, re-scanned on menu open/send.
- `extensions/ask-user-question.ts` — the `ask_user_question` tool.
- `extensions/custom-header.ts` — replaces the startup header (editable `buildHeader()`).
- `packages/pi-interactive-subagents` — bundled in `packages/` (registered in `settings.json`
  `packages`), not auto-discovered; entry at `pi-extension/subagents/index.ts`, resolves
  `agents/` and `config.json.example` relative to its own path through the symlink.
