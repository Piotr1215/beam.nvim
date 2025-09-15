local M = {}

local config = require('beam.config')
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

---Check if we should process a bracket at position
---@param search_key string
---@param pos table Position [line, col]
---@return boolean
local function should_process_bracket(search_key, pos)
  -- Table of brackets that need special handling
  local brackets = {
    ['['] = true,
    ['('] = true,
    ['{'] = true,
    ['<'] = true,
  }

  -- For non-brackets (quotes, etc.), always process
  if not brackets[search_key] then
    return true
  end

  -- Check if we're on an opening bracket
  local char_at_pos = vim.fn.getline(pos[1]):sub(pos[2], pos[2])
  -- Only process if we're on the same opening bracket
  return char_at_pos == search_key
end

---Get search pattern for delimiter
---@param search_key string
---@return string pattern
---@return string key
local function get_delimiter_search_pattern(search_key)
  -- Table-based pattern lookup to reduce complexity
  local pattern_map = {
    ['"'] = '"',
    ["'"] = "'",
    ['`'] = '`',
    ['('] = '[()]',
    [')'] = '[()]',
    ['['] = '\\[\\|\\]',
    [']'] = '\\[\\|\\]',
    ['{'] = '[{}]',
    ['}'] = '[{}]',
    ['<'] = '[<>]',
    ['>'] = '[<>]',
    ['b'] = '[()]',
    ['B'] = '[{}]',
  }

  local key_map = {
    ['b'] = '(',
    ['B'] = '{',
  }

  local pattern = pattern_map[search_key] or vim.fn.escape(search_key, '\\/.*$^~[]')
  local key = key_map[search_key] or search_key

  return pattern, key
end

---Find markdown code blocks in buffer
---@param source_buf number Source buffer
---@return table instances
local function find_markdown_code_blocks(source_buf)
  local instances = {}
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  local in_block = false
  local block_start = nil
  local block_language = nil

  for i, line in ipairs(lines) do
    local fence_match = line:match('^%s*```(.*)$')
    if fence_match then
      if not in_block then
        in_block = true
        block_start = i
        block_language = fence_match:match('^%s*(%S+)') or ''
      else
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

  return instances
end

-- Find all instances of a text object in the current buffer
---Check if instance is a duplicate
---@param instances table List of existing instances
---@param instance table Instance to check
---@return boolean is_duplicate
local function is_duplicate_instance(instances, instance)
  for _, existing in ipairs(instances) do
    if existing.start_line == instance.start_line and existing.start_col == instance.start_col then
      return true
    end
  end
  return false
end

---Try to select a text object at current position
---@param textobj_key string Text object key
---@param search_key string Search key for the text object
---@return table|nil instance Text object instance or nil
local function try_select_text_object(textobj_key, search_key)
  local ok, result = pcall(function()
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
      if content ~= nil then
        return {
          start_line = start_pos[2],
          end_line = end_pos[2],
          start_col = start_pos[3] - 1,
          end_col = end_pos[3] - 1,
          preview = content,
          first_line = vim.split(content, '\n')[1] or content,
          line_count = end_pos[2] - start_pos[2] + 1,
        }
      end
    end
    return nil
  end)

  return ok and result or nil
end

---Switch to source buffer for operations
---@param source_buf number Source buffer number
---@return number original_win Original window
---@return number original_buf Original buffer
---@return boolean need_restore Whether restoration is needed
local function switch_to_source_buffer(source_buf)
  local original_win = vim.api.nvim_get_current_win()
  local original_buf = vim.api.nvim_get_current_buf()
  local need_restore = false

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

  return original_win, original_buf, need_restore
end

-- Helper: Find custom motion instances
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return table instances List of instances
local function find_custom_motion_instances(textobj_key, source_buf)
  if not custom_motions.is_custom(textobj_key) then
    return {}
  end
  return custom_motions.find_all(textobj_key, source_buf)
end

-- Helper: Find custom text object instances
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return table instances List of instances
local function find_custom_textobj_instances(textobj_key, source_buf)
  if not custom_text_objects.is_custom(textobj_key) then
    return {}
  end
  return custom_text_objects.find_all(textobj_key, source_buf)
