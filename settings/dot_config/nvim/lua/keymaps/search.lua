local telescope = require('loaders.telescope')

return {
  { keys = '<leader>?', action = telescope.builtin('oldfiles'), desc = '[?] Find recently opened files' },
  { keys = '<leader><space>', action = telescope.builtin('buffers'), desc = '[ ] Find existing buffers' },
  { keys = '<leader>gs', action = telescope.builtin('git_status'), desc = '[S]tatus' },
  { keys = '<leader>gb', action = telescope.builtin('git_branches'), desc = '[B]ranches' },
  { keys = '<leader>gc', action = telescope.builtin('git_commits'), desc = '[C]ommits' },
  { keys = '<leader>sm', action = telescope.builtin('man_pages'), desc = '[M]an pages' },
  { keys = '<leader>gf', action = telescope.builtin('git_files'), desc = 'Search [G]it [F]iles' },
  { keys = '<leader>sf', action = telescope.builtin('live_grep'), desc = '[S]earch [F]iles' },
  { keys = '<leader>ff', action = telescope.builtin('find_files'), desc = '[F]ind [F]iles' },
  { keys = '<leader>sh', action = telescope.builtin('help_tags'), desc = '[S]earch [H]elp' },
  { keys = '<leader>sw', action = telescope.builtin('grep_string'), desc = '[S]earch current [W]ord' },
  { keys = '<leader>sg', action = telescope.builtin('live_grep'), desc = '[S]earch by [G]rep' },
  { keys = '<leader>sd', action = function() telescope.diagnostics() end, desc = '[S]earch [D]iagnostics' },
  { keys = '<leader>sr', action = telescope.builtin('resume'), desc = '[S]earch [R]resume' },
  { keys = '<C-p>', action = telescope.builtin('find_files'), desc = 'Find files' },
}
