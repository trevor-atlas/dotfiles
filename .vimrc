set nocompatible
set path+=**
set encoding=utf-8
scriptencoding utf-8
set history=1000                "Store lots of :cmdline history
set showcmd                     "Show incomplete cmds down the bottom
set showmode                    "Show current mode down the bottom
set gcr=a:blinkon0              "Disable cursor blink
set visualbell                  "No sounds
set autoread                    "Reload files changed outside vim
set nowrap       "Don't wrap lines
set linebreak    "Wrap lines at convenient points
autocmd BufReadPre,FileReadPre *.md :set wrap
autocmd FocusLost * silent! wa " Automatically save file
set scrolloff=5 " Keep 5 lines below and above the cursor
set cursorline
set laststatus=2
set statusline=%f "tail of the filename
set statusline+=\ c:%c
autocmd VimResized * wincmd = " Automatically resize splits when resizing window
set autochdir

let mapleader = "\<Space>"

"lazy js. Append ; at the end of the line
nnoremap <Leader>; m`A;<Esc>``

nnoremap H ^
nnoremap L $
nnoremap ; :

nmap <Leader>s :write<Enter>
nmap <Leader>r :redraw!<Enter>

" This makes vim act like all other editors, buffers can
" exist in the background without being in a window.
" http://items.sjbach.com/319/configuring-vim-right
set hidden



" Copy the relative path of the current file to the clipboard
nmap <Leader>cf :silent !echo -n % \| pbcopy<Enter>

" ================ Turn Off Swap Files ==============
set noswapfile
set nobackup
set nowb

" ================ Persistent Undo ==================
" Keep undo history across sessions, by storing in file.
" Only works all the time.
if has('persistent_undo')
  silent !mkdir ~/.vim/backups > /dev/null 2>&1
  set undodir=~/.vim/backups
  set undofile
endif

" grep word under cursor
nnoremap <Leader>g :grep! "\b<C-R><C-W>\b"<CR>:cw<CR><CR>

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
	Plug 'christoomey/vim-tmux-navigator'
	Plug 'editorconfig/editorconfig-vim'
	Plug 'kien/ctrlp.vim'
	Plug 'wincent/terminus'
	Plug 'Quramy/vim-js-pretty-template'
	Plug 'tpope/vim-scriptease'
	Plug 'tpope/vim-surround'
	Plug 'tpope/vim-unimpaired'
	Plug 'mhartington/oceanic-next'
	Plug 'othree/yajs'
	Plug 'easymotion/vim-easymotion'
	Plug 'scrooloose/nerdtree'
	Plug 'Xuyuanp/nerdtree-git-plugin'
	Plug 'jiangmiao/auto-pairs'
	Plug 'vim-scripts/CursorLineCurrentWindow'
	Plug 'w0rp/ale'
	Plug 'mattn/emmet-vim'
	Plug 'othree/yajs.vim'
	Plug 'fatih/vim-go'

	" autocompletion
	Plug 'HerringtonDarkholme/yats'
	Plug 'zchee/deoplete-go', { 'do': 'make'}
	Plug 'mhartington/nvim-typescript', { 'do': './install.sh' }
	if has('nvim')
		Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
	else
		Plug 'Shougo/deoplete.nvim'
		Plug 'roxma/nvim-yarp'
		Plug 'roxma/vim-hug-neovim-rpc'
	endif
call plug#end()

" set python version for vim/neovim
let g:python_host_prog = $HOME.'/.pyenv/versions/neovim2/bin/python'
let g:python3_host_prog = $HOME.'/.pyenv/versions/neovim3/bin/python3'

" Enable deoplete at startup
let g:deoplete#enable_at_startup = 1

" golang autocompletion
let g:deoplete#sources#go#gocode_binary = $GOPATH
let g:deoplete#sources#go#package_dot = 1

" Theme
 syntax enable
" for vim 7
 set t_Co=256

" For Neovim 0.1.3 and 0.1.4
let $NVIM_TUI_ENABLE_TRUE_COLOR=1

" Or if you have Neovim >= 0.1.5
if (has("termguicolors"))
	set termguicolors
endif

syntax on
set tabstop=4
set shiftwidth=4
let g:oceanic_next_terminal_bold = 1
let g:oceanic_next_terminal_italic = 1
colorscheme OceanicNext

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" ctrlp
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_show_hidden = 1
set wildignore+=*/.git/*,*/tmp/*,*.swp
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
  let g:ctrlp_use_caching = 0
endif

" autocomplete
" if !exists("g:ycm_semantic_triggers")
	" let g:ycm_semantic_triggers = {}
" endif
" let g:ycm_semantic_triggers['typescript'] = ['.']
imap <Tab> <C-P>

" NERD tree https://medium.com/@victormours/a-better-nerdtree-setup-3d3921abc0b9
" autocmd vimenter * NERDTree
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
map <C-e> :NERDTreeToggle<CR>
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
" Automatically close NerdTree when you open a file:
let NERDTreeQuitOnOpen = 1
" Automatically delete the buffer of the file you just deleted with NerdTree:
let NERDTreeAutoDeleteBuffer = 1
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

let g:better_whitespace_enabled = 0 " Dont' highlight whitespace in red
let g:strip_whitespace_on_save = 1

" remapping
nnoremap j gj
nnoremap k gk

" disable arrow keys, remap them to move between panes
noremap <up> <C-w><up>
noremap <down> <C-w><down>
noremap <left> <C-w><left>
noremap <right> <C-w><right>

set number
"set relativenumber

" easy navigation between splits to save a keystroke. So instead of ctrl-w then j, it’s just ctrl-j
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Open new splits easily
map vv <C-W>v
map ss <C-W>s
map Q <C-W>q

" Open new split panes to right and bottom, which feels more natural than Vim’s default
set splitbelow
set splitright


":augroup numbertoggle
":  autocmd!
":  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
":  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
":augroup END

" highlight current column
" set cursorcolumn

" show trailing whitespace
" set listchars=tab:·,trail:·
:set listchars=tab:➝\ ,trail:~
set list

" make line joins more sane
if v:version > 703 || v:version == 703 && has('patch541')
  set formatoptions+=j
endif

" mark ugliness
match ErrorMsg '\%>120v.\+'
match ErrorMsg '\s\+$'
