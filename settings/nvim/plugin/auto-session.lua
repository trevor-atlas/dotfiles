local auto_session = require("auto-session")

auto_session.setup({
    auto_restore = true,
    suppressed_dirs = { "~/", "~/Downloads", "~/Documents", "~/Desktop/" }
})
