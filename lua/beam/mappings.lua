local M = {}
local config = require('beam.config')
local operators = require('beam.operators')

function M.setup()
  local cfg = config.current
  local prefix = cfg.prefix or ','

  -- Handle regular text objects (with i/a variants)
  for op_key, op_info in pairs(config.operators) do
    for obj_key, obj_name in pairs(config.text_objects) do
      local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

      local key_i = prefix .. op_key .. 'i' .. obj_key
      local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc
      vim.keymap.set('n', key_i, function()
        local result = operators['Beam' .. op_info.func]('i' .. obj_key)
        if result == '/' then
          vim.api.nvim_feedkeys('/', 'n', false)
        end
      end, { desc = desc_i })

      if not (obj_key:match('[bB]')) then
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

    -- Also handle motions (single-letter mappings without i/a)
    for motion_key, motion_desc in pairs(config.motions or {}) do
      local key = prefix .. op_key .. motion_key
      local desc = 'Search & ' .. op_info.verb .. ' ' .. motion_desc
      vim.keymap.set('n', key, function()
        local result = operators['Beam' .. op_info.func](motion_key)
        if result == '/' then
          vim.api.nvim_feedkeys('/', 'n', false)
        end
      end, { desc = desc })
    end
  end

  -- Line operators with Telescope support
  local line_setup_funcs = {
    Y = 'BeamYankLineSearchSetup',
    D = 'BeamDeleteLineSearchSetup',
    C = 'BeamChangeLineSearchSetup',
    V = 'BeamVisualLineSearchSetup',
  }

  for op_key, op_info in pairs(config.line_operators) do
    local key = prefix .. op_key
    local desc = 'Search & ' .. op_info.verb
    local setup_func_name = line_setup_funcs[op_key]

    vim.keymap.set('n', key, function()
      local result = operators[setup_func_name]()
      if result == '/' then
        vim.api.nvim_feedkeys('/', 'n', false)
      end
    end, { desc = desc })
  end
end

function M.create_custom_mappings(text_objects)
  local cfg = config.current
  local prefix = cfg.prefix or ','

  for obj_key, obj_name in pairs(text_objects) do
    -- Handle both string descriptions and table definitions
    local obj_desc = type(obj_name) == 'table' and (obj_name.desc or obj_key) or obj_name

    for op_key, op_info in pairs(config.operators) do
      local key_i = prefix .. op_key .. 'i' .. obj_key
      local desc_i = 'Search & ' .. op_info.verb .. ' inside ' .. obj_desc
      vim.keymap.set('n', key_i, function()
        local result = operators['Beam' .. op_info.func]('i' .. obj_key)
        if result == '/' then
          vim.api.nvim_feedkeys('/', 'n', false)
        end
      end, { desc = desc_i })

      if not (obj_key:match('[bB]')) then
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
