local M = {}
local config = require('beam.config')
local search_transform = require('beam.search_transform')

M.BeamSearchOperator = function(type)
  local pattern = vim.g.beam_search_operator_pattern
  local saved_pos = vim.g.beam_search_operator_saved_pos
  local saved_buf = vim.g.beam_search_operator_saved_buf
  local textobj = vim.g.beam_search_operator_textobj
  local action = vim.g.beam_search_operator_action

  if not pattern or not textobj or not action then
    return
  end

  local saved_reg = vim.fn.getreg('"')
  local saved_reg_type = vim.fn.getregtype('"')
  local saved_search = vim.fn.getreg('/')

  local ok = pcall(function()
    local cfg = config.current
    local feedback_duration = cfg.visual_feedback_duration or 150

    -- Special handling for markdown code block text objects
    if textobj == 'im' or textobj == 'am' then
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      local last_line = vim.api.nvim_buf_line_count(0)

      -- Search backward for opening ```
      local start_line = nil
      for i = cursor_line, 1, -1 do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if line:match('^%s*```') then
          start_line = i
          break
        end
      end

      if not start_line then
        return
      end

      -- Search forward for closing ```
      local end_line = nil
      for i = start_line + 1, last_line do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if line:match('^%s*```') then
          end_line = i
          break
        end
      end

      if not end_line then
        return
      end

      if textobj == 'im' then
        -- Inside: exclude backticks
        start_line = start_line + 1
        end_line = end_line - 1
      end

      if start_line > end_line then
        return
      end

      -- Execute the action on the code block
      if action == 'yank' then
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        vim.cmd('normal! V' .. end_line .. 'G')
        vim.cmd('redraw')
        vim.cmd('sleep ' .. feedback_duration .. 'm')
        vim.cmd('normal! y')
      elseif action == 'delete' then
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        vim.cmd('normal! V' .. end_line .. 'Gd')
      elseif action == 'change' then
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        -- Use feedkeys to properly enter insert mode
        vim.api.nvim_feedkeys('V' .. end_line .. 'Gc', 'n', false)
      elseif action == 'visual' then
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        vim.cmd('normal! V' .. end_line .. 'G')
      end
    elseif action == 'yank' then
      vim.cmd('normal v' .. textobj)
      vim.cmd('redraw')
      vim.cmd('sleep ' .. feedback_duration .. 'm')
      vim.cmd('normal! y')
    elseif action == 'delete' then
      vim.cmd('normal v' .. textobj)
      vim.cmd('redraw')
      vim.cmd('sleep ' .. feedback_duration .. 'm')
      vim.cmd('normal! d')
    elseif action == 'change' then
      -- Delete content, position cursor, then enter insert mode
      vim.cmd('normal! v' .. textobj .. 'd')
      vim.cmd('normal a')
      vim.cmd('startinsert')
    elseif action == 'visual' then
      vim.cmd('normal v' .. textobj)
    elseif action == 'yankline' then
      vim.cmd('normal! yy')
    elseif action == 'deleteline' then
      vim.cmd('normal! dd')
    elseif action == 'changeline' then
      vim.cmd('normal! cc')
      vim.cmd('startinsert')
    elseif action == 'visualline' then
      vim.cmd('normal! V')
    end
  end)

  if ok then
    -- Yank and delete operations should restore cursor position
    if
      (action == 'yank' or action == 'delete' or action == 'yankline' or action == 'deleteline')
      and saved_pos
    then
      -- Check if we need to restore to a different buffer
      if saved_buf and vim.api.nvim_buf_is_valid(saved_buf) then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= saved_buf then
          -- Switch back to the original buffer
          vim.api.nvim_set_current_buf(saved_buf)
        end
      end
      -- Always restore position if we have it
      if saved_pos then
        vim.fn.setpos('.', saved_pos)
      end
    end

    local cfg = config.current
    if
      cfg.clear_highlight
      and action ~= 'change'
      and action ~= 'visual'
      and action ~= 'changeline'
      and action ~= 'visualline'
    then
      vim.defer_fn(function()
        vim.cmd('nohlsearch')
        vim.fn.setreg('/', saved_search)
      end, cfg.clear_highlight_delay or 500)
    end
  else
    if saved_pos then
      -- Restore buffer if needed
      if saved_buf and vim.api.nvim_buf_is_valid(saved_buf) then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= saved_buf then
          vim.api.nvim_set_current_buf(saved_buf)
        end
      end
      vim.fn.setpos('.', saved_pos)
    end
    vim.fn.setreg('"', saved_reg, saved_reg_type)
    vim.fn.setreg('/', saved_search)
    vim.cmd('nohlsearch')
  end

  vim.g.beam_search_operator_pattern = nil
  vim.g.beam_search_operator_saved_pos = nil
  vim.g.beam_search_operator_textobj = nil
  vim.g.beam_search_operator_action = nil
