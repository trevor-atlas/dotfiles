local M = {}

local repo = require('repo')
local lsp_attach = require('lsp_attach')

local filetypes = { 'java', 'scala', 'sbt' }
local registered = false
local pending_bsp_installs = {}

local function get_root(bufnr)
  return repo.find_mill_root(bufnr)
end

local function bsp_config_path(root)
  return vim.fs.joinpath(root, '.bsp', 'mill-bsp.json')
end

local function on_attach(client, bufnr)
  local metals = require('metals')
  local nmap = function(keys, func, desc)
    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = 'Metals: ' .. desc })
  end

  lsp_attach.common_on_attach(client, bufnr)
  metals.setup_dap()

  nmap('<leader>mg', M.install_mill_bsp, 'Install Mill [G]SP config')
  nmap('<leader>mc', metals.connect_build, '[C]onnect build')
  nmap('<leader>mi', metals.import_build, '[I]mport build')
  nmap('<leader>mo', metals.organize_imports, '[O]rganize imports')
  nmap('<leader>mb', metals.restart_build_server, 'Restart [B]uild server')
  nmap('<leader>md', metals.run_doctor, '[D]octor')
  nmap('<leader>mr', metals.restart_metals, '[R]estart server')
  nmap('<leader>mR', M.clean_mill_cache, 'Clean Mill cache and restart')
end

local function build_config(bufnr)
  local metals = require('metals')
  local config = metals.bare_config()

  config.root_dir = get_root(bufnr)
  config.capabilities = require('blink.cmp').get_lsp_capabilities()
  config.on_attach = on_attach
  config.settings = {
    automaticImportBuild = 'initial',
    defaultBspToBuildTool = true,
    superMethodLensesEnabled = true,
    targetBuildTool = 'mill',
    testUserInterface = 'code lenses',
  }
  config.init_options = config.init_options or {}
  config.init_options.statusBarProvider = 'on'

  return config
end

local function install_mill_bsp(root, callback)
  if pending_bsp_installs[root] then return end

  pending_bsp_installs[root] = true
  vim.notify('Installing Mill BSP config…', vim.log.levels.INFO)
  vim.system({ 'sh', '-c', 'MILL_NO_SEPARATE_BSP_OUTPUT_DIR=1 mill --bsp-install' }, { cwd = root }, function(result)
    pending_bsp_installs[root] = nil

    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify('Failed to install Mill BSP config', vim.log.levels.ERROR)
        if callback then callback(false) end
        return
      end

      vim.notify('Mill BSP config installed', vim.log.levels.INFO)
      if callback then callback(true) end
    end)
  end)
end

function M.maybe_attach(bufnr)
  local root = get_root(bufnr)
  if not root then return end

  if not vim.uv.fs_stat(bsp_config_path(root)) then
    install_mill_bsp(root, function(ok)
      if ok and vim.api.nvim_buf_is_valid(bufnr) then M.maybe_attach(bufnr) end
    end)
    return
  end

  vim.env.MILL_NO_SEPARATE_BSP_OUTPUT_DIR = '1'
  require('metals').initialize_or_attach(build_config(bufnr))
end

function M.install_mill_bsp()
  local root = get_root(0)
  if not root then
    vim.notify('No Mill workspace found for this buffer', vim.log.levels.WARN)
    return
  end

  install_mill_bsp(root)
end

function M.clean_mill_cache()
  local root = get_root(0)
  if not root then
    vim.notify('No Mill workspace found for this buffer', vim.log.levels.WARN)
    return
  end

  local ok, metals = pcall(require, 'metals')
  if ok then pcall(metals.disconnect_build_and_shutdown) end

  vim.notify('Cleaning Mill and BSP caches…', vim.log.levels.INFO)

  vim.system({ 'mill', 'shutdown' }, { cwd = root }, function()
    vim.system({ 'rm', '-rf', 'out', '.bsp/out', '.bsp/mill-bsp-out' }, { cwd = root }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify('Failed to clear Mill caches', vim.log.levels.ERROR)
          return
        end

        vim.notify('Mill caches cleared. Restarting Metals…', vim.log.levels.INFO)
        if ok then
          metals.restart_metals()
        else
          M.maybe_attach(vim.api.nvim_get_current_buf())
        end
      end)
    end)
  end)
end

function M.register()
  if registered then return end

  local group = vim.api.nvim_create_augroup('nvim-metals', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = filetypes,
    callback = function(args)
      M.maybe_attach(args.buf)
    end,
  })

  vim.api.nvim_create_user_command('MetalsInstallMillBsp', M.install_mill_bsp, {
    desc = 'Install Mill BSP config for the current workspace',
  })

  vim.api.nvim_create_user_command('MetalsCleanMillCache', M.clean_mill_cache, {
    desc = 'Clear Mill and BSP caches, then restart Metals',
  })

  registered = true
end

return M
