-- Telescope integration for beam.nvim
-- Handles both single-buffer and cross-buffer fuzzy search
local M = {}
local config = require('beam.config')

-- Get theme configuration for Telescope picker
local function get_telescope_theme()
  local cfg = config.current

  -- Determine if we're in single or cross-buffer mode
  local is_cross_buffer = cfg.cross_buffer and cfg.cross_buffer.enabled
  local has_multiple_buffers = require('beam.operators').has_multiple_buffers
      and require('beam.operators').has_multiple_buffers()
    or false
  local theme_config = nil

  -- Use single buffer config if available and applicable
  if cfg.experimental and cfg.experimental.telescope_single_buffer then
    theme_config = cfg.experimental.telescope_single_buffer
  else
    -- Fallback defaults
    theme_config = {
      theme = 'dropdown',
      preview = is_cross_buffer and has_multiple_buffers, -- Preview useful for cross-buffer
      winblend = 10,
    }
  end

  -- Build theme options
  local themes = require('telescope.themes')
  local theme_opts = {
    winblend = theme_config.winblend or 10,
    relative = 'editor',
  }

  -- Only set previewer if explicitly false (to disable)
  if theme_config.preview == false then
    theme_opts.previewer = false
  end

  -- Apply theme preset if it's a string
  if type(theme_config.theme) == 'string' then
    if theme_config.theme == 'dropdown' then
      return themes.get_dropdown(theme_opts)
    elseif theme_config.theme == 'cursor' then
      return themes.get_cursor(theme_opts)
    elseif theme_config.theme == 'ivy' then
      return themes.get_ivy(theme_opts)
    else
      -- Default to dropdown if unknown theme
      return themes.get_dropdown(theme_opts)
    end
  elseif type(theme_config.theme) == 'table' then
    -- Custom theme table provided
    return vim.tbl_extend('force', theme_opts, theme_config.theme)
  else
    -- Default theme
    return themes.get_dropdown(theme_opts)
  end
end

-- Collect lines from buffers for searching
local function collect_buffer_lines()
  local cfg = config.current
  local items = {}

  if cfg.cross_buffer and cfg.cross_buffer.enabled then
    -- Cross-buffer: collect from all loaded buffers
    local buffers = vim.fn.getbufinfo({ buflisted = 1 })
    
    -- Build a set of visible buffers
    local visible_buffers = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local bufnr = vim.api.nvim_win_get_buf(win)
      visible_buffers[bufnr] = true
    end

    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr) then
        local is_visible = visible_buffers[buf.bufnr] or false
        
        -- Skip hidden buffers if include_hidden is false
        -- Handle both boolean false and string "false"
        local include_hidden = cfg.cross_buffer.include_hidden
        if (include_hidden == false or include_hidden == "false") and not is_visible then
          goto continue
        end
        
        local lines = vim.api.nvim_buf_get_lines(buf.bufnr, 0, -1, false)
        local bufname = vim.fn.fnamemodify(buf.name, ':t') or '[No Name]'
        local indicator = is_visible and '●' or '○'  -- ● for visible, ○ for hidden

        for lnum, line in ipairs(lines) do
          if line ~= '' then -- Skip empty lines
            table.insert(items, {
              bufnr = buf.bufnr,
              bufname = bufname,
              lnum = lnum,
              line = line,
              is_visible = is_visible,
              display = string.format('%s %s:%4d: %s', indicator, bufname, lnum, line),
            })
          end
        end
      end
      ::continue::
    end
    
    -- Sort items: visible buffers first, then by buffer name and line number
    table.sort(items, function(a, b)
      if a.is_visible ~= b.is_visible then
        return a.is_visible  -- visible buffers come first
      end
      if a.bufname ~= b.bufname then
        return a.bufname < b.bufname
      end
      return a.lnum < b.lnum
    end)
  else
    -- Single buffer: only current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t') or '[Current]'

    for lnum, line in ipairs(lines) do
      if line ~= '' then -- Skip empty lines
        table.insert(items, {
          bufnr = bufnr,
          bufname = bufname,
          lnum = lnum,
          line = line,
          display = string.format('%4d: %s', lnum, line), -- Fixed width line numbers
        })
      end
    end
  end

  return items
