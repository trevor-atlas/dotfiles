-- return {
--   "olimorris/codecompanion.nvim",
--   dependencies = {
--     "nvim-lua/plenary.nvim",
--     "nvim-treesitter/nvim-treesitter",
--     "nvim-telescope/telescope.nvim",
--   },
--   config = function()
--     require("codecompanion").setup({
--       strategies = {
--         chat = {
--           adapter = "anthropic",
--         },
--         inline = {
--           adapter = "anthropic",
--         },
--         agent = {
--           adapter = "anthropic",
--         },
--       },
--       adapters = {
--         anthropic = function()
--           return require("codecompanion.adapters").extend("anthropic", {
--             env = {
--               api_key = "ANTHROPIC_API_KEY",
--             },
--           })
--         end,
--       },
--     })
--   end,
-- }
-- return {
--   'robitx/gp.nvim',
--   config = function()
--     local conf = {
--       providers = {
--         openai = {
--           disable = true,
--         },
--         anthropic = {
--           disable = false,
--           -- endpoint = 'https://api.anthropic.com/v1/messages',
--           -- secret = os.getenv('ANTHROPIC_API_KEY'),
--         },
--       },
--     }
--     require('gp').setup(conf)
--
--     -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
--   end,
-- }
return {
  'yetone/avante.nvim',
  event = 'VeryLazy',
  build = 'make', -- This is Optional, only if you want to use tiktoken_core to calculate tokens count
  opts = {
    -- add any opts here
  },
  dependencies = {
    'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
    'stevearc/dressing.nvim',
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    --- The below is optional, make sure to setup it properly if you have lazy=true
    {
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { 'markdown', 'Avante' },
      },
      ft = { 'markdown', 'Avante' },
    },
  },
}