end

M.BeamSearchOperatorPending = {}
_G.BeamSearchOperatorPending = nil

M.BeamExecuteSearchOperator = function()
  local pending = _G.BeamSearchOperatorPending or M.BeamSearchOperatorPending
  if not pending or not pending.action or not pending.textobj then
    vim.cmd('silent! autocmd! BeamSearchOperatorExecute')
    return
  end

  -- Get the pattern from our captured command line content or search register
  -- CmdlineChanged captures it as it's typed, so we should always have it
  local pattern = M.beam_search_pattern_from_cmdline or vim.fn.getreg('/')

  -- Clear the stored pattern for next use
  M.beam_search_pattern_from_cmdline = nil

  -- If no pattern, user probably pressed Escape or cleared the search
  if not pattern or pattern == '' then
    M.BeamSearchOperatorPending = {}
    _G.BeamSearchOperatorPending = nil
    vim.cmd('silent! autocmd! BeamSearchOperatorExecute')
    vim.g.beam_search_operator_indicator = nil
    vim.cmd('redrawstatus')
    return
  end

  -- Execute with the captured pattern
  M.BeamExecuteSearchOperatorImpl(pattern, pending)
end

M.BeamExecuteSearchOperatorImpl = function(pattern, pending)
  -- This is the actual implementation, moved from BeamExecuteSearchOperator
  local cfg = config.current

  -- Cross-buffer search if enabled
  if cfg.cross_buffer and cfg.cross_buffer.enabled then
    local start_buf = vim.api.nvim_get_current_buf()
    local start_pos = vim.api.nvim_win_get_cursor(0)

    -- Check current buffer first
    local found = vim.fn.search(pattern, 'c')

    if found == 0 then
      -- Search other buffers
      local buffers = vim.fn.getbufinfo({ buflisted = 1 })

      -- Build a set of visible buffers if include_hidden is false
      local visible_buffers = nil
      local include_hidden = cfg.cross_buffer.include_hidden
      if include_hidden == false or include_hidden == 'false' then
        visible_buffers = {}
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local bufnr = vim.api.nvim_win_get_buf(win)
          visible_buffers[bufnr] = true
        end
      end

      for _, buf in ipairs(buffers) do
        -- Skip hidden buffers if include_hidden is false
        if not (visible_buffers and not visible_buffers[buf.bufnr]) then
          if
            buf.bufnr ~= start_buf
            and vim.api.nvim_buf_is_valid(buf.bufnr)
            and vim.api.nvim_buf_is_loaded(buf.bufnr)
          then
            -- For yank/delete, we need to temporarily switch to execute the operation
            -- For change/visual, we want to open/switch to the buffer

            if pending.action == 'change' or pending.action == 'visual' then
              -- Check if buffer is already visible in a window
              local win_id = vim.fn.bufwinnr(buf.bufnr)

              if win_id > 0 then
                -- Buffer is visible, switch to that window
                vim.cmd(win_id .. 'wincmd w')
              else
                -- Open in a split for editing
                vim.cmd('split | buffer ' .. buf.bufnr)
              end
            else
              -- For yank/delete, just temporarily switch in current window
              -- We'll restore after the operation
              vim.cmd('buffer ' .. buf.bufnr)
            end

            vim.api.nvim_win_set_cursor(0, { 1, 0 })

            -- Search in this buffer
            found = vim.fn.search(pattern, 'c')
            if found > 0 then
              break
            else
              -- Didn't find in this buffer, restore
              if pending.action == 'change' or pending.action == 'visual' then
                -- Close the split we just opened
                vim.cmd('close')
              else
                -- Switch back to original buffer
                vim.cmd('buffer ' .. start_buf)
              end
            end
          end
        end
      end

      if found == 0 then
        -- Pattern not found anywhere
        if vim.api.nvim_buf_is_valid(start_buf) then
          vim.api.nvim_set_current_buf(start_buf)
        end
        M.BeamSearchOperatorPending = {}
        _G.BeamSearchOperatorPending = nil
        vim.cmd('silent! autocmd! BeamSearchOperatorExecute')
        vim.g.beam_search_operator_indicator = nil
        vim.cmd('redrawstatus')
        return
      end
    end

    -- Update saved position to return to the original buffer
    if start_buf ~= vim.api.nvim_get_current_buf() then
      -- We found the pattern in a different buffer
      if
        pending.action == 'yank'
        or pending.action == 'delete'
        or pending.action == 'yankline'
        or pending.action == 'deleteline'
      then
        -- For yank/delete, we need to return to original buffer
        pending.saved_pos_for_yank = { 0, start_pos[1], start_pos[2], 0 }
        pending.saved_buf = start_buf
      else
        -- For change/visual, clear the saved position so we don't return
        pending.saved_pos_for_yank = nil
        pending.saved_buf = nil
      end
    end
  else
    -- Cross-buffer disabled - only search current buffer
    local found = vim.fn.search(pattern, 'c')
    if found == 0 then
      -- Pattern not found in current buffer
      M.BeamSearchOperatorPending = {}
      _G.BeamSearchOperatorPending = nil
      vim.g.beam_search_operator_indicator = nil
      vim.cmd('redrawstatus')
      return
    end
  end

  vim.g.beam_search_operator_pattern = pattern
  vim.g.beam_search_operator_saved_pos = pending.saved_pos_for_yank
  vim.g.beam_search_operator_saved_buf = pending.saved_buf
  vim.g.beam_search_operator_textobj = pending.textobj
  vim.g.beam_search_operator_action = pending.action

  M.BeamSearchOperatorPending = {}
  _G.BeamSearchOperatorPending = nil

  -- Check if we're in test mode (synchronous execution needed)
  if vim.g.beam_test_mode then
    -- Direct call for tests
    M.BeamSearchOperator('line')
  else
    -- Use operator function for everything else
    _G.BeamSearchOperatorWrapper = function(type)
      return M.BeamSearchOperator(type)
    end
    vim.opt.operatorfunc = 'v:lua.BeamSearchOperatorWrapper'
    vim.api.nvim_feedkeys('g@l', 'n', false)
  end
