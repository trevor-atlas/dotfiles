local cmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local create_command = vim.api.nvim_create_user_command

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.highlight.on_yank() end,
  group = highlight_group,
  pattern = '*',
})

-- treat .lyaml files as .yaml
vim.cmd([[
augroup yaml_filetype
  autocmd!
  autocmd BufRead,BufNewFile *.lyaml setfiletype yaml
augroup END
]])

-- treat .jade files as .pug
vim.cmd([[
augroup jade_filetype
  autocmd!
  autocmd BufRead,BufNewFile *.jade setfiletype pug
augroup END
]])

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
  if vim.g.highlighturl_enabled then vim.fn.matchadd('HighlightURL', url_matcher, 15) end
end

augroup('highlighturl', { clear = true })
cmd({ 'VimEnter', 'FileType', 'BufEnter', 'WinEnter' }, {
  desc = 'URL Highlighting',
  group = 'highlighturl',
  pattern = '*',
  callback = function() set_url_match() end,
})

augroup('neotree_start', { clear = true })
cmd('BufEnter', {
  desc = 'Open Neo-Tree on startup with directory',
  group = 'neotree_start',
  callback = function()
    local stats = vim.loop.fs_stat(vim.api.nvim_buf_get_name(0))
    if stats and stats.type == 'directory' then require('neo-tree.setup.netrw').hijack() end
  end,
})
