local toggleterm_manager = require('toggleterm_manager')

return {
  {
    keys = '<leader>tt',
    action = function()
      toggleterm_manager.toggle('shell_float', { count = 1, direction = 'float', display_name = 'Terminal' })
    end,
    desc = '[T]erminal',
  },
  {
    keys = '<leader>tf',
    action = function()
      toggleterm_manager.toggle('shell_float', { count = 1, direction = 'float', display_name = 'Terminal' })
    end,
    desc = '[F]loating terminal',
  },
  {
    keys = '<leader>th',
    action = function()
      toggleterm_manager.toggle('shell_horizontal', { count = 2, direction = 'horizontal', display_name = 'Terminal (horizontal)' })
    end,
    desc = '[H]orizontal terminal',
  },
  {
    keys = '<leader>tv',
    action = function()
      toggleterm_manager.toggle('shell_vertical', { count = 3, direction = 'vertical', display_name = 'Terminal (vertical)' })
    end,
    desc = '[V]ertical terminal',
  },
  {
    keys = '<leader>gg',
    action = function()
      toggleterm_manager.toggle('lazygit', { cmd = 'lazygit', count = 4, direction = 'float', display_name = 'LazyGit' })
    end,
    desc = 'Lazy[G]it',
  },
  {
    keys = '<leader>ht',
    action = function()
      toggleterm_manager.toggle('htop', { cmd = 'htop', count = 5, direction = 'float', display_name = 'HTOP' })
    end,
    desc = '[H]TOP',
  },
  {
    keys = '<leader>cc',
    action = function()
      toggleterm_manager.toggle('claude', { cmd = 'claude', count = 6, direction = 'float', display_name = 'Claude Code' })
    end,
    desc = '[C]laude [C]ode',
  },
}
