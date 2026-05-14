vim.pack.add({
  {
    src = 'https://github.com/L3MON4D3/LuaSnip',
    -- follow latest release.
    version = 'v2.*', -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = 'make install_jsregexp',
  }
})

require("luasnip").setup({
  history = true,
  delete_check_events = "TextChanged",
  region_check_events = "CursorMoved",
})
