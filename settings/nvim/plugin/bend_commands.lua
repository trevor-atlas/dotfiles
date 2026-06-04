if vim.fn.executable('bend') ~= 1 then return end

local Terminal = require('toggleterm.terminal').Terminal

local function shell_join(argv)
  return table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ')
end

local function open_bend_command(subcommand, opts, terminal_opts)
  local argv = { 'bend', subcommand }
  vim.list_extend(argv, opts.fargs or {})

  local term = Terminal:new(vim.tbl_extend('force', {
    cmd = shell_join(argv),
    hidden = true,
    close_on_exit = false,
    display_name = table.concat(argv, ' '),
    direction = 'float',
  }, terminal_opts or {}))

  term:open(terminal_opts and terminal_opts.size or nil, terminal_opts and terminal_opts.direction or nil)
end

local commands = {
  { name = 'BendInstall', alias = 'Binstall', subcommand = 'install' },
  { name = 'BendGenerateCode', alias = 'Bcodegen', subcommand = 'generate-code' },
  { name = 'BendDev', alias = 'Bdev', subcommand = 'dev', direction = 'horizontal', size = 15 },
  { name = 'BendCheck', alias = 'Bcheck', subcommand = 'check' },
  { name = 'BendTest', alias = 'Btest', subcommand = 'test' },
  { name = 'BendFmt', alias = 'Bfmt', subcommand = 'fmt' },
}

for _, command in ipairs(commands) do
  local function create_user_command(name)
    vim.api.nvim_create_user_command(name, function(opts)
      open_bend_command(command.subcommand, opts, {
        direction = command.direction,
        size = command.size,
      })
    end, {
      nargs = '*',
      complete = 'file',
      desc = 'Run bend ' .. command.subcommand,
    })
  end

  create_user_command(command.name)
  create_user_command(command.alias)
end
