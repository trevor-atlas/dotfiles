local M = {}

local hubspot_markers = {
  'static_conf.json',
  '.blazar-enabled',
  '.blazar.yaml',
  'hubspot.deploy',
}

local mill_markers = {
  'build.mill.yaml',
}

local function resolve_search_path(target)
  if type(target) == 'number' then
    target = vim.api.nvim_buf_get_name(target)
  end

  if type(target) ~= 'string' or target == '' then
    return vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(target)
  if stat and stat.type == 'directory' then
    return target
  end

  return vim.fs.dirname(target)
end

function M.find_root(target, markers)
  local found = vim.fs.find(markers, { path = resolve_search_path(target), upward = true, limit = 1 })[1]
  return found and vim.fs.dirname(found) or nil
end

function M.is_hubspot_repo(target)
  return M.find_root(target, hubspot_markers) ~= nil
end

function M.find_mill_root(target)
  return M.find_root(target, mill_markers)
end

function M.is_mill_repo(target)
  return M.find_mill_root(target) ~= nil
end

function M.find_mill_module_root(target)
  local found = vim.fs.find({ 'package.mill.yaml' }, { path = resolve_search_path(target), upward = true, limit = 1 })[1]
  return found and vim.fs.dirname(found) or nil
end

function M.find_mill_module_name(target)
  local root = M.find_mill_module_root(target)
  return root and vim.fs.basename(root) or nil
end

function M.find_local_prettier(target)
  return vim.fs.find({ 'node_modules/.bin/prettier' }, { path = resolve_search_path(target), upward = true, limit = 1 })[1]
end

return M