end

-- Helper: Find delimited text objects (main logic)
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return table instances List of instances
local function find_delimited_instances(textobj_key, source_buf)
  local instances = {}

  -- Check if buffer is empty first
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == '') then
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

  -- Get search pattern for the delimiter
  local search_pattern
  search_pattern, search_key = get_delimiter_search_pattern(search_key)

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

    -- Check if we're stuck at the same position
    if pos[1] == last_pos[1] and pos[2] == last_pos[2] then
      -- Move cursor forward to avoid infinite loop
      vim.fn.cursor(pos[1], pos[2] + 1)
    elseif should_process_bracket(search_key, pos) then
      -- Try to select the text object at this position
      vim.api.nvim_win_set_cursor(0, pos)
      local instance = try_select_text_object(textobj_key, search_key)
      if instance and not is_duplicate_instance(instances, instance) then
        table.insert(instances, instance)
      end
    end
    last_pos = pos
  end

  -- Restore register and view
  vim.fn.setreg('a', saved_reg, saved_reg_type)
  vim.fn.winrestview(saved_view)

  return instances
end

---Find text objects in the source buffer
---@param textobj_key string Text object key
---@param source_buf number Source buffer number
---@return table instances List of text object instances
function M.find_text_objects(textobj_key, source_buf)
  -- Save current window and buffer
  local original_win, original_buf = switch_to_source_buffer(source_buf)

  -- Try different finders in order
  local instances = find_custom_motion_instances(textobj_key, source_buf)

  if #instances == 0 then
    instances = find_custom_textobj_instances(textobj_key, source_buf)
  end

  if #instances == 0 and textobj_key == 'm' then
    instances = find_markdown_code_blocks(source_buf)
  end

  if #instances == 0 then
    instances = find_delimited_instances(textobj_key, source_buf)
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
-- Delimiter mapping for text objects
local DELIMITER_MAP = {
  ['"'] = { '"', '"' },
  ["'"] = { "'", "'" },
  ['`'] = { '`', '`' },
  ['('] = { '(', ')' },
  [')'] = { '(', ')' },
  ['b'] = { '(', ')' },
  ['['] = { '[', ']' },
  [']'] = { '[', ']' },
  ['{'] = { '{', '}' },
  ['}'] = { '{', '}' },
  ['B'] = { '{', '}' },
  ['<'] = { '<', '>' },
  ['>'] = { '<', '>' },
}

---Format single line preview with delimiters
---@param preview string Preview text
---@param left_delim string Left delimiter
---@param right_delim string Right delimiter
---@return table lines Formatted lines
local function format_single_line(preview, left_delim, right_delim)
  if left_delim ~= '' then
    return { left_delim .. preview .. right_delim }
  end
  return { preview }
end

