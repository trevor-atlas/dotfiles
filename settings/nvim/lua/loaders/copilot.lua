local M = {}

local copilot_loaded = false

function M.setup()
  if copilot_loaded then return end

  pcall(vim.api.nvim_del_user_command, 'Copilot')

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

function M.register()
  vim.api.nvim_create_user_command('Copilot', function(opts)
    M.setup()
    vim.cmd('Copilot ' .. opts.args)
  end, { nargs = '*' })

  vim.api.nvim_create_autocmd('InsertEnter', {
    once = true,
    callback = M.setup,
  })

  vim.keymap.set('i', '<M-l>', function()
    M.setup()
    local nes = require('copilot-lsp.nes')
    nes.apply_pending_nes()
    nes.walk_cursor_end_edit()
  end, { desc = 'Accept NES suggestion (insert mode)' })
end

return M
