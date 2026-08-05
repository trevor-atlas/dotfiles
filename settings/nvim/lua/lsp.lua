local lsp_attach = require('lsp_attach')

local client_on_attach = {
  ts_ls = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
      local code_action_provider = client.server_capabilities.codeActionProvider
      local action_kinds = type(code_action_provider) == 'table' and code_action_provider.codeActionKinds or {}
      local source_actions = vim.tbl_filter(function(action) return vim.startswith(action, 'source.') end, action_kinds)

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

require('loaders.mason').setup()

local capabilities = require('blink.cmp').get_lsp_capabilities()
local is_hubspot, bend = pcall(require, 'bend')
local repo = require('repo')
local utils = require('utils')
local bend_initialized = false

local function warn_eslint(message)
  if utils.is_hubspot_machine then return {} end

  vim.notify(message, vim.log.levels.WARN)
  return {}
end

local function combined_on_attach(...)
  local callbacks = vim.tbl_filter(function(callback) return type(callback) == 'function' end, { ... })

  return function(client, bufnr)
    lsp_attach.common_on_attach(client, bufnr)

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

local ts_filetypes = {
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
}

local function hubspot_root_dir(bufnr, on_dir)
  if not repo.is_hubspot_repo(bufnr) then return end

  on_dir(vim.fs.root(bufnr, { 'build-info.json', '.git' }))
end

local function ts_ls_root_dir(bufnr, on_dir)
  if repo.is_hubspot_repo(bufnr) then
    return on_dir(vim.fs.root(bufnr, { 'build-info.json', '.git' }))
  end

  return on_dir(vim.fs.root(bufnr, { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' }))
end

local function ensure_bend_setup(bufnr)
  if bend_initialized or not is_hubspot or not repo.is_hubspot_repo(bufnr) then return end

  bend.setup({ v2 = true, auto_add_dirs = true })
  bend_initialized = true
end

local function ts_ls_config()
  return with_common_config({
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = ts_filetypes,
    root_dir = ts_ls_root_dir,
    init_options = {
      hostInfo = 'neovim',
    },
    before_init = function(_, config)
      if not is_hubspot or not repo.is_hubspot_repo(config.root_dir) then return end

      config.init_options = vim.tbl_deep_extend('force', config.init_options or {}, {
        tsserver = {
          path = bend.getTsServerPathForCurrentFile(),
        },
      })
    end,
  })
end

local bend_lsp_cmd = { 'bend', 'lsp' }

local upstream_eslint = vim.lsp.config.eslint or {}

local function eslint_root_dir(bufnr, on_dir)
  if repo.is_hubspot_repo(bufnr) then return end

  if type(upstream_eslint.root_dir) == 'function' then return upstream_eslint.root_dir(bufnr, on_dir) end

  if type(upstream_eslint.root_dir) == 'string' then return on_dir(upstream_eslint.root_dir) end

  return on_dir(vim.fs.root(bufnr, upstream_eslint.root_markers or { 'package.json', '.git' }))
end

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
    root_dir = eslint_root_dir,
    handlers = {
      ['eslint/probeFailed'] = function() return warn_eslint('[eslint] probe failed.') end,
      ['eslint/noLibrary'] = function() return warn_eslint('[eslint] Unable to find ESLint library.') end,
    },
  }, upstream_eslint.on_attach),
  ts_ls = ts_ls_config,
}

servers['bend-lsp'] = with_common_config({
  filetypes = ts_filetypes,
  cmd = bend_lsp_cmd,
  root_dir = hubspot_root_dir,
})

for server_name, server_config in pairs(servers) do
  if type(server_config) == 'function' then server_config = server_config() end

  vim.lsp.config(server_name, server_config)
end

local bend_setup_group = vim.api.nvim_create_augroup('BendSetup', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = bend_setup_group,
  pattern = ts_filetypes,
  callback = function(args)
    ensure_bend_setup(args.buf)
  end,
})

local core_servers = {
  lua_ls = 'lua-language-server',
  yamlls = 'yaml-language-server',
  ts_ls = 'typescript-language-server',
  eslint = 'vscode-eslint-language-server',
}

for server_name, executable in pairs(core_servers) do
  if utils.is_executable(executable) then vim.lsp.enable(server_name) end
end

if utils.is_hubspot_machine and utils.is_executable('bend') then vim.lsp.enable('bend-lsp') end

local optional_servers = {
  gopls = {
    executable = 'gopls',
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
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
      if utils.is_executable(server_config.executable) and not vim.lsp.is_enabled(server_name) then vim.lsp.enable(server_name) end
    end,
  })
end

if utils.is_hubspot_machine then
  require('hubspot-i18n').setup({
    keys = {
      -- Keep the i18n goto-definition behavior available, but don't let the
      -- plugin own `gd`. lua/nav.lua composes this hidden mapping with the
      -- normal LSP definition/usages behavior.
      goto_definition = '<Plug>(hubspot-i18n-goto-definition)',
    },
  })
end