---Format multiline preview with delimiters
---@param preview string Preview text with newlines
---@param left_delim string Left delimiter
---@param right_delim string Right delimiter
---@return table lines Formatted lines
local function format_multiline(preview, left_delim, right_delim)
  local lines = {}
  for line in preview:gmatch('[^\n]+') do
    table.insert(lines, line)
  end

  -- Add delimiters to first and last lines only
  if #lines > 0 and left_delim ~= '' then
    lines[1] = left_delim .. lines[1]
    lines[#lines] = lines[#lines] .. right_delim
  end

  return lines
end

---@param instance table Instance to format
---@param index number|nil Index (unused but kept for compatibility)
---@param textobj_key string Text object key
function M.format_instance_lines(instance, index, textobj_key)
  -- Try custom format functions first
  local custom_obj = custom_text_objects.get(textobj_key)
  if custom_obj and custom_obj.format then
    return custom_obj.format(instance)
  end

  local custom_motion = custom_motions.get(textobj_key)
  if custom_motion and custom_motion.format then
    return custom_motion.format(instance)
  end

  -- Get preview text and delimiters
  local preview = instance.first_line or instance.preview or ''
  local delims = DELIMITER_MAP[textobj_key] or { '', '' }
  local left_delim, right_delim = delims[1], delims[2]

  -- Format based on whether content is multiline
  if preview:find('\n') then
    return format_multiline(preview, left_delim, right_delim)
  else
    return format_single_line(preview, left_delim, right_delim)
  end
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
---Find window containing buffer
---@param buf number Buffer handle
---@return number|nil win Window handle or nil
local function find_window_for_buffer(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
  return nil
end

---Create source window for preview
---@param source_buf number Source buffer handle
---@return number win Window handle
local function create_source_window(source_buf)
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd('rightbelow vsplit')
  local source_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(source_win, source_buf)
  vim.api.nvim_set_current_win(current_win)
  return source_win
end

---Get or create source window
---@param source_buf number Source buffer handle
---@return number win Window handle
local function ensure_source_window(source_buf)
  local source_win = M.scope_state.source_window

  if source_win and vim.api.nvim_win_is_valid(source_win) then
    return source_win
  end

  -- Try to find existing window
  source_win = find_window_for_buffer(source_buf)
  if not source_win then
    source_win = create_source_window(source_buf)
  end

  M.scope_state.source_window = source_win
  return source_win
end

---Apply highlights to instance
---@param source_buf number Buffer handle
---@param instance table Instance to highlight
local function apply_instance_highlights(source_buf, instance)
  -- Ensure namespace exists
  if not M.scope_state.highlight_ns then
    M.scope_state.highlight_ns = vim.api.nvim_create_namespace('BeamScopeHighlight')
  end

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(source_buf, M.scope_state.highlight_ns, 0, -1)

  -- Apply new highlights
  for line = instance.start_line - 1, instance.end_line - 1 do
    vim.api.nvim_buf_add_highlight(source_buf, M.scope_state.highlight_ns, 'Visual', line, 0, -1)
  end
end

function M.update_preview(line_num)
  local instance_idx = M.scope_state.line_to_instance and M.scope_state.line_to_instance[line_num]
  if not instance_idx or not M.scope_state.node_map[instance_idx] then
    return
  end

  local instance = M.scope_state.node_map[instance_idx]
  local source_buf = M.scope_state.source_buffer

  -- Get or create source window
  local source_win = ensure_source_window(source_buf)

  -- Jump to instance and center view
  vim.api.nvim_win_set_cursor(source_win, { instance.start_line, instance.start_col })
  vim.api.nvim_win_call(source_win, function()
    vim.cmd('normal! zz')
  end)

  -- Apply highlights
  apply_instance_highlights(source_buf, instance)
end

-- Execute the operation on the selected instance
---Execute visual mode operation
---@param bounds table Bounds with start and end positions
---@param action string Action to perform
---@param visual_mode string Visual mode type (linewise or characterwise)
local function execute_visual_operation(bounds, action, visual_mode)
  local commands = {
    linewise = {
      yank = 'normal! V%dGy',
      delete = 'normal! V%dGd',
      change = 'normal! V%dGc',
      visual = 'normal! V%dG',
    },
    characterwise = {
      yank = 'normal! v%dG%d|y',
      delete = 'normal! v%dG%d|d',
      change = 'normal! v%dG%d|c',
      visual = 'normal! v%dG%d|',
    },
  }

  local mode = visual_mode == 'linewise' and 'linewise' or 'characterwise'
  local cmd_pattern = commands[mode][action]

  if not cmd_pattern then
    return
  end

  if mode == 'linewise' then
    vim.cmd(string.format(cmd_pattern, bounds.end_[1]))
  else
    -- Characterwise: adjust column for motions
    local end_col = bounds.end_[2]
    if bounds.is_motion then
      end_col = end_col + 1
    end
    vim.cmd(string.format(cmd_pattern, bounds.end_[1], end_col))
  end

  -- Start insert mode for change operations
  if action == 'change' then
    vim.cmd('startinsert')
  end
end

---Execute standard text object operation
---@param textobj string Text object to operate on
---@param action string Action to perform
local function execute_standard_operation(textobj, action)
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

---Execute custom text object operation
---@param textobj_key string Text object key
---@param instance table Text object instance
---@param action string Action to perform
---@param variant string|nil 'i' or 'a' variant
local function execute_custom_textobj(textobj_key, instance, action, variant)
  local custom_obj = custom_text_objects.get(textobj_key)
  local bounds = custom_text_objects.select(textobj_key, instance, action, variant)
  if not bounds then
    return
  end

  vim.api.nvim_win_set_cursor(0, bounds.start)
  local visual_mode = custom_obj and custom_obj.visual_mode or 'characterwise'
  ---@diagnostic disable-next-line: param-type-mismatch
  execute_visual_operation(bounds, action, visual_mode)
end

---Execute custom motion operation
---@param textobj_key string Motion key
---@param instance table Motion instance
---@param action string Action to perform
local function execute_custom_motion(textobj_key, instance, action)
  local custom_motion = custom_motions.get(textobj_key)
  local bounds = custom_motions.select(textobj_key, instance, action)
  if not bounds then
    return
  end

  vim.api.nvim_win_set_cursor(0, bounds.start)
  local visual_mode = custom_motion and custom_motion.visual_mode or 'characterwise'
  bounds.is_motion = true -- Mark as motion for proper column handling
  ---@diagnostic disable-next-line: param-type-mismatch
  execute_visual_operation(bounds, action, visual_mode)
end

-- Helper: Execute text object operation based on type
---@param textobj string Full text object string
---@param instance table Text object instance
---@param action string Action to perform
local function execute_textobj_operation(textobj, instance, action)
  ---@diagnostic disable-next-line: need-check-nil
  local textobj_key = #textobj == 1 and textobj or textobj:sub(2)
  ---@diagnostic disable-next-line: need-check-nil
  local variant = #textobj > 1 and textobj:sub(1, 1) or nil -- 'i' or 'a' for text objects

  -- Check for custom implementations
  if custom_text_objects.is_custom(textobj_key) then
    execute_custom_textobj(textobj_key, instance, action, variant)
  elseif custom_motions.is_custom(textobj_key) then
    execute_custom_motion(textobj_key, instance, action)
  else
    -- For other text objects, use the standard vim commands
    ---@diagnostic disable-next-line: param-type-mismatch
    execute_standard_operation(textobj, action)
  end
end

---Restore original window and position
---@param saved_win number|nil Saved window handle
---@param saved_buf number Saved buffer number
---@param return_pos table Saved cursor position
local function restore_original_position(saved_win, saved_buf, return_pos)
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

---Execute operation on selected instance
---@param line_num number Selected line number
---@return nil
---Get instance from line number
---@param line_num number Line number in scope buffer
---@return table|nil instance The instance or nil if not found
local function get_instance_from_line(line_num)
  local instance_idx = M.scope_state.line_to_instance and M.scope_state.line_to_instance[line_num]
  if not instance_idx or not M.scope_state.node_map[instance_idx] then
    return nil
  end
  return M.scope_state.node_map[instance_idx]
end

---Prepare for operation execution
---@return table|nil state Operation state or nil if invalid
local function prepare_operation_state()
  local state = {
    action = M.scope_state.action,
    textobj = M.scope_state.textobj,
    source_buf = M.scope_state.source_buffer,
    saved_pos = M.scope_state.saved_pos,
    saved_buf = M.scope_state.saved_buf,
    saved_win = M.scope_state.saved_win,
  }

  if not state.textobj then
    return nil
  end

  return state
end

---Execute operation at instance location
---@param instance table Instance to operate on
---@param state table Operation state
local function execute_at_instance(instance, state)
  -- Switch to source buffer
  if vim.api.nvim_get_current_buf() ~= state.source_buf then
    vim.api.nvim_set_current_buf(state.source_buf)
  end

  -- Jump to instance location
  vim.api.nvim_win_set_cursor(0, { instance.start_line, instance.start_col })

  -- Execute the operation
  execute_textobj_operation(state.textobj, instance, state.action)
end

function M.execute_operation(line_num)
  -- Get instance from line
  local instance = get_instance_from_line(line_num)
  if not instance then
    return
  end

  -- Prepare operation state
  local state = prepare_operation_state()
  if not state then
    return
  end

  -- Clean up BeamScope UI
  M.cleanup_scope()

  -- Return to original window after cleanup
  if state.saved_win and vim.api.nvim_win_is_valid(state.saved_win) then
    vim.api.nvim_set_current_win(state.saved_win)
  end

  -- Execute the operation
  execute_at_instance(instance, state)

  -- Return to original position for yank/delete
  local should_return = (state.action == 'yank' or state.action == 'delete')
  if should_return and state.saved_pos and state.saved_buf then
    restore_original_position(state.saved_win, state.saved_buf, state.saved_pos)
  end
end

---Create navigation function for jumping between instances
---@param scope_buf number Scope buffer handle
---@return function Navigation function
local function create_navigation_function(scope_buf)
  return function(direction)
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local current_instance = M.scope_state.line_to_instance[current_line]

    if not current_instance then
      -- Find nearest instance in given direction
      local start, stop, step = current_line + 1, vim.api.nvim_buf_line_count(scope_buf), 1
      if direction == -1 then
        start, stop, step = current_line - 1, 1, -1
      end

      for line = start, stop, step do
        if M.scope_state.line_to_instance[line] then
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
      return
    end

    -- Find next/previous instance with wrapping
    local target_instance = current_instance + direction
    if target_instance < 1 then
      target_instance = #M.scope_state.node_map -- Wrap to last
    elseif target_instance > #M.scope_state.node_map then
      target_instance = 1 -- Wrap to first
    end

    -- Jump to target instance
    local target_node = M.scope_state.node_map[target_instance]
    if target_node and target_node.display_start then
      vim.api.nvim_win_set_cursor(0, { target_node.display_start, 0 })
    end
  end
end

---Setup keymaps for BeamScope buffer
---@param scope_buf number Scope buffer handle
---@param jump_to_next_instance function Navigation function
local function setup_scope_keymaps(scope_buf, jump_to_next_instance)
  -- Enter key for selection
  vim.api.nvim_buf_set_keymap(scope_buf, 'n', '<CR>', '', {
    callback = function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      M.execute_operation(line)
    end,
    noremap = true,
    silent = true,
    desc = 'Execute operation on selected text object',
  })

  -- Navigation keymaps
  local nav_keys = {
    ['<C-n>'] = { direction = 1, desc = 'Next text object instance' },
    ['<C-p>'] = { direction = -1, desc = 'Previous text object instance' },
    ['J'] = { direction = 1, desc = 'Jump to next text object' },
    ['K'] = { direction = -1, desc = 'Jump to previous text object' },
    ['<Tab>'] = { direction = 1, desc = 'Next text object instance' },
    ['<S-Tab>'] = { direction = -1, desc = 'Previous text object instance' },
  }

  for key, opts in pairs(nav_keys) do
    vim.api.nvim_buf_set_keymap(scope_buf, 'n', key, '', {
      callback = function()
        jump_to_next_instance(opts.direction)
      end,
      noremap = true,
      silent = true,
      desc = opts.desc,
    })
  end

  -- Cancel/quit keymaps
  local cancel_keys = { '<Esc>', 'q' }
  for _, key in ipairs(cancel_keys) do
    vim.api.nvim_buf_set_keymap(scope_buf, 'n', key, '', {
      callback = function()
        M.cleanup_scope()
      end,
      noremap = true,
      silent = true,
      desc = key == '<Esc>' and 'Cancel BeamScope operation' or 'Quit BeamScope',
    })
  end
end

---Setup search handling for BeamScope
---@param scope_buf number Scope buffer handle
---@param augroup number Autocommand group ID
local function setup_search_handling(scope_buf, augroup)
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
        vim.defer_fn(function()
          if vim.api.nvim_get_current_buf() == scope_buf then
            local line = vim.api.nvim_win_get_cursor(0)[1]
            M.execute_operation(line)
          end
        end, 50)
      end
    end,
  })
