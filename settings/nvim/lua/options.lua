-- disable builtins plugins
local disabled_built_ins = {
  -- "netrw",
  -- "netrwPlugin",
  -- "netrwSettings",
  -- "netrwFileHandlers",
  'gzip',
  'zip',
  'zipPlugin',
  'tar',
  'tarPlugin',
  'getscript',
  'getscriptPlugin',
  'vimball',
  'vimballPlugin',
  'logipat',
  'rrhelper',
  'spellfile_plugin',
  'matchit',
}

for _, plugin in pairs(disabled_built_ins) do
  vim.g['loaded_' .. plugin] = 1
end

-- local g = vim.g         				-- global variables
-- local opt = vim.opt         		-- global/buffer/windows-scoped options
-- local api = vim.api

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
vim.g.neovide_refresh_rate_idle = 5
vim.g.neovide_refresh_rate = 60
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_cursor_vfx_mode = 'sonicboom'
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.o.guifont = 'Comic Code Ligatures:h18'
--
-- Helper function for transparency formatting
local alpha = function() return string.format('%x', math.floor(255 * vim.g.transparency or 0.8)) end
-- g:neovide_transparency should be 0 if you want to unify transparency of content and title bar.
vim.g.neovide_transparency = 0.9
vim.g.transparency = 0.9
vim.g.neovide_background_color = '#0f1117' .. alpha()

-- Remap space as leader key
vim.api.nvim_set_keymap('', '<Space>', '<Nop>', { noremap = true, silent = true })
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Map blankline
vim.g.indent_blankline_char = '┊'
vim.g.indent_blankline_filetype_exclude = { 'help', 'packer' }
vim.g.indent_blankline_buftype_exclude = { 'terminal', 'nofile' }
vim.g.indent_blankline_show_trailing_blankline_indent = false

vim.opt.mouse = 'a' -- enable mouse support
vim.opt.clipboard = 'unnamedplus' -- copy/paste to system clipboard
vim.opt.swapfile = false -- don't use swapfile

vim.opt.number = true -- show line number
vim.opt.relativenumber = true -- line numbers are relative to the cursor
vim.opt.showmatch = true -- highlight matching parenthesis
vim.opt.foldmethod = 'marker' -- enable folding (default 'foldmarker')
-- opt.colorcolumn = '80'        -- line lenght marker at 80 columns
vim.opt.ignorecase = true -- ignore case letters when search
vim.opt.smartcase = true -- ignore lowercase for the whole pattern
vim.opt.linebreak = true -- wrap on word boundary
vim.opt.scrolloff = 999
vim.opt.encoding = 'utf-8'

-- open new split panes to right and bottom, which feels more natural than Vim’s default
vim.opt.splitbelow = true
vim.opt.splitright = true

-- This makes vim act like all other editors, buffers can
-- exist in the background without being in a window.
-- http://items.sjbach.com/319/configuring-vim-right
vim.opt.hidden = true

-- Tabs, indent
vim.opt.expandtab = true -- use spaces instead of tabs
vim.opt.shiftwidth = 2 -- shift 4 spaces when tab
vim.opt.tabstop = 2 -- 1 tab == 4 spaces
vim.opt.smartindent = true -- autoindent new lines

-- Memory, CPU
vim.opt.hidden = true -- enable background buffers
vim.opt.history = 100 -- remember n lines in history
vim.opt.lazyredraw = true -- faster scrolling
vim.opt.synmaxcol = 240 -- max column for syntax highlight

-- disable nvim intro
-- opt.shortmess:append "sI"opt

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

vim.o.relativenumber = true -- sets vim.opt.relativenumber
vim.o.scrolloff = 999
vim.o.swapfile = false
-- I prefer '>' and '<' to move text the same distance as the tab-key.
-- by settin shiftwidth=0 you tell vim that you always want it to match tabstop
vim.o.shiftwidth = 0
vim.o.tabstop = 2
vim.o.softtabstop = 2

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true
