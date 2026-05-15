local M = {}

local lspconfig_util = require('lspconfig.util')
local get_lib_dir = lspconfig_util.root_pattern('tsconfig.json', 'webpack.config.js', 'target')
local get_root = lspconfig_util.root_pattern('.git', '.blazar-enabled', 'package.json')
local ns = vim.api.nvim_create_namespace('hs_i18n_diagnostics')

local function debounce(fn, delay_ms)
  local timer = vim.uv.new_timer()
  return function(...)
    local argv = { ... }
    timer:stop()
    timer:start(delay_ms, 0, vim.schedule_wrap(function() fn(unpack(argv)) end))
  end
end

-- ── Cache ─────────────────────────────────────────────────────────────────────

M.cache = {
  -- { ["/path/to/app"] = { ["some.key"] = { value = "Some english string value", file = "/path/to/en.lyaml", row = 42, col = 2 } } }
  -- file/row/col are nil for keys sourced from imported packages
  ---@type table<string, table<string, {value: string, file: string|nil, row: integer|nil, col: integer|nil}>>
  translations = {},
}

-- ── Root detection ────────────────────────────────────────────────────────────

---@param bufnr number|nil
---@return string|nil
function M.get_root_dir(bufnr)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  return get_root(buffer_path)
end

---@param bufnr number|nil
---@return string|nil
function M.get_app_or_lib_dir(bufnr)
  local buffer_path = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  return get_lib_dir(buffer_path)
end

-- ── Translation parsing ───────────────────────────────────────────────────────

local static_archive = vim.env.HOME .. '/.hubspot/static-archive'

local function get_required_packages(file_path)
  local pkgs = {}
  local f = io.open(file_path, 'r')
  if not f then return pkgs end
  for line in f:lines() do
    local pkg = line:match('^#=%s*require_lang%s+([^/]+)/lang/')
    if pkg then table.insert(pkgs, pkg) end
  end
  f:close()
  return pkgs
end

local function resolve_package_lang(pkg_name, git_root)
  local local_path = git_root .. '/' .. pkg_name .. '/static/lang/en.lyaml'
  if vim.loop.fs_stat(local_path) then return local_path end

  local version_tags = static_archive .. '/' .. pkg_name .. '/version-tags'
  if not vim.loop.fs_stat(version_tags) then return nil end

  local handle = vim.loop.fs_opendir(version_tags)
  if not handle then return nil end
  local result = nil
  while not result do
    local entries = vim.loop.fs_readdir(handle)
    if not entries then break end
    for _, entry in ipairs(entries) do
      if entry.name:match('%-latest$') then
        local f = io.open(version_tags .. '/' .. entry.name, 'r')
        if f then
          local version_dir = f:read('l')
          f:close()
          if version_dir and version_dir ~= '' then
            local lang = static_archive .. '/' .. pkg_name .. '/' .. version_dir .. '/lang/en.lyaml'
            if vim.loop.fs_stat(lang) then result = lang end
          end
        end
      end
    end
  end
  vim.loop.fs_closedir(handle)
  return result
end

local file_cache = {}
local import_cache = {}
local pkg_resolve_cache = {}

local function resolve_package_lang_cached(pkg_name, git_root)
  local k = pkg_name .. '|' .. git_root
  if pkg_resolve_cache[k] ~= nil then return pkg_resolve_cache[k] or nil end
  local result = resolve_package_lang(pkg_name, git_root)
  pkg_resolve_cache[k] = result or false
  return result
end

local function collect_mappings(node, source, prefix, file_path)
  local result = {}
  for child in node:iter_children() do
    if child:type() ~= 'block_mapping_pair' then goto skip end

    local key_field = child:field('key')
    if not key_field or #key_field == 0 then goto skip end
    local raw_key = vim.treesitter.get_node_text(key_field[1], source)
    local key = raw_key:match('^"(.*)"$') or raw_key:match("^'(.*)'$") or raw_key
    local full_key = prefix ~= '' and (prefix .. '.' .. key) or key

    local val_field = child:field('value')
    if not val_field or #val_field == 0 then goto skip end
    local val = val_field[1]

    if val:type() == 'block_node' then
      local inner = val:named_child(0)
      if inner and inner:type() == 'block_mapping' then
        for k, v in pairs(collect_mappings(inner, source, full_key, file_path)) do
          result[k] = v
        end
      end
    elseif val:type() == 'flow_node' then
      local scalar = val:named_child(0)
      if scalar then
        local raw = vim.treesitter.get_node_text(scalar, source)
        local entry = { value = raw:match('^"(.*)"$') or raw:match("^'(.*)'$") or raw }
        if file_path then
          local row, col = key_field[1]:range()
          entry.file = file_path
          entry.row  = row
          entry.col  = col
        end
        result[full_key] = entry
      end
    end

    ::skip::
  end
  return result
