# skill-picker

Adds an inline `$` skill autocomplete **anywhere in a prompt** — the same UX as
pi's built-in `/` command and `@` file pickers. Replaces pi's default
`/skill:name` command selector.

## Usage

Type `$` at the **start of a word** (prompt start, line start, or after
whitespace); a dropdown pops up **as you type**:

| Input | Behavior |
|---|---|
| `$` | Dropdown with the full skill list |
| `$rev` | Live fuzzy-filtered to `rev` (e.g. `pr-review`) |

Use ↑/↓ to move, Enter/Tab to accept. Accepting leaves `$<name> ` in the editor
(trailing space), so you can type arguments after it, e.g. `$pr-review focus on tests`.
On submit, `$<name>` mentions are rewritten:

- **Leading** `$<name>` (exact skill match) becomes `/skill:<name> <args>` and
  pi's built-in skill expansion inlines the skill body, rendering it as a
  skill-invocation block.
- **Mid-text** `$<name>` (exact skill match, word-boundary anchored) is expanded
  by this extension: the token is replaced in place with the same
  `<skill name=... location=...>…</skill>` block pi emits, leaving surrounding
  text intact. (pi only expands `/skill:` when it starts the message, so
  mid-text expansion must be done here.)

The dropdown shows plain skill names (no `skill:` prefix) and includes
`disable-model-invocation` skills, since those are meant to be launched manually.

## Implementation

Uses `ctx.ui.addAutocompleteProvider()` (registered on `session_start`) with
`triggerCharacters: ["$"]`. `getSuggestions` fires when the cursor is inside a
`$…` token whose `$` starts the line or follows whitespace (so `foo$bar` and
mid-word `$` never trigger); otherwise it delegates to the built-in provider.
`applyCompletion` replaces the `$…` prefix in place with `$<name> ` — the tidy
`$` form stays visible in the editor.

An `input` handler rewrites `$<name>` mentions at submit time. Leading mentions
become `/skill:<name> <args>` (pi expands those); mid-text mentions are inlined
by the extension itself using pi's exported `stripFrontmatter()` and the same
`<skill …>` block format as pi's own expansion. Everything fires **only on exact
skill-name matches**, so literal `$` usage (`$5`, `$PATH`, `$1`) passes through
untouched. Trailing punctuation on the token (`$grill-me,`) is tolerated.
Skills are re-scanned on `/reload` via `resources_discover`.

## How it replaces the default selector

`modify_settings.json` sets `enableSkillCommands: false`, which stops pi from
registering `/skill:name` entries in the command palette
(`interactive-mode.js` gates that on the setting). The `$` autocomplete becomes the
sole skill selector, while `/skill:name` **expansion** still works because pi
expands it unconditionally on submit.

## Skill discovery

Uses the exported `loadSkills()` + `getAgentDir()` helpers to mirror pi's default
locations: `~/.pi/agent/skills`, `~/.agents/skills`, and project `.pi/skills` /
`.agents/skills` up to the git root, plus add/remove (`-` prefix) entries from
`~/.pi/agent/settings.json`'s `skills` array.

Limitation: skills contributed **only** via pi packages or `--skill` CLI flags are
not surfaced (they are not in the scanned default locations).
