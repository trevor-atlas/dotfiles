local float = {
  focusable = false,
  style = 'minimal',
  border = 'rounded',
}

-- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, float)
-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, float)

-- local lspconfig = require('lspconfig')
-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
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
  vim.keymap.set('n', 'gh', function() vim.diagnostic.open_float({ bufnr = 0 }) end, { remap = true, silent = true })

  -- See `:help K` for why this keymap
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  --nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  -- Lesser used LSP functionality
  --nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  --nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  --nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, '[W]orkspace [L]ist Folders')

  -- Create a command `:Format` local to the LSP buffer
  --vim.api.nvim_buf_create_user_command(bufnr, 'Format', vim.lsp.buf.format, { desc = 'Format current buffer with LSP' })
end

local capabilities = require('blink.cmp').get_lsp_capabilities()
local isHubspot, bend = pcall(require, 'bend')

--  If you want to override the default filetypes that your language server will attach to you can
--  define the property 'filetypes' to the map in question.
local servers = {
  lua_ls = {
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
  },
  yamlls = {},
}

for _, server_name in ipairs(vim.tbl_keys(servers)) do
  vim.lsp.config(server_name, {
    capabilities = capabilities,
    on_attach = on_attach,
    settings = servers[server_name],
    filetypes = (servers[server_name] or {}).filetypes,
  })
  vim.lsp.enable(server_name)
end

if isHubspot then
  bend.setup({ v2 = true, auto_add_dirs = true })
  vim.lsp.config('ts_ls', {
    filetypes = {
      'javascript',
      'javascriptreact',
      'javascript.jsx',
      'typescript',
      'typescriptreact',
      'typescript.tsx',
    },
    capabilities = capabilities,
    root_markers = { '.git', 'build-info.json' },
    on_attach = on_attach,
    cmd = { 'typescript-language-server', '--stdio' },
    init_options = {
      hostInfo = 'neovim',
      tsserver = {
        path = bend.getTsServerPathForCurrentFile(),
      },
    },
  })
end
vim.lsp.enable('ts_ls')

-- Enable language servers with default configs
vim.lsp.enable('jdtls')
vim.lsp.enable('gopls')
vim.lsp.enable('pyright')
vim.lsp.enable('nixd')
vim.lsp.enable('templ')
vim.lsp.enable('clangd')

require('hubspot-i18n').setup()
