require('toggleterm').setup({
  highlights = {
    Normal = { link = 'Normal' },
    NormalNC = { link = 'NormalNC' },
    NormalFloat = { link = 'NormalFloat' },
    FloatBorder = { link = 'FloatBorder' },
    StatusLine = { link = 'StatusLine' },
    StatusLineNC = { link = 'StatusLineNC' },
    WinBar = { link = 'WinBar' },
    WinBarNC = { link = 'WinBarNC' },
  },
  size = function(term)
    if term.direction == 'horizontal' then return 10 end
    if term.direction == 'vertical' then return math.floor(vim.o.columns * 0.4) end
    return 10
  end,
  on_create = function()
    vim.opt_local.foldcolumn = '0'
    vim.opt_local.signcolumn = 'no'
  end,
  on_open = function()
    vim.cmd('startinsert!')
  end,
  open_mapping = nil,
  insert_mappings = false,
  terminal_mappings = false,
  shading_factor = 2,
  direction = 'float',
  float_opts = {
    border = 'curved',
    highlights = {
      border = 'Normal',
      background = 'Normal',
    },
  },
})

local group = vim.api.nvim_create_augroup('ToggleTermKeymaps', { clear = true })

local function is_lazygit_term(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == 'terminal'
    and vim.api.nvim_buf_get_name(buf):match('term://.*lazygit') ~= nil
end

local function ensure_lazygit_terminal_mode(buf)
  vim.schedule(function()
    if not is_lazygit_term(buf) then return end
    if vim.api.nvim_get_current_buf() ~= buf then return end
    if vim.api.nvim_get_mode().mode == 't' then return end
    vim.cmd('startinsert!')
  end)
end

vim.api.nvim_create_autocmd('TermOpen', {
  group = group,
  pattern = 'term://*toggleterm#*',
  callback = function(args)
    local opts = { buffer = args.buf, silent = true }
    vim.keymap.set('t', '<C-\\>', [[<Cmd>wincmd c<CR>]], opts)
    vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
    vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
    vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
    vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)

    if is_lazygit_term(args.buf) then ensure_lazygit_terminal_mode(args.buf) end
  end,
})

vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
  group = group,
  pattern = 'term://*lazygit*',
  callback = function(args)
    ensure_lazygit_terminal_mode(args.buf)
  end,
})

vim.api.nvim_create_autocmd('ModeChanged', {
  group = group,
  pattern = 't:*',
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if is_lazygit_term(buf) then ensure_lazygit_terminal_mode(buf) end
  end,
})
