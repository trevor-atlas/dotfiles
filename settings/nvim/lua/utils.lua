local Job = require('plenary.job')

local M = {}

---@param table1 {}
---@param table2 {}
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

function M.dir_exists(dirpath)
  local result = ''
  Job:new({
    command = 'ls',
    args = { dirpath },
    on_exit = function(_, return_val) result = return_val end,
  }):sync()
  vim.system({ 'ls', dirpath }, { text = true }):wait()
  return result == 0
end

function M.conditional_func(func, condition, ...)
  if (condition == nil and true or condition) and type(func) == 'function' then return func(...) end
end

M.path_sep = vim.loop.os_uname().sysname == 'Windows' and '\\' or '/'

local function is_hubspot_machine() return vim.system({ 'ls', vim.env.HOME .. '/.hubspot' }, { text = true }):wait().code == 0 end

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

function M.is_available(plugin) return packer_plugins ~= nil and packer_plugins[plugin] ~= nil end

function M.find_root_git_dir() return M.buffer_find_file_dir(M.buffer(), '.git') end

function M.buffer_find_file(bufnr, filename)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.filereadable(bufname) == 0 then return nil end
  return vim.fn.finddir(filename, vim.fn.expand('%:p:h') .. '.;')
end

function M.buffer_find_file_dir(bufnr, filename) M.buffer_find_file(bufnr, filename .. '/..') end

function M.file_exists(fname)
  local stat = vim.loop.fs_stat(fname)
  return (stat and stat.type) or false
end

function M.open_file(file) vim.cmd('e ' .. file) end

function M.get_uname() return vim.loop.os_uname().sysname end

function M.determine_os()
  local uname = M.get_uname()
  local osnames = { 'WSL', 'Darwin' }
  for _, name in ipairs(osnames) do
    if not not string.find(uname or '', name) then return name end
  end
  return 'Unknown'
end

local user_terminals = {}
function M.toggle_term_cmd(term_details)
  -- if a command string is provided, create a basic table for Terminal:new() options
  if type(term_details) == 'string' then term_details = { cmd = term_details, hidden = true } end
  -- use the command as the key for the table
  local term_key = term_details.cmd
  -- set the count in the term details
  if vim.v.count > 0 and term_details.count == nil then
    term_details.count = vim.v.count
    term_key = term_key .. vim.v.count
  end
  -- if terminal doesn't exist yet, create it
  if user_terminals[term_key] == nil then user_terminals[term_key] = require('toggleterm.terminal').Terminal:new(term_details) end
  -- toggle the terminal
  user_terminals[term_key]:toggle()
end

M.is_hubspot_machine = M.dir_exists(vim.env.HOME .. '/.hubspot')
M.os = M.determine_os()
M.is_wsl = M.os == 'WSL'
M.is_macos = M.os == 'Darwin'

return M
