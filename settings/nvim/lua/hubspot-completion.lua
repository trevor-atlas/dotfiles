local util = require('lspconfig.util')

local function get_project_root(startdir) return util.root_pattern('.git', 'yarn.lock', 'package.json')(startdir) end

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
  local self = setmetatable({ cache = {} }, { __index = source })
  return self
end

source.complete = function(self, _, callback)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only generate this map once per session. Might want to add an invalidate flag somewhere eventually
  if self.cache[bufnr] then
    callback({ items = self.cache[bufnr], isIncomplete = false })
    return
  end
  local root_dir = get_project_root(vim.fn.expand('%:p'))
  -- We couldn't find a root directory, so ignore this file.
  if not root_dir then
    callback({ items = {}, isIncomplete = false })
    return
  end

  vim.system({ 'rg', '--files', root_dir, '-g', 'en.lyaml' }, { text = true }, function(result)
    local dirs = {}
    for dir in result.stdout:gmatch('[^\r\n]+') do
      table.insert(dirs, dir)
    end

    local yq_args = { 'yq', 'ea', '. as $item ireduce ({}; . * $item )' }
    for _, v in pairs(dirs) do
      table.insert(yq_args, v)
    end
    table.insert(yq_args, '-o')
    table.insert(yq_args, 'p')

    -- merge together all en.lyaml files and output the aggregate in the format of
    -- this.is.a.key = This is the translation
    vim.system(yq_args, { text = true }, function(res)
      local parsed_lines = {}
      for line in res.stdout:gmatch('[^\r\n]+') do
        table.insert(parsed_lines, line)
      end
      local entries = {}
      -- map over every key/translation line
      for _, v in pairs(parsed_lines) do
        -- separate each line into a key/translation via the ` = ` between then
        local translationKeyValuePair = split_string(v, ' = ')
        local label = remove_prefix_from_string(translationKeyValuePair[1], 'en.')

        if label ~= '' and not label:match('^#') then -- filter out empty lines and comment lines
          -- strip off the "en." from the beginning of every key
          table.insert(entries, {
            label = label,
            documentation = {
              kind = 'markdown',
              value = translationKeyValuePair[2],
            },
          })
        end
      end

      self.cache[bufnr] = entries
      callback({ items = entries, isIncomplete = false })
    end)
  end)
end

local is_hubspot_machine = vim.loop.fs_stat(vim.env.HOME .. '/.hubspot')
local key = 'nvim_cmp_hs_translations'
return {
  key = key,
  setup = function()
    if is_hubspot_machine then require('cmp').register_source(key, source.new()) end
  end,
}