end

local function parse_lyaml_content(content, file_path)
  local ok, parser = pcall(vim.treesitter.get_string_parser, content, 'yaml')
  if not ok then return {} end

  local tree = parser:parse()[1]
  if not tree then return {} end

  local root = tree:root()
  local document, block_node, block_mapping
  for child in root:iter_children() do
    if child:type() == 'document' then document = child; break end
  end
  if not document then return {} end
  for child in document:iter_children() do
    if child:type() == 'block_node' then block_node = child; break end
  end
  if not block_node then return {} end
  for child in block_node:iter_children() do
    if child:type() == 'block_mapping' then block_mapping = child; break end
  end
  if not block_mapping then return {} end

  for child in block_mapping:iter_children() do
    if child:type() ~= 'block_mapping_pair' then goto skip end
    local key_field = child:field('key')
    if key_field and #key_field > 0 and
       vim.treesitter.get_node_text(key_field[1], content) == 'en' then
      local val_field = child:field('value')
      if val_field and #val_field > 0 and val_field[1]:type() == 'block_node' then
        local inner = val_field[1]:named_child(0)
        if inner and inner:type() == 'block_mapping' then
          return collect_mappings(inner, content, '', file_path)
        end
      end
    end
    ::skip::
  end

  return {}
end

local function parse_lyaml_flat(file_path)
  local f = io.open(file_path, 'r')
  if not f then return {} end
  local content = f:read('*a')
  f:close()
  return parse_lyaml_content(content)
end

local function parse_file_cached(file_path)
  local f = io.open(file_path, 'r')
  if not f then return {}, false end
  local content = f:read('*a')
  f:close()
  local hash = vim.fn.sha256(content)
  local cached = file_cache[file_path]
  if cached and cached.hash == hash then return cached.data, true end
  local data = parse_lyaml_content(content, file_path)
  file_cache[file_path] = { hash = hash, data = data }
  return data, false
end

local function parse_imported_cached(file_path)
  if import_cache[file_path] then return import_cache[file_path] end
  local data = parse_lyaml_flat(file_path)
  import_cache[file_path] = data
  return data
end

-- ── Public cache API ──────────────────────────────────────────────────────────

local function _run_parse(on_done)
  local root_dir = M.get_root_dir()
  if not root_dir or root_dir == '' then
    if on_done then on_done() end
    return
  end

  vim.system({ 'rg', '--files', root_dir, '-g', 'en.lyaml' }, { text = true }, vim.schedule_wrap(function(rg_result)
    if rg_result.code ~= 0 then
      if on_done then on_done() end
      return
    end

    local file_paths = {}
    for fp in rg_result.stdout:gmatch('[^\r\n]+') do
      table.insert(file_paths, fp)
    end

    if #file_paths == 0 then
      if on_done then on_done() end
      return
    end

    ---@type table<string, table<string, {value: string, file: string|nil, row: integer|nil, col: integer|nil}>>
    local translations_by_directory = {}

    for _, file_path in ipairs(file_paths) do
      local path = file_path:gsub('/static/lang/en.lyaml', '')
      translations_by_directory[path] = {}

      local base_data = parse_file_cached(file_path)
      for k, v in pairs(base_data) do translations_by_directory[path][k] = v end

      for _, pkg in ipairs(get_required_packages(file_path)) do
        local resolved = resolve_package_lang_cached(pkg, root_dir)
        if resolved then
          for k, v in pairs(parse_imported_cached(resolved)) do
            translations_by_directory[path][k] = v
          end
        end
      end
    end

    M.set_translations(translations_by_directory)
    if on_done then on_done() end
  end))
