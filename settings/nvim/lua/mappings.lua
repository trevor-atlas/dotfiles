local diagnostic_floats = require('diagnostic_floats')
local map = vim.keymap.set
-- buffer, split and window cheatsheet https://gist.github.com/Starefossen/5957088
map('n', '<C-x>', '<cmd>close<cr>', { desc = 'Close Buffer' })
map('n', '<C-w>', function() MiniBufremove.delete(0, false) end, { desc = 'Close Buffer' })
map('n', '<C-t>', '<cmd>tabnew<cr>', { desc = 'Create Buffer' })

map('n', 'n', 'nzzzv', { desc = "centered 'next' when searching" })
map('n', 'N', 'Nzzzv', { desc = "centered 'prev' when searching" })

map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down one line' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up one line' })

map('i', '<C-c>', '<Esc>', { desc = 'ctrl+c applies vertical edits' })

map('n', 'Q', '<nop>', { desc = 'Q does nothing' })

-- Keep the cursor in the same position when wrapping lines with J
map('n', 'J', 'mzJ`z', { desc = 'Maintain cursor position when wrapping lines with J' })

-- clear highlights on escape in normal mode
map('n', '<esc>', function()
  diagnostic_floats.close_all()
  vim.cmd('noh')
end, { desc = 'Clear highlights and close diagnostic floats' })
map('n', '<esc>^[', '<esc>^[')

-- Stay in indent mode (don't lose selection on indent/outdent)
map('v', '<S-Tab>', '<gv', { desc = 'Unindent line' })
map('v', '<Tab>', '>gv', { desc = 'Indent line' })
map('v', '<', '<gv', { desc = 'Unindent line' })
map('v', '>', '>gv', { desc = 'Indent line' })

-- jump to line start with H and line end with L
map('n', '<S-h>', '^', { desc = 'Jump to start of line' })
map('n', '<S-l>', '$', { desc = 'Jump to end of line' })
map('v', '<S-h>', '_', { desc = 'Jump to start of line' })
map('v', '<S-l>', 'g_', { desc = 'Jump to end of line' })

if vim.g.neovide then
  map('n', '<D-s>', ':w<CR>') -- Save
  map('v', '<D-c>', '"+y') -- Copy
  map('n', '<D-v>', '"+P') -- Paste normal mode
  map('v', '<D-v>', '"+P') -- Paste visual mode
  map('c', '<D-v>', '<C-R>+') -- Paste command mode
  map('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

-- QOL cursor movement for long lines
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move cursor down' })
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move cursor up' })

-- common keymaps for text editor stuff
map('n', '<C-s>', '<cmd>w!<cr>', { desc = 'Force write' })
map('i', '<C-s>', '<cmd>w!<cr>', { desc = 'Force write' })
map('n', '<C-q>', '<cmd>qa!<cr>', { desc = 'Force quit' })

-- Splits
map('n', '|', '<cmd>vsplit<cr>', { desc = 'Vertical Split' })
map('n', '_', '<cmd>split<cr>', { desc = 'Horizontal Split' })

map('n', '<C-h>', '<cmd>NavigatorLeft<cr>', { desc = 'jump to left split' })
map('n', '<C-l>', '<cmd>NavigatorRight<cr>', { desc = 'jump to right split' })
map('n', '<C-k>', '<cmd>NavigatorUp<cr>', { desc = 'jump to upper split' })
map('n', '<C-j>', '<cmd>NavigatorDown<cr>', { desc = 'jump to lower split' })

map('n', '<S-Up>', '<cmd>resize -2<cr>', { desc = 'Resize split up' })
map('n', '<S-Down>', '<cmd>resize +2<cr>', { desc = 'Resize split down' })
map('n', '<S-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Resize split left' })
map('n', '<S-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Resize split right' })

-- Diagnostic keymaps
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
map('n', 'gh', function() diagnostic_floats.open({ bufnr = 0 }) end, { remap = true, silent = true })
