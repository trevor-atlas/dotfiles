local log = require('vim.lsp.log')
local getTsServerPathForCurrentFile = require('hubspot-bender').getTsServerPathForCurrentFile
local util = require('lspconfig.util')

local utils = require('utils')
local tsserverpath = getTsServerPathForCurrentFile()

local settings = {
  separate_diagnostic_server = true,
  publish_diagnostic_on = 'insert_leave',
  expose_as_code_action = 'all',
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

vim.diagnostic.config({ source = true, virtual_text = true, underline = true })
vim.lsp.handlers['workspace/diagnostic/refresh'] = function(_, _, ctx)
  local ns = vim.lsp.diagnostic.get_namespace(ctx.client_id)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.diagnostic.reset(ns, bufnr)
  return true
end
