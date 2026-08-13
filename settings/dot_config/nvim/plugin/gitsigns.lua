require('gitsigns').setup({
  -- Adds git related signs to the gutter, as well as utilities for managing changes
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
      -- don't override the built-in and fugitive keymaps
      local gs = package.loaded.gitsigns
      require('keymaps').apply_buffer(bufnr, require('keymaps.gitsigns').for_buffer(gs))
    end,
})
