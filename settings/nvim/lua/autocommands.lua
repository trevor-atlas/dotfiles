local cmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local create_command = vim.api.nvim_create_user_command

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local yank_highlight_group = augroup('YankHighlight', { clear = true })
cmd('TextYankPost', {
  callback = function() vim.highlight.on_yank() end,
  group = yank_highlight_group,
  pattern = '*',
})

-- treat .lyaml files as .yaml
local hubspot_translation_group = augroup('HSTranslations', { clear = true })
cmd({ 'BufRead', 'BufNewFile' }, {
  desc = 'treat .lyaml files as yaml',
  group = hubspot_translation_group,
  pattern = '*.lyaml',
  callback = function() vim.api.nvim_command('setfiletype yaml') end,
})

-- treat .jade files as .pug
local remap_legacy_filetypes_group = augroup('LegacyFiletypesGroup', { clear = true })
cmd({ 'BufRead', 'BufNewFile' }, {
  desc = 'treat .jade files as .pug',
  group = remap_legacy_filetypes_group,
  pattern = '*.jade',
  callback = function() vim.api.nvim_command('setfiletype pug') end,
})

local url_matcher =
  '\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*})\\})+'

--- Delete the syntax matching rules for URLs/URIs if set
local function delete_url_match()
  for _, match in ipairs(vim.fn.getmatches()) do
    if match.group == 'HighlightURL' then vim.fn.matchdelete(match.id) end
  end
end

local function set_url_match()
  delete_url_match()
  vim.fn.matchadd('HighlightURL', url_matcher, 15)
end

local highlighturl_group = augroup('highlighturl', { clear = true })
cmd({ 'VimEnter', 'FileType', 'BufEnter', 'WinEnter' }, {
  desc = 'URL Highlighting',
  group = highlighturl_group,
  pattern = '*',
  callback = function() set_url_match() end,
})

local neotree_start_group = augroup('neotree_start', { clear = true })
cmd('BufEnter', {
  desc = 'Open Neo-Tree on startup with directory',
  group = neotree_start_group,
  callback = function()
    local stats = vim.loop.fs_stat(vim.api.nvim_buf_get_name(0))
    if stats and stats.type == 'directory' then require('neo-tree.setup.netrw').hijack() end
  end,
})
