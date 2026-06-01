local M = {}

local repo_caches = {}

local function get_repo_root()
  return require('repo').find_root(0, { '.git' }) or vim.fn.getcwd()
end

local function get_repo_cache(repo_root)
  local cache = repo_caches[repo_root]
  if cache then return cache end

  cache = {
    generated_from = {},
    imports = {},
    paths = {},
    files_by_basename = {},
  }
  repo_caches[repo_root] = cache
  return cache
end

local function get_java_root(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, 'java')
  return parser:parse()[1]:root()
end

local function node_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  return get_java_root(bufnr):named_descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])
end

local function infer_java_qualifier()
  local bufnr = vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr)
  if not node then return nil end

  local identifier = node:type() == 'identifier' and vim.treesitter.get_node_text(node, bufnr) or nil
  local current = node
  while current do
    if current:type() == 'method_invocation' or current:type() == 'field_access' then
      local first_identifier = nil
      for child in current:iter_children() do
        if child:type() == 'identifier' then
          first_identifier = vim.treesitter.get_node_text(child, bufnr)
          break
        end
      end
      if first_identifier and first_identifier:match('^[%u][%w_]*$') then return first_identifier end
    elseif current:type() == 'import_declaration' and identifier and identifier:match('^[%u][%w_]*$') then
      return identifier
    end
    current = current:parent()
  end

  if identifier and identifier:match('^[%u][%w_]*$') then return identifier end
  return nil
end

local function find_java_import(simple_name)
  local repo_root = get_repo_root()
  local cache = get_repo_cache(repo_root)
  local cached = cache.imports[simple_name]
  if cached ~= nil then return cached or nil end

  local bufnr = vim.api.nvim_get_current_buf()
  local root = get_java_root(bufnr)
  for child in root:iter_children() do
    if child:type() == 'import_declaration' then
      for import_child in child:iter_children() do
        if import_child:type() == 'scoped_identifier' then
          local import = vim.treesitter.get_node_text(import_child, bufnr)
          if import:match('([^.]+)$') == simple_name then
            cache.imports[simple_name] = import
            return import
          end
        end
      end
    end
  end

  cache.imports[simple_name] = false
  return nil
end

local function edit_file(path, message)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.notify(message, vim.log.levels.INFO)
  return true
end

local function cached_path_lookup(repo_root, key, finder)
  local cache = get_repo_cache(repo_root)
  local cached = cache.paths[key]
  if cached ~= nil then return cached or nil end

  local path = finder()
  cache.paths[key] = path or false
  return path
end

local function files_by_basename(repo_root, basename)
  local cache = get_repo_cache(repo_root)
  local cached = cache.files_by_basename[basename]
  if cached then return cached end

  local result = vim.system({ 'rg', '--files', repo_root, '-g', basename }, { text = true }):wait()
  local files = {}
  if result.code == 0 and result.stdout then
    for file in result.stdout:gmatch('[^\r\n]+') do
      files[#files + 1] = file
    end
  end

  cache.files_by_basename[basename] = files
  return files
end

local function find_java_file(repo_root, package_path, basename, allowed_segments)
  return cached_path_lookup(repo_root, table.concat({ package_path, basename, table.concat(allowed_segments, '|') }, '::'), function()
    local expected_suffix = package_path .. '/' .. basename
    for _, file in ipairs(files_by_basename(repo_root, basename)) do
      local normalized = file:gsub('\\', '/')
      if normalized:sub(-#expected_suffix) == expected_suffix then
        for _, segment in ipairs(allowed_segments) do
          if normalized:find(segment, 1, true) then return file end
        end
      end
    end
    return nil
  end)
end

local function find_java_source_file(repo_root, package_path, source_name)
  return find_java_file(repo_root, package_path, source_name .. '.java', { '/src/main/java/', '/src/test/java/' })
end

local function find_generated_java_file(repo_root, package_path, simple_name)
  return find_java_file(repo_root, package_path, simple_name .. '.java', { '/target/generated-sources/annotations/', '/out/' })
end

local function source_from_generated_file(path)
  local repo_root = get_repo_root()
  local cache = get_repo_cache(repo_root)
  local cached = cache.generated_from[path]
  if cached ~= nil then return cached or nil end

  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    cache.generated_from[path] = false
    return nil
  end

  local source = table.concat(content, '\n')
  local parser = vim.treesitter.get_string_parser(source, 'java')
  local root = parser:parse()[1]:root()

  for child in root:iter_children() do
    if child:type() == 'class_declaration' then
      for class_child in child:iter_children() do
        if class_child:type() == 'modifiers' then
          for modifier in class_child:iter_children() do
            if modifier:type() == 'annotation' then
              local name_node = modifier:named_child(0)
              if name_node and vim.treesitter.get_node_text(name_node, source):match('Generated$') then
                local args = modifier:named_child(1)
                if args and args:type() == 'annotation_argument_list' then
                  for i = 0, args:named_child_count() - 1 do
                    local pair = args:named_child(i)
                    if pair:type() == 'element_value_pair' then
                      local key = pair:named_child(0)
                      local value = pair:named_child(1)
                      if key and value and vim.treesitter.get_node_text(key, source) == 'from' then
                        local source_name = vim.treesitter.get_node_text(value, source):gsub('^"', ''):gsub('"$', '')
                        cache.generated_from[path] = source_name
                        return source_name
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  cache.generated_from[path] = false
  return nil
end

local function open_generated_java_source(simple_name)
  local import = find_java_import(simple_name)
  if not import then return false end

  local package_path = import:gsub('%.?[^%.]+$', ''):gsub('%.', '/')
  local repo_root = get_repo_root()
  local generated = find_generated_java_file(repo_root, package_path, simple_name)

  if generated then
    local source_name = source_from_generated_file(generated)
    if source_name then
      local source = find_java_source_file(repo_root, package_path, source_name)
      if source then return edit_file(source, 'Opened source for generated type ' .. simple_name) end
    end

    return edit_file(generated, 'Opened generated source for ' .. simple_name)
  end

  for _, source_name in ipairs({ simple_name .. 'IF', 'Abstract' .. simple_name, simple_name }) do
    local source = find_java_source_file(repo_root, package_path, source_name)
    if source then return edit_file(source, 'Opened source for generated type ' .. simple_name) end
  end

  return false
end

local function jump_to_definition_result(result)
  local locations = vim.islist(result) and result or { result }
  if #locations == 0 then return false end

  local target = locations[1]
  local uri = target.uri or target.targetUri
  local range = target.range or target.targetSelectionRange or target.targetRange
  if not uri or not range then return false end

  vim.lsp.util.show_document({ uri = uri, range = range }, 'utf-8', { focus = true })
  if #locations > 1 then
    vim.notify('Multiple definitions found, jumped to the first match', vim.log.levels.INFO)
  end
  return true
end

function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(0, 'utf-8')
  local qualifier = vim.bo[bufnr].filetype == 'java' and infer_java_qualifier() or nil

  if qualifier and open_generated_java_source(qualifier) then return end

  vim.lsp.buf_request(bufnr, 'textDocument/definition', params, function(err, result)
    vim.schedule(function()
      if err == nil and result and not vim.tbl_isempty(result) and jump_to_definition_result(result) then return end
      vim.notify('No results found for lsp_definitions', vim.log.levels.WARN)
    end)
  end)
end

return M
