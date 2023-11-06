local utils = require('utils')

local function get_prettier_executable(root_dir)
  if utils.is_hubspot_machine then return '~/.bpm/packages/hs-prettier/channels/default/prettier-config-hubspot/bin/hs-prettier.js' end
  if utils.is_dir(utils.path_join(root_dir, 'node_modules', 'prettier')) then
    return utils.path_join(root_dir, 'node_modules', 'prettier', 'bin-prettier.js')
  end
  return utils.path_join('~', 'node_modules', 'prettier', 'bin-prettier.js')
end

local function prettier_config()
  local bufnr = vim.api.nvim_get_current_buf()
  local root_dir = utils.buffer_find_file_dir(bufnr, 'prettier.config.js')
  if not root_dir or root_dir == '' then root_dir = utils.find_root_git_dir() end

  local prettier_executable = get_prettier_executable(root_dir)
  local config_path = utils.is_hubspot_machine and utils.path_join(root_dir, 'prettier.config.js') or '~/prettier.config.js'

  return {
    exe = prettier_executable,
    args = { '--stdin-filepath', vim.api.nvim_buf_get_name(0), '--config', config_path },
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
    args = { vim.api.nvim_buf_get_name(0) },
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
    mdx = { prettier_config },
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
