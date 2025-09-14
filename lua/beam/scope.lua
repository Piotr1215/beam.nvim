local M = {}

local config = require('beam.config')
local operators = require('beam.operators')
local custom_text_objects = require('beam.custom_text_objects')
local custom_motions = require('beam.custom_motions')

M.scope_state = {
  buffer = nil,
  window = nil,
  source_window = nil,
  source_buffer = nil,
  node_map = {},
  line_to_instance = {},
  highlight_ns = nil,
  action = nil,
  textobj = nil,
  saved_pos = nil,
  saved_buf = nil,
  saved_win = nil,
}

-- Cleanup function
function M.cleanup_scope()
  -- Clear highlights
  if M.scope_state.highlight_ns and M.scope_state.source_buffer then
    vim.api.nvim_buf_clear_namespace(M.scope_state.source_buffer, M.scope_state.highlight_ns, 0, -1)
  end

  -- Clear any remaining autocmds
  vim.cmd('silent! autocmd! BeamScope')

  -- Close BeamScope window if it exists and it's not the last window
  if M.scope_state.window and vim.api.nvim_win_is_valid(M.scope_state.window) then
    -- Check if this is the last window
    local win_count = #vim.api.nvim_list_wins()
    if win_count > 1 then
      vim.api.nvim_win_close(M.scope_state.window, true)
    end
  end

  -- Reset state
  M.scope_state = {
    buffer = nil,
    window = nil,
    source_window = nil,
    source_buffer = nil,
    node_map = {},
    line_to_instance = {},
    highlight_ns = nil,
    action = nil,
    textobj = nil,
    saved_pos = nil,
    saved_buf = nil,
    saved_win = nil,
  }
end

