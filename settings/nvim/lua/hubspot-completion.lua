local M = {
  key = 'nvim_cmp_hs_translations',
  cache = {
    completions = {},
    translations = { ['/Users/atlas/.config/atlas/settings/nvim'] = { ['a.test.string'] = "It's translation" } },
  },
}

---@return string|nil
local function get_root_dir() return require('lspconfig.util').root_pattern('.git', 'lazy-lock.json', 'yarn.lock', 'package.json')(vim.fn.expand('%:p')) end

local function split_string(s, delimiter)
  local result = {}
  for match in (s .. delimiter):gmatch('(.-)' .. delimiter) do
    table.insert(result, match)
  end
  return result
end

local function remove_prefix_from_string(str, pattern) return (str:sub(0, #pattern) == pattern) and str:sub(#pattern + 1) or str end

local source = {
  get_trigger_characters = function() return { '"' } end,
  is_available = function() return true end,
}

source.new = function()
  local self = setmetatable({ cache = M.cache.completions }, { __index = source })
  return self
end

source.complete = function(self, _, callback)
  local root_dir = get_root_dir()
  -- We couldn't find a root directory, so ignore this file.
  if not root_dir then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local cached_completions = M.get_completions()
  if cached_completions ~= nil then
    callback({ items = cached_completions, isIncomplete = false })
    return
  end

  callback({ items = {}, isIncomplete = false })
end

local is_processing = false
function M.parse_and_cache_translations()
  local root_dir = get_root_dir()
  if is_processing then return end

  is_processing = true
  vim.system({ 'rg', '--files', root_dir, '-g', 'en.lyaml' }, { text = true }, function(result)
    ---@type table<string>
    local dirs_with_translations = {}
    for dir in result.stdout:gmatch('[^\r\n]+') do
      table.insert(dirs_with_translations, dir)
    end

    local yq_args = { 'yq', 'ea', '. as $item ireduce ({}; . * $item )' }
    for _, v in pairs(dirs_with_translations) do
      table.insert(yq_args, v)
    end
    table.insert(yq_args, '-o')
    table.insert(yq_args, 'p')

    -- merge en.lyaml files
    vim.system(yq_args, { text = true }, function(res)
      ---@type table<"app.translation.key", "This is the translation">
      local parsed_lines = {}
      for line in res.stdout:gmatch('[^\r\n]+') do
        table.insert(parsed_lines, line)
      end
      ---@type table<string, string>
      ---{ "app.translation.key", "This is the translation" }
      local entries = {}
      for _, v in pairs(parsed_lines) do
        local key, value = unpack(split_string(v, ' = '))
        local label = remove_prefix_from_string(key, 'en.')
        entries[label] = value
      end

      M.set_translations(entries)
      M.parse_and_cache_completions()
      is_processing = false
    end)
  end)
end

function M.parse_and_cache_completions()
  local cached_completions = M.get_completions()
  if cached_completions ~= nil then return cached_completions end

  local completions = {}
  for key, value in pairs(M.cache) do
    if key ~= '' and not key:match('^#') then -- filter out comments and empty lines
      table.insert(completions, {
        label = key,
        documentation = {
          kind = 'markdown',
          value = value,
        },
      })
    end
  end
  M.set_completions(completions)
  return completions
end

---@param completions table<{label: string, documentation: { kind: string, value: string }}>
function M.set_completions(completions)
  if completions == nil then return end
  local root_dir = get_root_dir()
  M.cache.completions[root_dir] = completions
end

---@return table<{label: string, documentation: { kind: string, value: string }}>
function M.get_completions()
  local root_dir = get_root_dir()
  return M.cache.completions[root_dir]
end

---@param translations table<string, string>
function M.set_translations(translations)
  if translations == nil then return end
  local root_dir = get_root_dir()
  M.cache.translations[root_dir] = translations
end

---@return table<string, string>
function M.get_translations()
  local root_dir = get_root_dir()
  return M.cache.translations[root_dir]
end

local is_hubspot_machine = vim.loop.fs_stat(vim.env.HOME .. '/.hubspot')
function M.setup()
  local root_dir = get_root_dir()
  if is_hubspot_machine and root_dir ~= nil then
    -- M.parse_and_cache_translations()
    require('cmp').register_source(M.key, source.new())
  end
end

return M
