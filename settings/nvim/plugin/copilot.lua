local copilot_loaded = false

local function setup_copilot()
  if copilot_loaded then return end

  pcall(vim.api.nvim_del_user_command, 'Copilot')

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
      enabled = true,
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

  copilot_loaded = true
end

vim.api.nvim_create_user_command('Copilot', function(opts)
  setup_copilot()
  vim.cmd('Copilot ' .. opts.args)
end, { nargs = '*' })

vim.api.nvim_create_autocmd('InsertEnter', {
  once = true,
  callback = setup_copilot,
})

vim.keymap.set('i', '<M-l>', function()
  setup_copilot()
  local nes = require('copilot-lsp.nes')
  nes.apply_pending_nes()
  nes.walk_cursor_end_edit()
end, { desc = 'Accept NES suggestion (insert mode)' })