end

-- Execute the operator after selection
local function execute_operator(selection, operator, textobj, start_buf, start_pos)
  if not selection then
    return
  end

  -- Handle buffer switching properly based on operator
  local target_buf = selection.value.bufnr
  local current_buf = vim.api.nvim_get_current_buf()

  if target_buf ~= current_buf then
    -- For change/visual operations (including line versions), we need to open the buffer properly
    if operator == 'change' or operator == 'visual' or operator == 'changeline' or operator == 'visualline' then
      -- Check if buffer is already visible in a window
      local win_id = vim.fn.bufwinnr(target_buf)

      if win_id > 0 then
        -- Buffer is visible, switch to that window
        vim.cmd(win_id .. 'wincmd w')
      else
        -- Open in a split for editing
        vim.cmd('split | buffer ' .. target_buf)
      end
    else
      -- For yank/delete operations (including line versions), just temporarily switch in current window
      vim.api.nvim_set_current_buf(target_buf)
    end
  end

  -- Now set cursor position
  vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })

  -- Special handling for markdown code blocks
  if textobj == 'im' or textobj == 'am' then
    local cursor_line = selection.value.lnum
    local last_line = vim.api.nvim_buf_line_count(0)
    
    -- Search backward for opening ```
    local start_line = nil
    for line = cursor_line, 1, -1 do
      local content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
      if content and content:match('^```') then
        start_line = line
        break
      end
    end
    
    -- Search forward for closing ```
    local end_line = nil
    if start_line then
      for line = cursor_line, last_line do
        local content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
        if content and content:match('^```') and line > start_line then
          end_line = line
          break
        end
      end
    end
    
    if not start_line or not end_line then
      vim.notify('No markdown code block found at target', vim.log.levels.WARN)
      if target_buf ~= start_buf then
        vim.api.nvim_set_current_buf(start_buf)
        vim.fn.setpos('.', start_pos)
      end
      return
    end
    
    -- Adjust for inside vs around
    local visual_start = start_line
    local visual_end = end_line
    
    if textobj == 'im' then
      -- Inside: exclude backticks
      visual_start = start_line + 1
      visual_end = end_line - 1
    end
    
    -- Set cursor to start of block
    vim.api.nvim_win_set_cursor(0, { visual_start, 0 })
    
    -- Execute operation based on type
    if operator == 'yank' then
      vim.cmd('normal! V')
      vim.api.nvim_win_set_cursor(0, { visual_end, 0 })
      vim.cmd('normal! y')
      -- Return to original position
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)
    elseif operator == 'delete' then
      vim.cmd('normal! V')
      vim.api.nvim_win_set_cursor(0, { visual_end, 0 })
      vim.cmd('normal! d')
      -- Return to original position
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)
    elseif operator == 'change' then
      vim.cmd('normal! V')
      vim.api.nvim_win_set_cursor(0, { visual_end, 0 })
      vim.cmd('normal! c')
      -- Stay in insert mode at target
    elseif operator == 'visual' then
      vim.cmd('normal! V')
      vim.api.nvim_win_set_cursor(0, { visual_end, 0 })
      -- Stay in visual mode at target
    end
    
    return -- Don't continue with normal text object handling
  end

  -- Find first non-whitespace character on the line if searching for a word
  if textobj == 'iw' or textobj == 'aw' then
    vim.cmd('normal! ^')
  end

  -- Execute the operator for normal text objects
  local ok, err
  if operator == 'yank' then
    ok, err = pcall(vim.cmd, 'normal! v' .. textobj .. 'y')
    if ok then
      -- Return to original position for yank
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)

      -- Yanked successfully, cursor returned
    end
  elseif operator == 'delete' then
    ok, err = pcall(vim.cmd, 'normal! v' .. textobj .. 'd')
    if ok then
      -- Return to original position for delete
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)
      -- Deleted successfully, cursor returned
    end
  elseif operator == 'change' then
    -- For change, we stay at the target location
    vim.api.nvim_feedkeys('c' .. textobj, 'n', false)
  elseif operator == 'visual' then
    -- For visual, we stay at the target location
    ok, err = pcall(vim.cmd, 'normal! v' .. textobj)
  elseif operator == 'yankline' then
    ok, err = pcall(vim.cmd, 'normal! yy')
    if ok then
      -- Return to original position for yank line
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)
    end
  elseif operator == 'deleteline' then
    ok, err = pcall(vim.cmd, 'normal! dd')
    if ok then
      -- Return to original position for delete line
      vim.api.nvim_set_current_buf(start_buf)
      vim.fn.setpos('.', start_pos)
    end
  elseif operator == 'changeline' then
    -- For change line, we stay at the target location
    vim.cmd('normal! cc')
    vim.cmd('startinsert')
  elseif operator == 'visualline' then
    -- For visual line, we stay at the target location
    ok, err = pcall(vim.cmd, 'normal! V')
  end

  if not ok and err then
    vim.notify('Failed to ' .. operator .. ': ' .. err, vim.log.levels.ERROR)
  end
