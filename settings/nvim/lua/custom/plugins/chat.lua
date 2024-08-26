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
return {
  'robitx/gp.nvim',
  config = function()
    local conf = {
      providers = {
        openai = {
          disable = true,
        },
        anthropic = {
          disable = false,
          -- endpoint = 'https://api.anthropic.com/v1/messages',
          -- secret = os.getenv('ANTHROPIC_API_KEY'),
        },
      },
    }
    require('gp').setup(conf)

    -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
  end,
}
