local mason_loaded = false

local function setup_mason()
  if mason_loaded then return end

  pcall(vim.api.nvim_del_user_command, 'Mason')

  vim.pack.add({
    'https://github.com/mason-org/mason.nvim',
    'https://github.com/mason-org/mason-lspconfig.nvim',
  })

  require('mason').setup()
  require('mason-lspconfig').setup({
    ensure_installed = {
      'eslint',
      'lua_ls',
      'ts_ls',
      'yamlls',
    },
  })

  mason_loaded = true
end

vim.api.nvim_create_user_command('Mason', function(opts)
  setup_mason()
  vim.cmd('Mason ' .. opts.args)
end, { nargs = '*' })

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.schedule(setup_mason)
  end,
})
