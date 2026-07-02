local wk = require('which-key')
wk.setup({
  icons = { group = vim.g.icons_enabled and '' or '+', separator = '' },
  disable = { filetypes = { 'TelescopePrompt' } },
})

require('keymaps').apply()

vim.o.timeout = true
vim.o.timeoutlen = 300
