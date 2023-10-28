local utils = require('utils')
local map = utils.map

-- https://github.com/famiu/bufdelete.nvim
-- buffer, split and window cheatsheet https://gist.github.com/Starefossen/5957088
map('n', '<C-x>', '<cmd>close<cr>', { desc = 'Close Buffer' })
map('n', '<C-w>', '<cmd>Bdelete<cr>', { desc = 'Close Buffer' })
map('n', '<C-t>', '<cmd>tabnew<cr>', { desc = 'Create Buffer' })

map('n', 'n', 'nzzzv', { desc = "centered 'next' when searching" })
map('n', 'N', 'Nzzzv', { desc = "centered 'prev' when searching" })

-- Remap for dealing with word wrap
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- reload config
map('n', '<Leader>rr', ':source $MYVIMRC<CR>')

-- clear highlights on escape in normal mode
map('n', '<esc>', ':noh<CR><esc>')
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

-- jump buffers with leader j-k
map('n', '<Leader>k', ':bn<cr>')
map('n', '<Leader>j', ':bp<cr>')

-- jump splits with ctrl
-- map('n', '<C-j>', '<C-W><C-J>')
-- map('n', '<C-k>', '<C-W><C-K>')
-- map('n', '<C-l>', '<C-W><C-L>')
-- map('n', '<C-h>', '<C-W><C-H>')

if vim.g.neovide then
  map('n', '<D-s>', ':w<CR>') -- Save
  map('v', '<D-c>', '"+y') -- Copy
  map('n', '<D-v>', '"+P') -- Paste normal mode
  map('v', '<D-v>', '"+P') -- Paste visual mode
  map('c', '<D-v>', '<C-R>+') -- Paste command mode
  map('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

map('n', '<leader>/', function() require('Comment.api').toggle.linewise.current() end, { desc = 'Comment line' })
map('v', '<leader>/', "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = 'Toggle comment line' })

-- QOL cursor movement for long lines
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move cursor down' })
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move cursor up' })

map('n', '<leader>pi', function() require('lazy').install() end, { desc = 'Plugins Install' })
map('n', '<leader>ps', function() require('lazy').home() end, { desc = 'Plugins Status' })
map('n', '<leader>pS', function() require('lazy').sync() end, { desc = 'Plugins Sync' })
map('n', '<leader>pu', function() require('lazy').check() end, { desc = 'Plugins Check Updates' })
map('n', '<leader>pU', function() require('lazy').update() end, { desc = 'Plugins Update' })

map('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle Explorer' })
map('n', '<leader>o', function()
  if vim.bo.filetype == 'neo-tree' then
    vim.cmd.wincmd('p')
  else
    vim.cmd.Neotree('focus')
  end
end, { desc = 'Toggle Explorer Focus' })

-- common keymaps for text editor stuff
map('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>confirm q<cr>', { desc = 'Quit' })
map('n', '<leader>n', '<cmd>enew<cr>', { desc = 'New File' })
map('n', '<C-s>', '<cmd>w!<cr>', { desc = 'Force write' })
map('n', '<C-q>', '<cmd>qa!<cr>', { desc = 'Force quit' })

-- Splits
map('n', '|', '<cmd>vsplit<cr>', { desc = 'Vertical Split' })
map('n', '_', '<cmd>split<cr>', { desc = 'Horizontal Split' })

map('n', '<C-h>', '<cmd>NavigatorLeft<cr>', { desc = 'jump to left split' })
map('n', '<C-l>', '<cmd>NavigatorRight<cr>', { desc = 'jump to right split' })
map('n', '<C-k>', '<cmd>NavigatorUp<cr>', { desc = 'jump to upper split' })
map('n', '<C-j>', '<cmd>NavigatorDown<cr>', { desc = 'jump to lower split' })
map('n', '<C-p>', '<cmd>NavigatorPrevious<cr>', { desc = 'jump to prev split' })

map('n', '<S-Up>', '<cmd>resize -2<cr>', { desc = 'Resize split up' })
map('n', '<S-Down>', '<cmd>resize +2<cr>', { desc = 'Resize split down' })
map('n', '<S-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Resize split left' })
map('n', '<S-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Resize split right' })

-- Diagnostic keymaps
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
map('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
map('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

map('n', '<leader>lx', '<cmd>Inspect<cr>', { desc = 'describe token under cursor' })

-- LSP keymaps
map('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', { noremap = true, silent = true })
map('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', { noremap = true, silent = true })
map('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', { noremap = true, silent = true })
map('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', { noremap = true, silent = true })
map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', { noremap = true, silent = true })
map('n', '<space>ga', '<cmd>lua vim.lsp.buf.code_action()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', 'gh', function() vim.diagnostic.open_float({ bufnr = 0 }) end, { remap = true, silent = true })
--map('n', '<space>gsd', '<cmd>lua vim.lsp.buf.show_line_diagnostics({ focusable = false })<CR>', { noremap = true, silent = true })
--
--vim.keymap.set('n', '<space>gsd', function() vim.lsp.buf.show_line_diagnostics({ focusable = false }) end, { noremap = true, silent = true })

local toggle_term_cmd = utils.toggle_term_cmd
map('n', '<C-\\>', '<cmd>ToggleTerm<cr>', { desc = 'Toggle terminal' })
map('n', '<leader>gg', function() toggle_term_cmd('lazygit') end, { desc = 'ToggleTerm lazygit' })
map('n', '<leader>tn', function() toggle_term_cmd('node') end, { desc = 'ToggleTerm node' })
map('n', '<leader>tu', function() toggle_term_cmd('ncdu') end, { desc = 'ToggleTerm NCDU' })
map('n', '<leader>tt', function() toggle_term_cmd('htop') end, { desc = 'ToggleTerm htop' })
map('n', '<leader>tp', function() toggle_term_cmd('python') end, { desc = 'ToggleTerm python' })
map('n', '<leader>tl', function() toggle_term_cmd('lazygit') end, { desc = 'ToggleTerm lazygit' })
map('n', '<leader>tf', '<cmd>ToggleTerm direction=float<cr>', { desc = 'ToggleTerm float' })
map('n', '<leader>th', '<cmd>ToggleTerm size=10 direction=horizontal<cr>', { desc = 'ToggleTerm horizontal split' })
map('n', '<leader>tv', '<cmd>ToggleTerm size=80 direction=vertical<cr>', { desc = 'ToggleTerm vertical split' })
