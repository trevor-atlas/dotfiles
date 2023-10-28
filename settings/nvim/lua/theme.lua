local M = {}

local palette = {

  -- Bg Shades
  sumiInk0 = '#16161D',
  sumiInk1 = '#181820',
  sumiInk2 = '#1a1a22',
  sumiInk3 = '#1F1F28',
  sumiInk4 = '#2A2A37',
  sumiInk5 = '#363646',
  sumiInk6 = '#54546D', --fg

  -- Popup and Floats
  waveBlue1 = '#223249',
  waveBlue2 = '#2D4F67',

  -- Diff and Git
  winterGreen = '#2B3328',
  winterYellow = '#49443C',
  winterRed = '#43242B',
  winterBlue = '#252535',
  autumnGreen = '#76946A',
  autumnRed = '#C34043',
  autumnYellow = '#DCA561',

  -- Diag
  samuraiRed = '#E82424',
  roninYellow = '#FF9E3B',
  waveAqua1 = '#6A9589',
  dragonBlue = '#658594',

  -- Fg and Comments
  oldWhite = '#C8C093',
  fujiWhite = '#DCD7BA',
  fujiGray = '#727169',

  oniViolet = '#957FB8',
  oniViolet2 = '#b8b4d0',
  crystalBlue = '#7E9CD8',
  springViolet1 = '#938AA9',
  springViolet2 = '#9CABCA',
  springBlue = '#7FB4CA',
  lightBlue = '#A3D4D5',
  waveAqua2 = '#7AA89F',
  waveAqua3 = '#68AD99',
  waveAqua4 = '#7AA880',
  waveAqua5 = '#8BD5B3',

  springGreen = '#98BB6C',
  boatYellow1 = '#938056',
  boatYellow2 = '#C0A36E',
  carpYellow = '#E6C384',

  sakuraPink = '#D27E99',
  waveRed = '#E46876',
  peachRed = '#FF5D62',
  surimiOrange = '#FFA066',
  katanaGray = '#717C7C',

  dragonBlack0 = '#0d0c0c',
  dragonBlack1 = '#12120f',
  dragonBlack2 = '#1D1C19',
  dragonBlack3 = '#181616',
  dragonBlack4 = '#282727',
  dragonBlack5 = '#393836',
  dragonBlack6 = '#625e5a',

  dragonWhite = '#c5c9c5',
  dragonGreen = '#87a987',
  dragonGreen2 = '#8a9a7b',
  dragonPink = '#a292a3',
  dragonOrange = '#b6927b',
  dragonOrange2 = '#b98d7b',
  dragonGray = '#a6a69c',
  dragonGray2 = '#9e9b93',
  dragonGray3 = '#7a8382',
  dragonBlue2 = '#8ba4b0',
  dragonViolet = '#8992a7',
  dragonRed = '#c4746e',
  dragonAqua = '#8ea4a2',
  dragonAsh = '#737c73',
  dragonTeal = '#949fb5',
  dragonYellow = '#c4b28a',

  lotusInk1 = '#545464',
  lotusInk2 = '#43436c',
  lotusGray = '#dcd7ba',
  lotusGray2 = '#716e61',
  lotusGray3 = '#8a8980',
  lotusWhite0 = '#d5cea3',
  lotusWhite1 = '#dcd5ac',
  lotusWhite2 = '#e5ddb0',
  lotusWhite3 = '#f2ecbc',
  lotusWhite4 = '#e7dba0',
  lotusWhite5 = '#e4d794',
  lotusViolet1 = '#a09cac',
  lotusViolet2 = '#766b90',
  lotusViolet3 = '#c9cbd1',
  lotusViolet4 = '#624c83',
  lotusBlue1 = '#c7d7e0',
  lotusBlue2 = '#b5cbd2',
  lotusBlue3 = '#9fb5c9',
  lotusBlue4 = '#4d699b',
  lotusBlue5 = '#5d57a3',
  lotusGreen = '#6f894e',
  lotusGreen2 = '#6e915f',
  lotusGreen3 = '#b7d0ae',
  lotusPink = '#b35b79',
  lotusOrange = '#cc6d00',
  lotusOrange2 = '#e98a00',
  lotusYellow = '#77713f',
  lotusYellow2 = '#836f4a',
  lotusYellow3 = '#de9800',
  lotusYellow4 = '#f9d791',
  lotusRed = '#c84053',
  lotusRed2 = '#d7474b',
  lotusRed3 = '#e82424',
  lotusRed4 = '#d9a594',
  lotusAqua = '#597b75',
  lotusAqua2 = '#5e857a',
  lotusTeal1 = '#4e8ca2',
  lotusTeal2 = '#6693bf',
  lotusTeal3 = '#5a7785',
  lotusCyan = '#d7e3d8',
}

