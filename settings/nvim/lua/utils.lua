local M = {}

M.os = vim.uv.os_uname().sysname
M.is_windows = M.os == 'Windows'
M.is_wsl = M.os == 'WSL'
M.is_macos = M.os == 'Darwin'
M.path_sep = M.is_windows and '\\' or '/'
M.is_hubspot_machine = vim.uv.fs_stat(vim.env.HOME .. '/.hubspot')
M.root_markers = {
  git = { '.git' },
  package_manager = {
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'bun.lockb',
    'bun.lock',
    '.git',
  },
  deno = { 'deno.json', 'deno.jsonc' },
  deno_lock = { 'deno.lock' },
  deno_with_lock = { 'deno.json', 'deno.jsonc', 'deno.lock' },
  go = { 'go.work', 'go.mod', '.git' },
}

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

function M.root_pattern(...)
  local markers = { ... }

  return function(path)
    if type(path) == 'number' then path = vim.api.nvim_buf_get_name(path) end
    if not path or path == '' then return nil end

    local stat = vim.uv.fs_stat(path)
    local start_path = stat and stat.type == 'directory' and path or vim.fs.dirname(path)
    local found = vim.fs.find(markers, { path = start_path, upward = true, limit = 1 })[1]

    return found and vim.fs.dirname(found) or nil
  end
end

function M.buf_root(bufnr, markers) return vim.fs.root(bufnr, markers) end

function M.is_deno_project(bufnr, project_root)
  local deno_root = M.buf_root(bufnr, M.root_markers.deno)
  local deno_lock_root = M.buf_root(bufnr, M.root_markers.deno_lock)

  if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then return true end
  if deno_root and (not project_root or #deno_root >= #project_root) then return true end

  return false
end

function M.find_node_root(bufnr, opts)
  opts = opts or {}

  local project_root = M.buf_root(bufnr, M.root_markers.package_manager)
  if M.is_deno_project(bufnr, project_root) then return nil end

  return project_root or (opts.fallback_to_cwd and vim.fn.getcwd() or nil)
end

function M.is_dir(filename)
  local stat = vim.uv.fs_stat(filename)
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

function M.find_root_git_dir() return M.buffer_find_file_dir(M.buffer(), '.git') end

function M.buffer_find_file(bufnr, filename)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  if vim.fn.filereadable(buffer_path) == 0 then return nil end
  return vim.fn.finddir(filename, vim.fn.expand('%:p:h'))
end

function M.buffer_find_file_dir(bufnr, filename) M.buffer_find_file(bufnr, filename .. '/..') end

function M.file_exists(fname)
  local stat = vim.uv.fs_stat(fname)
  return (stat and stat.type) or false
end

function M.is_executable(cmd)
  return vim.fn.executable(cmd) == 1
end

function M.open_file(file) vim.cmd('e ' .. file) end

function M.onUpdate(packageName, command)
  vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == packageName and kind == 'update' then
      if not ev.data.active then vim.cmd.packadd(packageName) end
      command()
    end
  end })
end

return M

