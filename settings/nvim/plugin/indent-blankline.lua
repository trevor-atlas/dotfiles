vim.pack.add({ 'https://github.com/lukas-reineke/indent-blankline.nvim' })

require("ibl").setup({
  indent = { char = '▏' },
  scope = { show_start = false, show_end = false },
  exclude = {
    buftypes = {
      'nofile',
      'terminal',
    },
    filetypes = {
      'help',
      'startify',
      'aerial',
      'alpha',
      'dashboard',
      'lazy',
      'neogitstatus',
      'NvimTree',
      'neo-tree',
      'Trouble',
    },
  },
})
