vim.api.nvim_command('packadd packer.nvim')
local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
local fn = vim.fn

-- install packer if needed
if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system({
        'git',
        'clone',
        '--depth',
        '1',
        'https://github.com/wbthomason/packer.nvim',
        install_path,
    })
end

require('packer').init({
    compile_path = install_path .. '/packer_compiled.lua',
})

require('packer').startup(function()

  use 'wbthomason/packer.nvim' -- Package manager

  use 'tpope/vim-fugitive' -- Git commands in nvim
  use 'tpope/vim-rhubarb' -- Fugitive-companion to interact with github
  use 'tpope/vim-commentary' -- "gc" to comment visual regions/lines
  use 'tpope/vim-surround'

  use 'christoomey/vim-tmux-navigator' -- make tmux and vim splits play nicely

  use {
    'romgrk/barbar.nvim', -- show buffers as tabs
    requires = {'kyazdani42/nvim-web-devicons'}
  }

  use 'itchyny/lightline.vim' -- Fancier statusline

    -- Add indentation guides even on blank lines
  use 'lukas-reineke/indent-blankline.nvim'

    -- Add git related info in the signs columns and popups
  use { 'lewis6991/gitsigns.nvim', requires = { 'nvim-lua/plenary.nvim' } }

    -- UI to select things (files, grep results, open buffers...)
  use { 'nvim-telescope/telescope.nvim', requires = { 'nvim-lua/plenary.nvim' } }

  use {'dracula/vim'} -- color theme

  use({ 'windwp/nvim-autopairs' }) -- auto-pairing of parens

  -- Completion
  use({
    'hrsh7th/nvim-cmp',
    'saadparwaiz1/cmp_luasnip',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-nvim-lua',
    'lukas-reineke/cmp-rg',
  })

  -- Snippets
    use({
      'L3MON4D3/luasnip',
      requires = {
        'rafamadriz/friendly-snippets',
      },
    })

  -- Treesitter: Highlight, edit, and navigate code using a fast incremental parsing library
  use({
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = [[require('modules.plugins.treesitter')]],
  })

  use {
    'neovim/nvim-lspconfig',
    'williamboman/nvim-lsp-installer'
  }

  use 'nvim-lua/popup.nvim' -- Popups

  use {
    'kyazdani42/nvim-tree.lua',
    requires = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icon
    },
    config = function() require'nvim-tree'.setup {} end
  }
end)
