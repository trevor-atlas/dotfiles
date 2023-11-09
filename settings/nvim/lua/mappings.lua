local utils = require('utils')
-- https://github.com/famiu/bufdelete.nvim
-- buffer, split and window cheatsheet https://gist.github.com/Starefossen/5957088
vim.keymap.set('n', '<C-x>', '<cmd>close<cr>', { desc = 'Close Buffer' })
vim.keymap.set('n', '<C-w>', '<cmd>Bdelete<cr>', { desc = 'Close Buffer' })
vim.keymap.set('n', '<C-t>', '<cmd>tabnew<cr>', { desc = 'Create Buffer' })
vim.keymap.set('n', '<leader>pb', '<cmd>BufferLinePick<CR>', { desc = 'Jump to a specific buffer' })

vim.keymap.set('n', 'n', 'nzzzv', { desc = "centered 'next' when searching" })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = "centered 'prev' when searching" })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", {
  desc = 'Remap for dealing with word wrap',
  expr = true,
  silent = true,
})
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", {
  desc = 'Remap for dealing with word wrap',
  expr = true,
  silent = true,
})

vim.keymap.set('n', '<leader>gnt', function() P(utils.get_text_under_cursor()) end, { desc = 'get the text under the cursor' })

vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down one line' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up one line' })

vim.keymap.set('x', '<leader>p', '"_dP', { desc = 'paste over selection without losing paste buffer' })

vim.keymap.set('n', '<leader>d', '"_d', { desc = 'Delete without copying' })
vim.keymap.set('v', '<leader>d', '"_d', { desc = 'Delete without copying' })

vim.keymap.set('i', '<C-c>', '<Esc>', { desc = 'ctrl+c applies vertical edits' })

vim.keymap.set('n', 'Q', '<nop>', { desc = 'Q does nothing' })

-- Keep the cursor in the same position when wrapping lines with J
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Maintain cursor position when wrapping lines with J' })

-- source current buffer
vim.keymap.set('n', '<Leader>rr', '<cmd>so<CR>', { desc = 'source the current buffer' })

-- clear highlights on escape in normal mode
vim.keymap.set('n', '<esc>', ':noh<CR><esc>')
vim.keymap.set('n', '<esc>^[', '<esc>^[')

