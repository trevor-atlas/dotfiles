local M = {}

local telescope_loaded = false

function M.setup()
  if telescope_loaded then return end

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

function M.diagnostics(opts)
  opts = opts or {}
  M.setup()

  local bufnr = opts.bufnr
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  if vim.tbl_isempty(vim.diagnostic.get(bufnr)) then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    pickers
      .new(opts, {
        prompt_title = bufnr == nil and 'Workspace Diagnostics' or 'Document Diagnostics',
        finder = finders.new_table({ results = {} }),
        previewer = false,
        sorter = conf.generic_sorter(opts),
      })
      :find()

    return
  end

  return M.run(function(builtin)
    return builtin.diagnostics(opts)
  end)
end

return M
