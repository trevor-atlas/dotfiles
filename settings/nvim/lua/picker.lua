local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local hs_completion = require('hubspot-completion')

local pad = '                                        '
local ascii_arr = {
  '⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠛⠻⣿⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣄⡀⠀⢻⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⠃⢰⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⢶⣶⣶⣾⣿⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⢠⡀⠐⠀⠀⠀⠻⢿⣿⣿⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⢸⣷⡄⠀⠣⣄⡀⠀⠉⠛⢿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⣿⣿⣦⠀⠹⣿⣷⣶⣦⣼⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣼⣿⣿⣿⣷⣄⣸⣿⣿⣿⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
  '⣿⣿⡿⢛⡙⢻⠛⣉⢻⣉⢈⣹⣿⣿⠟⣉⢻⡏⢛⠙⣉⢻⣿⣿⣿',
  '⣿⣿⣇⠻⠃⣾⠸⠟⣸⣿⠈⣿⣿⣿⡀⠴⠞⡇⣾⡄⣿⠘⣿⣿⣿',
  '⣿⣿⣟⠛⣃⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⣿',
  '⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
}

local function is_empty(t)
  if t == nil then return true end
  for _ in pairs(t) do
    return false
  end
  return true
end

local function get_translation_keys()
  local path = hs_completion.get_app_or_lib_dir()
  local translations = hs_completion.get_translations()
  if is_empty(translations) then return {} end

  local keys = {}
  if path ~= nil and not is_empty(translations[path]) then
    for key, value in pairs(translations[path]) do
      table.insert(keys, { key, value })
    end
    return keys
  end

  for _, values in pairs(translations) do
    for key, value in pairs(values) do
      table.insert(keys, { key, value })
    end
  end

  return keys
end

local previewer = previewers.new_buffer_previewer({
  define_preview = function(self, entry)
    -- P({ self = self, entry = entry })
    if self.state.winid ~= -1 then vim.api.nvim_win_set_option(self.state.winid, 'wrap', true) end
    local lines = 10
    if entry.value == nil then
      for i, line in ipairs(ascii_arr) do
        vim.api.nvim_buf_set_lines(self.state.bufnr, lines + i - 1, lines + i, false, { line })
      end
      return
    end

    vim.api.nvim_buf_set_lines(self.state.bufnr, lines, lines, false, { entry.value[2] })
  end,
})

-- our picker function
local find_translation = function(opts)
  local results = get_translation_keys()

  local path = hs_completion.get_app_or_lib_dir()
  opts = opts or { defaults = { preview = { wrap = true } } }
  pickers
    .new(opts, {
      defaults = { preview = { wrap = true } },
      prompt_title = path and 'Translations for ' .. path:match('([^/]+)$') or 'All Translations',
      previewer = previewer,
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- P({ selection = selection })
          vim.api.nvim_put({ selection.value[1] }, '', false, true)
        end)
        return true
      end,
      finder = finders.new_table({
        -- results is a list of tuples
        -- [value shown in filter list, key used to look up preview (or use as the preview directly)]
        -- {
        --   { 'red', '#ff0000' },
        --   { 'green', '#00ff00' },
        --   { 'blue', '#0000ff' },
        -- },
        results = results,
        entry_maker = function(entry)
          if entry == nil then
            return {
              value = 'No results',
              display = 'No results',
              ordinal = 'No results',
            }
          end
          return {
            value = entry,
            display = entry[1],
            ordinal = entry[1],
          }
        end,
      }),
    })
    :find()
end

local M = {}
function M.open() find_translation() end
return M
