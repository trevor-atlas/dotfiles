local M = {
  key = 'nvim_cmp_hs_translations',
  cache = {
    -- {
    --    ['/Users/username/repos/some-repo/some-lib'] = {
    --      {
    --        label = 'some.translation.key',
    --        documentation = {
    --          kind = 'markdown'
    --          value = 'Translated text'
    --        }
    --    },
    --    ['/Users/username/repos/some-repo/some-app-ui'] = {
    --      {
    --        label = 'app.translation.keys',
    --        documentation = {
    --          kind = 'markdown'
    --          value = 'App Translated text'
    --        }
    --      },
    --    }
    -- }
    ---@type table<string, table<{label: string, documentation: { kind: string, value: string }}>>
    completions = {},
    -- {
    --    ['/Users/username/repos/some-repo/some-lib'] = {
    --      ['some.translation.key'] = "Translated text"
    --    },
    --    ['/Users/username/repos/some-repo/some-app-ui'] = {
    --      ['app.translation.keys'] = "App Translated text"
    --    }
    -- }
    ---@type table<string, table<string, string>>
    translations = {},
  },
}

local lspconfig_util = require('lspconfig.util')
local get_lib_dir = lspconfig_util.root_pattern('tsconfig.json', 'webpack.config.js', 'target')
local get_root = lspconfig_util.root_pattern('.git', '.blazar-enabled', 'package.json')

---@param bufnr number|nil
---@return string|nil
function M.get_root_dir(bufnr)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  return get_root(buffer_path)
end

---@param bufnr number|nil
---@return string|nil
function M.get_app_or_lib_dir(bufnr)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  return get_lib_dir(buffer_path)
end

local function split_string(str, delimiter)
  local result = {}
  for match in (str .. delimiter):gmatch('(.-)' .. delimiter) do
    table.insert(result, match)
  end
  return result
end

local function remove_prefix_from_string(str, pattern) return (str:sub(0, #pattern) == pattern) and str:sub(#pattern + 1) or str end

local function get_completion_source()
  local source = {
    get_trigger_characters = function() return { '"' } end,
    is_available = function() return true end,
  }

  source.new = function()
    local self = setmetatable({ cache = M.cache.completions }, { __index = source })
    return self
  end

  source.complete = function(self, comp, callback)
    local path = M.get_app_or_lib_dir(comp.context.bufnr)
    if not path then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local cached_completions = M.get_completions()
    if cached_completions[path] == nil then
      M.parse_and_cache_translations()
      cached_completions = M.get_completions()
    end
    if cached_completions[path] ~= nil then
      callback({ items = cached_completions[path], isIncomplete = false })
      return
    end

    callback({ items = {}, isIncomplete = false })
  end

  return source.new()
end

---@return table<string>
local function get_translation_files(root_dir)
  ---@type table<string>
  local translation_file_paths = {}
  vim
    .system({ 'rg', '--files', root_dir, '-g', 'en.lyaml' }, { text = true }, function(result)
      if result.code ~= 0 then
        print('Error collecting translation files: ' .. result.stderr)
        return
      end
      for file_path in result.stdout:gmatch('[^\r\n]+') do
        table.insert(translation_file_paths, file_path)
      end
    end)
    :wait()
  return translation_file_paths
end

function M.parse_and_cache_translations()
  local root_dir = M.get_root_dir()
  if root_dir == nil or root_dir == '' then
    print('Unable to find a root dir, skipping translation cache generation')
    return
  end

  local file_paths = get_translation_files(root_dir)
  ---@type table<string, table<string, string>>
  local translations_by_directory = {}

  for _, file_path in ipairs(file_paths) do
    local path = file_path:gsub('/static/lang/en.lyaml', '')
    translations_by_directory[path] = {}
    vim
      .system({ 'yq', 'ea', '. as $item ireduce ({}; . * $item )', file_path, '-o', 'p' }, { text = true }, function(res)
        if res.code ~= 0 then
          print('Error parsing translation files: ' .. res.stderr)
          return
        end
        -- need to remove ending '/static/lang/en.lyaml' from paths for cache
        for line in res.stdout:gmatch('[^\r\n]+') do
          local key, value = unpack(split_string(line, ' = '))
          local label = remove_prefix_from_string(key, 'en.')
          translations_by_directory[path][label] = value
        end
      end)
      :wait()
  end
  M.set_translations(translations_by_directory)
  M.parse_and_cache_completions()
end

function M.parse_and_cache_completions()
  ---@type table<string, table<{label: string, documentation: { kind: string, value: string }}>>
  local completions = {}
  local translations = M.get_translations()
  for path, map in pairs(translations) do
    completions[path] = {}
    for key, value in pairs(map) do
      if key ~= '' and not key:match('^#') then -- filter out comments and empty lines
        table.insert(completions[path], {
          label = key,
          documentation = {
            kind = 'markdown',
            value = value,
          },
        })
      end
    end
  end
  M.set_completions(completions)
  return completions
end

---@param completions table<string, table<{label: string, documentation: { kind: string, value: string }}>>
function M.set_completions(completions)
  if completions == nil then return end
  M.cache.completions = completions
end

---@return table<string, table<{label: string, documentation: { kind: string, value: string }}>>
function M.get_completions() return M.cache.completions end

---@param translations table<string, table<string, string>>
function M.set_translations(translations)
  if translations == nil then return end
  M.cache.translations = translations
end

---@return table<string, table<string, string>>
function M.get_translations() return M.cache.translations end

local is_hubspot_machine = vim.loop.fs_stat(vim.env.HOME .. '/.hubspot')
function M.setup()
  if is_hubspot_machine then
    M.parse_and_cache_translations()
    require('cmp').register_source(M.key, get_completion_source())
  end
end

return M
