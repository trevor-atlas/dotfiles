local log = require('vim.lsp.log')
local getTsServerPathForCurrentFile = require('hubspot-bender').getTsServerPathForCurrentFile
local util = require('lspconfig.util')

local utils = require('utils')
local tsserverpath = getTsServerPathForCurrentFile()

local settings = {
  separate_diagnostic_server = true,
  publish_diagnostic_on = 'insert_leave',
  expose_as_code_action = {},
  tsserver_logs = 'terse',
  -- specify a list of plugins to load by tsserver, e.g., for support `styled-components`
  -- (see ?? `styled-components` support section)
  tsserver_plugins = {},
  tsserver_max_memory = 'auto',
  tsserver_format_options = {},
  tsserver_file_preferences = {},
  complete_function_calls = false,
  include_completions_with_insert_text = true,
  disable_member_code_lens = true,
}

if utils.is_hubspot_machine then settings.tsserver_path = tsserverpath end

require('typescript-tools').setup({
  settings,
  root_dir = util.root_pattern('.git', 'yarn.lock', 'package.json'),
  on_attach = function(server, bufnr)
    if utils.is_hubspot_machine then
      local tsserverVersionForThisFile = getTsServerPathForCurrentFile()

      if tsserverVersionForThisFile ~= tsserverpath then
        local msg = 'You opened a file that requires a different tsserver version than what is currently being used.'
          .. '\nOriginal server path: '
          .. tsserverpath
          .. '\nPath for this file: '
          .. tsserverVersionForThisFile
        log.info(msg)
      end
    end
  end,
})

vim.diagnostic.config({ virtual_text = false, underline = true })
vim.lsp.handlers['workspace/diagnostic/refresh'] = function(_, _, ctx)
  local ns = vim.lsp.diagnostic.get_namespace(ctx.client_id)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.diagnostic.reset(ns, bufnr)
  return true
end

vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'single' })
vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'single' })

-- vim.api.nvim_set_keymap("n", "<space>gd", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap(
--   "n",
--   "<space>gi",
--   "<cmd>lua vim.lsp.buf.implementation()<CR>",
--   { noremap = true, silent = true }
-- )
-- vim.api.nvim_set_keymap("n", "<space>gr", "<cmd>lua vim.lsp.buf.references()<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = false, silent = true })
--
-- vim.api.nvim_set_keymap("n", "<space>ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", { noremap = true, silent = true })
