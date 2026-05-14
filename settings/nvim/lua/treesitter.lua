
local treesitter = require('nvim-treesitter')
treesitter.setup()

local ensure_installed = {
  'c',
  'cpp',
  'go',
  'lua',
  'python',
  'rust',
  'tsx',
  'javascript',
  'typescript',
  'vimdoc',
  'vim',
  'java',
  'bash',
  'toml',
  'yaml',
  'xml',
  'pug',
  'graphql',
  'css',
  'scss',
}

treesitter.install(ensure_installed)

vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    local parsers = require('nvim-treesitter.parsers')
    parsers.lyaml = {
    ---@diagnostic disable-next-line missing-fields
      install_info = {
        url = parsers.yaml.install_info.url,
        -- path = parsers.yaml.install_info.path,
        revision = parsers.yaml.install_info.revision,
      },
      -- WARN: `tier = 2` is important for custom parsers
      -- `norm_languages()` in config.lua checks vor `tier < 4`
      -- see: https://github.com/nvim-treesitter/nvim-treesitter/blob/0140c29b31d56be040697176ae809ba0c709da02/lua/nvim-treesitter/config.lua#L95
      -- tiers: 1: stable, 2: unstable, 3: unmaintained, 4 or nil: unsupported
      --        supported = tier < 4
      tier = 2,
    }
    parsers.jade = {
      ---@diagnostic disable-next-line missing-fields
      install_info = {
        url = parsers.pug.install_info.url,
        -- path = parsers.pug.install_info.path,
        revision = parsers.pug.install_info.revision,
      },
      tier = 2,
    }
  end,
})
