local M = {}

function M.for_buffer(client)
  local picker = require('snacks.picker')
  local telescope = require('loaders.telescope')
  local nav = require('nav')

  local specs = {
    { keys = '<leader>rn', action = vim.lsp.buf.rename, desc = '[R]e[n]ame' },
    { keys = '<leader>ca', action = vim.lsp.buf.code_action, desc = '[C]ode [A]ction' },
    { keys = 'gd', action = function() require('nav').goto_definition() end, desc = '[G]oto [D]efinition' },
    { keys = 'gr', action = picker.lsp_references, desc = '[G]oto [R]eferences' },
    { keys = 'gi', action = picker.lsp_implementations, desc = '[G]oto [I]mplementation' },
    { keys = 'gI', action = picker.lsp_implementations, desc = '[G]oto [I]mplementation' },
    { keys = 'K', action = vim.lsp.buf.hover, desc = 'Hover Documentation' },
    {
      keys = '<leader>wl',
      action = function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end,
      desc = '[W]orkspace [L]ist Folders',
    },
  }

  if client:supports_method(vim.lsp.protocol.Methods.textDocument_typeDefinition) then
    table.insert(specs, { keys = '<leader><S-d>', action = vim.lsp.buf.type_definition, desc = 'Type [D]efinition' })
  end

  if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentSymbol) then
    table.insert(specs, { keys = '<leader>ds', action = telescope.builtin('lsp_document_symbols'), desc = '[D]ocument [S]ymbols' })
  end

  if client:supports_method(vim.lsp.protocol.Methods.workspace_symbol) then
    table.insert(specs, { keys = '<leader>ws', action = telescope.builtin('lsp_dynamic_workspace_symbols'), desc = '[W]orkspace [S]ymbols' })
  end

  return specs
end

return M
