local function map(mode, from, to, opts)
    opts = opts or { noremap = true, silent = true }
    vim.api.nvim_set_keymap(mode, from, to, opts)
end

-- ctrl-s to save
map('n', '<C-s>', ':w<CR>')

-- leader q to quit
map('n', '<Leader>q', ':q<CR>', { noremap = false, silent = true })
map('n', '<C-q>', ':q<CR>', { noremap = false, silent = true })

-- leader e to open file explorer
map('n', '<C-e>', ':NvimTreeToggle<CR>')

--Remap for dealing with word wrap
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { noremap = true, expr = true, silent = true })
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { noremap = true, expr = true, silent = true })

-- Better indent for selections (don't lose selection on indent/outdent)
map('v', '<', '<gv')
map('v', '>', '>gv')

-- jump to line start with H and line end with L
map('n', 'H', '^')
map('n', 'L', '$')
map('v', 'H', '^')
map('v', 'L', '$')

-- jump buffers with leader j-k
map('n', '<Leader>j', ':bn<cr>')
map('n', '<Leader>k', ':bp<cr>')

-- jump splits with ctrl
map('n', '<C-j>', '<C-W><C-J>')
map('n', '<C-k>', '<C-W><C-K>')
map('n', '<C-l>', '<C-W><C-L>')
map('n', '<C-h>', '<C-W><C-H>')

-- open splits with leader
map('n', '<Leader>-', '<C-W>s')
map('n', '<Leader><Bar>', '<C-W>v')

map('n', '<Leader>x', ':BufferClose<CR>')
map('n', '<C-w>', ':BufferClose<CR>')

-- clear highlights on escape in normal mode
map('n', '<esc>', ':noh<CR><esc>')
map('n', '<esc>^[', '<esc>^[')

-- reload config
map('n', '<Leader>rr', ':source $MYVIMRC<CR>')

-- comment lines
map('n', '<C-_>', ':Commentary<CR>')

vim.cmd [[
  nmap <Up> <Nop>
  nmap <Down> <Nop>
  nmap <Left> <Nop>
  nmap <Right> <Nop>
  map $ <Nop>
  map ^ <Nop>
  map { <Nop>
  map } <Nop>
  noremap K {
  noremap J }

  imap <Up>    <Nop>
  imap <Down>  <Nop>
  imap <Left>  <Nop>
  imap <Right> <Nop>
  inoremap <C-k> <Up>
  inoremap <C-j> <Down>
  inoremap <C-h> <Left>
  inoremap <C-l> <Right>

  nnoremap Y y$
]]

