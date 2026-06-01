local M = {}

function M.common_on_attach(client, bufnr)
  local picker = require('snacks.picker')
  local telescope = require('loaders.telescope')
  local nav = require('nav')
  local nmap = function(keys, func, desc)
    if desc then desc = 'LSP: ' .. desc end
    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', nav.goto_definition, '[G]oto [D]efinition')
  nmap('gr', picker.lsp_references, '[G]oto [R]eferences')
  nmap('gi', picker.lsp_implementations, '[G]oto [I]mplementation')
  nmap('gI', picker.lsp_implementations, '[G]oto [I]mplementation')
  nmap('<leader><S-d>', vim.lsp.buf.type_definition, 'Type [D]efinition')
  nmap('<leader>ds', telescope.builtin('lsp_document_symbols'), '[D]ocument [S]ymbols')
  nmap('<leader>ws', telescope.builtin('lsp_dynamic_workspace_symbols'), '[W]orkspace [S]ymbols')
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, '[W]orkspace [L]ist Folders')

  if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens) then
    vim.schedule(function()
      pcall(vim.lsp.codelens.enable, true, { bufnr = bufnr })
    end)
  end
end

return M
