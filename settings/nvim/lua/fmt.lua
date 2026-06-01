local repo = require('repo')

local prettier_filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  mdx = true,
}

local function format_on_save(bufnr)
  if vim.bo[bufnr].buftype ~= '' then return nil end

  local filetype = vim.bo[bufnr].filetype
  if filetype == 'lua' or prettier_filetypes[filetype] then
    return {
      timeout_ms = 1000,
      lsp_format = 'never',
      quiet = true,
    }
  end

  return nil
end

require('conform').setup({
  notify_no_formatters = false,
  format_on_save = format_on_save,
  formatters_by_ft = {
    javascript = { 'hs_prettier', 'project_prettier', stop_after_first = true },
    javascriptreact = { 'hs_prettier', 'project_prettier', stop_after_first = true },
    typescript = { 'hs_prettier', 'project_prettier', stop_after_first = true },
    typescriptreact = { 'hs_prettier', 'project_prettier', stop_after_first = true },
    mdx = { 'hs_prettier', 'project_prettier', stop_after_first = true },
    lua = { 'stylua' },
  },
  formatters = {
    hs_prettier = {
      inherit = false,
      command = 'bpx',
      args = { 'hs-prettier', '--stdin-filepath', '$FILENAME' },
      stdin = true,
      condition = function(_, ctx)
        return vim.fn.executable('bpx') == 1 and repo.is_hubspot_repo(ctx.filename)
      end,
    },
    project_prettier = function(bufnr)
      local prettier = repo.find_local_prettier(bufnr)
      if not prettier or repo.is_hubspot_repo(bufnr) then return nil end

      return {
        inherit = false,
        command = prettier,
        args = { '--stdin-filepath', '$FILENAME' },
        stdin = true,
      }
    end,
  },
})
