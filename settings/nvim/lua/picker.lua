local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local hs_completion = require('hubspot-completion')

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

local loading_message = 'stranslations.are.loading'

local function get_translation_keys()
  local translations = nil --hs_completion.get_translations()
  if translations == nil then
    hs_completion.setup()
    return {
      {
        'Translations are loading, please try again',
        loading_message,
      },
    }
  end

  local keys = {}
  local i = 1
  for key, value in pairs(translations) do
    keys[i] = { key, value }
    i = i + 1
  end
  return keys
end
local values = get_translation_keys()

local previewer = previewers.new_buffer_previewer({
  define_preview = function(self, entry)
    if entry.value[2] == loading_message then
      for i, line in ipairs(ascii_arr) do
        vim.api.nvim_buf_set_lines(self.state.bufnr, i - 1, i, false, { line })
      end
    else
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { entry.value[2] })
    end
  end,
})

-- our picker function
local find_translation = function(opts)
  opts = opts or {}
  pickers
    .new(opts, {
      prompt_title = 'Translations',
      previewer = previewer,
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          P({ selection = selection })
          vim.api.nvim_put({ selection.value[2] }, '', false, true)
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
        results = values,
        entry_maker = function(entry)
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

-- to execute the function
find_translation()
