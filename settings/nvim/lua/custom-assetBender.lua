local jsJsx = 'javascript.jsx'
local js = 'javascript'
local ts = 'typescript'
local tsJsx = 'typescript.jsx'
local jsReact = 'javascriptreact'
local tsReact = 'typescriptreact'

local filetypes = {
  defaultConfig = {
    [jsJsx] = true,
    [js] = true,
    [ts] = true,
    [tsJsx] = true,
    [jsReact] = true,
    [tsReact] = true,
  },
}

-- This is for some HubSpot specific stuff to get LSP working for javascript and typescript.
-- HubSpot decided the standard node runtime the rest of the world runs on wasn't good enough
-- for them and built a bunch of custom nonsense on top of it like `static_conf.json` which is
-- basically doing the same kinds of things pnpm does, but custom and not compatible with
-- any editor that isn't running their custom LSP setup.

local M = {}
local Job = require('plenary.job')
local log = require('plenary.log').new({ plugin = 'asset-bender', use_console = false })
local is_hubspot_machine = require('utils').is_hubspot_machine

local path_join = require('bobrown101.plugin-utils').path_join

local buffer_find_root_dir = require('bobrown101.plugin-utils').buffer_find_root_dir

local is_dir = require('bobrown101.plugin-utils').is_dir

local filetypes = filetypes.defaultConfig

local uv = vim.loop

local current_project_roots = {}
local current_process = nil

local function has_value(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
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

function trimString(s)
  return s:match('^%s*(.-)%s*$')
end

local function getLogPath()
  return vim.lsp.get_log_path()
end

local function shutdownCurrentProcess()
  if current_process then
    log.info('shutting down current process')
    uv.kill(-current_process.pid, uv.constants.SIGTERM)
    current_process = nil
  end
end

local function startAssetBenderProcess(rootsArray)
  log.info('Asset Bender starting new client')

  local baseArgs = { 'reactor', 'host', '--host-most-recent', 100 }

  local baseArgsWithWorkspaces = reduce_array(rootsArray, function(accumulator, current)
    table.insert(accumulator, current)
    return accumulator
  end, baseArgs)

  log.info('Starting NEW asset-bender with args, ' .. vim.inspect(baseArgsWithWorkspaces))

  local function jobLogger(data)
    if data ~= nil then
      local prefix = 'asset-bender process #' .. jobId .. ' - '
      log.info(prefix .. vim.inspect(data))
    end
  end

  local newJob = Job:new({
    command = 'bend',
    args = baseArgsWithWorkspaces,
    detached = true,
    on_exit = function(j, signal)
      jobLogger('process exited')
      jobLogger(j:result())
      jobLogger(signal)
    end,
    on_stdout = function(error, data)
      jobLogger(data)
    end,
    on_stderr = function(error, data)
      jobLogger(data)
    end,
  })

  newJob:start()

  jobId = jobId + 1

  return newJob
end

function M.check_start_javascript_lsp()
  log.info('Checking if we need to start a process')
  if not is_hubspot_machine then
    log.info('Not a HubSpot machine. Skipping.')
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()

  -- Filter which files we are considering.
  if not filetypes[vim.api.nvim_buf_get_option(bufnr, 'filetype')] then
    return
  end

  -- Try to find our root directory. We will define this as a directory which contains
  -- .git. Another choice would be to check for `package.json`, or for `node_modules`.
  local root_dir = buffer_find_root_dir(bufnr, function(dir)
    -- return is_dir(path_join(dir, 'node_modules'))
    -- return vim.fn.filereadable(path_join(dir, 'package.json')) == 1
    return is_dir(path_join(dir, '.git'))
  end)

  -- We couldn't find a root directory, so ignore this file.
  if not root_dir then
    log.info('we couldnt find a root directory, ending')
    return
  end

  -- if the current root_dir is not in the current_project_roots, then we must stop the current process and start a new one with the new root
  if not has_value(current_project_roots, root_dir) then
    log.info('asset-bender.nvim - detected new root, shutting down current process and starting another')

    shutdownCurrentProcess()

    table.insert(current_project_roots, root_dir)

    current_process = startAssetBenderProcess(current_project_roots)

    log.info('started new process, ' .. vim.inspect(current_process))
  end
end

local function setupAutocommands()
  log.info('setting up autocommands')
  local group = vim.api.nvim_create_augroup('asset-bender.nvim', { clear = true })

  log.info('group created')
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    desc = 'asset-bender.nvim will check if it needs to start a new process on the BufReadPost event',
    callback = function()
      local data = { buf = vim.fn.expand('<abuf>'), file = vim.fn.expand('<afile>'), match = vim.fn.expand('<amatch>') }
      vim.schedule(function()
        M.check_start_javascript_lsp()
      end)
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'shut down asset-bender process before exiting',
    callback = function()
      vim.schedule(M.stop)
    end,
  })

  log.info('autocommand created')
  log.info('Asset bender plugin intialized')
end

function M.stop()
  shutdownCurrentProcess()
end

function M.setup()
  setupAutocommands()
end

function M.reset()
  log.info('"reset" called - running LspStop, cancelling current asset-bender process, resetting roots, and running LspStart')
  vim.cmd('LspStop')
  current_project_roots = {}
  shutdownCurrentProcess()
  vim.cmd('LspStart')
  print('Open a new file, or re-open an existing one with ":e" for asset-bender.nvim to start a new process')
end

return M
