return {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'williamboman/mason.nvim',
        config = function()
          require('mason-lspconfig').setup_handlers({
            ['rust_analyzer'] = function() end,
          })
        end,
      },
      'williamboman/mason-lspconfig.nvim', -- Useful status updates for LSP
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      {
        'neovim/nvim-lspconfig',
        opts = {
          setup = {
            rust_analyzer = function() return true end,
          },
        },
      },
      { 'j-hui/fidget.nvim', tag = 'legacy', opts = {} }, -- Additional lua configuration, makes nvim stuff amazing!
      'folke/neodev.nvim',
    },
    config = function() require('lspconfig').eslint.setup({}) end,
  }
