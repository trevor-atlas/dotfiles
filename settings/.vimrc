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


cmap w!! w !sudo tee %                  " You can't stop me
au! BufWritePost $MYVIMRC source %      " auto source when writing to init.vm alternatively you can run :source $MYVIMRC

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


" Source depending on if VSCode is our client
if exists('g:vscode')
    " VSCode extension
    source $HOME/.config/nvim/vscode/windows.vim
else
    " ordinary neovim

	nnoremap <silent> <C-j> :call VSCodeNotify('workbench.action.focusBelowGroup')<CR>
	xnoremap <silent> <C-j> :call VSCodeNotify('workbench.action.focusBelowGroup')<CR>
	nnoremap <silent> <C-k> :call VSCodeNotify('workbench.action.focusAboveGroup')<CR>
	xnoremap <silent> <C-k> :call VSCodeNotify('workbench.action.focusAboveGroup')<CR>
	nnoremap <silent> <C-h> :call VSCodeNotify('workbench.action.focusLeftGroup')<CR>
	xnoremap <silent> <C-h> :call VSCodeNotify('workbench.action.focusLeftGroup')<CR>
	nnoremap <silent> <C-l> :call VSCodeNotify('workbench.action.focusRightGroup')<CR>

	xnoremap <silent> <C-l> :call VSCodeNotify('workbench.action.focusRightGroup')<CR>
endif

" ================ Persistent Undo ==================
" Keep undo history across sessions, by storing in file.
" Only works all the time.
if has('persistent_undo')
  silent !mkdir ~/.config/nvim/backups > /dev/null 2>&1
  set undodir=~/.config/nvim/backups
  set undofile
endif

" auto-install vim-plug
if empty(glob('~/.config/nvim/autoload/plug.vim'))
  silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  "autocmd VimEnter * PlugInstall
  autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.config/nvim/autoload/plugged')
	if !exists('g:vscode')
		Plug 'christoomey/vim-tmux-navigator'
		Plug 'itchyny/lightline.vim'
		" Better Syntax Support
		Plug 'sheerun/vim-polyglot'
		" Auto pairs for '(' '[' '{'
		Plug 'jiangmiao/auto-pairs'
		" Themes
		Plug 'christianchiarulli/onedark.vim'
		" Intellisense
		Plug 'neoclide/coc.nvim', {'branch': 'release'}
		" FZF
		Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
		Plug 'junegunn/fzf.vim'
		Plug 'airblade/vim-rooter'
		" Better Comments
		Plug 'tpope/vim-commentary'
		" Add some color
		Plug 'norcalli/nvim-colorizer.lua'
		Plug 'junegunn/rainbow_parentheses.vim'
		" Git
		Plug 'airblade/vim-gitgutter'
		" Terminal
		Plug 'voldikss/vim-floaterm'
		" Start Screen
		Plug 'mhinz/vim-startify'
		" Surround
		Plug 'tpope/vim-surround'
		" Vista
		Plug 'liuchengxu/vista.vim'
		"
	endif
call plug#end()

" Automatically install missing plugins on startup
autocmd VimEnter *
  \  if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \|   PlugInstall --sync | q
  \| endif


" Trigger a highlight in the appropriate direction when pressing these keys:
let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']

autocmd FileType * RainbowParentheses
let g:rainbow#max_level = 16
let g:rainbow#pairs = [['(', ')'], ['[', ']'], ['{', '}']]

let g:lightline = {
      \ 'colorscheme': 'one',
      \ }

" Theme
syntax on

" onedark.vim override: Don't set a background color when running in a terminal;
if (has("autocmd") && !has("gui_running"))
  augroup colorset
    autocmd!
    let s:white = { "gui": "#ABB2BF", "cterm": "145", "cterm16" : "7" }
    autocmd ColorScheme * call onedark#set_highlight("Normal", { "fg": s:white }) " `bg` will not be styled since there is no `bg` setting
  augroup END
endif

"autocmd ColorScheme * call onedark#set_highlight("Normal", { "fg": s:white }) " `bg` will not be styled since there is no `bg` setting

hi Comment cterm=italic
let g:onedark_hide_endofbuffer=1
let g:onedark_terminal_italics=1
let g:onedark_termcolors=256

colorscheme onedark


" checks if your terminal has 24-bit color support
if (has("termguicolors"))
    set termguicolors
    hi LineNr ctermbg=NONE guibg=NONE
endif
set tabstop=4
set shiftwidth=4

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

nnoremap <space>/ :Commentary<CR>
vnoremap <space>/ :Commentary<CR>

" fzf
" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

map <C-p> :Files<CR>
map <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>
nnoremap <leader>t :Tags<CR>
nnoremap <leader>m :Marks<CR>

" ctrl-g search in file content
nnoremap <C-g> :RG<Cr>

nnoremap <silent> <leader>gl :Commits<CR>
nnoremap <silent> <leader>ga :BCommits<CR>
nnoremap <silent> <leader>ft :Filetypes<CR>


let g:fzf_tags_command = 'ctags -R'
" Border color
let g:fzf_layout = {'up':'~90%', 'window': { 'width': 0.8, 'height': 0.8,'yoffset':0.5,'xoffset': 0.5, 'highlight': 'Todo', 'border': 'sharp' } }

let $FZF_DEFAULT_OPTS = '--layout=reverse --info=inline'
let $FZF_DEFAULT_COMMAND="rg --files --hidden"


" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

"Get Files
command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, fzf#vim#with_preview({'options': ['--layout=reverse', '--info=inline']}), <bang>0)


" Get text in files with Rg
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview(), <bang>0)

" Ripgrep advanced
function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang RG call RipgrepFzf(<q-args>, <bang>0)

" Git grep
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number '.shellescape(<q-args>), 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)

let g:better_whitespace_enabled = 0 " Dont' highlight whitespace in red
let g:strip_whitespace_on_save = 1


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

