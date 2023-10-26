local M = {}

M.colors = {
  white = "#bbc2cf",
  darker_black = "#22262e",
  black = "#282c34",
  black2 = "#2e323a",
  one_bg = "#32363e",
  one_bg2 = "#3c4048",
  one_bg3 = "#41454d",
  grey = "#494d55",
  grey_fg = "#53575f",
  grey_fg2 = "#5d6169",
  light_grey = "#676b73",
  red = "#ff6b5a",
  baby_pink = "#ff7665",
  pink = "#ff75a0",
  line = "#3b3f47", -- for lines like vertsplit
  green = "#98be65",
  comments = "#6ea67c",
  strings = "#a6e4a3",
  vibrant_green = "#a9cf76",
  nord_blue = "#47a5e5",
  blue = "#61afef",
  yellow = "#ECBE7B",
  sun = "#f2c481",
  purple = "#dc8ef3",
  dark_purple = "#c678dd",
  teal = "#4db5bd",
  orange = "#ea9558",
  cyan = "#46D9FF",
  statusline_bg = "#2d3139",
  lightbg = "#3a3e46",
  pmenu_bg = "#98be65",
  folder_bg = "#51afef",
}

M.cool = {
  black = "#151820",
  bg0 = "#242b38",
  bg1 = "#2d3343",
  bg2 = "#343e4f",
  bg3 = "#363c51",
  bg_d = "#1e242e",
  bg_blue = "#6db9f7",
  bg_yellow = "#f0d197",
  fg = "#a5b0c5",
  purple = "#ca72e4",
  green = "#97ca72",
  orange = "#d99a5e",
  blue = "#5ab0f6",
  yellow = "#ebc275",
  cyan = "#4dbdcb",
  red = "#ef5f6b",
  grey = "#546178",
  light_grey = "#7d899f",
  dark_cyan = "#25747d",
  dark_red = "#a13131",
  dark_yellow = "#9a6b16",
  dark_purple = "#8f36a9",
  diff_add = "#303d27",
  diff_delete = "#3c2729",
  diff_change = "#18344c",
  diff_text = "#265478",
}

function M.theme_syntax()
  -- class interfaces
  vim.api.nvim_set_hl(0, "TSTypeDefinition", { fg = M.colors.vibrant_green })
  vim.api.nvim_set_hl(0, "typescriptTSType", { fg = M.colors.vibrant_green })

  -- editor gutter (line numbers, icon column)
  vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "FoldColumn", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "LineNr", { fg = M.colors.grey, bg = "NONE" })

  -- editor background
  vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE" })

  -- comments
  vim.api.nvim_set_hl(0, "Comment", { fg = M.colors.comments })

  -- strings
  vim.api.nvim_set_hl(0, "String", { fg = M.colors.strings })

  -- '<' and '>' in html
  -- vim.api.nvim_set_hl(0, 'TSTagDelimiter', {fg = "#ff9ff5"})

  -- <TAGNAME/>
  -- vim.api.nvim_set_hl(0, 'TSTag', {fg = M.colors.dark_purple})
  -- vim.api.nvim_set_hl(0, 'tsxTSTag', {fg = M.colors.dark_purple})

  -- <div attribute="" />
  vim.api.nvim_set_hl(0, "TSTagAttribute", { fg = "#f0d197" })

  -- vim.api.nvim_set_hl(0, 'tsxTSConstructor', {fg = M.colors.dark_purple})
  -- vim.api.nvim_set_hl(0, 'typescriptTSConstructor', {fg = M.colors.blue})

  -- const THING = ''
  -- vim.api.nvim_set_hl(0, 'TSVariable', {fg = '#b2abe8'})

  -- //comments
  -- vim.api.nvim_set_hl(0, "TSComment", { fg = "#eaaf8f" })
end

function M.theme_telescope()
  local telescopetheme = {
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
  }
  for hl, col in pairs(telescopetheme) do
    vim.api.nvim_set_hl(0, hl, col)
  end
end

return M