-- Find all instances of a text object in the current buffer
---Find text objects in the source buffer
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return table instances List of text object instances
function M.find_text_objects(textobj_key, source_buf)
  local instances = {}

  -- Save current window and buffer
  local original_win = vim.api.nvim_get_current_win()
  local original_buf = vim.api.nvim_get_current_buf()
  local need_restore = false

  -- Switch to source buffer to perform searches
  if original_buf ~= source_buf then
    need_restore = true
    -- Find or create a window for the source buffer
    local source_win = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == source_buf then
        source_win = win
        break
      end
    end

    if source_win then
      vim.api.nvim_set_current_win(source_win)
    else
      vim.api.nvim_set_current_buf(source_buf)
    end
  end

  -- Check if it's a custom motion
  if custom_motions.is_custom(textobj_key) then
    local instances = custom_motions.find_all(textobj_key, source_buf)
    if need_restore then
      vim.api.nvim_set_current_win(original_win)
    end
    return instances

  -- Check if it's a custom text object
  elseif custom_text_objects.is_custom(textobj_key) then
    local instances = custom_text_objects.find_all(textobj_key, source_buf)
    if need_restore then
      vim.api.nvim_set_current_win(original_win)
    end
    return instances

  -- Handle markdown headers specially (DEPRECATED - now in custom_text_objects)
  elseif false and textobj_key == 'h' then
    local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
    local headers = {}

    -- First pass: find all headers with their levels
    for i, line in ipairs(lines) do
      local header_prefix = line:match('^(#+)%s+')
      if header_prefix then
        local header_level = #header_prefix
        local header_text = line:match('^#+%s+(.*)$')
        table.insert(headers, {
          line = i,
          level = header_level,
          text = header_text or line,
          full_line = line,
        })
      end
    end

    -- Second pass: determine content range for each header
    for idx, header in ipairs(headers) do
      local end_line = #lines -- Default to end of file

      -- Find the next header of same or higher level (lower number)
      for j = idx + 1, #headers do
        if headers[j].level <= header.level then
          end_line = headers[j].line - 1
          break
        end
      end

      -- If there's a next header at any level, use that as boundary
      if idx < #headers and end_line == #lines then
        end_line = headers[idx + 1].line - 1
      end

      table.insert(instances, {
        start_line = header.line,
        end_line = end_line,
        start_col = 0,
        end_col = #lines[end_line],
        preview = header.full_line, -- Just show the header line in preview
        first_line = header.full_line,
        line_count = end_line - header.line + 1,
        header_level = header.level,
        header_text = header.text,
      })
    end
  -- Handle markdown code blocks specially
  elseif textobj_key == 'm' then
    local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
    local in_block = false
    local block_start = nil
    local block_language = nil

    for i, line in ipairs(lines) do
      local fence_match = line:match('^%s*```(.*)$')
      if fence_match then
        if not in_block then
          -- Starting a new block
          in_block = true
          block_start = i
          block_language = fence_match:match('^%s*(%S+)') or ''
        else
          -- Ending current block
          local block_lines = {}
          for j = block_start + 1, i - 1 do
            table.insert(block_lines, lines[j])
          end

          local preview = table.concat(block_lines, '\n')

          table.insert(instances, {
            start_line = block_start,
            end_line = i,
            start_col = 0,
            end_col = #lines[i],
            language = block_language,
            preview = preview,
            first_line = block_lines[1] or '',
            line_count = i - block_start - 1,
          })

          in_block = false
          block_start = nil
          block_language = nil
        end
      end
    end
  else
    -- For delimited text objects (quotes, brackets, etc.)
    -- Check if buffer is empty first
    local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
    if #lines == 0 or (#lines == 1 and lines[1] == '') then
      -- Empty buffer, no text objects to find
      -- Restore original window/buffer before returning
      if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
      if
        vim.api.nvim_buf_is_valid(original_buf) and vim.api.nvim_get_current_buf() ~= original_buf
      then
        vim.api.nvim_set_current_buf(original_buf)
      end
      return instances
    end

    local saved_view = vim.fn.winsaveview()

    -- Map of closing delimiters to their opening counterparts
    local delimiter_pairs = {
      [')'] = '(',
      [']'] = '[',
      ['}'] = '{',
      ['>'] = '<',
    }

    -- Use opening delimiter for searching
    local search_key = delimiter_pairs[textobj_key] or textobj_key

    -- Search for all occurrences of the delimiter
    local search_pattern
    if search_key == '"' then
      search_pattern = '"'
    elseif search_key == "'" then
      search_pattern = "'"
    elseif search_key == '`' then
      search_pattern = '`'
    elseif search_key == '(' or search_key == ')' then
      search_pattern = '[()]'
    elseif search_key == '[' or search_key == ']' then
      search_pattern = '\\[\\|\\]'
    elseif search_key == '{' or search_key == '}' then
      search_pattern = '[{}]'
    elseif search_key == '<' or search_key == '>' then
      search_pattern = '[<>]'
    elseif search_key == 'b' then
      search_pattern = '[()]'
      search_key = '('
    elseif search_key == 'B' then
      search_pattern = '[{}]'
      search_key = '{'
    else
      search_pattern = vim.fn.escape(search_key, '\\/.*$^~[]')
    end

    -- Find all occurrences of the delimiter
    vim.fn.cursor(1, 1)
    local saved_reg = vim.fn.getreg('a')
    local saved_reg_type = vim.fn.getregtype('a')

    -- Add safety counter to prevent infinite loops
    local max_iterations = 1000
    local iteration = 0
    local last_pos = { 0, 0 }

    while iteration < max_iterations do
      iteration = iteration + 1
      local pos = vim.fn.searchpos(search_pattern, 'W')
      if pos[1] == 0 then
        break
      end

      local should_process = true

      -- Check if we're stuck at the same position
      if pos[1] == last_pos[1] and pos[2] == last_pos[2] then
        -- Move cursor forward to avoid infinite loop
        vim.fn.cursor(pos[1], pos[2] + 1)
        should_process = false
      end
      last_pos = pos

      -- For brackets, check if we're on an opening bracket
      -- But for quotes, we don't need this check since they're symmetric
      if
        should_process
        and (search_key == '[' or search_key == '(' or search_key == '{' or search_key == '<')
      then
        local char_at_pos = vim.fn.getline(pos[1]):sub(pos[2], pos[2])
        local is_opening = false
        if search_key == '[' and char_at_pos == '[' then
          is_opening = true
        elseif search_key == '(' and char_at_pos == '(' then
          is_opening = true
        elseif search_key == '{' and char_at_pos == '{' then
          is_opening = true
        elseif search_key == '<' and char_at_pos == '<' then
          is_opening = true
        end

        -- Skip closing brackets as yi[ doesn't work from closing bracket position
        if not is_opening then
          should_process = false
        end
      end

      if should_process then
        -- Try to select the text object at this position
        vim.api.nvim_win_set_cursor(0, pos)

        local ok = pcall(function()
          -- For single-letter motions, use the motion directly
          -- For text objects, use yi + key
          if #textobj_key == 1 and textobj_key:match('[A-Z]') then
            -- Single uppercase letter is likely a motion (like L for URL)
            vim.cmd('silent! normal! "ay' .. textobj_key)
          else
            -- Regular text object with inner variant
            vim.cmd('silent! normal! "ayi' .. search_key)
          end

          -- Get the selection marks
          local start_pos = vim.fn.getpos("'[")
          local end_pos = vim.fn.getpos("']")

          if start_pos[2] > 0 and end_pos[2] > 0 then
            local content = vim.fn.getreg('a')

            -- Check if this is a new instance
            local is_new = true
            for _, existing in ipairs(instances) do
              if existing.start_line == start_pos[2] and existing.start_col == start_pos[3] - 1 then
                is_new = false
                break
              end
            end

            if is_new and content ~= nil then
              -- Get the full content (no truncation), allow empty strings
              local preview = content

              table.insert(instances, {
                start_line = start_pos[2],
                end_line = end_pos[2],
                start_col = start_pos[3] - 1,
                end_col = end_pos[3] - 1,
                preview = preview,
                first_line = vim.split(content, '\n')[1] or content,
                line_count = end_pos[2] - start_pos[2] + 1,
              })
            end
          end
        end)
      end
    end

    -- Restore register and view
    vim.fn.setreg('a', saved_reg, saved_reg_type)
    vim.fn.winrestview(saved_view)

    -- Try Tree-sitter as a fallback for more complex text objects
    local has_ts, ts_textobjects = pcall(require, 'nvim-treesitter.textobjects.select')
    if has_ts and #instances == 0 then
      -- Try to find Tree-sitter nodes for this text object
      local parser = vim.treesitter.get_parser(source_buf)
      if parser then
        local tree = parser:parse()[1]
        local root = tree:root()

        -- Map common text objects to Tree-sitter queries
        local query_map = {
          f = '@function.outer',
          F = '@function.inner',
          c = '@class.outer',
          C = '@class.inner',
          a = '@parameter.outer',
          A = '@parameter.inner',
        }

        local query_string = query_map[textobj_key]
        if query_string then
          -- Use Tree-sitter to find matches
          -- This is simplified - real implementation would need proper query handling
          local lang = parser:lang()
          local ok, query =
            pcall(vim.treesitter.query.parse, lang, '(' .. query_string .. ') @capture')
          if ok then
            for id, node in query:iter_captures(root, source_buf) do
              local start_row, start_col, end_row, end_col = node:range()
              local text = vim.treesitter.get_node_text(node, source_buf)
              local preview = text:match('^[^\n]*') or ''

              table.insert(instances, {
                start_line = start_row + 1,
                end_line = end_row + 1,
                start_col = start_col,
                end_col = end_col,
                node = node,
                preview = preview,
                first_line = preview,
                line_count = end_row - start_row + 1,
              })
            end
          end
        end
      end
    end

    -- Fallback: Try to execute the text object and capture positions
    -- This is a simplified approach - real implementation would be more robust
    if #instances == 0 then
      local saved_view = vim.fn.winsaveview()
      local lines = vim.api.nvim_buf_line_count(source_buf)

      for line = 1, lines do
        vim.api.nvim_win_set_cursor(0, { line, 0 })

        -- Try to select the text object
        local ok = pcall(function()
          vim.cmd('normal! v' .. 'i' .. textobj_key)
          local start_pos = vim.fn.getpos("'<")
          local end_pos = vim.fn.getpos("'>")

          if start_pos[2] > 0 and end_pos[2] > 0 then
            local text = vim.fn.getline(start_pos[2], end_pos[2])
            local preview = type(text) == 'table' and text[1] or text
            if #preview > 100 then
              preview = preview:sub(1, 100) .. '...'
            end

            table.insert(instances, {
              start_line = start_pos[2],
              end_line = end_pos[2],
              start_col = start_pos[3] - 1,
              end_col = end_pos[3] - 1,
              preview = preview,
              first_line = preview,
              line_count = end_pos[2] - start_pos[2] + 1,
            })
          end

          vim.cmd('normal! \\<Esc>')
        end)
      end

      vim.fn.winrestview(saved_view)
    end
  end

  -- Restore original window/buffer
  if vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end
  if vim.api.nvim_buf_is_valid(original_buf) and vim.api.nvim_get_current_buf() ~= original_buf then
    vim.api.nvim_set_current_buf(original_buf)
  end

  return instances
end

-- Create formatted lines for the scope buffer (returns multiple lines per instance)
---Format instance lines for display
---@param instance table Text object instance
---@param index number Instance index
---@param textobj_key string Text object key
---@return table lines Formatted lines
function M.format_instance_lines(instance, index, textobj_key)
  local lines = {}

  -- Check if it's a custom text object with a format function
  local custom_obj = custom_text_objects.get(textobj_key)
  if custom_obj and custom_obj.format then
    return custom_obj.format(instance)
  end

  -- Check if it's a custom motion with a format function
  local custom_motion = custom_motions.get(textobj_key)
  if custom_motion and custom_motion.format then
    return custom_motion.format(instance)
  end

  -- For built-in text objects, show the complete content with delimiters
  local preview = instance.first_line or instance.preview or ''

  -- Determine delimiters based on text object type
  local left_delim, right_delim = '', ''
  if textobj_key == '"' then
    left_delim, right_delim = '"', '"'
  elseif textobj_key == "'" then
    left_delim, right_delim = "'", "'"
  elseif textobj_key == '`' then
    left_delim, right_delim = '`', '`'
  elseif textobj_key == '(' or textobj_key == ')' or textobj_key == 'b' then
    left_delim, right_delim = '(', ')'
  elseif textobj_key == '[' or textobj_key == ']' then
    left_delim, right_delim = '[', ']'
  elseif textobj_key == '{' or textobj_key == '}' or textobj_key == 'B' then
    left_delim, right_delim = '{', '}'
  elseif textobj_key == '<' or textobj_key == '>' then
    left_delim, right_delim = '<', '>'
  end

  -- Handle multiline content properly
  if preview:find('\n') then
    local preview_lines = {}
    for line in preview:gmatch('[^\n]+') do
      table.insert(preview_lines, line)
    end

    -- Add delimiters to first and last lines only
    if #preview_lines > 0 and left_delim ~= '' then
      preview_lines[1] = left_delim .. preview_lines[1]
      preview_lines[#preview_lines] = preview_lines[#preview_lines] .. right_delim
    end

    for _, line in ipairs(preview_lines) do
      table.insert(lines, line)
    end
  else
    -- Single line - add delimiters if applicable
    if left_delim ~= '' then
      table.insert(lines, left_delim .. preview .. right_delim)
    else
      table.insert(lines, preview)
    end
  end

  return lines
end

-- Create the BeamScope buffer
---Create scope buffer with formatted content
---@param instances table List of instances
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return number buffer Buffer number
function M.create_scope_buffer(instances, textobj_key, source_buf)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)

  -- Populate the buffer and build line-to-instance mapping
  local lines = {}
  local line_to_instance = {}
  local current_line = 1

  for i, instance in ipairs(instances) do
    local instance_lines = M.format_instance_lines(instance, i, textobj_key)
    local start_line = current_line

    for _, line in ipairs(instance_lines) do
      table.insert(lines, line)
      -- Map each line of this instance to the instance index
      line_to_instance[current_line] = i
      current_line = current_line + 1
    end

    -- Store the display range for this instance
    instance.display_start = start_line
    instance.display_end = current_line - 1
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Make buffer readonly after populating
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)

  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'BeamScope: ' .. textobj_key)

  -- Set filetype to match source buffer
  local source_ft = vim.api.nvim_buf_get_option(source_buf, 'filetype')
  if source_ft and source_ft ~= '' then
    vim.api.nvim_buf_set_option(buf, 'filetype', source_ft)
  end

  -- Store the mapping
  M.scope_state.node_map = instances
  M.scope_state.line_to_instance = line_to_instance
  M.scope_state.buffer = buf
  M.scope_state.source_buffer = source_buf

  return buf
