local M = {}

M.os = vim.loop.os_uname().sysname
M.is_windows = M.os == 'Windows'
M.is_wsl = M.os == 'WSL'
M.is_macos = M.os == 'Darwin'
M.path_sep = M.is_windows and '\\' or '/'
M.is_hubspot_machine = vim.loop.fs_stat(vim.env.HOME .. '/.hubspot')

function M.get_text_under_cursor() return vim.treesitter.get_node_text(vim.treesitter.get_node({ bufnr = 0 }), 0) end

---@param table1 {}
---@param table2 {}
---@return {}
function M.merge_tables(table1, table2)
  local result = {}

  for k, v in pairs(table1) do
    result[k] = v
  end

  for k, v in pairs(table2) do
    result[k] = v
  end

  return result
end

function M.buffer() return vim.api.nvim_get_current_buf() end

function M.map(mode, from, to, opts)
  opts = opts or { noremap = true, silent = true }
  vim.keymap.set(mode, from, to, opts)
end

function M.conditional_func(func, condition, ...)
  if (condition == nil and true or condition) and type(func) == 'function' then return func(...) end
end

function M.path_join(...) return table.concat(vim.tbl_flatten({ ... }), M.path_sep) end

function M.is_dir(filename)
  local stat = vim.loop.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

function M.dirname(filepath)
  local is_changed = false
  local result = filepath:gsub(M.path_sep .. '([^' .. M.path_sep .. ']+)$', function()
    is_changed = true
    return ''
  end)
  return result, is_changed
end

function M.is_available(plugin)
  local l = require('lazy').plugins()
  for _, p in ipairs(l) do
    -- p[1] is the string plugin name
    -- {"some-person/plugin.nvim", _ = {...}}
    if p[1] == plugin then return true end
  end
  return false
end

function M.find_root_git_dir() return M.buffer_find_file_dir(M.buffer(), '.git') end

function M.buffer_find_file(bufnr, filename)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  if vim.fn.filereadable(buffer_path) == 0 then return nil end
  return vim.fn.finddir(filename, vim.fn.expand('%:p:h'))
end

function M.buffer_find_file_dir(bufnr, filename) M.buffer_find_file(bufnr, filename .. '/..') end

function M.file_exists(fname)
  local stat = vim.loop.fs_stat(fname)
  return (stat and stat.type) or false
end

function M.open_file(file) vim.cmd('e ' .. file) end

return M
