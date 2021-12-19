local map = vim.api.nvim_set_keymap  -- set global keymap

local opts = { noremap = true, silent = true }
map('n', '<Leader>gs', ':G<CR>',  opts)
