-- Custom text object implementations for beam.nvim
-- These are text objects that beam provides or reimplements for BeamScope compatibility

local M = {}

-- Text object definitions
-- Each entry contains:
--   - find: function to find all instances in a buffer
--   - select: function to select a specific instance
--   - source: where this implementation comes from
--   - why: reason for custom implementation

M.text_objects = {
  -- Markdown code blocks (beam's own text object)
  m = {
    source = 'beam.nvim',
    why = 'Native beam text object for markdown code blocks',
    description = 'markdown code block',

    -- Metadata for BeamScope
    visual_mode = 'linewise', -- Use V instead of v for operations
    format_style = 'fenced', -- How to display in BeamScope buffer

    -- Find all markdown code blocks in buffer
    find = function(buf)
      local instances = {}
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local in_code_block = false
      local block_start = nil
      local block_lang = nil

      for i, line in ipairs(lines) do
        if line:match('^```') then
          if not in_code_block then
            in_code_block = true
            block_start = i
            block_lang = line:match('^```(.*)') or ''
          else
            -- End of code block
            in_code_block = false
            if block_start then
              -- Get the content between the backticks
              local content_lines = {}
              for j = block_start + 1, i - 1 do
                table.insert(content_lines, lines[j] or '')
              end
              local content = table.concat(content_lines, '\n')

              table.insert(instances, {
                start_line = block_start,
                end_line = i,
                start_col = 0,
                end_col = #lines[i] - 1,
                preview = content ~= '' and content or '[empty code block]',
                first_line = content_lines[1] or '[empty]',
                line_count = i - block_start + 1,
                language = block_lang,
              })
            end
            block_start = nil
            block_lang = nil
          end
        end
      end

      return instances
    end,

    -- Select a specific instance (called when user picks from BeamScope)
    select = function(instance, action, variant)
      -- variant is 'i' for inner or 'a' for around
      if variant == 'i' then
        -- Inside code block (content only, excluding backticks)
        return {
          start = { instance.start_line + 1, 0 },
          end_ = { instance.end_line - 1, 999 }, -- End of line before closing backticks
        }
      else -- 'a'
        -- Around code block (including backticks)
        return {
          start = { instance.start_line, instance.start_col },
          end_ = { instance.end_line, instance.end_col },
        }
      end
    end,

    -- Format function for BeamScope display
    format = function(instance)
      local lines = {}
      local lang = instance.language and instance.language ~= '' and instance.language or ''
      table.insert(lines, string.format('```%s', lang))

      -- Show ALL content lines
      if instance.preview then
        for line in instance.preview:gmatch('[^\n]+') do
          table.insert(lines, line)
        end
      end

      table.insert(lines, '```')
      return lines
    end,
  },

  -- Markdown headers (beam's own text object)
  h = {
    source = 'beam.nvim',
    why = 'Native beam text object for markdown headers with hierarchy',
    description = 'markdown header',

    -- Metadata for BeamScope
    visual_mode = 'linewise', -- Use V for operations
    format_style = 'simple', -- Just show the header line

    -- Find all markdown headers with hierarchy
    find = function(buf)
      local instances = {}
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local headers = {}

      -- First pass: find all headers with their levels
      for i, line in ipairs(lines) do
        local level = #(line:match('^(#+)%s') or '')
        if level > 0 then
          table.insert(headers, {
            line = i,
            level = level,
            text = line,
            content_start = i + 1,
          })
        end
      end

      -- Second pass: determine content end for each header
      for i, header in ipairs(headers) do
        local content_end = #lines

        -- Find the next header (any level) to determine where this one ends
        if i < #headers then
          content_end = headers[i + 1].line - 1
        else
          -- Last header extends to end of file
          content_end = #lines
        end

        header.content_end = content_end

        -- Calculate actual content (non-empty lines)
        local has_content = false
        for line_num = header.content_start, header.content_end do
          if lines[line_num] and lines[line_num]:match('%S') then
            has_content = true
            break
          end
        end

        header.has_content = has_content

        -- Create instance for BeamScope
        table.insert(instances, {
          start_line = header.line,
          end_line = header.content_end,
          start_col = 0,
          end_col = #(lines[header.content_end] or '') - 1,
          preview = header.text,
          first_line = header.text,
          line_count = header.content_end - header.line + 1,
          level = header.level,
          has_content = has_content,
          content_start = header.content_start,
        })
      end

      return instances
    end,

    -- Select a specific header instance
    select = function(instance, action, variant)
      if variant == 'i' then
        -- Inside header (just the content, not the header line)
        if instance.has_content then
          return {
            start = { instance.content_start, 0 },
            end_ = { instance.end_line, 999 },
          }
        else
          -- No content, select the header line itself
          return {
            start = { instance.start_line, 0 },
            end_ = { instance.start_line, 999 },
          }
        end
      else -- 'a'
        -- Around header (header line + all content)
        return {
          start = { instance.start_line, 0 },
          end_ = { instance.end_line, 999 },
        }
      end
    end,

    -- Format function for BeamScope display
    format = function(instance)
      -- For headers, just show the header line itself
      return { instance.preview or instance.first_line or '' }
    end,
  },
}

-- Check if a text object is handled by this module
function M.is_custom(textobj_key)
  return M.text_objects[textobj_key] ~= nil
end

-- Get custom text object definition
function M.get(textobj_key)
  return M.text_objects[textobj_key]
end

-- Find all instances of a custom text object
function M.find_all(textobj_key, buf)
  local obj = M.text_objects[textobj_key]
  if obj and obj.find then
    return obj.find(buf)
  end
  return {}
end

-- Select a specific instance of a custom text object
function M.select(textobj_key, instance, action, variant)
  local obj = M.text_objects[textobj_key]
  if obj and obj.select then
    return obj.select(instance, action, variant)
  end
  return nil
end

return M
