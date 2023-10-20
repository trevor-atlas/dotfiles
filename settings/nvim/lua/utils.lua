local Job = require("plenary.job")

local M = {}

function M.dir_exists(dirpath)
  local result = ""
  Job:new({command = "ls", args = {dirpath}, on_exit = function(_, return_val) result = return_val end}):sync()
  return result == 0
end

function M.conditional_func(func, condition, ...)
  if (condition == nil and true or condition) and type(func) == "function" then return func(...) end
end

M.path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"

function M.path_join(...) return table.concat(vim.tbl_flatten({...}), M.path_sep) end

function M.is_dir(filename)
  local stat = vim.loop.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

function M.dirname(filepath)
  local is_changed = false
  local result = filepath:gsub(M.path_sep .. "([^" .. M.path_sep .. "]+)$", function()
    is_changed = true
    return ""
  end)
  return result, is_changed
end

function M.is_available(plugin) return packer_plugins ~= nil and packer_plugins[plugin] ~= nil end

function M.find_root_git_dir()
  local git_root = ""
  Job:new({
    command = "git",
    args = {"rev-parse", "--show-toplevel"},
    on_exit = function(results, _) git_root = results and results._stdout_results[1] or "" end
  }):sync()
  local result, _ = string.gsub(git_root, "[\r\n]", "")
  return result
end

function M.buffer_find_file_dir(bufnr, filename)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.filereadable(bufname) == 0 then return nil end
  local dir = bufname
  while (dir ~= "") do
    dir = dir:gsub(M.path_sep .. "([^" .. M.path_sep .. "]+)$", "")
    if vim.fn.findfile(filename, vim.fn.finddir(dir)) ~= "" then return dir, bufname end
  end
  return nil
end

function M.buffer_find_file(bufnr, filename)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.filereadable(bufname) == 0 then return nil end
  local dir = bufname
  while (dir ~= "") do
    dir = dir:gsub(M.path_sep .. "([^" .. M.path_sep .. "]+)$", "")
    local found_file = vim.fn.findfile(filename, vim.fn.finddir(dir))
    if found_file ~= "" then return found_file end
  end
  return nil
end

function M.file_exists(fname)
  local stat = vim.loop.fs_stat(fname)
  return (stat and stat.type) or false
end

function M.open_file(file) vim.cmd("e " .. file) end

function M.get_uname()
  local result = ""
  Job:new({command = "uname", args = {"-a"}, on_exit = function(res, return_val) result = res._stdout_results[1] end})
      :sync()
  return result
end

function M.determine_os()
  local uname = M.get_uname()
  local osnames = {"WSL", "Darwin"}
  for _, name in ipairs(osnames) do if not not string.find(uname or "", name) then return name end end
  return "Unknown"
end

M.is_hubspot_machine = M.dir_exists(vim.env.HOME .. "/.hubspot")
M.os = M.determine_os()
M.is_wsl = M.os == "WSL"
M.is_macos = M.os == "Darwin"

return M