end

-- Update preview by showing the code block in the source buffer
---Update preview highlighting
---@param line_num number Current line number
---@return nil
function M.update_preview(line_num)
  local instance_idx = M.scope_state.line_to_instance and M.scope_state.line_to_instance[line_num]
  if not instance_idx or not M.scope_state.node_map[instance_idx] then
    return
  end

  local instance = M.scope_state.node_map[instance_idx]
  local source_buf = M.scope_state.source_buffer

  -- Find or create source window
  local source_win = M.scope_state.source_window
  if not source_win or not vim.api.nvim_win_is_valid(source_win) then
    -- Find existing window with source buffer
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == source_buf then
        source_win = win
        break
      end
    end

    -- If no window found, create one
    if not source_win then
      -- Save current window
      local current_win = vim.api.nvim_get_current_win()

      -- Create a split for the source buffer
      vim.cmd('rightbelow vsplit')
      source_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(source_win, source_buf)

      -- Go back to BeamScope window
      vim.api.nvim_set_current_win(current_win)
    end

    M.scope_state.source_window = source_win
  end

  -- Jump to the code block in the source window
  vim.api.nvim_win_set_cursor(source_win, { instance.start_line, instance.start_col })

  -- Clear previous highlights
  if M.scope_state.highlight_ns then
    vim.api.nvim_buf_clear_namespace(source_buf, M.scope_state.highlight_ns, 0, -1)
  else
    M.scope_state.highlight_ns = vim.api.nvim_create_namespace('BeamScopeHighlight')
  end

  -- Highlight the code block lines
  for line = instance.start_line - 1, instance.end_line - 1 do
    vim.api.nvim_buf_add_highlight(source_buf, M.scope_state.highlight_ns, 'Visual', line, 0, -1)
  end

  -- Center the view on the code block in source window
  vim.api.nvim_win_call(source_win, function()
    vim.cmd('normal! zz')
  end)
