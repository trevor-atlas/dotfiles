local M = {}

local utils = require('utils')

local supported_filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
}

local severities = {
  vim.diagnostic.severity.WARN,
  vim.diagnostic.severity.ERROR,
}

local function read_json_file(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*a')
  file:close()

  if not content or content == '' then return nil end

  local ok, decoded = pcall(vim.json.decode, content, { luanil = { object = true, array = true } })
  if not ok then return nil end

  return decoded
end

local function package_uses_hs_eslint(package_json_path)
  if vim.fn.filereadable(package_json_path) == 0 then return false end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json_path), '\n'))
  if not ok or type(decoded) ~= 'table' then return false end

  return (decoded.bpm and decoded.bpm.deps and decoded.bpm.deps['hs-eslint'])
    or (decoded.scripts and decoded.scripts.lint and decoded.scripts.lint:find('hs%-eslint'))
end

local function find_hs_eslint_root(bufname)
  local dir = vim.fs.dirname(bufname)

  while dir and dir ~= '' do
    local package_json_path = vim.fs.joinpath(dir, 'package.json')
    if package_uses_hs_eslint(package_json_path) then return dir end

    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end

  return nil
end

local function has_eslint_client(bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr, name = 'eslint' }) > 0
end

local function lint_output_path(bufnr)
  local dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'lint', 'hs-eslint')
  vim.fn.mkdir(dir, 'p')
  return vim.fs.joinpath(dir, ('%s.json'):format(bufnr))
end

local function build_linter(bufnr, cwd, bufname)
  local output_path = lint_output_path(bufnr)
  local ok = pcall(vim.uv.fs_unlink, output_path)
  if not ok then
    vim.fn.delete(output_path)
  end

  local env = vim.fn.environ()
  env.HS_ESLINT_UNHOSTED_MODE = 'true'

  return {
    name = 'hs_eslint',
    cmd = 'bend',
    cwd = cwd,
    stdin = false,
    ignore_exitcode = true,
    env = env,
    args = {
      'hs-eslint',
      '--output-file',
      output_path,
      bufname,
    },
    parser = function(_, target_bufnr)
      local decoded = read_json_file(output_path)
      if not decoded then return {} end

      local diagnostics = {}
      local results = decoded.results or decoded

      for _, result in ipairs(results or {}) do
        for _, message in ipairs(result.messages or {}) do
          table.insert(diagnostics, {
            lnum = message.line and (message.line - 1) or 0,
            end_lnum = message.endLine and (message.endLine - 1) or nil,
            col = message.column and (message.column - 1) or 0,
            end_col = message.endColumn and (message.endColumn - 1) or nil,
            message = message.message,
            code = message.ruleId,
            severity = severities[message.severity] or vim.diagnostic.severity.ERROR,
            source = 'hs-eslint',
            bufnr = target_bufnr,
          })
        end
      end

      return diagnostics
    end,
  }
end

local function maybe_run_hs_eslint(bufnr)
  if not utils.is_hubspot_machine then return end
  if not supported_filetypes[vim.bo[bufnr].filetype] then return end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' or vim.fn.filereadable(bufname) == 0 then return end

  local cwd = find_hs_eslint_root(bufname)
  if not cwd then return end

  local lint = require('lint')
  local ns = lint.get_namespace('hs_eslint')

  if has_eslint_client(bufnr) then
    vim.diagnostic.reset(ns, bufnr)
    return
  end

  lint.linters.hs_eslint = function()
    return build_linter(bufnr, cwd, bufname)
  end

  lint.try_lint('hs_eslint', { cwd = cwd })
end

function M.setup()
  if not utils.is_hubspot_machine then return end

  local group = vim.api.nvim_create_augroup('HsEslintFallback', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    group = group,
    pattern = { '*.js', '*.jsx', '*.ts', '*.tsx', '*.cjs', '*.mjs' },
    callback = function(args) maybe_run_hs_eslint(args.buf) end,
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == 'eslint' then
        vim.diagnostic.reset(require('lint').get_namespace('hs_eslint'), args.buf)
      end
    end,
  })

  vim.api.nvim_create_user_command('HsEslint', function()
    maybe_run_hs_eslint(vim.api.nvim_get_current_buf())
  end, {})
end

return M
