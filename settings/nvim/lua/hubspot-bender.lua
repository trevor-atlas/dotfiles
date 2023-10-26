local M = {}
local Job = require('plenary.job')
local log = require('vim.lsp.log')
local utils = require('utils')

local jsJsx = 'javascript.jsx'
local js = 'javascript'
local ts = 'typescript'
local tsJsx = 'typescript.jsx'
local jsReact = 'javascriptreact'
local tsReact = 'typescriptreact'

-- vim.lsp.set_log_level('trace')

local function log_error(msg) log.error('🚨🤖🚨', msg) end
local function log_info(msg) log.info('🤖', msg) end

local filetypes = {
  [jsJsx] = true,
  [js] = true,
  [ts] = true,
  [tsJsx] = true,
  [jsReact] = true,
  [tsReact] = true,
}

local find_node_modules_ancestor = require('lspconfig').util.find_node_modules_ancestor
local path_join = require('lspconfig').util.path.join
local function get_git_root() return vim.fn.finddir('.git/..', vim.fn.expand('%:p:h') .. '.;') end
local uv = vim.loop
local current_project_roots = {}
local current_process = nil

local function has_value(tab, val)
  for index, value in ipairs(tab) do
    if value == val then return true end
  end
  return false
end

local function reduce_array(arr, fn, init)
  local acc = init
  for k, v in ipairs(arr) do
    if 1 == k and not init then
      acc = v
    else
      acc = fn(acc, v)
    end
  end
  return acc
end

local jobId = 0

function trimString(s) return s:match('^%s*(.-)%s*$') end

-- local function getLogPath() return vim.lsp.get_log_path() end

local function shutdownCurrentProcess()
  if current_process then
    log_info('shutting down current process')
    uv.kill(-current_process.pid, uv.constants.SIGTERM)
    current_process = nil
  end
end

local function jobLogger(data)
  if data ~= nil then
    local prefix = 'asset-bender process #' .. jobId .. ' - '
    log_info(prefix .. vim.inspect(data))
  end
end

local function startAssetBenderProcess(rootsArray)
  local baseArgs = {
    'reactor',
    'host',
    '--host-most-recent',
    100,
  }

  local baseArgsWithWorkspaces = reduce_array(rootsArray, function(accumulator, current)
    table.insert(accumulator, current)
    return accumulator
  end, baseArgs)

  log_info('Starting NEW asset-bender with args, ' .. vim.inspect(baseArgsWithWorkspaces))

  local newJob = Job:new({
    command = 'bend',
    args = baseArgsWithWorkspaces,
    detached = true,
    on_exit = function(j, signal)
      jobLogger('process exited')
      jobLogger(j:result())
      jobLogger(signal)
    end,
    on_stdout = function(error, data) jobLogger(data) end,
    on_stderr = function(error, data) jobLogger(data) end,
  })

  newJob:start()

  jobId = jobId + 1

  return newJob
end

function M.check_start_javascript_lsp()
  log_info('Checking if we need to start a process')
  local bufnr = vim.api.nvim_get_current_buf()

  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  -- Filter which files we are considering.
  if not filetypes[ft] then
    log_info("found this filetype that isnt what we're looking for: " .. ft .. ' for buffer number: ' .. bufnr)
    return
  end

  -- Try to find our root directory (a directory which contains .git)
  local root_dir = get_git_root()
  log_info('Found root dir: ' .. root_dir)

  -- We couldn't find a root directory, so ignore this file.
  if not root_dir or root_dir == nil or root_dir == '' then
    log_error('we couldnt find a root directory, ending')
    return
  end

  -- if the current root_dir is not in the current_project_roots, then we must stop the current process and start a new one with the new root
  if has_value(current_project_roots, root_dir) then return end

  log_info('⚠️ detected new root, shutting down current process and starting another')
  shutdownCurrentProcess()
  table.insert(current_project_roots, root_dir)
  current_process = startAssetBenderProcess(current_project_roots)
  log_info('started new process, ' .. vim.inspect(current_process))
  log_info('current roots' .. vim.inspect(current_project_roots))
