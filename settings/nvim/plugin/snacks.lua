local Snacks = require('snacks')
Snacks.setup({
  picker = {
    enabled = true,
    ui_select = true,
  },
  keys = {
    { '<leader>gi', function() Snacks.picker.gh_issue() end, desc = 'GitHub Issues (open)' },
    { '<leader>gI', function() Snacks.picker.gh_issue({ state = 'all' }) end, desc = 'GitHub Issues (all)' },
    { '<leader>pr', function() Snacks.picker.gh_pr() end, desc = 'GitHub Pull Requests (open)' },
    { '<leader>gP', function() Snacks.picker.gh_pr({ state = 'all' }) end, desc = 'GitHub Pull Requests (all)' },
  },
})
