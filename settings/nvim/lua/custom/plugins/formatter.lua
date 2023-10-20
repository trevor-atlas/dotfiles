local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
local function path_join(...) return table.concat(vim.tbl_flatten {...}, path_sep) end

local utils = require('utils')

local Job = require("plenary.job")

local get_current_root_dir = function()

  local bufnr = vim.api.nvim_get_current_buf()

  -- Some path manipulation utilities
  local function is_dir(filename)
    local stat = vim.loop.fs_stat(filename)
    return stat and stat.type == 'directory' or false
  end

  -- Asumes filepath is a file.
  local function dirname(filepath)
    local is_changed = false
    local result = filepath:gsub(path_sep .. "([^" .. path_sep .. "]+)$", function()
      is_changed = true
      return ""
    end)
    return result, is_changed
  end

  -- Ascend the buffer's path until we find the rootdir.
  -- is_root_path is a function which returns bool
  local function buffer_find_root_dir(bufnr, is_root_path)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if vim.fn.filereadable(bufname) == 0 then return nil end
    local dir = bufname
    -- Just in case our algo is buggy, don't infinite loop.
    for _ = 1, 100 do
      local did_change
      dir, did_change = dirname(dir)

      if is_root_path(dir, bufname) then return dir, bufname end
      -- If we can't ascend further, then stop looking.
      if not did_change then return nil end
    end
  end

  local root_dir = buffer_find_root_dir(bufnr, function(dir) return is_dir(path_join(dir, '.git')) end)
  return root_dir
end

local function get_prettier_executable(root_dir)
  if utils.is_hubspot_machine then
    return "~/.bpm/packages/hs-prettier/channels/default/prettier-config-hubspot/bin/hs-prettier.js"
  end
  if utils.is_dir(path_join(root_dir, 'node_modules', 'prettier')) then
    return path_join(root_dir, 'node_modules', 'prettier', 'bin-prettier.js')
  end
  return path_join('~', 'node_modules', 'prettier', 'bin-prettier.js')
end

local function prettier_config()
  local bufnr = vim.api.nvim_get_current_buf()
  local root_dir = utils.buffer_find_file_dir(bufnr, 'prettier.config.js')
  if not root_dir or root_dir == '' then rootDir = utils.find_root_git_dir() end

  local prettier_executable = get_prettier_executable(root_dir)
  local config_path = utils.is_hubspot_machine and path_join(root_dir, 'prettier.config.js') or "~/prettier.config.js"

  return {
    exe = prettier_executable,
    args = {"--stdin-filepath", vim.api.nvim_buf_get_name(0), '--config', config_path},
    stdin = true
  }
end
return { "mhartington/formatter.nvim", config = function()

require('formatter').setup({
  logging = false,
  filetype = {
    javascript = {prettier_config},

    javascriptreact = {prettier_config},

    typescript = {prettier_config},

    typescriptreact = {prettier_config},

    mdx = {
      -- prettier
      function()
        return {
          exe = prettier_executable,
          args = {"--stdin-filepath", vim.api.nvim_buf_get_name(0), '--config ~/prettier.config.js'},
          stdin = true
        }
      end
    },

    -- https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix
    -- luarocks install --server=https://luarocks.org/dev luaformatter
    lua = {
      function()
        return {
          exe = "lua-format",
          args = {
            vim.api.nvim_buf_get_name(0), "--indent-width=2", "--no-align-parameter", "--tab-width=2",
            "--align-table-field", "--chop-down-parameter", "--no-break-after-operator", "--column-limit=120",
            "--break-after-table-lb"
          },
          stdin = true
        }
      end
    }
  }
})

vim.api.nvim_exec([[
                au! BufRead,BufNewFile *.mdx setfiletype mdx
                augroup FormatAutogroup
                autocmd!
                autocmd BufWritePost *.js,*.ts,*.tsx,*.lua,*.mdx FormatWrite
                augroup END
                ]], true)

end
}