M.colors = {
  white = '#bbc2cf',
  darker_black = '#22262e',
  black = '#282c34',
  black2 = '#2e323a',
  one_bg = '#32363e',
  one_bg2 = '#3c4048',
  one_bg3 = '#41454d',
  grey = '#494d55',
  grey_fg = '#53575f',
  grey_fg2 = '#5d6169',
  light_grey = '#676b73',
  red = '#ff6b5a',
  baby_pink = '#ff7665',
  pink = '#ff75a0',
  line = '#3b3f47', -- for lines like vertsplit
  green = '#98be65',
  comments = '#6ea67c',
  strings = '#a6e4a3',
  vibrant_green = '#a9cf76',
  nord_blue = '#47a5e5',
  blue = '#61afef',
  yellow = '#ECBE7B',
  sun = '#f2c481',
  purple = '#dc8ef3',
  dark_purple = '#c678dd',
  teal = '#4db5bd',
  orange = '#ea9558',
  cyan = '#46D9FF',
  statusline_bg = '#2d3139',
  lightbg = '#3a3e46',
  pmenu_bg = '#98be65',
  folder_bg = '#51afef',
}

M.cool = {
  black = '#151820',
  bg0 = '#242b38',
  bg1 = '#2d3343',
  bg2 = '#343e4f',
  bg3 = '#363c51',
  bg_d = '#1e242e',
  bg_blue = '#6db9f7',
  bg_yellow = '#f0d197',
  fg = '#a5b0c5',
  purple = '#ca72e4',
  green = '#97ca72',
  orange = '#d99a5e',
  blue = '#5ab0f6',
  yellow = '#ebc275',
  cyan = '#4dbdcb',
  red = '#ef5f6b',
  grey = '#546178',
  light_grey = '#7d899f',
  dark_cyan = '#25747d',
  dark_red = '#a13131',
  dark_yellow = '#9a6b16',
  dark_purple = '#8f36a9',
  diff_add = '#303d27',
  diff_delete = '#3c2729',
  diff_change = '#18344c',
  diff_text = '#265478',
}

