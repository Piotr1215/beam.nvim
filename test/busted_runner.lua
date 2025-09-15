#!/usr/bin/env -S nvim -l
-- Busted test runner for Neovim plugins
-- Pioneering approach: Run busted tests inside Neovim!

-- Set up paths for locally installed luarocks packages
local home = os.getenv('HOME')
local luarocks_path = home
  .. '/.luarocks/share/lua/5.1/?.lua;'
  .. home
  .. '/.luarocks/share/lua/5.1/?/init.lua'
local luarocks_cpath = home .. '/.luarocks/lib/lua/5.1/?.so'

package.path = luarocks_path .. ';' .. package.path
package.cpath = luarocks_cpath .. ';' .. package.cpath

-- Set up isolated test environment
vim.cmd('set rtp=')
vim.cmd('set packpath=')

-- Add beam.nvim to runtime path
vim.cmd('set rtp+=.')

-- Add Neovim runtime
vim.cmd('set rtp+=' .. vim.env.VIMRUNTIME)

-- Load beam.nvim
vim.cmd('runtime plugin/beam.lua')

-- Now run busted
local busted = require('busted.runner')

-- Get command line arguments (skip the script name)
local args = {}
for i = 1, #arg do
  table.insert(args, arg[i])
end

-- Default to running unit tests if no args
if #args == 0 then
  table.insert(args, 'test/unit')
end

-- Run busted with our arguments
local exit_code = busted(args)

-- Exit with the proper code
os.exit(exit_code or 0)
