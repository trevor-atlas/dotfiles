" set leader key
let g:mapleader = "\<Space>"

set nocompatible
syntax enable                           " Enables syntax highlighing
set hidden                              " Required to keep multiple buffers open multiple buffers
set nowrap                              " Display long lines as just one line
set encoding=utf-8                      " The encoding displayed
set pumheight=10                        " Makes popup menu smaller set fileencoding=utf-8                  " The encoding written to file
set cmdheight=2                         " More space for displaying messages
set iskeyword+=-                        " treat dash separated words as a word text object"
set mouse=a                             " Enable your mouse
set splitbelow                          " Horizontal splits will automatically be below
set splitright                          " Vertical splits will automatically be to the right
set conceallevel=0                      " So that I can see `` in markdown files
set tabstop=2                           " Insert 2 spaces for a tab
set shiftwidth=2                        " Change the number of space characters inserted for indentation
set smarttab                            " Makes tabbing smarter will realize you have 2 vs 4
set expandtab                           " Converts tabs to spaces
set smartindent                         " Makes indenting smart
set autoindent                          " Good auto indent
set laststatus=2                        " Always display the status line
set number                              " Line numbers
set cursorline                          " Enable highlighting of the current line
set background=dark                     " tell vim what the background color looks like
set showtabline=2                       " Always show tabs
set noshowmode                          " We don't need to see things like -- INSERT -- anymore
set nobackup                            " This is recommended by coc
set nowritebackup                       " This is recommended by coc
set updatetime=300                      " Faster completion
set timeoutlen=500                      " By default timeoutlen is 1000 ms
set formatoptions-=cro                  " Stop newline continution of comments
set clipboard=unnamedplus               " Copy paste between vim and everything else
set autochdir                           " Your working directory will always be the same as your working directory
set history=1000                        " Store lots of :cmdline history
set showcmd                             " Show incomplete cmds down the bottom
set showmode                            " Show current mode down the bottom
set gcr=a:blinkon0                      " Disable cursor blink
set visualbell                          " No sounds
set autoread                            " Reload files changed outside vim
set linebreak                           " Wrap lines at convenient points
set scrolloff=5                         " Keep 5 lines below and above the cursor
set statusline=%f                       " tail of the filename
set statusline+=\ c:%c
set path+=**
if !has('gui_running')
  set t_Co=256
endif

" don't give |ins-completion-menu| messages.
set shortmess+=c

" show trailing whitespace
" set listchars=tab:·,trail:·
set listchars=tab:➝\ ,trail:~
set list
set number
set relativenumber
set formatoptions+=j

scriptencoding utf-8
autocmd BufReadPre,FileReadPre *.md :set wrap
autocmd FocusLost * silent! wa " Automatically save file
autocmd VimResized * wincmd = " Automatically resize splits when resizing window


" Better nav for omnicomplete
inoremap <expr> <c-j> ("\<C-n>")
inoremap <expr> <c-k> ("\<C-p>")

" Use alt + hjkl to resize windows
nnoremap <M-j>    :resize -2<CR>
nnoremap <M-k>    :resize +2<CR>
nnoremap <M-h>    :vertical resize -2<CR>
nnoremap <M-l>    :vertical resize +2<CR>

" Easy CAPS
inoremap <c-u> <ESC>viwUi
nnoremap <c-u> viwU<Esc>

" TAB in general mode will move to text buffer
nnoremap <TAB> :bnext<CR>
" SHIFT-TAB will go back
nnoremap <S-TAB> :bprevious<CR>

" Alternate way to save
nnoremap <C-s> :w<CR>
" Alternate way to quit
nnoremap <C-Q> :wq!<CR>
" Use control-c instead of escape
nnoremap <C-c> <Esc>
" <TAB>: completion.
inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"

" Better tabbing
vnoremap < <gv
vnoremap > >gv

" jump to line start with H and line end with L
nnoremap H ^
nnoremap L $
vnoremap H ^
vnoremap L $

nmap <Leader>s :write<Enter>
nmap <Leader>q :q<Enter>
nmap <Shift>Q :q<Enter>
nmap <Leader>r :redraw!<Enter>

" This makes vim act like all other editors, buffers can
" exist in the background without being in a window.
" http://items.sjbach.com/319/configuring-vim-right
set hidden

" Copy the relative path of the current file to the clipboard
nmap <Leader>cf :silent !echo -n % \| pbcopy<Enter>

map <Leader>j :bn<cr>
map <Leader>k :bp<cr>

" ================ Turn Off Swap Files ==============
set noswapfile
set nobackup
set nowb



" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

nnoremap <space>/ :Commentary<CR>
vnoremap <space>/ :Commentary<CR>

" remapping
nnoremap j gj
nnoremap k gk

" disable arrow keys, remap them to move between panes
noremap <Up> <NOP>
noremap <Down> <NOP>
noremap <Left> <NOP>
noremap <Right> <NOP>


" easy navigation between splits to save a keystroke. So instead of ctrl-w then j, it’s just ctrl-j
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Open new splits easily
map <leader><Bar> <C-W>v
map <leader>- <C-W>s
map Q <C-W>q

" make line joins more sane
" mark ugliness
match ErrorMsg '\%>120v.\+'
match ErrorMsg '\s\+$'

