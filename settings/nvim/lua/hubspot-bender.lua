local M = {}
local log = require("vim.lsp.log")
local util = require("lspconfig.util")

local find_node_modules_ancestor = require("lspconfig").util.find_node_modules_ancestor
local path_join = require("lspconfig").util.path.join

vim.lsp.set_log_level("OFF")

local function log_error(msg)
  log.error("🚨🤖🚨", msg)
end
local function log_info(msg)
  log.info("🤖", msg)
end
local is_hubspot_machine = vim.loop.fs_stat(vim.env.HOME .. "/.hubspot")

local js_jsx = "javascript.jsx"
local js = "javascript"
local ts = "typescript"
local ts_tsx = "typescript.jsx"
local js_react = "javascriptreact"
local ts_react = "typescriptreact"

local filetypes = {
  [js_jsx] = true,
  [js] = true,
  [ts] = true,
  [ts_tsx] = true,
  [js_react] = true,
  [ts_react] = true,
}

local function get_project_root(startdir)
  return util.root_pattern(".git", "yarn.lock", "package.json")(startdir)
end
local function is_none(value)
  return value == nil or value == ""
end

local function contains(table, target)
  for _, value in pairs(table) do
    if value == target then
      return true
    end
  end
  return false
end

local LATEST = "latest"
local current_project_roots = {}
local current_process = nil
local job_id = 0

local function shutdown_current_process()
  if current_process then
    log_info("shutting down current process")
    vim.loop.kill(-current_process, vim.loop.constants.SIGTERM)
    current_process = nil
  end
end

local function should_handle_file(bufnr)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  -- Filter which files we are considering.
  if not filetypes[filetype] then
    log_info("found this filetype that isnt what we're looking for: " .. filetype .. " for buffer number: " .. bufnr)
    return false
  end
  return true
end

local function job_logger(data)
  if is_none(data) then
    return
  end
  log_info("process #" .. job_id .. " - " .. vim.inspect(data))
end

local function start_asset_bender(rootsArray)
  local args = { "bend", "reactor", "host", "--host-most-recent", 100, unpack(rootsArray) }
  log_info("Starting NEW asset-bender with args: " .. vim.inspect(args))

  local job = vim.system(args, {
    stdout = function(err, data)
      job_logger(data)
    end,
    stderr = function(err, data)
      job_logger(data)
    end,
    text = true,
    detach = true,
  }, function(result)
    job_logger("process exited")
    job_logger(result.stdout)
    job_logger(result.signal)
    job_logger(result.code)
    current_process = nil
  end)

  -- Check if the job started successfully
  if job.pid <= 0 then
    log_error("Failed to start the job!")
    return
  else
    current_process = job.pid
    job_id = job_id + 1
  end

  log_info("started new process, " .. vim.inspect(current_process))
  log_info("current roots" .. vim.inspect(current_project_roots))
end

function M.check_start_javascript_lsp()
  log_info("Checking if we need to start a process")

  local bufnr = vim.api.nvim_get_current_buf()
  if not should_handle_file(bufnr) then
    return
  end

  local root_dir = get_project_root(vim.fn.expand("%:p"))

  -- We couldn't find a root directory, so ignore this file.
  if is_none(root_dir) then
    log_error("we couldnt find a root directory, ending")
    return
  end

  -- if the current root_dir is not in the current_project_roots, then we must stop the current process and start a new one with the new root
  if contains(current_project_roots, root_dir) then
    return
  end

  log_info("⚠️ detected new root, shutting down current process and starting another")
  shutdown_current_process()
  table.insert(current_project_roots, root_dir)
  start_asset_bender(current_project_roots)
end

local command_name = "BufEnter"
local function setup_autocommands()
  if not is_hubspot_machine then
    log_info("not a HubSpot machine, skipping setting up autocommands")
    return
  end
  log_info("setting up autocommands")
  local group = vim.api.nvim_create_augroup("asset-bender.nvim", { clear = true })

  vim.api.nvim_create_autocmd(command_name, {
    group = group,
    desc = "asset-bender will check if it needs to start a new process",
    callback = function()
      local data = {
        buf = vim.fn.expand("<abuf>"),
        file = vim.fn.expand("<afile>"),
        match = vim.fn.expand("<amatch>"),
      }
      vim.schedule(M.check_start_javascript_lsp)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    desc = "shut down asset-bender process before exiting",
    callback = function()
      vim.schedule(M.stop)
    end,
  })

  log_info("Asset bender intialized")
end

function M.stop()
  shutdown_current_process()
end

function M.setup()
  setup_autocommands()
end

function M.reset()
  log_info(
    '"reset" called - running LspStop, cancelling current asset-bender process, resetting roots, and running LspStart'
  )
  vim.cmd("LspStop")
  current_project_roots = {}
  shutdown_current_process()
  vim.cmd("LspStart")
end

function M.getTsServerPathForCurrentFile()
  local bufnr = vim.api.nvim_get_current_buf()
  if not should_handle_file(bufnr) then
    return LATEST
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local node_module_dir = find_node_modules_ancestor(path)

  if is_none(node_module_dir) then
    log_info("node_modules not found for current file, skipping auto-sense of hs-typescript/tsserver version")
    return LATEST
  end

  log_info(
    "node_modules found at "
      .. node_module_dir
      .. " - will parse the package.json in that directory for the hs-typescript version"
  )

  local packagejson_path = path_join(node_module_dir, "package.json")
  local version_check = vim
    .system({ "jq", "-r", '.bpm.deps.["hs-typescript"]', packagejson_path }, { text = true })
    :wait()

  if version_check.stderr ~= "" then
    log_error("there was an error reading hs-typescript version" .. version_check.stderr)
    return LATEST
  end

  local version = version_check.stdout
  version = version:gsub('"', "")
  version = version:gsub("\n", "")
  log_info("found an hs-typescript version of " .. version)

  local resolved_version_path = vim
    .system({ "bpx", "--path", string.format("hs-typescript@%s", version) }, { text = true })
    :wait()

  if resolved_version_path.stderr ~= "" then
    log_error(
      "there was an error determining the path of hs-typescript from version number: "
        .. version
        .. "\n"
        .. resolved_version_path.stderr
    )
    return LATEST
  end

  local typescript_path = resolved_version_path.stdout
  typescript_path = typescript_path:gsub('"', "")
  typescript_path = typescript_path:gsub("\n", "")
  log_info("Using typescript path" .. typescript_path)
  return typescript_path
end

return M
