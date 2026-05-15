# hubspot-i18n.nvim

Neovim tooling for HubSpot i18n translation files. Parses `.lyaml` translation files and provides hover documentation, go-to-definition, diagnostics, and completions for translation keys in TypeScript/JavaScript files.

## Features

- **Hover** (`K`) — press over any translation key string to see its English value
- **Go to definition** (`gd`) — jump to the key's definition in the source `.lyaml` file
- **Diagnostics** — warnings on unknown translation keys in `I18n.text()`, `unescapedText()`, `<FormattedMessage>`, and other i18n call sites
- **Completions** — nvim-cmp source that completes translation keys with prefix filtering

## Requirements

- Neovim 0.10+
- [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) with the `yaml` and `tsx`/`typescript` parsers installed
- [`nvim-cmp`](https://github.com/hrsh7th/nvim-cmp)
- [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`) on `$PATH`
- A `~/.hubspot` directory (the plugin is a no-op on non-HubSpot machines)

## Setup

The plugin is split into two files:

- **`hubspot-i18n.lua`** — owns the translation cache, parsing, hover, diagnostics, and go-to-definition
- **`hubspot-completion.lua`** — thin nvim-cmp adapter that consumes the cache

### treesitter

The plugin parses `.lyaml` files using the treesitter YAML grammar. Two things are required:

**1. Enable treesitter for all buffers** (nvim-treesitter does not do this automatically):

```lua
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})
```

**2. Install the required parsers:**

```lua
require('nvim-treesitter').install({ 'yaml', 'tsx', 'typescript' })
```

**3. Register `lyaml` as an alias for the `yaml` parser** (run after `TSUpdate`):

```lua
vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    local parsers = require('nvim-treesitter.parsers')
    parsers.lyaml = {
      install_info = {
        url      = parsers.yaml.install_info.url,
        revision = parsers.yaml.install_info.revision,
      },
      tier = 2,
    }
  end,
})
```

### Plugin

```lua
-- In your LSP config (or wherever you call setup):
require('hubspot-i18n').setup()

-- With custom keybindings (these are the defaults):
require('hubspot-i18n').setup({
  keys = {
    hover           = 'K',   -- set to false to disable
    goto_definition = 'gd',  -- set to false to disable
  },
})

-- In your nvim-cmp config:
local hs = require('hubspot-completion')
hs.setup()

cmp.setup({
  sources = {
    -- other sources ...
    { name = hs.key },
  },
})
```

## How it works

### Translation loading

On `setup()`, the plugin:

1. Runs `rg --files <git-root> -g en.lyaml` to find all base translation files in the repo
2. Parses each file's `#= require_lang` directives to find imported packages
3. Resolves required packages from monorepo siblings or `~/.hubspot/static-archive/<pkg>/`
4. Parses all `.lyaml` files via the treesitter YAML parser (no external tools required)
5. Merges imported keys into each package's translation map
6. Refreshes every 5 minutes in the background, and immediately on `BufWritePost` of any `.lyaml` file within the project

Base project files are re-checked on every refresh using SHA-256 content hashing.
Imported package files (static archive) are parsed once per session and never re-read — they are versioned and immutable.

### Diagnostics

A treesitter query runs on every `InsertLeave`, `TextChanged`, and `BufWritePost` for TypeScript/JavaScript buffers.
It flags unknown keys at the following call sites:

```typescript
I18n.text('some.key')
I18n.html('some.key')
unescapedText('some.key')
setDocumentTitle('some.key')
<FormattedMessage message="some.key" />
<FormattedHTMLMessage message="some.key" />
// ...and other Formatted* components
```

### Completions

The nvim-cmp source triggers on `"` and `'`.
It only returns results when the cursor is inside a non-empty string that is a prefix of at least one translation key.
Labels in the popup show the unique suffix (with one parent segment for context) rather than the full repeated prefix, keeping the menu readable for deeply nested keys.

## Commands

All commands are subcommands of `:HsI18n` with tab completion:

| Command | Description |
|---------|-------------|
| `:HsI18n refresh` | Re-parse all lyaml translation files |
| `:HsI18n reset` | Clear all caches and re-parse from scratch |
| `:HsI18n scan` | Run diagnostic scan on the current buffer immediately |
| `:HsI18n debug` | Print cache state for the current buffer |
| `:HsI18n debug-parse [file]` | Dump treesitter tree and parsed keys for a lyaml file (defaults to current buffer) |

## Public API

```lua
local i18n = require('hubspot-i18n')

-- Force a full re-parse (e.g. after pulling new translations)
i18n.parse_and_cache_translations()

-- Clear all in-memory caches and force a fresh parse on next call
i18n.reset()

-- Manually trigger a diagnostic scan on the current buffer
i18n.scan()

-- Debug: print cache state for the current buffer
i18n.debug()

-- Debug: dump the treesitter tree and parsed keys for a lyaml file
i18n.debug_parse('/path/to/en.lyaml')

-- Look up a key's source location (file, row, col)
i18n.get_key_position(app_lib_dir, key)
```
