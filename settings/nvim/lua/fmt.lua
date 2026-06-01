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
    project_prettier = {
      inherit = false,
      command = function(_, ctx)
        return repo.find_local_prettier(ctx.filename) or vim.v.progpath
      end,
      args = { '--stdin-filepath', '$FILENAME' },
      stdin = true,
      condition = function(_, ctx)
        return not repo.is_hubspot_repo(ctx.filename) and repo.find_local_prettier(ctx.filename) ~= nil
      end,
    },
  },
})

local java_spotless_group = vim.api.nvim_create_augroup('JavaSpotlessFormat', { clear = true })
local running_modules = {}

vim.api.nvim_create_autocmd('BufWritePost', {
  group = java_spotless_group,
  pattern = '*.java',
  callback = function(args)
    if vim.bo[args.buf].buftype ~= '' then return end
    if not repo.is_hubspot_repo(args.buf) or not repo.is_mill_repo(args.buf) then return end

    local module_name = repo.find_mill_module_name(args.buf)
    local root = repo.find_mill_root(args.buf)
    if not module_name or not root or vim.fn.executable('mill') ~= 1 then return end

    local key = root .. '::' .. module_name
    if running_modules[key] then return end
    running_modules[key] = true

    local filename = vim.api.nvim_buf_get_name(args.buf)
    local before = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, false), '\n')

    vim.system({ 'mill', module_name .. '.spotless' }, {
      cwd = root,
      env = { MILL_NO_SEPARATE_BSP_OUTPUT_DIR = '1' },
    }, function(result)
      running_modules[key] = nil

      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify('Spotless failed for ' .. module_name, vim.log.levels.ERROR)
          return
        end

        local after = table.concat(vim.fn.readfile(filename), '\n')
        local changed = after ~= before

        if vim.api.nvim_buf_is_valid(args.buf) and vim.api.nvim_buf_get_name(args.buf) == filename and not vim.bo[args.buf].modified then
          vim.api.nvim_buf_call(args.buf, function()
            vim.cmd('checktime')
          end)
        end

        if changed then
          vim.notify('Spotless formatted ' .. vim.fs.basename(filename), vim.log.levels.INFO)
        end
      end)
    end)
  end,
})
