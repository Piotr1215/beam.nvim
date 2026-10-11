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
---@param direction_suffix? string Suffix for description ('forward' or 'backward')
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
---@param direction_suffix? string Suffix for description
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
---@param direction_suffix? string Suffix for description
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

---Action name per operator key, for multicursor mappings
---@type table<string, string>
local multi_actions = { y = 'yank', d = 'delete', c = 'change', v = 'visual' }

---Get the multicursor mapping prefix ('<prefix><multi_key>'), or nil when it is
---disabled or this Neovim has no `zq`
---@return string|nil
local function multi_prefix()
  local cfg = config.current
  if not cfg.multi_key or cfg.multi_key == '' then
    return nil
  end
  if not require('beam.multicursor').available() then
    return nil
  end
  return (cfg.prefix or ',') .. cfg.multi_key
end

---Create a keymap that runs an action at every search match
---@param key string
---@param desc string
---@param action string
---@param textobj string
local function create_multi_keymap(key, desc, action, textobj)
  vim.keymap.set('n', key, function()
    if operators.BeamMultiSearchSetup(action, textobj) == '/' then
      vim.api.nvim_feedkeys('/', 'n', false)
    end
  end, { desc = desc })
end

---Setup multicursor mappings for text objects
---@param p string Multicursor prefix
---@param text_objects table<string, string|table>
local function setup_multi_text_object_mappings(p, text_objects)
  for obj_key, obj_name in pairs(text_objects) do
    local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name
    for op_key, op_info in pairs(config.operators) do
      create_multi_keymap(
        p .. op_key .. 'i' .. obj_key,
        'Search & ' .. op_info.verb .. ' inside ' .. obj_desc .. ' at every match',
        multi_actions[op_key],
        'i' .. obj_key
      )
      create_multi_keymap(
        p .. op_key .. 'a' .. obj_key,
        'Search & ' .. op_info.verb .. ' around ' .. obj_desc .. ' at every match',
        multi_actions[op_key],
        'a' .. obj_key
      )
    end
  end
end

---Setup multicursor mappings for motions and line operators
---@param p string Multicursor prefix
local function setup_multi_motion_and_line_mappings(p)
  for op_key, op_info in pairs(config.operators) do
    for motion_key, motion_desc in pairs(config.motions or {}) do
      create_multi_keymap(
        p .. op_key .. motion_key,
        'Search & ' .. op_info.verb .. ' ' .. motion_desc .. ' at every match',
        multi_actions[op_key],
        motion_key
      )
    end
  end
  for op_key, op_info in pairs(config.line_operators) do
    create_multi_keymap(
      p .. op_key,
      'Search & ' .. op_info.verb .. ' at every match',
      op_info.action,
      ''
    )
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

  -- Setup multicursor mappings when this Neovim has zq
  local mp = multi_prefix()
  if mp then
    setup_multi_text_object_mappings(mp, config.active_text_objects)
    setup_multi_motion_and_line_mappings(mp)
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

  -- Create multicursor mappings when this Neovim has zq
  local mp = multi_prefix()
  if mp then
    setup_multi_text_object_mappings(mp, text_objects)
  end
end

return M
