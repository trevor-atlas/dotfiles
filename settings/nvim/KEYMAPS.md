# Neovim leader keymaps

Leader is `<Space>`.

## Find / search

- `<leader><space>` buffers
- `<leader>?` recent files
- `<leader>ff` find files
- `<leader>gf` git files
- `<leader>sf` search files
- `<leader>sg` live grep
- `<leader>sw` grep word under cursor
- `<leader>sd` search diagnostics
- `<leader>sh` help tags
- `<leader>sm` man pages
- `<leader>sr` resume picker

## Explorer / buffers / editing

- `<leader>e` toggle explorer
- `<leader>o` focus explorer
- `<leader>pb` pick buffer
- `<leader>j` previous buffer
- `<leader>k` next buffer
- `<leader>d` delete without copying
- `<leader>p` paste over selection without clobbering paste buffer (visual)
- `<leader>/` toggle comment
- `<leader>s` replace word under cursor
- `<leader>rp` replace template
- `<leader>rr` source current file
- `<leader>lf` run current file as Lua
- `<leader>ev` run selected Lua (visual)
- `<leader>lx` inspect token under cursor

## Diagnostics

- `<leader>dd` floating diagnostic
- `<leader>dl` diagnostics location list
- `<leader>xx` Trouble diagnostics pane

## Git

- `<leader>gs` git status
- `<leader>gb` git branches
- `<leader>gc` git commits
- `<leader>gg` LazyGit
- `<leader>hp` preview hunk
- `<leader>lb` toggle current line blame

## Terminals

- `<leader>tt` toggle default terminal
- `<leader>tf` toggle floating terminal
- `<leader>th` toggle horizontal terminal
- `<leader>tv` toggle vertical terminal
- `<leader>ht` HTOP
- `<leader>cc` Claude Code

### Inside toggleterm

- `<C-\>` close terminal window but keep terminal process/buffer alive
- `<C-h/j/k/l>` move between windows
- native Neovim terminal escape: `<C-\><C-n>`

## Sessions

- `<leader>ws` save session for current cwd
- `<leader>wr` restore session for current cwd

## LSP (buffer-local)

- `<leader>rn` rename
- `<leader>ca` code action
- `<leader>D` type definition
- `<leader>ds` document symbols
- `<leader>ws` workspace symbols
- `<leader>wl` list workspace folders

## Metals (buffer-local, Scala/Java)

- `<leader>mg` install Mill BSP config
- `<leader>mc` connect build
- `<leader>mi` import build
- `<leader>mo` organize imports
- `<leader>mb` restart build server
- `<leader>md` run doctor
- `<leader>mr` restart Metals
- `<leader>mR` clean Mill cache and restart