end

-- Execute the operation on the selected instance
---Execute operation on selected instance
---@param line_num number Selected line number
---@return nil
function M.execute_operation(line_num)
  local instance_idx = M.scope_state.line_to_instance and M.scope_state.line_to_instance[line_num]
  if not instance_idx or not M.scope_state.node_map[instance_idx] then
    return
  end

  local instance = M.scope_state.node_map[instance_idx]

  local action = M.scope_state.action
  local textobj = M.scope_state.textobj
  local source_buf = M.scope_state.source_buffer
  local saved_pos = M.scope_state.saved_pos
  local saved_buf = M.scope_state.saved_buf
  local saved_win = M.scope_state.saved_win -- Get the saved window from state

  -- Clean up BeamScope UI first
  M.cleanup_scope()

  -- After cleanup, we should return to the original window if it still exists
  if saved_win and vim.api.nvim_win_is_valid(saved_win) then
    vim.api.nvim_set_current_win(saved_win)
  end

  -- Save the return position for yank/delete operations
  local should_return = (action == 'yank' or action == 'delete')
  local return_pos = should_return and saved_pos or nil

  -- Switch to source buffer temporarily to execute the operation
  if vim.api.nvim_get_current_buf() ~= source_buf then
    vim.api.nvim_set_current_buf(source_buf)
  end

  -- Jump to the code block
  vim.api.nvim_win_set_cursor(0, { instance.start_line, instance.start_col })

  -- Execute the actual text object operation
  local textobj_key = #textobj == 1 and textobj or textobj:sub(2)
  local variant = #textobj > 1 and textobj:sub(1, 1) or nil -- 'i' or 'a' for text objects

  -- Check for custom implementations
  if custom_text_objects.is_custom(textobj_key) then
    -- Get the custom object definition
    local custom_obj = custom_text_objects.get(textobj_key)
    -- Get the selection bounds from the custom text object
    local bounds = custom_text_objects.select(textobj_key, instance, action, variant)
    if bounds then
      vim.api.nvim_win_set_cursor(0, bounds.start)

      -- Determine visual mode from object metadata
      local visual_mode = custom_obj and custom_obj.visual_mode or 'characterwise'

      if visual_mode == 'linewise' then
        -- Use linewise visual mode
        if action == 'yank' then
          vim.cmd(string.format('normal! V%dGy', bounds.end_[1]))
        elseif action == 'delete' then
          vim.cmd(string.format('normal! V%dGd', bounds.end_[1]))
        elseif action == 'change' then
          vim.cmd(string.format('normal! V%dGc', bounds.end_[1]))
          vim.cmd('startinsert')
        elseif action == 'visual' then
          vim.cmd(string.format('normal! V%dG', bounds.end_[1]))
        end
      else
        -- Use characterwise visual mode (default)
        if action == 'yank' then
          vim.cmd(string.format('normal! v%dG%d|y', bounds.end_[1], bounds.end_[2]))
        elseif action == 'delete' then
          vim.cmd(string.format('normal! v%dG%d|d', bounds.end_[1], bounds.end_[2]))
        elseif action == 'change' then
          vim.cmd(string.format('normal! v%dG%d|c', bounds.end_[1], bounds.end_[2]))
          vim.cmd('startinsert')
        elseif action == 'visual' then
          vim.cmd(string.format('normal! v%dG%d|', bounds.end_[1], bounds.end_[2]))
        end
      end
    end
  elseif custom_motions.is_custom(textobj_key) then
    -- Custom motion handling (single-letter like L)
    local custom_motion = custom_motions.get(textobj_key)
    local bounds = custom_motions.select(textobj_key, instance, action)
    if bounds then
      vim.api.nvim_win_set_cursor(0, bounds.start)

      -- Motions are typically characterwise
      local visual_mode = custom_motion and custom_motion.visual_mode or 'characterwise'

      if visual_mode == 'linewise' then
        -- Use linewise visual mode (unlikely for motions, but supported)
        if action == 'yank' then
          vim.cmd(string.format('normal! V%dGy', bounds.end_[1]))
        elseif action == 'delete' then
          vim.cmd(string.format('normal! V%dGd', bounds.end_[1]))
        elseif action == 'change' then
          vim.cmd(string.format('normal! V%dGc', bounds.end_[1]))
          vim.cmd('startinsert')
        elseif action == 'visual' then
          vim.cmd(string.format('normal! V%dG', bounds.end_[1]))
        end
      else
        -- Use characterwise visual mode (default for motions)
        if action == 'yank' then
          vim.cmd(string.format('normal! v%dG%d|y', bounds.end_[1], bounds.end_[2] + 1))
        elseif action == 'delete' then
          vim.cmd(string.format('normal! v%dG%d|d', bounds.end_[1], bounds.end_[2] + 1))
        elseif action == 'change' then
          vim.cmd(string.format('normal! v%dG%d|c', bounds.end_[1], bounds.end_[2] + 1))
          vim.cmd('startinsert')
        elseif action == 'visual' then
          vim.cmd(string.format('normal! v%dG%d|', bounds.end_[1], bounds.end_[2] + 1))
        end
      end
    end
  else
    -- For other text objects, use the standard vim commands
    if action == 'yank' then
      vim.cmd('normal! v' .. textobj .. 'y')
    elseif action == 'delete' then
      vim.cmd('normal! v' .. textobj .. 'd')
    elseif action == 'change' then
      -- Delete content, position cursor, then enter insert mode
      vim.cmd('normal! v' .. textobj .. 'd')
      -- Use 'a' to position cursor correctly (after the opening delimiter)
      vim.cmd('normal a')
      vim.cmd('startinsert')
    elseif action == 'visual' then
      vim.cmd('normal! v' .. textobj)
    end
  end

  -- Return to original position if needed
  if return_pos and saved_buf then
    -- Try to return to the original window if it's still valid
    if saved_win and vim.api.nvim_win_is_valid(saved_win) then
      vim.api.nvim_set_current_win(saved_win)
      -- Make sure the window has the correct buffer
      if vim.api.nvim_win_get_buf(saved_win) ~= saved_buf then
        vim.api.nvim_win_set_buf(saved_win, saved_buf)
      end
    elseif vim.api.nvim_buf_is_valid(saved_buf) then
      -- Original window no longer exists, switch current window to saved buffer
      vim.api.nvim_set_current_buf(saved_buf)
    end
    -- Restore cursor position
    vim.fn.setpos('.', return_pos)
  end
