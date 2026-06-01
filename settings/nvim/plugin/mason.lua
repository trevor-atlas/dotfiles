vim.pack.add({
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/mason-org/mason-lspconfig.nvim'
})

require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    'eslint',
    'lua_ls',
    'ts_ls',
    'yamlls',
  },
})
