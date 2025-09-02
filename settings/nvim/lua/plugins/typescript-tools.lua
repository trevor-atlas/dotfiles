local getModule = function()
  local utils = require('utils')
  local util = require('lspconfig.util')

  local configFN = function(tsserver_path)
    require("typescript-tools").setup({
      root_dir = util.root_pattern('.git', 'yarn.lock', 'package.json'),
      settings = {
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
        tsserver_path = tsserver_path or nil,
      },
    })
    vim.diagnostic.config({ source = true, virtual_text = true, underline = true })
    vim.lsp.handlers['workspace/diagnostic/refresh'] = function(_, _, ctx)
      local ns = vim.lsp.diagnostic.get_namespace(ctx.client_id)
      local bufnr = vim.api.nvim_get_current_buf()
      vim.diagnostic.reset(ns, bufnr)
      return true
    end
  end


  local moduleConfig = {
    'pmizio/typescript-tools.nvim',
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    config = configFN
  }

  if utils.is_hubspot_machine then
    table.insert(moduleConfig.dependencies, {
      url = "git@git.hubteam.com:HubSpot/bend.nvim.git"
    })
    moduleConfig.event = { "BufReadPost *.ts", "BufReadPost *.js", "BufReadPost *.tsx", "BufReadPost *.jsx" }
    moduleConfig.config = function()
      local bend = require("bend")
      bend.setup()
      configFN(bend.getTsServerPathForCurrentFile());
    end
  end

  return moduleConfig;
end

return getModule();