end

-- Main entry point for BeamScope
---Main BeamScope function
---@param action string Action to perform
---@param textobj string Text object to select
---@return boolean success Whether BeamScope was activated
function M.beam_scope(action, textobj)
  local source_buf = vim.api.nvim_get_current_buf()
  local saved_pos = vim.fn.getpos('.')
  local saved_win = vim.api.nvim_get_current_win() -- Save the original window

  -- Extract the actual text object key
  -- For single-letter motions (like L), use as-is
  -- For text objects with i/a prefix, remove the prefix
  local textobj_key
  if #textobj == 1 then
    textobj_key = textobj -- Single-letter motion
  else
    textobj_key = textobj:sub(2) -- Remove i/a prefix
  end

  -- Find all instances of the text object
  local instances = M.find_text_objects(textobj_key, source_buf)

  if #instances == 0 then
    vim.notify('No instances of text object "' .. textobj .. '" found', vim.log.levels.WARN)
    return
  end

  -- Store operation state
  M.scope_state.action = action
  M.scope_state.textobj = textobj
  M.scope_state.saved_pos = saved_pos
  M.scope_state.saved_buf = source_buf
  M.scope_state.saved_win = saved_win -- Store the original window

  -- Create the scope buffer
  local scope_buf = M.create_scope_buffer(instances, textobj_key, source_buf)

  -- Open in a vertical split on the left
  vim.cmd('topleft vsplit')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, scope_buf)
  M.scope_state.window = win

  -- Calculate appropriate width based on content
  local cfg = config.current
  local max_width = (cfg.beam_scope and cfg.beam_scope.window_width) or 60
  local min_width = 40

  -- Calculate the actual width needed based on buffer content
  local lines = vim.api.nvim_buf_get_lines(scope_buf, 0, -1, false)
  local content_width = min_width
  for _, line in ipairs(lines) do
    content_width = math.max(content_width, #line + 5) -- Add some padding
  end

  vim.api.nvim_win_set_width(win, math.min(max_width, math.max(min_width, content_width)))

  -- Set up autocmds for preview and selection
  local augroup = vim.api.nvim_create_augroup('BeamScope', { clear = true })

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = scope_buf,
    callback = function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      M.update_preview(line)
    end,
  })

  -- Set up Enter key for both normal mode and after search
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<CR>', '', {
    callback = function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      M.execute_operation(line)
    end,
    noremap = true,
    silent = true,
    desc = 'Execute operation on selected text object',
  })

  -- Track if we want to execute on search completion
  local execute_on_search = false

  -- Override Enter in command-line mode for search
  vim.keymap.set('c', '<CR>', function()
    local cmdtype = vim.fn.getcmdtype()
    if cmdtype == '/' or cmdtype == '?' then
      execute_on_search = true
    end
    return '<CR>'
  end, { buffer = scope_buf, expr = true })

  -- Handle search completion
  vim.api.nvim_create_autocmd('CmdlineLeave', {
    group = augroup,
    buffer = scope_buf,
    callback = function()
      if execute_on_search then
        execute_on_search = false
        -- Small delay to let cursor position update after search
        vim.defer_fn(function()
          if vim.api.nvim_get_current_buf() == scope_buf then
            local line = vim.api.nvim_win_get_cursor(0)[1]
            M.execute_operation(line)
          end
        end, 50)
      end
    end,
  })

  -- Navigation helper function
  local function jump_to_next_instance(direction)
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local current_instance = M.scope_state.line_to_instance[current_line]

    if not current_instance then
      -- If not on an instance, find the nearest one
      if direction == 1 then
        for line = current_line + 1, vim.api.nvim_buf_line_count(scope_buf) do
          if M.scope_state.line_to_instance[line] then
            vim.api.nvim_win_set_cursor(0, { line, 0 })
            return
          end
        end
      else
        for line = current_line - 1, 1, -1 do
          if M.scope_state.line_to_instance[line] then
            vim.api.nvim_win_set_cursor(0, { line, 0 })
            return
          end
        end
      end
      return
    end

    -- Find next/previous instance
    local target_instance = current_instance + direction
    if target_instance < 1 then
      target_instance = #M.scope_state.node_map -- Wrap to last
    elseif target_instance > #M.scope_state.node_map then
      target_instance = 1 -- Wrap to first
    end

    -- Find line for target instance
    local target_node = M.scope_state.node_map[target_instance]
    if target_node and target_node.display_start then
      vim.api.nvim_win_set_cursor(0, { target_node.display_start, 0 })
    end
  end

  -- Set up navigation keybindings using Ctrl-n/Ctrl-p
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<C-n>', '', {
    callback = function()
      jump_to_next_instance(1)
    end,
    noremap = true,
    silent = true,
    desc = 'Next text object instance',
  })

  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<C-p>', '', {
    callback = function()
      jump_to_next_instance(-1)
    end,
    noremap = true,
    silent = true,
    desc = 'Previous text object instance',
  })

  -- Alternative navigation with j/k (jump between instances, not lines)
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', 'J', '', {
    callback = function()
      jump_to_next_instance(1)
    end,
    noremap = true,
    silent = true,
    desc = 'Jump to next text object',
  })

  vim.api.nvim_buf_set_keymap(scope_buf, 'n', 'K', '', {
    callback = function()
      jump_to_next_instance(-1)
    end,
    noremap = true,
    silent = true,
    desc = 'Jump to previous text object',
  })

  -- Tab/Shift-Tab navigation
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<Tab>', '', {
    callback = function()
      jump_to_next_instance(1)
    end,
    noremap = true,
    silent = true,
    desc = 'Next text object instance',
  })

  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<S-Tab>', '', {
    callback = function()
      jump_to_next_instance(-1)
    end,
    noremap = true,
    silent = true,
    desc = 'Previous text object instance',
  })

  -- Set up cancel
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<Esc>', '', {
    callback = function()
      M.cleanup_scope()
    end,
    noremap = true,
    silent = true,
    desc = 'Cancel BeamScope operation',
  })

  vim.api.nvim_buf_set_keymap(scope_buf, 'n', 'q', '', {
    callback = function()
      M.cleanup_scope()
    end,
    noremap = true,
    silent = true,
    desc = 'Quit BeamScope',
  })

  -- Find the best initial position based on cursor location
  local initial_line = 1
  if saved_pos and saved_pos[2] > 0 then
    local cursor_line = saved_pos[2]
    local best_instance = 1
    local min_distance = math.huge

    -- Find the text object instance closest to (preferably below) the cursor
    for i, instance in ipairs(instances) do
      -- Prefer instances at or below cursor position
      if instance.start_line >= cursor_line then
        local distance = instance.start_line - cursor_line
        if distance < min_distance then
          min_distance = distance
          best_instance = i
        end
      end
    end

    -- If no instance below cursor, find the closest one above
    if min_distance == math.huge then
      for i, instance in ipairs(instances) do
        if instance.start_line < cursor_line then
          local distance = cursor_line - instance.start_line
          if distance < min_distance then
            min_distance = distance
            best_instance = i
          end
        end
      end
    end

    -- Set cursor to the display position of the best instance
    local target_node = M.scope_state.node_map[best_instance]
    if target_node and target_node.display_start then
      initial_line = target_node.display_start
    end
  end

  -- Focus the BeamScope window and set cursor position
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { initial_line, 0 })

  -- Show preview for the selected position
  M.update_preview(initial_line)
