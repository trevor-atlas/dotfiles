local diagnostic_floats = require('diagnostic_floats')
local utils = require('utils')

return {
  { keys = '<leader>pb', action = '<cmd>BufferLinePick<CR>', desc = '[B]uffer pick' },
  { keys = '<leader>gnt', action = function() P(utils.get_text_under_cursor()) end, desc = 'Get text under cursor' },
  { keys = '<leader>p', action = '"_dP', desc = '[P]aste over selection', mode = 'x' },
  { keys = '<leader>d', action = '"_d', desc = '[D]elete without copying', mode = { 'n', 'v' } },
  { keys = '<Leader>rr', action = '<cmd>so<CR>', desc = '[R]eload current file' },
  { keys = '<leader>s', action = [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], desc = '[S]ubstitute word under cursor' },
  { keys = '<leader>rp', action = [[:%s/word/word/gI<Left><Left><Left>]], desc = '[P]attern replace' },
  { keys = '<Leader>k', action = ':bn<cr>', desc = 'Next buffer' },
  { keys = '<Leader>j', action = ':bp<cr>', desc = 'Previous buffer' },
  { keys = '<leader>/', action = function() require('Comment.api').toggle.linewise.current() end, desc = 'Comment line' },
  { keys = '<leader>/', action = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", desc = 'Toggle comment line', mode = 'v' },
  { keys = '<leader>e', action = '<cmd>Neotree reveal_force_cwd toggle<cr>', desc = '[E]xplorer' },
  {
    keys = '<leader>o',
    action = function()
      if vim.bo.filetype == 'neo-tree' then
        vim.cmd.wincmd('p')
      else
        vim.cmd.Neotree('focus')
      end
    end,
    desc = 'F[o]cus Explorer',
  },
  { keys = '<leader>dd', action = function() diagnostic_floats.open({ bufnr = 0 }) end, desc = '[D]iagnostic float' },
  { keys = '<leader>dl', action = vim.diagnostic.setloclist, desc = '[L]ocation list' },
  { keys = '<leader>xx', action = '<cmd>Trouble diagnostics toggle<cr>', desc = '[X] Diagnostics pane' },
  { keys = '<leader>lx', action = '<cmd>Inspect<cr>', desc = 'Inspect token' },
  {
    keys = '<leader>ev',
    action = function()
      vim.cmd('noau normal! "vy"')
      local text = vim.fn.getreg('v')
      if not text then text = 'print("invalid string")' end
      text = text:gsub('[\n\r]', '')
      text = text:gsub('^%s*(.-)%s*$', '%1')
      local res = vim.api.nvim_exec2('lua ' .. text, { output = true })
      if res and res.output then print(res.output) end
    end,
    desc = 'Run selected Lua',
    mode = 'v',
  },
  { keys = '<leader>lf', action = '<cmd>luafile %<CR>', desc = 'Lua [F]ile' },
}
