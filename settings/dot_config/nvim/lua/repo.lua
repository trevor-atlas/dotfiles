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

-- Cache of static_conf.json path -> decoded contents (or false when unreadable).
-- static_conf.json rarely changes within a session, so this avoids re-reading
-- and re-decoding JSON on every root_dir / cmd resolution.
local static_conf_cache = {}

local function read_json(path)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local content = fd:read('*a')
  fd:close()
  if not content or content == '' then return nil end
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then return nil end
  return decoded
end

local function read_static_conf(path)
  local cached = static_conf_cache[path]
  if cached ~= nil then
    return cached or nil
  end

  local decoded = read_json(path)
  static_conf_cache[path] = decoded or false
  return decoded
end

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

-- Nearest static_conf.json walking upward from the buffer/dir.
function M.find_static_conf(target)
  return vim.fs.find({ 'static_conf.json' }, { path = resolve_search_path(target), upward = true, limit = 1 })[1]
end

-- Root directory of a tsgo project, or nil when the project has not migrated.
-- See https://tools.hubteamqa.com/bend/tsgo — migrated repos install BPM deps
-- into a local node_modules and use the off-the-shelf tsgo compiler/LSP instead
-- of the bend-forked hs-typescript tsserver + asset-bender reactor.
--
-- The `useTsgo` flag lives in the *build-root* static_conf.json (the one that
-- lists `packages`), NOT the per-package static_conf.json that sits next to the
-- source. A file therefore lives in nested static_conf.json descriptors, so we
-- walk every static_conf.json upward and return the first one that opts in.
function M.find_tsgo_root(target)
  local confs = vim.fs.find(
    { 'static_conf.json' },
    { path = resolve_search_path(target), upward = true, limit = math.huge }
  )

  for _, conf in ipairs(confs) do
    local data = read_static_conf(conf)
    if type(data) == 'table' and data.useTsgo == true then
      return vim.fs.dirname(conf)
    end
  end

  return nil
end

function M.is_tsgo_repo(target)
  return M.find_tsgo_root(target) ~= nil
end

-- Local `node_modules/.bin/tsgo` shim (walking upward), used to spawn the tsgo
-- language server for the current file.
function M.find_local_tsgo(target)
  return vim.fs.find({ 'node_modules/.bin/tsgo' }, { path = resolve_search_path(target), upward = true, limit = 1 })[1]
end

return M