end

function M.create_setup_function(action, save_pos)
  return function(textobj)
    M.BeamSearchOperatorPending = {
      action = action,
      textobj = textobj,
      saved_pos_for_yank = save_pos and vim.fn.getpos('.') or nil,
      saved_buf = save_pos and vim.api.nvim_get_current_buf() or nil,
    }

    vim.g.beam_search_operator_indicator = action .. '[' .. textobj .. ']'

    -- Check if smart highlighting is enabled and text object has constraints
    local cfg = config.current
    if cfg.smart_highlighting and search_transform.has_constraints(textobj) then
      -- Get prefix and suffix for the text object
      local constraint = search_transform.textobj_constraints[textobj]
      if constraint and constraint.wrap_pattern then
        -- Extract prefix and suffix from the wrap pattern
        local test_pattern = constraint.wrap_pattern('TEST')
        local prefix = test_pattern:match('^(.*)TEST')
        local suffix = test_pattern:match('TEST(.*)$')

        if prefix and suffix then
          -- Store suffix for later (use buffer-local to avoid global state)
          vim.b.beam_smart_suffix = suffix

          -- Start search with prefix
          vim.defer_fn(function()
            vim.api.nvim_feedkeys('/' .. prefix, 'n', false)
          end, 10)

          -- Map Enter to add suffix
          vim.cmd([[
            cnoremap <expr> <CR> getcmdtype() == '/' && exists('b:beam_smart_suffix') ? '<End>' . b:beam_smart_suffix . '<CR>' : '<CR>'
          ]])

          -- Setup autocmd for execution with pattern capture
          vim.cmd([[
            silent! augroup! BeamSearchOperatorExecute
            augroup BeamSearchOperatorExecute
              autocmd!
              autocmd CmdlineChanged / lua require('beam.operators').beam_search_pattern_from_cmdline = vim.fn.getcmdline()
              autocmd CmdlineLeave / ++once lua require('beam.operators').BeamExecuteSearchOperator(); vim.g.beam_search_operator_indicator = nil; vim.cmd('redrawstatus'); vim.cmd('silent! cunmap <CR>'); vim.b.beam_smart_suffix = nil; vim.cmd('silent! autocmd! BeamSearchOperatorExecute CmdlineChanged')
            augroup END
          ]])

          vim.cmd('redrawstatus')
          return '' -- Don't return '/' since we're starting search with feedkeys
        end
      end
    end

    -- Standard search (no smart highlighting)
    -- Set up autocmd to capture the pattern as it's typed
    vim.cmd([[
      silent! augroup! BeamSearchOperatorExecute
      augroup BeamSearchOperatorExecute
        autocmd!
        autocmd CmdlineChanged / lua require('beam.operators').beam_search_pattern_from_cmdline = vim.fn.getcmdline()
        autocmd CmdlineLeave / ++once lua require('beam.operators').BeamExecuteSearchOperator(); vim.g.beam_search_operator_indicator = nil; vim.cmd('redrawstatus'); vim.cmd('silent! autocmd! BeamSearchOperatorExecute CmdlineChanged')
      augroup END
    ]])

    vim.cmd('redrawstatus')
    return '/'
  end
end

