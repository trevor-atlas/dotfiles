require("options")
require("autocommands")
require("lazy-conf")


require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  checker = { enabled = true },
}, {})


