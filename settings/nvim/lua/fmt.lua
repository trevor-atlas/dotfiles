local utils = require('utils')
local util = require('lspconfig.util')

local config_pattern = util.root_pattern('prettier.config.js', '.prettierrc')

local function prettier_config()
  local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local config_path = config_pattern(bufname)

  local exe = utils.is_hubspot_machine and 'bpx' or config_path .. '/node_modules/prettier/node_modules/.bin/prettier'

  return {
    exe = exe,
    args = { 'hs-prettier', '--stdin-filepath', vim.api.nvim_buf_get_name(0), '--config', config_path .. '/prettier.config.js' },
    stdin = true,
  }
end

require('formatter').setup({
  logging = false,
  filetype = {
    javascript = { prettier_config },
    javascriptreact = { prettier_config },
    typescript = { prettier_config },
    typescriptreact = { prettier_config },
    mdx = {},
    lua = {
      function()
        return {
          exe = 'stylua',
        }
      end,
    },
  },
})

vim.api.nvim_exec2(
  [[
au! BufRead,BufNewFile *.mdx setfiletype mdx
augroup FormatAutogroup
autocmd!
autocmd BufWritePost *.js,*.ts,*.tsx,*.lua,*.mdx,*.rs FormatWrite
augroup END]],
  { output = true }
)
