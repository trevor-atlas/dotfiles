local M = {}

function M.common_on_attach(client, bufnr)
  require('keymaps').apply_buffer(bufnr, require('keymaps.lsp').for_buffer(client))

  if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens) then
    vim.schedule(function()
      pcall(vim.lsp.codelens.enable, true, { bufnr = bufnr })
    end)
  end
end

return M
