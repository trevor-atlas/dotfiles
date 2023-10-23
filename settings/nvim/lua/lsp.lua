local log = require('vim.lsp.log')
local getTsServerPathForCurrentFile = require('asset-bender').getTsServerPathForCurrentFile

local utils = require('utils')
require('neodev').setup({})
require('lspconfig').lua_ls.setup({})

local tsserverpath = getTsServerPathForCurrentFile()

log.info('Initializing lsp with tsserver version found from package.json:' .. tsserverpath)

require('typescript-tools').setup({
  settings = {
    separate_diagnostic_server = true,
    publish_diagnostic_on = 'insert_leave',
    expose_as_code_action = {},
    tsserver_path = utils.is_hubspot_machine and tsserverpath or '',
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
  },
  on_attach = function()
    local tsserverVersionForThisFile = getTsServerPathForCurrentFile()

    if tsserverVersionForThisFile ~= tsserverpath then
      local msg = 'You opened a file that requires a different tsserver version than what is currently being used.'
        .. '\nOriginal server path: '
        .. tsserverpath
        .. '\nPath for this file: '
        .. tsserverVersionForThisFile
      vim.notify(msg)
      log.info(msg)
    end
  end,
})

-- FAQ
-- [ERROR][2022-02-22 11:10:04] ...lsp/handlers.lua:454 "[tsserver] /bin/sh: /usr/local/Cellar/node/17.5.0/bin/npm: No such file or directory\n"
--    ln -s (which npm) /usr/local/Cellar/node/17.5.0/bin/npm
--

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
-- vim.api.nvim_set_keymap(
--   "n",
--   "<space>gsd",
--   "<cmd>lua vim.lsp.buf.show_line_diagnostics({ focusable = false })<CR>",
--   { noremap = true, silent = true }
-- )
