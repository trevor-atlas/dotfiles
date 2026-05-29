vim.opt.rtp:prepend(vim.env.HOME .. '/src/hubspot-i18n-nvim')
-- local nix_path = vim.fs.joinpath(vim.fn.stdpath("data"), "nix")
-- local dev_path = require("helpers").get_subdirectories(vim.fs.joinpath(vim.env.HOME, "Projects", "vim-plugins"))
-- local paths = vim.iter({ nix_path, dev_path }):flatten():totable()

-- vim.iter(paths):each(function(path) vim.opt.rtp:prepend(path) end)

vim.pack.add({
  'https://github.com/MagicDuck/grug-far.nvim',
  'https://github.com/NickvanDyke/opencode.nvim',
  'https://github.com/ThePrimeagen/refactoring.nvim',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/igorlfs/nvim-dap-view',
  'https://github.com/jbyuki/one-small-step-for-vimkind',
  'https://github.com/kevinhwang91/nvim-bqf',
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/mfussenegger/nvim-lint',
  'https://github.com/mistweaverco/kulala.nvim',
  'https://github.com/nvim-mini/mini.nvim',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/stevearc/quicker.nvim',
  'https://github.com/tadmccorkle/markdown.nvim',
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/neovim/nvim-lspconfig',
  -- 'https://github.com/pmizio/typescript-tools.nvim',
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.x') },
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/MunifTanjim/nui.nvim',
  {
    src = 'git@github.com:HubSpotEngineering/bend.nvim.git',
  },

  { src = 'https://github.com/L3MON4D3/LuaSnip', version = vim.version.range('2.x') },
  'https://github.com/rafamadriz/friendly-snippets',
  {
    src = 'git@github.com:HubSpotEngineering/bend.nvim.git',
  },
  {
    src = 'https://github.com/nvim-neo-tree/neo-tree.nvim',
    version = 'v3.x',
  },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/rmagatti/auto-session',

  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main', name = 'ts' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  -- 'https://github.com/nvim-treesitter/nvim-treesitter-context',
})

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'nvim-treesitter' and kind == 'update' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
    if name == 'luasnip' and kind == 'update' or kind == 'install' then vim.cmd('make install_jsregexp') end
  end,
})

require('mini.misc').setup()
require('mini.basics').setup()
require('mini.surround').setup()
_G.safely = require('mini.misc').safely

require('globals')
require('options')
require('autocommands')
require('treesitter')
require('lsp')
-- require("rust")
require('completion')
require('theme').setup()
require('mappings')