-- Helper to check if multiple buffers are open
M.has_multiple_buffers = function()
  local cfg = config.current

  -- If cross_buffer is not enabled, return false
  if not cfg.cross_buffer or not cfg.cross_buffer.enabled then
    return false
  end

  local count = 0
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })

  -- If include_hidden is false, only count visible buffers
  -- Handle both boolean false and string "false"
  local include_hidden = cfg.cross_buffer.include_hidden
  if include_hidden == false or include_hidden == 'false' then
    local visible_buffers = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local bufnr = vim.api.nvim_win_get_buf(win)
      visible_buffers[bufnr] = true
    end

    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr) and visible_buffers[buf.bufnr] then
        count = count + 1
        if count > 1 then
          return true
        end
      end
    end
  else
    -- Count all loaded buffers
    for _, buf in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(buf.bufnr) then
        count = count + 1
        if count > 1 then
          return true
        end
      end
    end
  end

  return false
end

-- Helper to determine if we should use Telescope
local function should_use_telescope_immediately(cfg)
  -- Check if we have multiple buffers
  local multiple_buffers = M.has_multiple_buffers()

  -- Use Telescope if:
  -- 1. Single buffer Telescope is explicitly enabled (regardless of buffer count), OR
  -- 2. Cross-buffer is enabled AND we have multiple buffers

  if
    cfg.experimental
    and cfg.experimental.telescope_single_buffer
    and cfg.experimental.telescope_single_buffer.enabled
  then
    -- Single buffer Telescope explicitly enabled
    return true
  end

  if cfg.cross_buffer and cfg.cross_buffer.enabled and multiple_buffers then
    -- Cross-buffer enabled and we have multiple buffers
    return true
  end

  return false
end

-- Create operator setup functions with Telescope support
local original_yank_setup = M.create_setup_function('yank', true)
local original_delete_setup = M.create_setup_function('delete', true)
local original_change_setup = M.create_setup_function('change', false)
local original_visual_setup = M.create_setup_function('visual', false)

M.BeamYankSearchSetup = function(textobj)
  local cfg = config.current

  -- Check if BeamScope should be used for this text object
  local scope = require('beam.scope')
  if scope.should_use_scope(textobj) then
    scope.beam_scope('yank', textobj)
    return '' -- Don't trigger normal search
  end

  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_yank(textobj)
      return '' -- Don't trigger normal search
    end
  end
  return original_yank_setup(textobj)
end

M.BeamDeleteSearchSetup = function(textobj)
  local cfg = config.current

  -- Check if BeamScope should be used for this text object
  local scope = require('beam.scope')
  if scope.should_use_scope(textobj) then
    scope.beam_scope('delete', textobj)
    return '' -- Don't trigger normal search
  end

  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_delete(textobj)
      return '' -- Don't trigger normal search
    end
  end
  return original_delete_setup(textobj)
end

M.BeamChangeSearchSetup = function(textobj)
  local cfg = config.current

  -- Check if BeamScope should be used for this text object
  local scope = require('beam.scope')
  if scope.should_use_scope(textobj) then
    scope.beam_scope('change', textobj)
    return '' -- Don't trigger normal search
  end

  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_change(textobj)
      return '' -- Don't trigger normal search
    end
  end
  return original_change_setup(textobj)
end

M.BeamVisualSearchSetup = function(textobj)
  local cfg = config.current

  -- Check if BeamScope should be used for this text object
  local scope = require('beam.scope')
  if scope.should_use_scope(textobj) then
    scope.beam_scope('visual', textobj)
    return '' -- Don't trigger normal search
  end

  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_visual(textobj)
      return '' -- Don't trigger normal search
    end
  end
  return original_visual_setup(textobj)
end

-- Line operator setup functions with Telescope support
M.BeamYankLineSearchSetup = function()
  local cfg = config.current
  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_yank_line()
      return '' -- Don't trigger normal search
    end
  end
  -- Fall back to normal search setup for line
  return M.create_setup_function('yankline', true)('')
end

M.BeamDeleteLineSearchSetup = function()
  local cfg = config.current
  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_delete_line()
      return '' -- Don't trigger normal search
    end
  end
  return M.create_setup_function('deleteline', true)('')
end

M.BeamChangeLineSearchSetup = function()
  local cfg = config.current
  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_change_line()
      return '' -- Don't trigger normal search
    end
  end
  return M.create_setup_function('changeline', false)('')
end

M.BeamVisualLineSearchSetup = function()
  local cfg = config.current
  if should_use_telescope_immediately(cfg) then
    local ok, telescope = pcall(require, 'beam.telescope')
    if ok then
      telescope.search_and_visual_line()
      return '' -- Don't trigger normal search
    end
  end
  return M.create_setup_function('visualline', false)('')
end

return M
