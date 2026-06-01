local telescope = require('telescope_loader')

vim.keymap.set('n', '<leader>?', telescope.builtin('oldfiles'), { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', telescope.builtin('buffers'), { desc = '[ ] Find existing buffers' })

vim.keymap.set('n', '<leader>gs', telescope.builtin('git_status'), { desc = 'Git status' })
vim.keymap.set('n', '<leader>gb', telescope.builtin('git_branches'), { desc = 'Git branches' })
vim.keymap.set('n', '<leader>gc', telescope.builtin('git_commits'), { desc = 'Git commits' })

vim.keymap.set('n', '<leader>sm', telescope.builtin('man_pages'), { desc = 'Search man' })

vim.keymap.set('n', '<leader>gf', telescope.builtin('git_files'), { desc = 'Search [G]it [F]iles' })
vim.keymap.set('n', '<leader>sf', telescope.builtin('live_grep'), { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ff', telescope.builtin('find_files'), { desc = '[F]ind [F]iles' })
vim.keymap.set('n', '<leader>sh', telescope.builtin('help_tags'), { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', telescope.builtin('grep_string'), { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', telescope.builtin('live_grep'), { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', telescope.builtin('diagnostics'), { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', telescope.builtin('resume'), { desc = '[S]earch [R]resume' })
vim.keymap.set('n', '<C-p>', telescope.builtin('find_files'), { desc = 'Find files' })
vim.keymap.set('n', '<leader>st', function()
  telescope.setup()
  require('picker').open()
end, { desc = 'pick translations' })
