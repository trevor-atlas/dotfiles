local utils = require('utils')

require('luasnip.loaders.from_vscode').lazy_load()
require('luasnip.loaders.from_vscode').lazy_load({ paths = { '~/.config/nvim/snippets/' } })

local sources_default = { 'lsp', 'path', 'snippets', 'buffer' }

local hs_filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' }
local hs_sources = { 'hs_translations', 'lsp', 'path', 'snippets', 'buffer' }

local per_filetype = {}
if utils.is_hubspot_machine then
  for _, ft in ipairs(hs_filetypes) do
    per_filetype[ft] = hs_sources
  end
end

local sources = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer', 'copilot' }

local providers = {
  lazydev = {
    name = 'LazyDev',
    module = 'lazydev.integrations.blink',
    score_offset = 100,
  },
  copilot = {
    name = 'copilot',
    module = 'blink-cmp-copilot',
    score_offset = 100,
    async = true,
  },
}

if utils.is_hubspot_machine then
  table.insert(sources, 1, 'hs_translations')
  providers.hs_translations = {
    name = 'HubSpot Translations',
    module = 'hubspot-completion',
    score_offset = -3,
    async = true,
  }
end

require('blink.cmp').setup({
  snippets = { preset = 'luasnip' },

  sources = {
    default = sources_default,
    per_filetype = per_filetype,
    providers = providers,
  },

  keymap = {
    preset = 'default',
    ['<CR>'] = { 'accept', 'fallback' },
    ['<C-c>'] = { 'cancel', 'fallback' },
    ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
    ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
  },

  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
      window = { border = 'rounded' },
    },
    menu = {
      border = 'rounded',
      draw = {
        columns = {
          { 'kind_icon' },
          { 'label', 'label_description', gap = 1 },
          { 'source_name' },
        },
      },
    },
  },

  appearance = {
    nerd_font_variant = 'mono',
  },
})
