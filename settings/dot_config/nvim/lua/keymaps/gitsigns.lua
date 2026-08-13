local M = {}

function M.for_buffer(gs)
  return {
    { keys = '<leader>hp', action = gs.preview_hunk, desc = '[P]review hunk' },
    { keys = '<leader>lb', action = gs.toggle_current_line_blame, desc = '[B]lame line' },
    {
      keys = ']c',
      action = function()
        if vim.wo.diff then return ']c' end
        vim.schedule(gs.next_hunk)
        return '<Ignore>'
      end,
      expr = true,
      desc = 'Jump to next hunk',
      mode = { 'n', 'v' },
    },
    {
      keys = '[c',
      action = function()
        if vim.wo.diff then return '[c' end
        vim.schedule(gs.prev_hunk)
        return '<Ignore>'
      end,
      expr = true,
      desc = 'Jump to previous hunk',
      mode = { 'n', 'v' },
    },
  }
end

return M
