local cmp = require('cmp')
local luasnip = require('luasnip')
require('luasnip.loaders.from_vscode').lazy_load()
luasnip.config.setup({})
local hs_completion = require('hubspot-completion')

cmp.setup({
  formatting = {
    format = function(entry, vim_item)
      vim_item.menu = ({
        [hs_completion.key] = '[Translation]',
        --other examples may look like
        --buffer = "[Buffer]",
        --nvim_lsp = "[LSP]",
        --luasnip = "[LuaSnip]",
        --nvim_lua = "[Lua]",
        --latex_symbols = "[Latex]",
      })[entry.source.name]

      return vim_item
    end,
  },
  performance = {
    throttle = 100,
    debounce = 100,
    max_view_entries = 15,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete({}),
    ['<CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
  sources = { { name = 'nvim_lsp' }, { name = hs_completion.key } },
})

hs_completion.setup()
