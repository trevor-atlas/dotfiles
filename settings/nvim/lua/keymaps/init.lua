local M = {}

local specs = {}
local applied = false

local function normalize(spec)
  return vim.tbl_extend('keep', spec, {
    mode = 'n',
    silent = true,
  })
end

local function mapping_keys(spec)
  return spec.keys or spec.lhs
end

local function mapping_action(spec)
  return spec.action or spec.rhs
end

local function is_group(spec)
  return spec.group ~= nil and mapping_action(spec) == nil
end

local function add_which_key_group(spec)
  local ok, wk = pcall(require, 'which-key')
  if not ok then return end

  wk.add({ {
    mapping_keys(spec),
    group = spec.group,
    mode = spec.mode,
  } })
end

local function apply_spec(spec)
  spec = normalize(spec)

  if is_group(spec) then
    add_which_key_group(spec)
    return
  end

  vim.keymap.set(spec.mode, mapping_keys(spec), mapping_action(spec), {
    desc = spec.desc,
    expr = spec.expr,
    remap = spec.remap,
    silent = spec.silent,
    buffer = spec.buffer,
  })
end

function M.add(new_specs)
  for _, spec in ipairs(new_specs) do
    table.insert(specs, normalize(spec))
  end
end

function M.apply()
  if applied then return end

  for _, spec in ipairs(specs) do
    apply_spec(spec)
  end

  applied = true
end

function M.apply_buffer(bufnr, new_specs)
  for _, spec in ipairs(new_specs) do
    apply_spec(vim.tbl_extend('force', spec, { buffer = bufnr }))
  end
end

return M
