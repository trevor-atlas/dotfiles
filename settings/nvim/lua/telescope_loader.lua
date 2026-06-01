local M = {}

local telescope_loaded = false

function M.setup()
  if telescope_loaded then return end

  vim.pack.add({
    'https://github.com/nvim-telescope/telescope.nvim',
  })

  local telescope = require('telescope')
  local actions = require('telescope.actions')

  telescope.setup({
    defaults = {
      git_worktrees = vim.g.git_worktrees,
      path_display = { 'truncate' },
      sorting_strategy = 'ascending',
      vimgrep_arguments = {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
      },
      file_sorter = require('telescope.sorters').get_fuzzy_file,
      file_ignore_patterns = { 'node%_modules/.*' },
      generic_sorter = require('telescope.sorters').get_generic_fuzzy_sorter,
      winblend = 0,
      color_devicons = true,
      layout_config = {
        horizontal = { prompt_position = 'top', preview_width = 0.55 },
        vertical = { mirror = false },
        width = 0.87,
        height = 0.80,
        preview_cutoff = 120,
      },
      mappings = {
        i = {
          ['<esc>'] = actions.close,
          ['<C-n>'] = actions.cycle_history_next,
          ['<C-p>'] = actions.cycle_history_prev,
          ['<C-j>'] = actions.move_selection_next,
          ['<C-k>'] = actions.move_selection_previous,
        },
        n = {
          ['<esc>'] = actions.close,
          q = actions.close,
        },
      },
    },
  })

  telescope_loaded = true
end

function M.run(fn)
  M.setup()
  return fn(require('telescope.builtin'))
end

function M.builtin(name, opts)
  return function()
    return M.run(function(builtin)
      return builtin[name](opts or {})
    end)
  end
end

return M
