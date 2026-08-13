local M = {}

local winids = {}

local function compact()
  local valid = {}
  for _, winid in ipairs(winids) do
    if vim.api.nvim_win_is_valid(winid) then
      table.insert(valid, winid)
    end
  end
  winids = valid
end

function M.open(opts)
  compact()
  local _, winid = vim.diagnostic.open_float(opts)
  if winid and vim.api.nvim_win_is_valid(winid) then
    table.insert(winids, winid)
  end
  return winid
end

function M.close_all()
  compact()
  for _, winid in ipairs(winids) do
    pcall(vim.api.nvim_win_close, winid, true)
  end
  winids = {}
end

return M