end

-- Main search function for all operators
M.search_and_operate = function(operator, textobj)
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.notify('Telescope not found, falling back to normal search', vim.log.levels.WARN)
    -- Fall back to normal search
    if operator == 'yank' then
      return require('beam.operators').create_setup_function('yank', true)(textobj)
    elseif operator == 'delete' then
      return require('beam.operators').create_setup_function('delete', true)(textobj)
    elseif operator == 'change' then
      return require('beam.operators').create_setup_function('change', false)(textobj)
    elseif operator == 'visual' then
      return require('beam.operators').create_setup_function('visual', false)(textobj)
    end
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Save current position
  local start_pos = vim.fn.getpos('.')
  local start_buf = vim.api.nvim_get_current_buf()

  -- Collect lines
  local items = collect_buffer_lines()

  -- Get theme
  local theme = get_telescope_theme()

  -- Determine prompt title
  local cfg = config.current
  local is_cross_buffer = cfg.cross_buffer and cfg.cross_buffer.enabled
  local prompt_title = string.format(
    'Beam %s %s: %s',
    is_cross_buffer and 'Cross-Buffer' or 'Buffer',
    operator:gsub('^%l', string.upper),
    textobj
  )

  -- Create picker with theme
  local picker_opts = vim.tbl_extend('force', theme, {
    prompt_title = prompt_title,
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          display = item.display,
          ordinal = item.line,
          bufnr = item.bufnr,
          lnum = item.lnum,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          execute_operator(selection, operator, textobj, start_buf, start_pos)
        end
      end)
      return true
    end,
  })

  pickers.new({}, picker_opts):find()
end

-- Convenience functions for each operator
M.search_and_yank = function(textobj)
  M.search_and_operate('yank', textobj)
end

M.search_and_delete = function(textobj)
  M.search_and_operate('delete', textobj)
end

M.search_and_change = function(textobj)
  M.search_and_operate('change', textobj)
end

M.search_and_visual = function(textobj)
  M.search_and_operate('visual', textobj)
end

-- Line operator functions
M.search_and_yank_line = function()
  M.search_and_operate('yankline', '')
end

M.search_and_delete_line = function()
  M.search_and_operate('deleteline', '')
end

M.search_and_change_line = function()
  M.search_and_operate('changeline', '')
end

M.search_and_visual_line = function()
  M.search_and_operate('visualline', '')
end

return M