-- replace all occurences of word under cursor
vim.keymap.set('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = 'Find and replace word under cursor' })
vim.keymap.set('n', '<leader>rp', [[:%s/word/word/gI<Left><Left><Left>]], { desc = 'Find and replace' })

-- Stay in indent mode (don't lose selection on indent/outdent)
vim.keymap.set('v', '<S-Tab>', '<gv', { desc = 'Unindent line' })
vim.keymap.set('v', '<Tab>', '>gv', { desc = 'Indent line' })
vim.keymap.set('v', '<', '<gv', { desc = 'Unindent line' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent line' })

-- jump to line start with H and line end with L
vim.keymap.set('n', '<S-h>', '^', { desc = 'Jump to start of line' })
vim.keymap.set('n', '<S-l>', '$', { desc = 'Jump to end of line' })
vim.keymap.set('v', '<S-h>', '_', { desc = 'Jump to start of line' })
vim.keymap.set('v', '<S-l>', 'g_', { desc = 'Jump to end of line' })

-- jump buffers with leader j-k
vim.keymap.set('n', '<Leader>k', ':bn<cr>')
vim.keymap.set('n', '<Leader>j', ':bp<cr>')

if vim.g.neovide then
  vim.keymap.set('n', '<D-s>', ':w<CR>') -- Save
  vim.keymap.set('v', '<D-c>', '"+y') -- Copy
  vim.keymap.set('n', '<D-v>', '"+P') -- Paste normal mode
  vim.keymap.set('v', '<D-v>', '"+P') -- Paste visual mode
  vim.keymap.set('c', '<D-v>', '<C-R>+') -- Paste command mode
  vim.keymap.set('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

vim.keymap.set('n', '<leader>/', function() require('Comment.api').toggle.linewise.current() end, { desc = 'Comment line' })
vim.keymap.set('v', '<leader>/', "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = 'Toggle comment line' })

-- QOL cursor movement for long lines
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move cursor down' })
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move cursor up' })

vim.keymap.set('n', '<leader>pi', function() require('lazy').install() end, { desc = 'Plugins Install' })
vim.keymap.set('n', '<leader>ps', function() require('lazy').home() end, { desc = 'Plugins Status' })
vim.keymap.set('n', '<leader>pS', function() require('lazy').sync() end, { desc = 'Plugins Sync' })
vim.keymap.set('n', '<leader>pu', function() require('lazy').check() end, { desc = 'Plugins Check Updates' })
vim.keymap.set('n', '<leader>pU', function() require('lazy').update() end, { desc = 'Plugins Update' })

vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle Explorer' })
vim.keymap.set('n', '<leader>o', function()
  if vim.bo.filetype == 'neo-tree' then
    vim.cmd.wincmd('p')
  else
    vim.cmd.Neotree('focus')
  end
end, { desc = 'Toggle Explorer Focus' })

-- common keymaps for text editor stuff
-- vim.keymap.set('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save' })
-- vim.keymap.set('n', '<leader>q', '<cmd>confirm q<cr>', { desc = 'Quit' })
-- vim.keymap.set('n', '<leader>n', '<cmd>enew<cr>', { desc = 'New File' })
vim.keymap.set('n', '<C-s>', '<cmd>w!<cr>', { desc = 'Force write' })
vim.keymap.set('i', '<C-s>', '<cmd>w!<cr>', { desc = 'Force write' })
vim.keymap.set('n', '<C-q>', '<cmd>qa!<cr>', { desc = 'Force quit' })

-- Splits
vim.keymap.set('n', '|', '<cmd>vsplit<cr>', { desc = 'Vertical Split' })
vim.keymap.set('n', '_', '<cmd>split<cr>', { desc = 'Horizontal Split' })

vim.keymap.set('n', '<C-h>', '<cmd>NavigatorLeft<cr>', { desc = 'jump to left split' })
vim.keymap.set('n', '<C-l>', '<cmd>NavigatorRight<cr>', { desc = 'jump to right split' })
vim.keymap.set('n', '<C-k>', '<cmd>NavigatorUp<cr>', { desc = 'jump to upper split' })
vim.keymap.set('n', '<C-j>', '<cmd>NavigatorDown<cr>', { desc = 'jump to lower split' })
-- vim.keymap.set('n', '<C-p>', '<cmd>NavigatorPrevious<cr>', { desc = 'jump to prev split' })

vim.keymap.set('n', '<S-Up>', '<cmd>resize -2<cr>', { desc = 'Resize split up' })
vim.keymap.set('n', '<S-Down>', '<cmd>resize +2<cr>', { desc = 'Resize split down' })
vim.keymap.set('n', '<S-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Resize split left' })
vim.keymap.set('n', '<S-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Resize split right' })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

vim.keymap.set('n', '<leader>lx', '<cmd>Inspect<cr>', { desc = 'describe token under cursor' })

-- LSP keymaps
vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<space>ga', '<cmd>lua vim.lsp.buf.code_action()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'gh', function() vim.diagnostic.open_float({ bufnr = 0 }) end, { remap = true, silent = true })

local user_terminals = {}
local function toggle_term_cmd(term_details)
  -- if a command string is provided, create a basic table for Terminal:new() options
  if type(term_details) == 'string' then term_details = { cmd = term_details, hidden = true } end
  -- use the command as the key for the table
  local term_key = term_details.cmd
  -- set the count in the term details
  if vim.v.count > 0 and term_details.count == nil then
    term_details.count = vim.v.count
    term_key = term_key .. vim.v.count
  end
  -- if terminal doesn't exist yet, create it
  if user_terminals[term_key] == nil then user_terminals[term_key] = require('toggleterm.terminal').Terminal:new(term_details) end
  -- toggle the terminal
  user_terminals[term_key]:toggle()
end

vim.keymap.set('n', '<C-\\>', '<cmd>ToggleTerm<cr>', { desc = 'Toggle terminal' })
vim.keymap.set('n', '<leader>gg', function() toggle_term_cmd('lazygit') end, { desc = 'ToggleTerm lazygit' })
vim.keymap.set('n', '<leader>tn', function() toggle_term_cmd('node') end, { desc = 'ToggleTerm node' })
vim.keymap.set('n', '<leader>tu', function() toggle_term_cmd('ncdu') end, { desc = 'ToggleTerm NCDU' })
vim.keymap.set('n', '<leader>tt', function() toggle_term_cmd('htop') end, { desc = 'ToggleTerm htop' })
vim.keymap.set('n', '<leader>tp', function() toggle_term_cmd('python') end, { desc = 'ToggleTerm python' })
vim.keymap.set('n', '<leader>tl', function() toggle_term_cmd('lazygit') end, { desc = 'ToggleTerm lazygit' })
vim.keymap.set('n', '<leader>tf', '<cmd>ToggleTerm direction=float<cr>', { desc = 'ToggleTerm float' })
vim.keymap.set('n', '<leader>th', '<cmd>ToggleTerm size=10 direction=horizontal<cr>', { desc = 'ToggleTerm horizontal split' })
vim.keymap.set('n', '<leader>tv', '<cmd>ToggleTerm size=80 direction=vertical<cr>', { desc = 'ToggleTerm vertical split' })

local function trim(s)
  if not s then return 'print("invalid string")' end
  s = s:gsub('[\n\r]', '')
  s = s:gsub('^%s*(.-)%s*$', '%1')
  return s
end

local function get_visual_selection()
  -- Get the start and end position of the visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Calculate the start and end line numbers
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Calculate the start and end column numbers
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  -- If the end column is the max value, use the end of the line
  if end_col == 2147483647 then end_col = nil end

  -- Get the text from the buffer
  local lines = vim.api.nvim_buf_get_text(0, start_line - 1, start_col, end_line, end_col, {})
  P(lines)

  -- Handle single-line selection
  if start_line == end_line then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    if end_col then lines[#lines] = string.sub(lines[#lines], 1, end_col) end
  end

  -- Join the lines to get the selected text
  return table.concat(lines, '\n')
end

local function region_to_text()
  -- Get the start and end position of the visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Calculate the start and end line numbers
  local start_row = start_pos[2]
  local end_row = end_pos[2]

  -- Calculate the start and end column numbers
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  -- Adjust the end column to include the last character in the selection
  if end_col == 2147483647 then
    end_col = start_col
  else
    end_col = end_col + 1
  end

  P({ start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col })

  -- or use api.nvim_buf_get_lines
  local lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
  local text = ''
  for _, line in pairs(lines) do
    text = text .. line
  end
  text = trim(text)
  -- local text = trim(lines)
  return text
end

vim.keymap.set('v', '<leader>ev', function()
  -- local text = region_to_text()
  P(get_visual_selection())
  -- P(vim.api.nvim_exec2('lua ' .. text, { output = true }))
end, { desc = 'Run selected lua code and print the result' })

vim.keymap.set('n', '<leader>lf', '<cmd>luafile %<CR>', { desc = 'interpret current file as lua' })