end

---@param on_done fun()|nil
M.parse_and_cache_translations = debounce(_run_parse, 2000)

---@param translations table<string, table<string, string>>
function M.set_translations(translations)
  if translations == nil then return end
  M.cache.translations = translations
end

---@return table<string, table<string, string>>
function M.get_translations() return M.cache.translations end

---@param app_lib_dir string
---@param key string
---@return {file: string, row: integer, col: integer}|nil
function M.get_key_position(app_lib_dir, key)
  local entry = M.cache.translations[app_lib_dir] and M.cache.translations[app_lib_dir][key]
  if not entry or not entry.file then return nil end
  return { file = entry.file, row = entry.row, col = entry.col }
end

function M.reset()
  file_cache = {}
  import_cache = {}
  pkg_resolve_cache = {}
  ts_queries = {}
  M.cache.translations = {}
end

function M.debug_parse(file_path)
  file_path = file_path or vim.api.nvim_buf_get_name(0)
  local f = io.open(file_path, 'r')
  if not f then print('cannot open: ' .. file_path); return end
  local content = f:read('*a')
  f:close()

  local ok, parser = pcall(vim.treesitter.get_string_parser, content, 'yaml')
  if not ok then print('parser error: ' .. tostring(parser)); return end

  local tree = parser:parse()[1]
  if not tree then print('no tree returned'); return end

  local function dump(node, depth)
    if not node or depth > 4 then return end
    local tok, txt = pcall(vim.treesitter.get_node_text, node, content)
    txt = tok and tostring(txt):gsub('\n', '\\n') or '?'
    if #txt > 40 then txt = txt:sub(1, 40) .. '…' end
    print(string.rep('  ', depth) .. '[' .. node:type() .. '] ' .. vim.inspect(txt))
    for child in node:iter_children() do dump(child, depth + 1) end
  end

  print('=== tree (depth ≤ 4) ===')
  dump(tree:root(), 0)

  print('\n=== parsed keys (first 10) ===')
  local data = parse_lyaml_content(content)
  local n = 0
  for k, entry in pairs(data) do
    n = n + 1
    if n <= 10 then print(string.format('  %s = %s', k, tostring(entry.value):sub(1, 60))) end
  end
  print('total: ' .. n)
end

-- ── Diagnostics ───────────────────────────────────────────────────────────────

local ts_queries = {}

local function try_query(lang, str)
  local ok, q = pcall(vim.treesitter.query.parse, lang, str)
  return ok and q or nil
end

