#!/usr/bin/env lua
-- Extract configuration from beam.nvim config.lua for documentation

local config_file = 'lua/beam/config.lua'
local f = io.open(config_file, 'r')
if not f then
  print('Error: Could not open ' .. config_file)
  os.exit(1)
end

local content = f:read('*all')
f:close()

-- Extract the defaults table
local defaults_start = content:find('M%.defaults = {')
if not defaults_start then
  print('Error: Could not find M.defaults in config file')
  os.exit(1)
end

-- Find the matching closing brace
local brace_count = 0
local i = defaults_start
local defaults_end = nil

while i <= #content do
  local char = content:sub(i, i)
  if char == '{' then
    brace_count = brace_count + 1
  elseif char == '}' then
    brace_count = brace_count - 1
    if brace_count == 0 then
      defaults_end = i
      break
    end
  end
  i = i + 1
end

if not defaults_end then
  print('Error: Could not find matching closing brace')
  os.exit(1)
end

-- Extract the defaults configuration
local defaults = content:sub(defaults_start + 14, defaults_end)

-- Format it nicely with proper indentation
print('```lua')
print("require('beam').setup({")
print(defaults)
print('```')
