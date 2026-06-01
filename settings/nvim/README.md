# neovim config

This config is built around a small set of conventions that were cleaned up during the Neovim 0.12 review.

## Location

Neovim configuration lives under the following paths:

| OS | Path |
| :- | :--- |
| Linux | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| macOS | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| Windows | `%userprofile%\AppData\Local\nvim\` |

## Core decisions

### Plugin management

This config uses Neovim's built-in `vim.pack` plugin manager.

- `init.lua` is the single plugin manifest
- `nvim-pack-lock.json` is the lockfile
- plugin inventory should be changed in `init.lua`, not scattered across the repo

On first startup, `vim.pack` installs missing plugins from the lockfile.

To review and apply plugin updates:

```sh
nvim
:lua vim.pack.update()
```

## Structure

The config now uses a consistent layout:

- `init.lua`
  - package manifest
  - core startup bootstrapping
- `plugin/*.lua`
  - eager startup config only
  - thin bootstraps for features that should register commands/autocmds at startup
- `lua/loaders/*.lua`
  - deferred plugin lifecycle for plugins that load on first use
  - current examples: Telescope, Mason, Copilot
- `lua/*.lua`
  - reusable modules and local config logic

This keeps package ownership centralized while making deferred behavior explicit.

## Current architecture choices

### Pickers and navigation

The config keeps both picker systems on purpose:

- **Telescope** = search / exploration
  - files
  - grep
  - git pickers
  - help
  - diagnostics search
  - translation picker
- **Snacks** = jump / navigation
  - LSP definitions
  - references
  - implementations

### Formatting

Formatting is handled by `conform.nvim` plus a small Java save hook.

- autoformat on save is enabled for configured filetypes
- JS/TS/MDX prefer external formatters
- Lua uses `stylua`
- HubSpot Mill Java runs `mill <module>.spotless` after save

JS/TS formatting policy:

- **HubSpot repos** use `bpx hs-prettier`
- **non-HubSpot repos** use project-local `node_modules/.bin/prettier`
- if a non-HubSpot repo has no local prettier, it is not autoformatted

Java formatting policy:

- HubSpot Mill repos format Java with Spotless via the module-local `mill <module>.spotless` task
- formatting runs after save so the real repo file is reformatted in place

HubSpot repo detection is repo-based, using markers like:

- `static_conf.json`
- `.blazar-enabled`
- `.blazar.yaml`
- `hubspot.deploy/`

### LSP

LSP is configured with Neovim's native 0.12 APIs.

- `vim.lsp.config()` defines server config
- `vim.lsp.enable()` enables servers
- **Mason** is used for provisioning, not for runtime LSP abstraction
- core LSP mappings are buffer-local on attach
- diagnostics stay global
- optional servers are gated by executable availability and relevant filetypes
- HubSpot Mill workspaces use `nvim-metals` for Java/Scala BSP integration
- Metals is pinned to `targetBuildTool = 'mill'` so mixed Maven + Mill repos prefer Mill
- when a Mill workspace is missing BSP config, the loader auto-runs `mill --bsp-install` and creates `.bsp/mill-bsp.json`
- `:MetalsInstallMillBsp` installs a Mill BSP config for the current workspace
- `:MetalsCleanMillCache` clears `out/`, `.bsp/out`, and `.bsp/mill-bsp-out`, then restarts Metals to recover from stale Mill BSP state

### Completion

Completion uses:

- `blink.cmp`
- `LuaSnip`
- `lazydev`
- optional Copilot completion source when Copilot is loaded

### Mini.nvim

Where it made sense, focused plugins were consolidated into `mini.nvim` modules.

Current examples:
- `mini.basics`
- `mini.misc`
- `mini.surround`
- `mini.bufremove`

## Notes for future changes

When adding or changing behavior:

1. add or remove plugins in `init.lua`
2. keep eager startup behavior in `plugin/*.lua`
3. put real deferred lifecycle code in `lua/loaders/*.lua`
4. keep reusable logic in `lua/*.lua`
5. prefer readable structure over shaving tiny startup costs

A rough rule from this cleanup pass:
performance work is only worth the churn if it produces a clearly meaningful win or fixes an actual UX problem.
