local colors = {
  blue = '#80a0ff',
  cyan = '#79dac8',
  black = '#080808',
  white = '#c6c6c6',
  red = '#ff5189',
  violet = '#d183e8',
  grey = '#303030',
}

local theme = {
  normal = {
    a = { fg = colors.black, bg = colors.violet },
    b = { fg = colors.white, bg = colors.grey },
    c = { fg = colors.black, bg = colors.black },
  },
  insert = { a = { fg = colors.black, bg = colors.blue } },
  visual = { a = { fg = colors.black, bg = colors.cyan } },
  replace = { a = { fg = colors.black, bg = colors.red } },
  inactive = {
    a = { fg = colors.white, bg = colors.black },
    b = { fg = colors.white, bg = colors.black },
    c = { fg = colors.black, bg = colors.black },
  },
}

local function metals_status()
  local status = vim.g.metals_status
  if type(status) ~= 'string' or status == '' then return '' end
  return status
end

local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local lsp_startup_window_ms = 5000

local function spinner()
  local frame = math.floor(vim.uv.now() / 120) % #spinner_frames + 1
  return spinner_frames[frame]
end

local function current_buffer_pending_requests(bufnr)
  local pending = 0

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    for _, request in pairs(client.requests or {}) do
      if request.type == 'pending' and request.bufnr == bufnr then pending = pending + 1 end
    end
  end

  return pending
end

local function lsp_status()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then return '' end

  local status = vim.lsp.status()
  if type(status) == 'string' and status ~= '' then return ' ' .. status end

  if current_buffer_pending_requests(bufnr) > 0 then return spinner() .. ' LSP' end

  local attached_at = vim.b[bufnr].lsp_attached_at
  if type(attached_at) == 'number' and vim.uv.now() - attached_at < lsp_startup_window_ms then return spinner() .. ' LSP' end

  return ''
end

vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach', 'LspProgress', 'LspRequest' }, {
  callback = function(args)
    if args.event == 'LspAttach' and args.buf and vim.api.nvim_buf_is_valid(args.buf) then vim.b[args.buf].lsp_attached_at = vim.uv.now() end

    vim.cmd.redrawstatus()
  end,
})

require('lualine').setup({
  theme,
  component_separators = '|',
  section_separators = { left = '', right = '' },
  sections = {
    lualine_a = {
      { 'mode', separator = { left = '' }, right_padding = 2 },
    },
    lualine_b = { 'filename', 'branch' },
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {
      { lsp_status, metals_status, separator = { right = '' }, left_padding = 2 },
    },
  },
  inactive_sections = {
    lualine_a = { 'filename' },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = { 'location' },
  },
  tabline = {},
  extensions = {},
})
