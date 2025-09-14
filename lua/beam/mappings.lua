---@class BeamMappings
local M = {}
local config = require('beam.config')
local operators = require('beam.operators')

---Create a single keymap for beam operations
---@param key string The full key combination
---@param desc string Description for the mapping
---@param func_name string Operator function name
---@param arg string Argument to pass to operator function
local function create_beam_keymap(key, desc, func_name, arg)
  vim.keymap.set('n', key, function()
    local result = operators[func_name](arg)
    if result == '/' then
      vim.api.nvim_feedkeys('/', 'n', false)
    end
  end, { desc = desc })
end

---Setup text object mappings for an operator
---@param prefix string Prefix for mappings
---@param op_key string Operator key
---@param op_info table Operator info
local function setup_text_object_mappings(prefix, op_key, op_info)
  for obj_key, obj_name in pairs(config.active_text_objects) do
    local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

    -- Inner variant
    local key_i = prefix .. op_key .. 'i' .. obj_key
    local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc
    create_beam_keymap(key_i, desc_i, 'Beam' .. op_info.func, 'i' .. obj_key)

    -- Around variant
    local key_a = prefix .. op_key .. 'a' .. obj_key
    local desc_a = 'Search & ' .. op_info.verb .. ' around ' .. obj_desc
    create_beam_keymap(key_a, desc_a, 'Beam' .. op_info.func, 'a' .. obj_key)
  end
end

---Setup motion mappings for an operator
---@param prefix string Prefix for mappings
---@param op_key string Operator key
---@param op_info table Operator info
local function setup_motion_mappings(prefix, op_key, op_info)
  for motion_key, motion_desc in pairs(config.motions or {}) do
    local key = prefix .. op_key .. motion_key
    local desc = 'Search & ' .. op_info.verb .. ' ' .. motion_desc
    create_beam_keymap(key, desc, 'Beam' .. op_info.func, motion_key)
  end
end

---Setup line operator mappings
---@param prefix string Prefix for mappings
local function setup_line_operators(prefix)
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
      local desc = 'Search & ' .. op_info.verb
      vim.keymap.set('n', key, function()
        local result = operators[setup_func_name]()
        if result == '/' then
          vim.api.nvim_feedkeys('/', 'n', false)
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

  -- Setup mappings for each operator
  for op_key, op_info in pairs(config.operators) do
    setup_text_object_mappings(prefix, op_key, op_info)
    setup_motion_mappings(prefix, op_key, op_info)
  end

  setup_line_operators(prefix)
end

---Create custom mappings for discovered text objects
---@param text_objects table<string, string|table> Text objects to create mappings for
---@return nil
function M.create_custom_mappings(text_objects)
  local cfg = config.current
  local prefix = cfg.prefix or ','

  for obj_key, obj_name in pairs(text_objects) do
    -- Handle both string descriptions and table definitions
    local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

    for op_key, op_info in pairs(config.operators) do
      -- For multi-character text objects, we need to be careful about the mapping
      -- Single char: ,yif -> prefix + op + 'i' + obj
      -- Multi char: ,yifn -> prefix + op + 'i' + 'fn'
      local key_i = prefix .. op_key .. 'i' .. obj_key
      local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc
      vim.keymap.set('n', key_i, function()
        local result = operators['Beam' .. op_info.func]('i' .. obj_key)
        if result == '/' then
          vim.api.nvim_feedkeys('/', 'n', false)
        end
      end, { desc = desc_i })

      -- Skip 'around' variants for b/B (they're the same as 'inside')
      -- Don't create 'around' variant for certain text objects where it doesn't make sense
      -- For now, don't skip any - let each plugin decide what makes sense
      if true then -- Always create both inner and around
        local key_a = prefix .. op_key .. 'a' .. obj_key
        local desc_a = 'Search & ' .. op_info.verb .. ' around ' .. obj_desc
        vim.keymap.set('n', key_a, function()
          local result = operators['Beam' .. op_info.func]('a' .. obj_key)
          if result == '/' then
            vim.api.nvim_feedkeys('/', 'n', false)
          end
        end, { desc = desc_a })
      end
    end
  end
end

return M
