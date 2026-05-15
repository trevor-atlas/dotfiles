---@type blink.cmp.Source
local M = {}

local i18n = require('hubspot-i18n')

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { '"', "'", '.' }
end

function M:get_completions(ctx, callback)
  local bufnr = ctx.bufnr
  local path = i18n.get_app_or_lib_dir(bufnr)
  if not path then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return function() end
  end

  -- Walk backwards to the opening quote to get the full typed prefix.
  -- We can't rely on ctx.cursor[2] alone because when '.' triggers completion it
  -- lands just after the dot, not at the start of the key.
  local line = ctx.line:sub(1, ctx.cursor[2])
  local quote_col = nil
  for i = #line, 1, -1 do
    local c = line:sub(i, i)
    if c == '"' or c == "'" then quote_col = i; break end
  end

  if not quote_col then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return function() end
  end

  local input = line:sub(quote_col + 1)
  if input == '' then
    callback({ items = {}, is_incomplete_forward = true, is_incomplete_backward = false })
    return function() end
  end

  local translations = i18n.get_translations()
  if not translations[path] then
    i18n.parse_and_cache_translations()
    callback({ items = {}, is_incomplete_forward = true, is_incomplete_backward = false })
    return function() end
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

  -- When input ends with '.' the cursor offset lands right after the dot, so
  -- insertText should be only the key suffix that follows the typed prefix.
  -- Otherwise the cursor is at the keyword start and we insert the full key.
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

  callback({ items = items, is_incomplete_forward = true, is_incomplete_backward = false })
  return function() end
end

return M
