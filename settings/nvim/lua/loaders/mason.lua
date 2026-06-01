local M = {}

local mason_loaded = false

function M.setup()
  if mason_loaded then return end

  pcall(vim.api.nvim_del_user_command, 'Mason')

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

function M.register()
  vim.api.nvim_create_user_command('Mason', function(opts)
    M.setup()
    vim.cmd('Mason ' .. opts.args)
  end, { nargs = '*' })

  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      vim.schedule(M.setup)
    end,
  })
end

return M
