-- Custom motion implementations for beam.nvim
-- These are motions that beam reimplements for BeamScope compatibility

local M = {}

-- Motion definitions
-- Each entry contains:
--   - find: function to find all targets in a buffer
--   - select: function to select a specific target
--   - pattern: the pattern used for finding (often borrowed from the original plugin)
--   - source: where the pattern/logic comes from
--   - why: reason for custom implementation

M.motions = {
  -- URL motion (pattern borrowed from nvim-various-textobjs)
  L = {
    source = 'nvim-various-textobjs (pattern only)',
    why = 'Forward-seeking motion incompatible with buffer-wide enumeration',
    description = 'URL',
    pattern = '%l%l%l+://[^%s)%]}"\'`>]+', -- Borrowed from nvim-various-textobjs

    -- Metadata for BeamScope
    visual_mode = 'characterwise', -- Use v for operations
    format_style = 'simple', -- Just show the URL

    -- Find all URLs in buffer
    find = function(buf)
      local instances = {}
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Use the pattern from nvim-various-textobjs
      local url_pattern = '%l%l%l+://[^%s)%]}"\'`>]+'

      for line_num, line in ipairs(lines) do
        local col = 1
        while true do
          local start_col, end_col = line:find(url_pattern, col)
          if not start_col then
            break
          end

          local url = line:sub(start_col, end_col)
          table.insert(instances, {
            start_line = line_num,
            end_line = line_num,
            start_col = start_col - 1, -- Convert to 0-based
            end_col = end_col - 1, -- Convert to 0-based
            preview = url,
            first_line = url,
            line_count = 1,
          })

          col = end_col + 1
        end
      end

      return instances
    end,

    -- Select a specific URL
    select = function(instance, action)
      -- For motions, we select the exact range
      -- No inner/around variants for motions
      return {
        start = { instance.start_line, instance.start_col },
        end_ = { instance.end_line, instance.end_col },
      }
    end,

    -- Format function for BeamScope display
    format = function(instance)
      -- Just show the URL itself
      return { instance.preview or instance.first_line or '' }
    end,
  },

  -- Future motions can be added here
  -- For example, if we need to reimplement other forward-seeking motions:
  -- Q = { ... },  -- Next quote
  -- R = { ... },  -- Rest of paragraph
}

-- Check if a motion is handled by this module
function M.is_custom(motion_key)
  return M.motions[motion_key] ~= nil
end

-- Get custom motion definition
function M.get(motion_key)
  return M.motions[motion_key]
end

-- Find all targets of a custom motion
function M.find_all(motion_key, buf)
  local motion = M.motions[motion_key]
  if motion and motion.find then
    return motion.find(buf)
  end
  return {}
end

-- Select a specific target of a custom motion
function M.select(motion_key, instance, action)
  local motion = M.motions[motion_key]
  if motion and motion.select then
    return motion.select(instance, action)
  end
  return nil
end

-- List all custom motions (for discovery/documentation)
function M.list()
  local list = {}
  for key, motion in pairs(M.motions) do
    table.insert(list, {
      key = key,
      description = motion.description,
      source = motion.source,
      why = motion.why,
    })
  end
  return list
end

return M
