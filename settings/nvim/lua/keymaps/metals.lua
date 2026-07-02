local M = {}

function M.for_buffer(ops)
  return {
    { keys = '<leader>mg', action = ops.install_mill_bsp, desc = 'Install Mill [G]SP config' },
    { keys = '<leader>mc', action = ops.connect_build, desc = '[C]onnect build' },
    { keys = '<leader>mi', action = ops.import_build, desc = '[I]mport build' },
    { keys = '<leader>mo', action = ops.organize_imports, desc = '[O]rganize imports' },
    { keys = '<leader>mb', action = ops.restart_build_server, desc = 'Restart [B]uild server' },
    { keys = '<leader>md', action = ops.run_doctor, desc = '[D]octor' },
    { keys = '<leader>mr', action = ops.restart_metals, desc = '[R]estart server' },
    { keys = '<leader>mR', action = ops.clean_mill_cache, desc = 'Clean Mill cache and restart' },
  }
end

return M