end

-- Check if a text object should use BeamScope
---Check if BeamScope should be used for a text object
---@param textobj string Text object to check
---@return boolean should_use Whether to use BeamScope
function M.should_use_scope(textobj)
  local cfg = config.current

  -- Check if BeamScope is enabled
  if not cfg.beam_scope or not cfg.beam_scope.enabled then
    return false
  end

  -- BeamScope is incompatible with cross-buffer operations
  if cfg.cross_buffer and cfg.cross_buffer.enabled then
    return false
  end

  -- Check if this text object is configured for BeamScope
  local scoped_objects = cfg.beam_scope.scoped_text_objects or {}
  local custom_objects = cfg.beam_scope.custom_scoped_text_objects or {}

  -- Handle single-letter motions (like L for URL)
  if #textobj == 1 then
    -- For single-letter inputs, check directly against scoped objects
    for _, obj in ipairs(scoped_objects) do
      if obj == textobj then
        if vim.g.beam_debug then
          vim.notify(
            string.format(
              'BeamScope: Matched motion %s with default scoped object %s',
              textobj,
              obj
            ),
            vim.log.levels.DEBUG
          )
        end
        return true
      end
    end

    for _, obj in ipairs(custom_objects) do
      if obj == textobj then
        if vim.g.beam_debug then
          vim.notify(
            string.format('BeamScope: Matched motion %s with custom scoped object %s', textobj, obj),
            vim.log.levels.DEBUG
          )
        end
        return true
      end
    end
  end

  -- Extract text object key (remove i/a prefix for standard text objects)
  local key = textobj:sub(2)

  -- Debug logging
  if vim.g.beam_debug then
    vim.notify(
      string.format('BeamScope check: textobj=%s, key=%s', textobj, key),
      vim.log.levels.DEBUG
    )
  end

  -- Check default scoped objects for text objects with i/a prefix
  for _, obj in ipairs(scoped_objects) do
    if obj == key then
      if vim.g.beam_debug then
        vim.notify(
          string.format('BeamScope: Matched %s with default scoped object %s', key, obj),
          vim.log.levels.DEBUG
        )
      end
      return true
    end
  end

  -- Check custom scoped objects for text objects with i/a prefix
  for _, obj in ipairs(custom_objects) do
    if obj == key then
      if vim.g.beam_debug then
        vim.notify(
          string.format('BeamScope: Matched %s with custom scoped object %s', key, obj),
          vim.log.levels.DEBUG
        )
      end
      return true
    end
  end

  if vim.g.beam_debug then
    vim.notify(
      string.format('BeamScope: No match for %s in %s', key, vim.inspect(scoped_objects)),
      vim.log.levels.DEBUG
    )
  end

  return false
end

return M