end

---Find closest instance in a direction
---@param instances table Array of instances
---@param cursor_line number Current cursor line
---@param prefer_below boolean Whether to prefer instances below cursor
---@return number best_instance Index of best instance
local function find_closest_instance(instances, cursor_line, prefer_below)
  local best_instance = 1
  local min_distance = math.huge

  for i, instance in ipairs(instances) do
    local is_match = prefer_below and (instance.start_line >= cursor_line)
      or (not prefer_below and instance.start_line < cursor_line)

    if is_match then
      local distance = math.abs(instance.start_line - cursor_line)
      if distance < min_distance then
        min_distance = distance
        best_instance = i
      end
    end
  end

  return min_distance < math.huge and best_instance or nil
end

---Find best initial cursor position based on saved position
---@param instances table Array of text object instances
---@param saved_pos table|nil Saved cursor position
---@return number initial_line Line number for initial cursor position
local function find_best_initial_position(instances, saved_pos)
  if not saved_pos or saved_pos[2] <= 0 then
    return 1
  end

  local cursor_line = saved_pos[2]

  -- Try to find instance at or below cursor first
  local best_instance = find_closest_instance(instances, cursor_line, true)

  -- If none found below, find closest above
  if not best_instance then
    best_instance = find_closest_instance(instances, cursor_line, false) or 1
  end

  local target_node = M.scope_state.node_map[best_instance]
  return (target_node and target_node.display_start) or 1
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
    return false
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

  -- Setup search handling
  setup_search_handling(scope_buf, augroup)

  -- Create a closure for navigation that captures scope_buf
  local jump_to_next_instance = create_navigation_function(scope_buf)

  -- Setup all keymaps
  setup_scope_keymaps(scope_buf, jump_to_next_instance)

  -- Find the best initial position
  local initial_line = find_best_initial_position(instances, saved_pos)

  -- Focus the BeamScope window and set cursor position
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { initial_line, 0 })

  -- Show preview for the selected position
  M.update_preview(initial_line)

  return true
