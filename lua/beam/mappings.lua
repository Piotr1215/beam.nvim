---@class BeamMappings
local M = {}
local config = require('beam.config')
local operators = require('beam.operators')

---Create a single keymap for beam operations
---@param key string The full key combination
---@param desc string Description for the mapping
---@param func_name string Operator function name
---@param arg string Argument to pass to operator function
---@param search_char string|nil Search character ('/' or '?'), defaults to '/'
local function create_beam_keymap(key, desc, func_name, arg, search_char)
  search_char = search_char or '/'
  vim.keymap.set('n', key, function()
    local result = operators[func_name](arg)
    if result == '/' or result == '?' then
      vim.api.nvim_feedkeys(search_char, 'n', false)
    end
  end, { desc = desc })
end

---Setup text object mappings for an operator
---@param prefix string Prefix for mappings
---@param op_key string Operator key
---@param op_info table Operator info
---@param search_char string Search character ('/' or '?')
---@param direction_suffix string Suffix for description ('forward' or 'backward')
local function setup_text_object_mappings(prefix, op_key, op_info, search_char, direction_suffix)
  search_char = search_char or '/'
  direction_suffix = direction_suffix or ''
  local desc_suffix = direction_suffix ~= '' and ' (' .. direction_suffix .. ')' or ''

  for obj_key, obj_name in pairs(config.active_text_objects) do
    local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

    -- Inner variant
    local key_i = prefix .. op_key .. 'i' .. obj_key
    local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc .. desc_suffix
    create_beam_keymap(key_i, desc_i, 'Beam' .. op_info.func, 'i' .. obj_key, search_char)

    -- Around variant
    local key_a = prefix .. op_key .. 'a' .. obj_key
    local desc_a = 'Search & ' .. op_info.verb .. ' around ' .. obj_desc .. desc_suffix
    create_beam_keymap(key_a, desc_a, 'Beam' .. op_info.func, 'a' .. obj_key, search_char)
  end
end

---Setup motion mappings for an operator
---@param prefix string Prefix for mappings
---@param op_key string Operator key
---@param op_info table Operator info
---@param search_char string Search character ('/' or '?')
---@param direction_suffix string Suffix for description
local function setup_motion_mappings(prefix, op_key, op_info, search_char, direction_suffix)
  search_char = search_char or '/'
  direction_suffix = direction_suffix or ''
  local desc_suffix = direction_suffix ~= '' and ' (' .. direction_suffix .. ')' or ''

  for motion_key, motion_desc in pairs(config.motions or {}) do
    local key = prefix .. op_key .. motion_key
    local desc = 'Search & ' .. op_info.verb .. ' ' .. motion_desc .. desc_suffix
    create_beam_keymap(key, desc, 'Beam' .. op_info.func, motion_key, search_char)
  end
end

---Setup line operator mappings
---@param prefix string Prefix for mappings
---@param search_char string Search character ('/' or '?')
---@param direction_suffix string Suffix for description
local function setup_line_operators(prefix, search_char, direction_suffix)
  search_char = search_char or '/'
  direction_suffix = direction_suffix or ''
  local desc_suffix = direction_suffix ~= '' and ' (' .. direction_suffix .. ')' or ''

  local line_setup_funcs = {
    Y = 'BeamYankLineSearchSetup',
    D = 'BeamDeleteLineSearchSetup',
    C = 'BeamChangeLineSearchSetup',
    V = 'BeamVisualLineSearchSetup',
  }

  for op_key, op_info in pairs(config.line_operators) do
    local setup_func_name = line_setup_funcs[op_key]
    if setup_func_name then
      local key = prefix .. op_key
      local desc = 'Search & ' .. op_info.verb .. desc_suffix
      vim.keymap.set('n', key, function()
        local result = operators[setup_func_name]()
        if result == '/' or result == '?' then
          vim.api.nvim_feedkeys(search_char, 'n', false)
        end
      end, { desc = desc })
    end
  end
end

---Setup all beam mappings based on configuration
---@return nil
function M.setup()
  local cfg = config.current
  local prefix = cfg.prefix or ','
  local backward_prefix = cfg.backward_prefix

  -- Setup forward mappings for each operator
  for op_key, op_info in pairs(config.operators) do
    setup_text_object_mappings(prefix, op_key, op_info, '/')
    setup_motion_mappings(prefix, op_key, op_info, '/')
  end
  setup_line_operators(prefix, '/')

  -- Setup backward mappings if backward_prefix is configured
  if backward_prefix then
    for op_key, op_info in pairs(config.operators) do
      setup_text_object_mappings(backward_prefix, op_key, op_info, '?', 'backward')
      setup_motion_mappings(backward_prefix, op_key, op_info, '?', 'backward')
    end
    setup_line_operators(backward_prefix, '?', 'backward')
  end
end

---Create custom mappings for discovered text objects
---@param text_objects table<string, string|table> Text objects to create mappings for
---@return nil
function M.create_custom_mappings(text_objects)
  local cfg = config.current
  local prefix = cfg.prefix or ','
  local backward_prefix = cfg.backward_prefix

  -- Helper to create mappings for a given prefix and search direction
  local function create_for_prefix(p, search_char, direction_suffix)
    local desc_suffix = direction_suffix ~= '' and ' (' .. direction_suffix .. ')' or ''

    for obj_key, obj_name in pairs(text_objects) do
      local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

      for op_key, op_info in pairs(config.operators) do
        local key_i = p .. op_key .. 'i' .. obj_key
        local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc .. desc_suffix
        vim.keymap.set('n', key_i, function()
          local result = operators['Beam' .. op_info.func]('i' .. obj_key)
          if result == '/' or result == '?' then
            vim.api.nvim_feedkeys(search_char, 'n', false)
          end
        end, { desc = desc_i })

        local key_a = p .. op_key .. 'a' .. obj_key
        local desc_a = 'Search & ' .. op_info.verb .. ' around ' .. obj_desc .. desc_suffix
        vim.keymap.set('n', key_a, function()
          local result = operators['Beam' .. op_info.func]('a' .. obj_key)
          if result == '/' or result == '?' then
            vim.api.nvim_feedkeys(search_char, 'n', false)
          end
        end, { desc = desc_a })
      end
    end
  end

  -- Create forward mappings
  create_for_prefix(prefix, '/', '')

  -- Create backward mappings if configured
  if backward_prefix then
    create_for_prefix(backward_prefix, '?', 'backward')
  end
end

return M
