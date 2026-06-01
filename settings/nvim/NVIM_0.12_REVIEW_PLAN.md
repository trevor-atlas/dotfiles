# Neovim 0.12 Config Review Plan

## Goal

Use the Neovim 0.12 upgrade as an opportunity for **intentional cleanup**, not a rewrite.

Target outcome:
- preserve workflows, not exact bindings
- reach a clean final state
- remove migration residue and stale config
- modernize owned code to current Neovim APIs where it is straightforward
- keep plugins for real UX wins, but prefer core Neovim for plumbing/defaults where it improves clarity

## Guiding principles

- **Intentional cleanup**, not a full re-think
- **Preserve workflows, not exact bindings**
- **Clean final state**, not incremental migration residue
- **Balanced approach**: use Neovim core where it clarifies plumbing, keep plugins for UX
- **Low-risk consolidation** only
- **Performance is secondary**, not a primary driver
- Deliver in **a few intentional phases**

## Architecture decisions

### Formatting

- Migrate from **`formatter.nvim`** to **`conform.nvim`**
- Keep **autoformat on save**
- Prefer **external formatters** for ecosystem-standard languages
- JS/TS formatting policy:
  - **HubSpot repos** use a HubSpot-aware formatter path
  - **non-HubSpot repos** use **project-local prettier only**, otherwise do not format
  - let prettier **discover its own config**
- HubSpot repo detection should be **repo-based**, not machine-based
- HubSpot repo marker set:
  - `static_conf.json`
  - `.blazar-enabled`
  - `.blazar.yaml`
  - `hubspot.deploy/`
- Introduce a reusable HubSpot repo classifier, but keep formatting policy as a separate layer
- Detection should be:
  - **buffer-rooted** when possible
  - with **cwd fallback**

### Consolidation

- Replace **`bufdelete.nvim`** with **`mini.bufremove`**
- Prefer moving small focused plugins to **mini.nvim** when the move is clean and low-risk
- **`blink.cmp`** is the sole completion engine
- **`ts_ls`** is the canonical TypeScript path
- Remove stale cmp-era and `typescript-tools.nvim` residue

### Pickers / navigation

Keep both picker systems, but define their roles explicitly:
- **Telescope = search / exploration**
- **Snacks = jump / navigation**

### Keymaps

- Prime bindings should favor **editing semantics**
- Restore `<leader>d` to **delete-without-yank**
- Keep diagnostics on `gh` and/or a more explicit diagnostic mapping
- Treat duplicate mappings as config debt to eliminate
- Make **LSP mappings buffer-local in `on_attach`**
- Keep **diagnostics global**
- Keep true **LSP actions buffer-local**

### Cleanup / modernization

- Remove **all lazy.nvim residue**
- Update **README.md** in the same pass
- Proactively modernize owned code to current Neovim 0.12-style APIs
- Theme work should:
  - fix correctness bugs
  - normalize obvious outdated highlight group usage
  - avoid a full theme rewrite

### LSP / provisioning

- Keep **Mason**, but only as **installation / provisioning**
- Native Neovim APIs should remain the runtime LSP configuration path
- Keep broad language support, but make enablement smarter
- Gate optional servers on:
  - **binary availability**
  - **project/file relevance**

### Helpers / structure

- Use a **minimal helper layer**
- Generic helpers can stay in `utils.lua`
- Repo/environment policy helpers should move to a focused module if they grow

## Planned phases

### Phase 1 — Truthfulness + 0.12 correctness

Goal: make the config tell the truth and remove broken/stale behavior.

Includes:
- remove lazy-era residue
  - `LazyDone` autocmd
  - lazy-style dead files/usages
  - `require('lazy')` assumptions
- fix broken/conflicting keymaps
  - especially `<leader>d`
  - remove broken Telescope frecency mapping
- fix Neovim 0.12-required changes
  - move diagnostic sign config to `vim.diagnostic.config()`
  - replace `vim.loop` with `vim.uv`
  - replace `vim.api.nvim_set_keymap` with `vim.keymap.set`
  - clean up filetype detection patterns
- update `README.md`
- clean clearly stale lockfile/plugin residue

### Phase 2 — Low-risk consolidation

Goal: finish migrations that are already logically complete.

Includes:
- move `formatter.nvim` to `conform.nvim`
- move `bufdelete.nvim` to `mini.bufremove`
- remove stale cmp-era packages
- remove `typescript-tools.nvim` residue
- collapse duplicate mappings
- make LSP mappings buffer-local in `on_attach`

### Phase 3 — Policy + architecture cleanup

Goal: make environment/repo behavior deliberate.

Includes:
- add HubSpot repo detection helper(s)
- encode formatter policy cleanly
- make optional LSP enablement smarter
- make the Telescope/Snacks split explicit in structure/docs
- fix theme palette bugs
- normalize obvious outdated highlight definitions

## Known issues already identified

- `README.md` still describes Lazy instead of `vim.pack`
- lazy-era residue exists in `lua/autocommands.lua`
- `plugin/devicons.lua` is written like a lazy spec and does not match the current runtime model
- `lua/utils.lua` still contains lazy-specific assumptions
- `plugin/neotree.lua` uses diagnostic sign configuration that should move to `vim.diagnostic.config()`
- `<leader>d` is mapped twice and currently conflicted
- Telescope frecency mapping is broken
- `ts_ls` config includes invalid filetypes like `javascript.jsx` and `typescript.tsx`
- stale cmp-era and `typescript-tools.nvim` entries remain in the pack lockfile
- `formatter.nvim` is active while `conform.nvim` is already installed
- `bufdelete.nvim` is active while `mini.bufremove` is already installed
- theme palette includes references to undefined colors
- theme mixes older Treesitter highlight groups with newer capture-based groups

## Success criteria

The pass is successful if:
- the config no longer contains obvious lazy-era migration residue
- plugin/tool choices reflect what is actually in use
- formatting behavior is explicit and reliable
- keymaps have one intentional source of truth
- LSP setup is native-first and less noisy
- docs match reality
- the config is easier to reason about six months from now