end

-- Check if a text object should use BeamScope
---Check if text object is in list
---@param target string Text object to find
---@param list table List to search
---@param label string Debug label
---@return boolean
local function is_in_scoped_list(target, list, label)
  for _, obj in ipairs(list) do
    if obj == target then
      if vim.g.beam_debug then
        vim.notify(
          string.format('BeamScope: Matched %s with %s scoped object %s', target, label, obj),
          vim.log.levels.DEBUG
        )
      end
      return true
    end
  end
  return false
end

---Check if BeamScope should be used for a text object
---@param textobj string Text object to check
---@return boolean should_use Whether to use BeamScope
---Check if BeamScope is available for use
---@return boolean enabled Whether BeamScope can be used
---@return string|nil reason Reason why it's not available
local function is_beam_scope_available()
  local cfg = config.current

  if not cfg.beam_scope or not cfg.beam_scope.enabled then
    return false, 'disabled'
  end

  if cfg.cross_buffer and cfg.cross_buffer.enabled then
    return false, 'cross_buffer_enabled'
  end

  return true, nil
end

---Get the search key from a text object
---@param textobj string Text object string
---@return string key The key to search for
local function get_textobj_key(textobj)
  return #textobj == 1 and textobj or textobj:sub(2)
end

---Log debug information if enabled
---@param message string Message to log
---@param level number|nil Log level (default: DEBUG)
local function debug_log(message, level)
  if vim.g.beam_debug then
    vim.notify(message, level or vim.log.levels.DEBUG)
  end
end

function M.should_use_scope(textobj)
  -- Check availability
  local available, reason = is_beam_scope_available()
  if not available then
    debug_log(string.format('BeamScope unavailable: %s', reason))
    return false
  end

  local cfg = config.current
  local scoped_objects = cfg.beam_scope.scoped_text_objects or {}
  local custom_objects = cfg.beam_scope.custom_scoped_text_objects or {}

  -- Get the key to search for
  local key = get_textobj_key(textobj)

  -- Debug logging for multi-character objects
  if #textobj > 1 then
    debug_log(string.format('BeamScope check: textobj=%s, key=%s', textobj, key))
  end

  -- Check if key is in either list
  local is_scoped = is_in_scoped_list(key, scoped_objects, 'default')
    or is_in_scoped_list(key, custom_objects, 'custom')

  if not is_scoped then
    debug_log(string.format('BeamScope: No match for %s in %s', key, vim.inspect(scoped_objects)))
  end

  return is_scoped
end

return M
