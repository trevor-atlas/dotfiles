local M = {}

M.is_hubspot_machine = vim.uv.fs_stat(vim.env.HOME .. '/.hubspot') ~= nil

function M.get_text_under_cursor()
  local node = vim.treesitter.get_node({ bufnr = 0 })
  if not node then return '' end
  return vim.treesitter.get_node_text(node, 0)
end

function M.is_executable(cmd)
  return vim.fn.executable(cmd) == 1
end

return M
