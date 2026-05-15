vim.pack.add({
  'https://github.com/zbirenbaum/copilot.lua',
  'https://github.com/copilotlsp-nvim/copilot-lsp',
  'https://github.com/giuxtaposition/blink-cmp-copilot',
})

vim.g.copilot_nes_debounce = 500
require('copilot').setup({
  suggestion = { enabled = false, keymap = { accept = false } },
  panel = { enabled = false },
  nes = {
    enabled = true, -- requires copilot-lsp as a dependency
    auto_trigger = true,
    keymap = {
      accept_and_goto = '<M-l>',
      accept = false,
      dismiss = '<Esc>',
    },
  },
  filetypes = {
    yaml = false,
    markdown = false,
    help = false,
    gitcommit = false,
    gitrebase = false,
    hgcommit = false,
    svn = false,
    cvs = false,
    ['.'] = false,
  },
})

vim.keymap.set('i', '<M-l>', function()
  local nes = require('copilot-lsp.nes')
  nes.apply_pending_nes()
  nes.walk_cursor_end_edit()
end, { desc = 'Accept NES suggestion (insert mode)' })