end

local commandName = 'BufEnter'
local function setupAutocommands()

  if not utils.is_hubspot_machine then
    log_info('not a HubSpot machine, skipping setting up autocommands')
    return
  end
  log_info('setting up autocommands')
  local group = vim.api.nvim_create_augroup('asset-bender.nvim', { clear = true })

  vim.api.nvim_create_autocmd(commandName, {
    group = group,
    desc = 'asset-bender.nvim will check if it needs to start a new process on the event: ' .. commandName,
    callback = function()
        local data = {
          buf = vim.fn.expand('<abuf>'),
          file = vim.fn.expand('<afile>'),
          match = vim.fn.expand('<amatch>'),
        }
        vim.schedule(M.check_start_javascript_lsp)
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'shut down asset-bender process before exiting',
    callback = function()
        vim.schedule(M.stop)
    end,
  })

  log_info('Asset bender intialized')
end

function M.stop() shutdownCurrentProcess() end

function M.setup() setupAutocommands() end

function M.reset()
  log_info('"reset" called - running LspStop, cancelling current asset-bender process, resetting roots, and running LspStart')
  vim.cmd('LspStop')
  current_project_roots = {}
  shutdownCurrentProcess()
  vim.cmd('LspStart')
end

local LATEST = 'latest'

function M.getTsServerPathForCurrentFile()
  if not utils.is_hubspot_machine then
    return nil
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  -- local _path, _filename, ft = splitFilename(path)

  --[[ Filter which files we are considering.
	if not fileExtensions[ft] then
		log.error(
			"asset-bender-tsserver-notification",
			"found this filetype that isnt what we're looking for: " .. ft .. " for buffer number: " .. bufnr
		)
		return LATEST
	end]]
  --

  local directoryOfNodeModules = find_node_modules_ancestor(path)

  if directoryOfNodeModules == '' or not directoryOfNodeModules then
    log_info('node_modules not found for current file, skipping auto-sense of hs-typescript/tsserver version')
    return LATEST
  end

  log_info('node_modules found at ' .. directoryOfNodeModules .. ' - will parse the package.json in that directory for the hs-typescript version')

  local pathOfPackageJson = path_join(directoryOfNodeModules, 'package.json')

  local getVersionResult = { stdout = '', stderr = '' }
  Job:new({
    command = 'jq',
    args = { '-r', '.bpm.deps.["hs-typescript"]', pathOfPackageJson },
    on_stdout = function(error, data) getVersionResult.stdout = data end,
    on_stderr = function(error, data) getVersionResult.stderr = data end,
  }):sync()

  if getVersionResult.stderr ~= '' then
    log_error('there was an error reading hs-typescript version' .. getVersionResult.stderr)
    return LATEST
  end

  local hsTypescriptVersion = getVersionResult.stdout
  hsTypescriptVersion = hsTypescriptVersion:gsub('"', '')
  hsTypescriptVersion = hsTypescriptVersion:gsub('\n', '')
  log_info('found an hs-typescript version of ' .. hsTypescriptVersion)

  local getHsTypescriptPathResult = { stdout = '', stderr = '' }
  Job:new({
    command = 'bpx',
    args = { '--path', string.format('hs-typescript@%s', hsTypescriptVersion) },
    on_stdout = function(error, data) getHsTypescriptPathResult.stdout = data end,
    on_stderr = function(error, data) getHsTypescriptPathResult.stderr = data end,
  }):sync()

  if getHsTypescriptPathResult.stderr ~= '' then
    log_error(
      'there was an error determining the path of hs-typescript from version number: ' .. hsTypescriptVersion .. '\n' .. getHsTypescriptPathResult.stderr
    )
    return LATEST
  end

  local hsTypescriptPath = getHsTypescriptPathResult.stdout
  hsTypescriptPath = hsTypescriptPath:gsub('"', '')
  hsTypescriptPath = hsTypescriptPath:gsub('\n', '')
  log_info('Using typescript path' .. hsTypescriptPath)
  return hsTypescriptPath
end

return M
