Vim�UnDo� �j9���ܫ�P�v�b�رQ�I��d{�3y��   L   parser_config.jade = {   J                         e<�   	 _�                        )    ����                                                                                                                                                                                                                                                                                                                                                             e< Y     �          B       �         B    �          A    5��                                                  �                       3                   �       5�_�                       2    ����                                                                                                                                                                                                                                                                                                                                                             e< [     �         E    5��                          �                      5�_�                           ����                                                                                                                                                                                                                                                                                                                                                             e< c     �         F      3parser_config.jsonc.filetype_to_parsername = "json"5��                        t                     �                         u                      �                        t                     5�_�                       .    ����                                                                                                                                                                                                                                                                                                                                                             e< k    �         F      3parser_config.lyaml.filetype_to_parsername = "json"5��       .                 �                     5�_�                       1    ����                                                                                                                                                                                                                                                                                                                                                             e< m    �               F   1local parsers = require "nvim-treesitter.parsers"       2local parser_config = parsers.get_parser_configs()   3parser_config.lyaml.filetype_to_parsername = "yaml"       *require("nvim-treesitter.configs").setup({   N  -- Add languages to be installed here that you want installed for treesitter     ensure_installed = {       "c",   
    "cpp",   	    "go",   
    "lua",       "python",       "rust",   
    "tsx",       "javascript",       "typescript",       "vimdoc",   
    "vim",       "java",       "bash",       "toml",       "yaml",   
    "xml",   
    "pug",     },   g  -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)     ignore_install = {},     sync_install = true,     auto_install = true,      highlight = { enable = true },     indent = { enable = true },     incremental_selection = {       enable = true,       keymaps = {   #      init_selection = "<c-space>",   %      node_incremental = "<c-space>",   "      scope_incremental = "<c-s>",   %      node_decremental = "<M-space>",       },     },     textobjects = {       select = {         enable = true,   X      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim         keymaps = {   D        -- You can use the capture groups defined in textobjects.scm   $        ["aa"] = "@parameter.outer",   $        ["ia"] = "@parameter.inner",   #        ["af"] = "@function.outer",   #        ["if"] = "@function.inner",            ["ac"] = "@class.outer",            ["ic"] = "@class.inner",         },       },       move = {         enable = true,   ?      set_jumps = true, -- whether to set jumps in the jumplist   P      goto_next_start = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },   N      goto_next_end = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },   T      goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },   R      goto_previous_end = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },       },       swap = {         enable = true,   9      swap_next = { ["<leader>a"] = "@parameter.inner" },   =      swap_previous = { ["<leader>A"] = "@parameter.inner" },       },     },   })5��            F       F               �      �      5�_�                       1    ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< o     �                 2local parsers = require('nvim-treesitter.parsers')       2local parser_config = parsers.get_parser_configs()   3parser_config.lyaml.filetype_to_parsername = 'yaml'5��                                   �               5�_�                    B        ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< q     �   B            5��    B                      V                     5�_�      	              C        ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< q    �   C            �   C            5��    C                      W              �       5�_�      
           	   D        ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< q    �               G       *require('nvim-treesitter.configs').setup({   N  -- Add languages to be installed here that you want installed for treesitter     ensure_installed = {       'c',   
    'cpp',   	    'go',   
    'lua',       'python',       'rust',   
    'tsx',       'javascript',       'typescript',       'vimdoc',   
    'vim',       'java',       'bash',       'toml',       'yaml',   
    'xml',   
    'pug',     },   g  -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)     ignore_install = {},     sync_install = true,     auto_install = true,      highlight = { enable = true },     indent = { enable = true },     incremental_selection = {       enable = true,       keymaps = {   #      init_selection = '<c-space>',   %      node_incremental = '<c-space>',   "      scope_incremental = '<c-s>',   %      node_decremental = '<M-space>',       },     },     textobjects = {       select = {         enable = true,   X      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim         keymaps = {   D        -- You can use the capture groups defined in textobjects.scm   $        ['aa'] = '@parameter.outer',   $        ['ia'] = '@parameter.inner',   #        ['af'] = '@function.outer',   #        ['if'] = '@function.inner',            ['ac'] = '@class.outer',            ['ic'] = '@class.inner',         },       },       move = {         enable = true,   ?      set_jumps = true, -- whether to set jumps in the jumplist   P      goto_next_start = { [']m'] = '@function.outer', [']]'] = '@class.outer' },   N      goto_next_end = { [']M'] = '@function.outer', [']['] = '@class.outer' },   T      goto_previous_start = { ['[m'] = '@function.outer', ['[['] = '@class.outer' },   R      goto_previous_end = { ['[M'] = '@function.outer', ['[]'] = '@class.outer' },       },       swap = {         enable = true,   9      swap_next = { ['<leader>a'] = '@parameter.inner' },   =      swap_previous = { ['<leader>A'] = '@parameter.inner' },       },     },   })       2local parsers = require('nvim-treesitter.parsers')       2local parser_config = parsers.get_parser_configs()   3parser_config.lyaml.filetype_to_parsername = 'yaml'5��            G       F               �      �      5�_�   	              
   F       ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< �     �   E              3parser_config.lyaml.filetype_to_parsername = 'yaml'5��    E                     �                     �    E                     �                     �    F                      �                     5�_�   
                 G       ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< �     �   F              "  .filetype_to_parsername = 'yaml'5��    F                     �                     5�_�                    G   !    ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< �    �   F              !  filetype_to_parsername = 'yaml'5��    F   !                 �                     �    G                     �                    �    G                      �                     �    G                     �                    5�_�                    H        ����                                                                                                                                                                                                                                                                                                                               1          1       V   1    e< �    �               H   *require('nvim-treesitter.configs').setup({   N  -- Add languages to be installed here that you want installed for treesitter     ensure_installed = {       'c',   
    'cpp',   	    'go',   
    'lua',       'python',       'rust',   
    'tsx',       'javascript',       'typescript',       'vimdoc',   
    'vim',       'java',       'bash',       'toml',       'yaml',   
    'xml',   
    'pug',     },   g  -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)     ignore_install = {},     sync_install = true,     auto_install = true,      highlight = { enable = true },     indent = { enable = true },     incremental_selection = {       enable = true,       keymaps = {   #      init_selection = '<c-space>',   %      node_incremental = '<c-space>',   "      scope_incremental = '<c-s>',   %      node_decremental = '<M-space>',       },     },     textobjects = {       select = {         enable = true,   X      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim         keymaps = {   D        -- You can use the capture groups defined in textobjects.scm   $        ['aa'] = '@parameter.outer',   $        ['ia'] = '@parameter.inner',   #        ['af'] = '@function.outer',   #        ['if'] = '@function.inner',            ['ac'] = '@class.outer',            ['ic'] = '@class.inner',         },       },       move = {         enable = true,   ?      set_jumps = true, -- whether to set jumps in the jumplist   P      goto_next_start = { [']m'] = '@function.outer', [']]'] = '@class.outer' },   N      goto_next_end = { [']M'] = '@function.outer', [']['] = '@class.outer' },   T      goto_previous_start = { ['[m'] = '@function.outer', ['[['] = '@class.outer' },   R      goto_previous_end = { ['[M'] = '@function.outer', ['[]'] = '@class.outer' },       },       swap = {         enable = true,   9      swap_next = { ['<leader>a'] = '@parameter.inner' },   =      swap_previous = { ['<leader>A'] = '@parameter.inner' },       },     },   })       2local parsers = require('nvim-treesitter.parsers')       2local parser_config = parsers.get_parser_configs()   parser_config.lyaml = {   !  filetype_to_parsername = 'yaml'   }5��            H       H               �      �      5�_�                    H        ����                                                                                                                                                                                                                                                                                                                            H           F          V       e<�     �   H            5��    H                      �                     5�_�                    I        ����                                                                                                                                                                                                                                                                                                                            H           F          V       e<�     �   I            �   I            5��    I                      �              =       5�_�                    J       ����                                                                                                                                                                                                                                                                                                                            H           F          V       e<�    �   I   K   L      parser_config.lyaml = {5��    I                    	                    5�_�                    K       ����                                                                                                                                                                                                                                                                                                                            H           F          V       e<�   	 �   J   L   L      "  filetype_to_parsername = 'yaml',5��    J                    .                    5�_�                     J       ����                                                                                                                                                                                                                                                                                                                            H           F          V       e<�     �   I   K   L      parser_config. = {5��    I                     	                     5��