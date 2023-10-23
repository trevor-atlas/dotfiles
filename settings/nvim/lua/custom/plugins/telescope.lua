local map = require('utils').map

return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', enabled = vim.fn.executable('make') == 1, build = 'make' },
  },
  cmd = 'Telescope',
  init = function()
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
        path_display = { 'truncate' },

        -- border = false
        winblend = 0,
        color_devicons = true,
        -- border="rounded"
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

    telescope.load_extension('fzf')

    -- Telescope
    local builtin = require('telescope.builtin')

    -- See `:help telescope.builtin`
    map('n', '<leader>?', builtin.oldfiles, { desc = '[?] Find recently opened files' })
    map('n', '<leader><space>', builtin.buffers, { desc = '[ ] Find existing buffers' })
    map('n', '<leader>/', function()
      -- You can pass additional configuration to telescope to change theme, layout, etc.
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
        winblend = 10,
        previewer = false,
      }))
    end, { desc = '[/] Fuzzily search in current buffer' })

    map('n', '<leader>gf', builtin.git_files, { desc = 'Search [G]it [F]iles' })
    map('n', '<leader>sf', builtin.live_grep, { desc = '[S]earch [F]iles' })
    map('n', '<leader>ff', builtin.find_files, { desc = '[F]ind [F]iles' })
    map('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    map('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    map('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    map('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    map('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]resume' })
  end,
}
