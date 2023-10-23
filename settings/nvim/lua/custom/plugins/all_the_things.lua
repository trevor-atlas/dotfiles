return {
  'nvim-lua/plenary.nvim',
  'echasnovski/mini.bufremove',
  { 'max397574/better-escape.nvim', event = 'InsertCharPre', opts = { timeout = 300 } },
  {
    'NMAC427/guess-indent.nvim',
    config = function(_, opts)
      require('guess-indent').setup(opts)
      vim.cmd.lua({ args = { "require('guess-indent').set_from_buffer('auto_cmd')" }, mods = { silent = true } })
    end,
  },
  {
    's1n7ax/nvim-window-picker',
    name = 'window-picker',
    opts = { picker_config = { statusline_winbar_picker = { use_winbar = 'smart' } } },
  },
  {
    'mrjones2014/smart-splits.nvim',
    opts = { ignored_filetypes = { 'nofile', 'quickfix', 'qf', 'prompt' }, ignored_buftypes = { 'nofile' } },
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
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
    opts = {
      mode = 'symbol',
      symbol_map = {
        Array = '??',
        Boolean = '?',
        Class = '??',
        Constructor = '?',
        Key = '??',
        Namespace = '??',
        Null = 'NULL',
        Number = '#',
        Object = '??',
        Package = '??',
        Property = '?',
        Reference = '?',
        Snippet = '?',
        String = '??',
        TypeParameter = '??',
        Unit = '?',
      },
      menu = {},
    },
    enabled = vim.g.icons_enabled,
    config = function(_, opts) require('lspkind').init(opts) end,
  },
  {
    'rcarriga/nvim-notify',
    opts = {
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 175 })
        if not vim.g.ui_notifications_enabled then vim.api.nvim_win_close(win, true) end
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
    'NvChad/nvim-colorizer.lua',
    cmd = { 'ColorizerToggle', 'ColorizerAttachToBuffer', 'ColorizerDetachFromBuffer', 'ColorizerReloadAllBuffers' },
    opts = { user_default_options = { names = false } },
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
}