local patterns = {
  -- t('key') adds a capture for any call expression with an identifier function matching /^t$/ and a single string argument
  -- this is just for convenience to make validating translation strings outside the base i18n fns and components easier
  -- const t = (s: string) => s;
  [[
    (call_expression
      function: (identifier) @_fn (#match? @_fn "^t$")
      arguments: (arguments . (string (string_fragment) @key)))
  ]],
  -- I18n.text('key'), I18n.html('key')
  [[
    (call_expression
      function: (member_expression
        object: (identifier) @_obj (#match? @_obj "^[Ii]18[Nn]$")
        property: (property_identifier) @_method (#match? @_method "^(text|html)s?$"))
      arguments: (arguments . (string (string_fragment) @key)))
  ]],
  -- unescapedText('key'), setDocumentTitle('key')
  [[
    (call_expression
      function: (identifier) @_fn (#match? @_fn "^(unescapedText|setDocumentTitle)$")
      arguments: (arguments . (string (string_fragment) @key)))
  ]],
  [[
(jsx_self_closing_element
          name: (identifier) @_comp (#any-of? @_comp
            "FormattedMessage"
            "FormattedHTMLMessage"
            "FormattedReactMessage"
            "FormattedList"
            "FormattedName"
            "FormattedJSXMessage"
            "FormattedCurrencyLabel"
            "FormattedNumber"
            "FormattedIntlCurrency"
            "FormattedPercentage"
            "FormattedPhoneNumber"
            "FormattedSize"
            "FormattedFraction"
            "FormattedDateTime"
            "FormattedShortFullDate"
            "FormattedMediumFullDate"
            "FormattedShortQuarterYear"
            "FormattedDuration"
            "FormattedRelative"
        )
          (jsx_attribute
            [(identifier) (jsx_attribute_name)] @_attr (#eq? @_attr "message")
            (property_identifier) @_attr (#eq? @_attr "message")
            (string (string_fragment) @key)))
]],
  -- <FormattedMessage message="key" />
  [[
      (jsx_self_closing_element
        name: (identifier) @component_name (#any-of? @component_name
            "FormattedMessage"
            "FormattedHTMLMessage"
            "FormattedReactMessage"
            "FormattedList"
            "FormattedName"
            "FormattedJSXMessage"
            "FormattedCurrencyLabel"
            "FormattedNumber"
            "FormattedIntlCurrency"
            "FormattedPercentage"
            "FormattedPhoneNumber"
            "FormattedSize"
            "FormattedFraction"
            "FormattedDateTime"
            "FormattedShortFullDate"
            "FormattedMediumFullDate"
            "FormattedShortQuarterYear"
            "FormattedDuration"
            "FormattedRelative"
        )
        (jsx_attribute
            (property_identifier) @prop_name
            [
                (string
                    (string_fragment) @key)
                (jsx_expression
                    (string
                        (string_fragment) @key
                    )
                )
            ]
            (#eq? @prop_name "message")
        )
      )
    ]]
}

local function get_query(lang)
  if not ts_queries[lang] then
    local valid = {}
    for _, p in ipairs(patterns) do
      if try_query(lang, p) then table.insert(valid, p) end
    end
    if #valid > 0 then
      local ok, q = pcall(vim.treesitter.query.parse, lang, table.concat(valid, '\n'))
      if ok then ts_queries[lang] = q end
    end
  end
  return ts_queries[lang]
end

local function scan_buffer(bufnr)
  local path = M.get_app_or_lib_dir(bufnr)
  if not path then return end

  local dir_translations = M.get_translations()[path]
  if not dir_translations then return end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return end

  local query = get_query(parser:lang())
  if not query then return end

  local tree = parser:parse()[1]
  if not tree then return end

  local diagnostics = {}
  for id, node in query:iter_captures(tree:root(), bufnr) do
    if query.captures[id] == 'key' then
      local key = vim.treesitter.get_node_text(node, bufnr)
      if key and key ~= '' and not (dir_translations[key] and dir_translations[key].value) then
        local row, col, end_row, end_col = node:range()
        table.insert(diagnostics, {
          lnum = row,
          col = col,
          end_lnum = end_row,
          end_col = end_col,
          severity = vim.diagnostic.severity.WARN,
          message = 'Unknown translation key: ' .. key,
          source = 'hs-i18n',
        })
      end
    end
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

local scan_buffer_debounced = debounce(function(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then scan_buffer(bufnr) end
end, 1000)

-- ── Hover / go-to-definition ──────────────────────────────────────────────────

local function get_string_under_cursor()
  local node = vim.treesitter.get_node()
  if not node then return nil end
  local t = node:type()
  if t ~= 'string' and t ~= 'string_fragment' and t ~= 'template_string' then
    node = node:parent()
    if not node then return nil end
    t = node:type()
    if t ~= 'string' and t ~= 'template_string' then return nil end
  end
  local text = vim.treesitter.get_node_text(node, 0)
  return text:match('^[\'"`](.+)[\'"`]$') or text
end

local function show_hover(_, value)
  vim.lsp.util.open_floating_preview({ value }, 'markdown', { border = 'rounded', focus_id = 'hs_i18n_hover' })
end

local function hover(bufnr)
  local key = get_string_under_cursor()
  if key then
    local path = M.get_app_or_lib_dir(bufnr)
    if path then
      local translations = M.get_translations()
      if translations[path] == nil then M.parse_and_cache_translations() end
      local entry = (translations[path] or {})[key]
      if entry then
        show_hover(key, entry.value)
        return
      end
    end
  end
  vim.lsp.buf.hover()
end

local function goto_definition(bufnr)
  local key = get_string_under_cursor()
  if key then
    local path = M.get_app_or_lib_dir(bufnr)
    if path then
      local pos = M.get_key_position(path, key)
      if pos then
        vim.cmd.edit(pos.file)
        vim.api.nvim_win_set_cursor(0, { pos.row + 1, pos.col })
        return
      end
    end
  end
  vim.lsp.buf.definition()
end

-- ── Public utilities ──────────────────────────────────────────────────────────

local targets = { typescript = true, typescriptreact = true, javascript = true, javascriptreact = true }

function M.scan() scan_buffer(vim.api.nvim_get_current_buf()) end

function M.debug()
  local bufnr = vim.api.nvim_get_current_buf()
  print('filetype: ' .. vim.bo[bufnr].filetype)

  local path = M.get_app_or_lib_dir(bufnr)
  print('app/lib path: ' .. vim.inspect(path))

  local translations = M.get_translations()
  print('cached translation paths: ' .. vim.inspect(vim.tbl_keys(translations)))

  if path then
    local dir_t = translations[path]
    print('translation count for path: ' .. vim.inspect(dir_t and vim.tbl_count(dir_t) or 'nil'))
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  print('treesitter parser: ' .. vim.inspect(ok and parser:lang() or 'none'))

  if ok then
    local lang = parser:lang()
    local query = get_query(lang)
    print('query parsed: ' .. vim.inspect(query ~= nil))

    if query then
      local tree = parser:parse()[1]
      local count = 0
      for id, node in query:iter_captures(tree:root(), bufnr) do
        if query.captures[id] == 'key' then
          count = count + 1
          print('  capture[' .. count .. ']: ' .. vim.treesitter.get_node_text(node, bufnr))
        end
      end
      print('total key captures: ' .. count)
    end
  end
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

---@class HsI18nKeys
---@field hover string|false
---@field goto_definition string|false

---@class HsI18nOpts
---@field keys HsI18nKeys|nil

---@param opts HsI18nOpts|nil
function M.setup(opts)
  if not vim.loop.fs_stat(vim.env.HOME .. '/.hubspot') then return end

  vim.filetype.add({ extension = { lyaml = 'yaml' } })

  opts = vim.tbl_deep_extend('force', {
    keys = {
      hover           = 'K',
      goto_definition = 'gd',
    },
  }, opts or {})

  vim.api.nvim_create_user_command('HsI18nRefresh',    function() M.parse_and_cache_translations() end, { desc = 'Re-parse all lyaml translation files' })
  vim.api.nvim_create_user_command('HsI18nReset',      function() M.reset(); M.parse_and_cache_translations() end, { desc = 'Clear caches and re-parse' })
  vim.api.nvim_create_user_command('HsI18nScan',       function() M.scan() end,  { desc = 'Run diagnostic scan on current buffer' })
  vim.api.nvim_create_user_command('HsI18nDebug',      function() M.debug() end, { desc = 'Print cache state for current buffer' })
  vim.api.nvim_create_user_command('HsI18nDebugParse', function(cmd) M.debug_parse(cmd.args ~= '' and cmd.args or nil) end, { nargs = '?', complete = 'file', desc = 'Dump treesitter tree and parsed keys for a lyaml file' })

  _run_parse()

  local timer = vim.loop.new_timer()
  timer:start(5 * 60 * 1000, 5 * 60 * 1000, vim.schedule_wrap(function()
    M.parse_and_cache_translations()
  end))

  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.lyaml',
    callback = function() M.parse_and_cache_translations() end,
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if not targets[ft] then return end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(ev.buf) then return end
        if opts.keys.hover then
          vim.keymap.set('n', opts.keys.hover, function() hover(ev.buf) end, {
            buffer = ev.buf,
            desc = 'Hover: translation or LSP',
          })
        end
        if opts.keys.goto_definition then
          vim.keymap.set('n', opts.keys.goto_definition, function() goto_definition(ev.buf) end, {
            buffer = ev.buf,
            desc = 'Go to definition: translation key or LSP',
          })
        end
        scan_buffer(ev.buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave', 'TextChanged', 'TextChangedI' }, {
    callback = function(ev)
      if targets[vim.bo[ev.buf].filetype] then scan_buffer_debounced(ev.buf) end
    end,
  })
end

return M
