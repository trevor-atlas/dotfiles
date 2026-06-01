local float = {
  focusable = false,
  style = 'minimal',
  border = 'rounded',
}

-- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, float)
-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, float)

-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.
local function common_on_attach(_, bufnr)
  local picker = require('snacks.picker')
  local nmap = function(keys, func, desc)
    if desc then desc = 'LSP: ' .. desc end
    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', picker.lsp_definitions, '[G]oto [D]efinition')
  nmap('gr', picker.lsp_references, '[G]oto [R]eferences')
  nmap('gi', picker.lsp_implementations, '[G]oto [I]mplementation')
  nmap('gI', picker.lsp_implementations, '[G]oto [I]mplementation')
  nmap('<leader><S-d>', vim.lsp.buf.type_definition, 'Type [D]efinition')
  nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, '[W]orkspace [L]ist Folders')
end

local client_on_attach = {
  ts_ls = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
      local code_action_provider = client.server_capabilities.codeActionProvider
      local action_kinds = type(code_action_provider) == 'table' and code_action_provider.codeActionKinds or {}
      local source_actions = vim.tbl_filter(function(action)
        return vim.startswith(action, 'source.')
      end, action_kinds)

      vim.lsp.buf.code_action({
        context = {
          only = source_actions,
          diagnostics = {},
        },
      })
    end, {})

    vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptGoToSourceDefinition', function()
      local win = vim.api.nvim_get_current_win()
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)

      client:exec_cmd({
        command = '_typescript.goToSourceDefinition',
        title = 'Go to source definition',
        arguments = { params.textDocument.uri, params.position },
      }, { bufnr = bufnr }, function(err, result)
        if err then
          vim.notify('Go to source definition failed: ' .. err.message, vim.log.levels.ERROR)
          return
        end
        if not result or vim.tbl_isempty(result) then
          vim.notify('No source definition found', vim.log.levels.INFO)
          return
        end

        vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
      end)
    end, { desc = 'Go to source definition' })
  end,
}

local capabilities = require('blink.cmp').get_lsp_capabilities()
local is_hubspot, bend = pcall(require, 'bend')
local utils = require('utils')

local function warn_eslint(message)
  if utils.is_hubspot_machine then return {} end

  vim.notify(message, vim.log.levels.WARN)
  return {}
end

local function combined_on_attach(...)
  local callbacks = vim.tbl_filter(function(callback)
    return type(callback) == 'function'
  end, { ... })

  return function(client, bufnr)
    common_on_attach(client, bufnr)

    for _, callback in ipairs(callbacks) do
      callback(client, bufnr)
    end

    local callback = client_on_attach[client.name]
    if callback then callback(client, bufnr) end
  end
end

local function with_common_config(config, ...)
  return vim.tbl_deep_extend('force', {
    capabilities = capabilities,
    on_attach = combined_on_attach(...),
  }, config or {})
end

local function ts_ls_config()
  local config = {}

  if is_hubspot then
    bend.setup({ v2 = true, auto_add_dirs = true })
    config = {
      filetypes = {
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
      },
      root_markers = { '.git', 'build-info.json' },
      cmd = { 'typescript-language-server', '--stdio' },
      init_options = {
        hostInfo = 'neovim',
        tsserver = {
          path = bend.getTsServerPathForCurrentFile(),
        },
      },
    }
  end

  return with_common_config(config)
end

local upstream_eslint = vim.lsp.config.eslint or {}
local servers = {
  lua_ls = with_common_config({
    settings = {
      Lua = {
        telemetry = { enable = false },
        runtime = {
          version = 'LuaJIT',
        },
        diagnostics = {
          globals = { 'vim' },
        },
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME,
          },
        },
      },
    },
  }),
  yamlls = with_common_config({
    filetypes = { 'yaml' },
  }),
  eslint = with_common_config({
    handlers = {
      ['eslint/probeFailed'] = function()
        return warn_eslint('[eslint] probe failed.')
      end,
      ['eslint/noLibrary'] = function()
        return warn_eslint('[eslint] Unable to find ESLint library.')
      end,
    },
  }, upstream_eslint.on_attach),
  ts_ls = ts_ls_config,
}

for server_name, server_config in pairs(servers) do
  if type(server_config) == 'function' then
    server_config = server_config()
  end

  vim.lsp.config(server_name, server_config)
end

for _, server_name in ipairs({
  'lua_ls',
  'yamlls',
  'eslint',
  'ts_ls',
}) do
  vim.lsp.enable(server_name)
end

local optional_servers = {
  gopls = {
    executable = 'gopls',
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  },
  jdtls = {
    executable = 'jdtls',
    filetypes = { 'java' },
  },
  clangd = {
    executable = 'clangd',
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  },
  pyright = {
    executable = 'pyright-langserver',
    filetypes = { 'python' },
  },
  nixd = {
    executable = 'nixd',
    filetypes = { 'nix' },
  },
  templ = {
    executable = 'templ',
    filetypes = { 'templ' },
  },
}

local optional_servers_group = vim.api.nvim_create_augroup('OptionalLspEnable', { clear = true })
for server_name, server_config in pairs(optional_servers) do
  vim.api.nvim_create_autocmd('FileType', {
    group = optional_servers_group,
    pattern = server_config.filetypes,
    callback = function()
      if utils.is_executable(server_config.executable) and not vim.lsp.is_enabled(server_name) then
        vim.lsp.enable(server_name)
      end
    end,
  })
end

require('hubspot-i18n').setup()
