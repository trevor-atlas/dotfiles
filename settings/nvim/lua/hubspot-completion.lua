local M = {}

local i18n = require('hubspot-i18n')

M.key = 'nvim_cmp_hs_translations'

local function get_completion_source()
  local source = {
    get_trigger_characters = function() return { '"', "'", '.' } end,
    get_keyword_pattern    = function() return [[[[:alnum:]_-]\+\%(\.[[:alnum:]_-]\+\)*]] end,
    is_available           = function() return true end,
  }

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.complete = function(_, comp, callback)
    local path = i18n.get_app_or_lib_dir(comp.context.bufnr)
    if not path then
      callback({ items = {}, isIncomplete = false })
      return
    end

    -- Walk backwards to the opening quote to get the full typed prefix.
    -- We can't rely on comp.offset because when '.' triggers completion it
    -- lands just after the dot, not at the start of the key.
    local line = comp.context.cursor_before_line
    local quote_col = nil
    for i = #line, 1, -1 do
      local c = line:sub(i, i)
      if c == '"' or c == "'" then quote_col = i; break end
    end

    if not quote_col then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local input = line:sub(quote_col + 1)
    if input == '' then
      callback({ items = {}, isIncomplete = true })
      return
    end

    local translations = i18n.get_translations()
    if not translations[path] then
      i18n.parse_and_cache_translations()
      callback({ items = {}, isIncomplete = true })
      return
    end

    -- Show from second-to-last dot in input so the label retains one parent
    -- segment as context (e.g. "modal.title" rather than just "title").
    local label_from = 1
    local dots = 0
    for i = #input, 1, -1 do
      if input:sub(i, i) == '.' then
        dots = dots + 1
        if dots == 2 then label_from = i + 1; break end
      end
    end

    -- When input ends with '.' comp.offset lands right after the dot, so
    -- insertText should be only the key suffix that follows the typed prefix.
    -- Otherwise comp.offset is at the keyword start and we insert the full key.
    local trailing_dot = input:sub(-1) == '.'

    local items = {}
    for key, entry in pairs(translations[path]) do
      if key ~= '' and not key:match('^#') and vim.startswith(key, input) then
        table.insert(items, {
          label         = key:sub(label_from),
          insertText    = trailing_dot and key:sub(#input + 1) or key,
          filterText    = key,
          documentation = { kind = 'markdown', value = entry.value },
        })
      end
    end
    callback({ items = items, isIncomplete = true })
  end

  return source.new()
end

function M.setup()
  require('cmp').register_source(M.key, get_completion_source())
end

return M
