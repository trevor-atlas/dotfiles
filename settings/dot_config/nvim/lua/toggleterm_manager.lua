local Terminal = require('toggleterm.terminal').Terminal

local M = {}
local terminals = {}

local function get_terminal(key, spec)
  if terminals[key] == nil then
    terminals[key] = Terminal:new(vim.tbl_extend('force', {
      hidden = true,
      close_on_exit = false,
    }, spec or {}))
  end

  return terminals[key]
end

function M.toggle(key, spec)
  get_terminal(key, spec):toggle()
end

return M
