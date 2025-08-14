require('options')
require("autocommands")

-- Install package manager
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)
-- require("lazy").setup({
--   spec = {
--     { import = "plugins" },
--   },
--   checker = { enabled = true },
-- }, {})
require('lazy').setup({
  'nvim-lua/plenary.nvim',
  'nvim-tree/nvim-web-devicons',
  'ggandor/lightspeed.nvim',
  -- "simrat39/rust-tools.nvim",
  { 'folke/neoconf.nvim', config = function() end },
  {
    'brenoprata10/nvim-highlight-colors',
    init = function() require('nvim-highlight-colors').setup({}) end,
  },
  {
    'numToStr/Comment.nvim',
    opts = {},
    lazy = false,
  },
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  },
  {
    'numToStr/Navigator.nvim',
    config = function() require('Navigator').setup({}) end,
  },
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },
  'MunifTanjim/nui.nvim',
  {
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
  },
  {

    'L3MON4D3/LuaSnip',
    -- follow latest release.
    version = 'v2.*', -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = 'make install_jsregexp',
    opts = {
      history = true,
      delete_check_events = 'TextChanged',
      region_check_events = 'CursorMoved',
    },
  },
  {
    -- Autocompletion
    'hrsh7th/nvim-cmp',
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',

      -- Adds LSP completion capabilities
      'hrsh7th/cmp-nvim-lsp',

      -- Adds a number of user-friendly snippets
      'rafamadriz/friendly-snippets',
    },
  },
  {
    -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      -- See `:help gitsigns.txt`
      --
      signs = {
        add = { hl = 'GitGutterAdd', text = '+' },
        change = { hl = 'GitGutterChange', text = '~' },
        delete = { hl = 'GitGutterDelete', text = '-' },
        topdelete = { hl = 'GitGutterDelete', text = '‾' },
        changedelete = { hl = 'GitGutterChange', text = '~' },
      },
      on_attach = function(bufnr)
        vim.keymap.set('n', '<leader>hp', require('gitsigns').preview_hunk, { buffer = bufnr, desc = 'Preview git hunk' })
        vim.keymap.set('n', '<leader>lb', require('gitsigns').toggle_current_line_blame, { buffer = bufnr, desc = 'Preview git hunk' })

        -- don't override the built-in and fugitive keymaps
        local gs = package.loaded.gitsigns
        vim.keymap.set({ 'n', 'v' }, ']c', function()
          if vim.wo.diff then return ']c' end
          vim.schedule(gs.next_hunk)
          return '<Ignore>'
        end, { expr = true, buffer = bufnr, desc = 'Jump to next hunk' })
        vim.keymap.set({ 'n', 'v' }, '[c', function()
          if vim.wo.diff then return '[c' end
          vim.schedule(gs.prev_hunk)
          return '<Ignore>'
        end, { expr = true, buffer = bufnr, desc = 'Jump to previous hunk' })
      end,
    },
  },
  {
    'mhartington/formatter.nvim',
    config = function() require('fmt') end,
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {},
    init = function() vim.cmd.colorscheme('tokyonight-storm') end,
  },
  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    init = function()
      local colors = {
        blue = '#80a0ff',
        cyan = '#79dac8',
        black = '#080808',
        white = '#c6c6c6',
        red = '#ff5189',
        violet = '#d183e8',
        grey = '#303030',
      }
      local theme = {
        normal = {
          a = { fg = colors.black, bg = colors.violet },
          b = { fg = colors.white, bg = colors.grey },
          c = { fg = colors.black, bg = colors.black },
        },

        insert = { a = { fg = colors.black, bg = colors.blue } },
        visual = { a = { fg = colors.black, bg = colors.cyan } },
        replace = { a = { fg = colors.black, bg = colors.red } },

        inactive = {
          a = { fg = colors.white, bg = colors.black },
          b = { fg = colors.white, bg = colors.black },
          c = { fg = colors.black, bg = colors.black },
        },
      }
      require('lualine').setup({
        theme,
        component_separators = '|',
        section_separators = { left = '', right = '' },
        sections = {
          lualine_a = {
            { 'mode', separator = { left = '' }, right_padding = 2 },
          },
          lualine_b = { 'filename', 'branch', 'diff' },
          lualine_c = { 'diagnostics', 'encoding' },
          lualine_x = {},
          lualine_y = { 'filetype', 'searchcount' },
          lualine_z = {
            { 'location', separator = { right = '' }, left_padding = 2 },
          },
        },
        inactive_sections = {
          lualine_a = { 'filename' },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = { 'location' },
        },
        tabline = {},
        extensions = {},
      })
    end,
  },
  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
    build = ':TSUpdate',
  },
  'echasnovski/mini.bufremove',
  { 'max397574/better-escape.nvim', event = 'InsertCharPre', opts = { timeout = 300 } },
  {
    'NMAC427/guess-indent.nvim',
    config = function(_, opts)
      require('guess-indent').setup(opts)
      --vim.cmd.lua({ args = { "require('guess-indent').set_from_buffer('auto_cmd')" }, mods = { silent = true } })
    end,
  },
  {
    's1n7ax/nvim-window-picker',
    name = 'window-picker',
    opts = { picker_config = { statusline_winbar_picker = { use_winbar = 'smart' } } },
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    init = function()
      -- local wk = require('which-key')
      -- wk.register({
      --   p = {
      --     name = "ChatGPT",
      --       c = { "<cmd>ChatGPT<CR>", "ChatGPT" },
      --       e = { "<cmd>ChatGPTEditWithInstruction<CR>", "Edit with instruction", mode = { "n", "v" } },
      --       g = { "<cmd>ChatGPTRun grammar_correction<CR>", "Grammar Correction", mode = { "n", "v" } },
      --       t = { "<cmd>ChatGPTRun translate<CR>", "Translate", mode = { "n", "v" } },
      --       k = { "<cmd>ChatGPTRun keywords<CR>", "Keywords", mode = { "n", "v" } },
      --       d = { "<cmd>ChatGPTRun docstring<CR>", "Docstring", mode = { "n", "v" } },
      --       a = { "<cmd>ChatGPTRun add_tests<CR>", "Add Tests", mode = { "n", "v" } },
      --       o = { "<cmd>ChatGPTRun optimize_code<CR>", "Optimize Code", mode = { "n", "v" } },
      --       s = { "<cmd>ChatGPTRun summarize<CR>", "Summarize", mode = { "n", "v" } },
      --       f = { "<cmd>ChatGPTRun fix_bugs<CR>", "Fix Bugs", mode = { "n", "v" } },
      --       x = { "<cmd>ChatGPTRun explain_code<CR>", "Explain Code", mode = { "n", "v" } },
      --       r = { "<cmd>ChatGPTRun roxygen_edit<CR>", "Roxygen Edit", mode = { "n", "v" } },
      --       l = { "<cmd>ChatGPTRun code_readability_analysis<CR>", "Code Readability Analysis", mode = { "n", "v" } },
      --     },
      -- })
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      icons = { group = vim.g.icons_enabled and '' or '+', separator = '' },
      disable = { filetypes = { 'TelescopePrompt' } },
    },
  },
  {
    'akinsho/toggleterm.nvim',
    cmd = { 'ToggleTerm', 'TermExec' },
    init = function() end,
    opts = {
      highlights = {
        Normal = { link = 'Normal' },
        NormalNC = { link = 'NormalNC' },
        NormalFloat = { link = 'NormalFloat' },
        FloatBorder = { link = 'FloatBorder' },
        StatusLine = { link = 'StatusLine' },
        StatusLineNC = { link = 'StatusLineNC' },
        WinBar = { link = 'WinBar' },
        WinBarNC = { link = 'WinBarNC' },
      },
      size = 10,
      on_create = function(term)
        vim.opt.foldcolumn = '0'
        vim.opt.signcolumn = 'no'
        vim.cmd('startinsert!')
      end,
      open_mapping = [[<c-\>]],
      shading_factor = 2,
      direction = 'float',
      float_opts = {
        border = 'curved',
        highlights = {
          border = 'Normal',
          background = 'Normal',
        },
      },
    },
  },
  {
    'nvim-tree/nvim-web-devicons',
    enabled = vim.g.icons_enabled,
    opts = {
      override = {
        default_icon = { icon = '[F]' },
        deb = { icon = '', name = 'Deb' },
        lock = { icon = '󰌾', name = 'Lock' },
        mp3 = { icon = '󰎆', name = 'Mp3' },
        mp4 = { icon = '', name = 'Mp4' },
        out = { icon = '', name = 'Out' },
        ['robots.txt'] = { icon = '󰚩', name = 'Robots' },
        ttf = { icon = '', name = 'TrueTypeFont' },
        rpm = { icon = '', name = 'Rpm' },
        woff = { icon = '', name = 'WebOpenFontFormat' },
        woff2 = { icon = '', name = 'WebOpenFontFormat2' },
        xz = { icon = '', name = 'Xz' },
        zip = { icon = '', name = 'Zip' },
      },
    },
  },
  {
    'onsails/lspkind.nvim',
    config = function(_, opts) require('lspkind').init(opts) end,
  },
  {
    'rcarriga/nvim-notify',
    opts = {
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 175 })
        if not package.loaded['nvim-treesitter'] then pcall(require, 'nvim-treesitter') end
        vim.wo[win].conceallevel = 3
        local buf = vim.api.nvim_win_get_buf(win)
        if not pcall(vim.treesitter.start, buf, 'markdown') then vim.bo[buf].syntax = 'markdown' end
        vim.wo[win].spell = false
      end,
    },
  },
  {
    'stevearc/dressing.nvim',
    opts = {
      input = { default_prompt = '➤ ' },
      select = { backend = { 'telescope', 'builtin' } },
    },
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { char = '▏' },
      scope = { show_start = false, show_end = false },
      exclude = {
        buftypes = {
          'nofile',
          'terminal',
        },
        filetypes = {
          'help',
          'startify',
          'aerial',
          'alpha',
          'dashboard',
          'lazy',
          'neogitstatus',
          'NvimTree',
          'neo-tree',
          'Trouble',
        },
      },
    },
  },
  { import = 'custom.plugins' },
  -- setup args explained: https://github.com/folke/lazy.nvim?tab=readme-ov-file#-plugin-spec
}, {})

require("globals")
require("hubspot-bender").setup()
require("treesitter")
require("lsp")
-- require("rust")
require("completion")
require("autocommands")
require("theme").setup()
require("mappings")
