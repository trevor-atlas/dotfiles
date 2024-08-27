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

local function lsp_or_leptos()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- true if any line contains "leptos"
  local probably_leptos_project = vim.iter(lines):any(function(content) return content:match('leptos') end)

  if probably_leptos_project == true then
    return {
      exe = 'leptosfmt',
      args = { vim.api.nvim_buf_get_name(0), '--stdin', '--rustfmt', '--quiet' },
      stdin = true,
    }
  end

  return {
    exe = 'rustfmt',
    args = { vim.api.nvim_buf_get_name(0), '--stdin' },
    stdin = true,
  }
end

require('formatter').setup({
  logging = false,
  filetype = {
    rust = { lsp_or_leptos },
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

vim.api.nvim_exec(
  [[
au! BufRead,BufNewFile *.mdx setfiletype mdx
augroup FormatAutogroup
autocmd!
autocmd BufWritePost *.js,*.ts,*.tsx,*.lua,*.mdx,*.rs FormatWrite
augroup END]],
  true
)