local interface = { fg = palette.waveAqua5, italic = true }
local theme = {
  syntax = {
    -- class interfaces
    TSTypeDefinition = { fg = M.colors.vibrant_green },
    typescriptTSType = { fg = M.colors.vibrant_green },
    Type = { fg = palette.waveAqua3 },
    Typedef = interface,

    ['@lsp.type.enum'] = { fg = palette.surimiOrange, bold = true },
    ['@lsp.type.type'] = { fg = palette.waveAqua3 },
    ['@lsp.type.interface'] = { fg = palette.waveAqua3 },
    -- ['@lsp.mod.declaration'] = interface,
    ['@lsp.typemod.interface.declaration'] = interface,
    ['@type.builtin'] = { fg = palette.lotusViolet4 },
    -- editor gutter (line numbers, icon column)
    SignColumn = { bg = 'NONE' },
    FoldColumn = { bg = 'NONE' },
    LineNr = { fg = M.colors.grey, bg = 'NONE' },

    -- editor background
    Normal = { bg = 'NONE' },
    CursorLineNr = { bg = 'NONE' },

    -- comments
    Comment = { fg = M.colors.comments },
    DiagnosticUnnecessary = { fg = M.colors.light_grey },

    --
    Statement = { fg = palette.oniViolet, bold = false },
    ['@lsp.typemod.function.readonly'] = { fg = palette.crystalBlue, bold = false },

    -- strings
    String = { fg = M.colors.strings },

    -- '<' and '>' in html
    -- vim.api.nvim_set_hl(0, 'TSTagDelimiter', {fg = "#ff9ff5"})

    -- <TAGNAME/>
    -- vim.api.nvim_set_hl(0, 'TSTag', {fg = M.colors.dark_purple})
    -- vim.api.nvim_set_hl(0, 'tsxTSTag', {fg = M.colors.dark_purple})

    -- <div attribute="" />
    TSTagAttribute = { fg = '#f0d197' },

    -- vim.api.nvim_set_hl(0, 'tsxTSConstructor', {fg = M.colors.dark_purple})
    -- vim.api.nvim_set_hl(0, 'typescriptTSConstructor', {fg = M.colors.blue})

    -- const THING = ''
    -- vim.api.nvim_set_hl(0, 'TSVariable', {fg = '#b2abe8'})

    -- //comments
    -- vim.api.nvim_set_hl(0, "TSComment", { fg = "#eaaf8f" })
  },
  lsp = {
    DiagnosticError = { fg = M.colors.red },
    DiagnosticHint = { fg = M.colors.yellow },
    DiagnosticInfo = { fg = M.colors.white },
    DiagnosticWarn = { fg = M.colors.orange },
    DiagnosticInformation = { fg = M.colors.yellow, bold = true },
    DiagnosticTruncateLine = { fg = M.colors.white, bold = true },
    DiagnosticUnderlineError = { sp = M.colors.red, undercurl = true },
    DiagnosticUnderlineHint = { sp = M.colors.red, undercurl = true },
    DiagnosticUnderlineInfo = { sp = M.colors.red, undercurl = true },
    DiagnosticUnderlineWarn = { sp = M.colors.red, undercurl = true },
    LspDiagnosticsFloatingError = { fg = M.colors.red },
    LspDiagnosticsFloatingHint = { fg = M.colors.yellow },
    LspDiagnosticsFloatingInfor = { fg = M.colors.white },
    LspDiagnosticsFloatingWarn = { fg = M.colors.orange },
    LspFloatWinBorder = { fg = M.colors.white },
    LspFloatWinNormal = { fg = M.cool.fg, bg = M.colors.black },
    LspReferenceRead = { fg = 'NONE', bg = M.colors.grey },
    LspReferenceText = { fg = 'NONE', bg = M.colors.grey },
    LspReferenceWrite = { fg = 'NONE', bg = M.colors.grey },
    ProviderTruncateLine = { fg = M.colors.white },
  },
  telescope_theme = {
    TelescopeBorder = { fg = M.colors.darker_black, bg = M.colors.darker_black },
    FloatBorder = { fg = M.colors.darker_black, bg = M.colors.darker_black },
    NormalFloat = { fg = M.colors.white, bg = M.colors.darker_black },
    -- search input border
    TelescopePromptBorder = { fg = M.colors.one_bg, bg = M.colors.one_bg },
    -- search input
    TelescopePromptNormal = { fg = M.colors.white, bg = M.colors.one_bg },
    -- search input prefix (icon)
    TelescopePromptPrefix = { fg = M.colors.red, bg = M.colors.one_bg },
    TelescopeNormal = { fg = M.colors.white, bg = M.colors.darker_black },
    TelescopePreviewTitle = { fg = M.colors.black, bg = M.colors.green },
    TelescopePromptTitle = { fg = M.colors.black, bg = M.colors.red },
    TelescopeResultsTitle = { fg = M.colors.white, bg = M.colors.darker_black },
    TelescopeSelection = { fg = M.colors.white, bg = M.colors.black2 },
  },
}

function M.setup()
  for _, options in pairs(theme) do
    for name, values in pairs(options) do
      vim.api.nvim_set_hl(0, name, values)
    end
  end
end

return M
