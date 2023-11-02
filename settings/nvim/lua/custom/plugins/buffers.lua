return {
  { 'famiu/bufdelete.nvim' },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup({
        options = {
          numbers = 'buffer_id',
          show_close_icon = false,
          separator_style = 'slant',
          groups = {
            options = {
              toggle_hidden_on_enter = true,
            },
            items = {
              require('bufferline.groups').builtin.pinned:with({ icon = '' }),
              {
                name = 'Tests',
                highlight = { underline = true, sp = 'blue' },
                priority = 2,
                icon = '',
                matcher = function(buf)
                  local fname = vim.api.nvim_buf_get_name(0)
                  return fname:match('%.test') or fname:match('%-test') or fname:match('%.spec') or fname:match('%-spec')
                end,
              },
              {
                name = 'Docs',
                highlight = { undercurl = true, sp = 'green' },
                auto_close = false,
                matcher = function(buf)
                  local fname = vim.api.nvim_buf_get_name(0)
                  return fname:match('%.md') or fname:match('%.txt')
                end,
                separator = {
                  style = require('bufferline.groups').separator.tab,
                },
              },
              {
                name = 'Lang',
                highlight = { undercurl = true, sp = 'orange' },
                auto_close = false,
                matcher = function(buf)
                  local fname = vim.api.nvim_buf_get_name(0)
                  return fname:match('%.lyaml')
                end,
                separator = {
                  style = require('bufferline.groups').separator.tab,
                },
              },
              {
                name = 'Config',
                highlight = { undercurl = true, sp = 'orange' },
                auto_close = false,
                matcher = function(buf)
                  local fname = vim.api.nvim_buf_get_name(0)
                  return fname:match('%.yaml') or fname:match('%.toml') or fname:match('%.json')
                end,
                separator = {
                  style = require('bufferline.groups').separator.tab,
                },
              },
            },
          },
        },
      })
    end,
  },
}
