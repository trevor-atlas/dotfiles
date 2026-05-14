vim.pack.add({ 'https://github.com/akinsho/toggleterm.nvim' })

require('toggleterm').setup({
  highlights = {
    Normal = { link = 'Normal' },
    NormalNC = { link = 'NormalNC' },
    NormalFloat = { link = 'NormalFloat' },
    FloatBorder = { link = 'FloatBorder' },
    StatusLine = { link = 'StatusLine' },
    StatusLineNC = { link = 'StatusLineNC' },
    WinBar = { link = 'WinBar' },
    WinBarNC = { link = 'WinBarNC' },
  },
  size = 10,
  on_create = function(term)
    vim.opt.foldcolumn = '0'
    vim.opt.signcolumn = 'no'
    vim.cmd('startinsert!')
  end,
  open_mapping = [[<leader>tt]],
  shading_factor = 2,
  direction = 'float',
  float_opts = {
    border = 'curved',
    highlights = {
      border = 'Normal',
      background = 'Normal',
    },
  },
})
