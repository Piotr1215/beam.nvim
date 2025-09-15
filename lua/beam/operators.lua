---@class BeamOperators
local M = {}
local config = require('beam.config')
local operation_strategies = require('beam.operation_strategies')
local constants = require('beam.constants')
local cross_buffer = require('beam.cross_buffer_search')
local smart_search = require('beam.smart_search')

---Execute the beam search operator
---@param type string The motion type (unused but required by operatorfunc)
---@return nil
M.BeamSearchOperator = function(type)
  local context = M.get_operator_context()
  if not M.validate_operator_context(context) then
    return
  end

  local state = M.save_editor_state()
  local ok = M.execute_operation(context)
  M.restore_editor_state(state, context, ok)
  M.cleanup_search_operator_state()
end

---Get operator context from global variables
---@return table context
function M.get_operator_context()
  return {
    pattern = vim.g.beam_search_operator_pattern,
    saved_pos = vim.g.beam_search_operator_saved_pos,
    saved_buf = vim.g.beam_search_operator_saved_buf,
    textobj = vim.g.beam_search_operator_textobj,
    action = vim.g.beam_search_operator_action,
  }
end

---Validate operator context
---@param context table
---@return boolean valid
function M.validate_operator_context(context)
  return context.pattern and context.textobj and context.action
end

---Save editor state
---@return table state
function M.save_editor_state()
  return {
    reg = vim.fn.getreg('"'),
    reg_type = vim.fn.getregtype('"'),
    search = vim.fn.getreg('/'),
  }
end

---Execute the operation
---@param context table
---@return boolean success
function M.execute_operation(context)
  return pcall(function()
    local cfg = config.current
    local feedback_duration = cfg.visual_feedback_duration or constants.VISUAL_FEEDBACK_DURATION

    -- Special handling for markdown code blocks
    if M.is_markdown_codeblock(context.textobj) then
      return operation_strategies.handle_markdown_codeblock(
        context.action,
        context.textobj,
        feedback_duration
      )
    end

    -- Use strategy pattern for standard operations
    local strategy = operation_strategies.get_strategy(context.action)
    if strategy then
      return strategy.execute(context.textobj, feedback_duration)
    end
  end)
end

---Check if textobj is markdown codeblock
---@param textobj string
---@return boolean
function M.is_markdown_codeblock(textobj)
  return textobj == constants.SPECIAL_TEXTOBJS.MARKDOWN_CODE_INNER
    or textobj == constants.SPECIAL_TEXTOBJS.MARKDOWN_CODE_AROUND
end

---Restore editor state
---@param state table
---@param context table
---@param success boolean
function M.restore_editor_state(state, context, success)
  if success then
    M.handle_successful_operation(context, state)
  else
    M.handle_failed_operation(context, state)
  end
end

---Handle successful operation
---@param context table
---@param state table
function M.handle_successful_operation(context, state)
  -- Handle position restoration
  if operation_strategies.should_return_to_origin(context.action) and context.saved_pos then
    M.restore_position(context.saved_buf, context.saved_pos)
  end

  -- Handle highlight clearing
  local cfg = config.current
  if cfg.clear_highlight and operation_strategies.should_clear_highlight(context.action) then
    vim.defer_fn(function()
      vim.cmd('nohlsearch')
      vim.fn.setreg('/', state.search)
    end, cfg.clear_highlight_delay or 500)
  end
end

---Handle failed operation
---@param context table
---@param state table
function M.handle_failed_operation(context, state)
  if context.saved_pos then
    M.restore_position(context.saved_buf, context.saved_pos)
  end
  vim.fn.setreg('"', state.reg, state.reg_type)
  vim.fn.setreg('/', state.search)
  vim.cmd('nohlsearch')
end

---Helper function to restore position
---@param saved_buf number|nil
---@param saved_pos table|nil
function M.restore_position(saved_buf, saved_pos)
  if saved_buf and vim.api.nvim_buf_is_valid(saved_buf) then
    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= saved_buf then
      vim.api.nvim_set_current_buf(saved_buf)
    end
  end
  if saved_pos then
    vim.fn.setpos('.', saved_pos)
  end
end

---Helper function to cleanup search operator state
function M.cleanup_search_operator_state()
  vim.g.beam_search_operator_pattern = nil
  vim.g.beam_search_operator_saved_pos = nil
  vim.g.beam_search_operator_textobj = nil
  vim.g.beam_search_operator_action = nil
end

M.BeamSearchOperatorPending = {}
_G.BeamSearchOperatorPending = nil

---Execute the search operator after search pattern is entered
---@return nil
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
  local cfg = config.current
  local found = M.perform_search(pattern, pending, cfg)

  if found == 0 then
    M.cleanup_pending_state()
    return
  end

  M.setup_operator_state(pattern, pending)
  M.execute_operator()
end

---Perform search with optional cross-buffer support
---@param pattern string
---@param pending table
---@param cfg table
---@return number found
function M.perform_search(pattern, pending, cfg)
  if cfg.cross_buffer and cfg.cross_buffer.enabled then
    return M.perform_cross_buffer_search(pattern, pending, cfg)
  else
    -- Cross-buffer disabled - only search current buffer
    local found = vim.fn.search(pattern, 'c')
    if found == 0 then
      M.cleanup_pending_state()
    end
    return found
  end
end

---Perform cross-buffer search
---@param pattern string
---@param pending table
---@param cfg table
---@return number found
function M.perform_cross_buffer_search(pattern, pending, cfg)
  local start_buf = vim.api.nvim_get_current_buf()
  local start_pos = vim.api.nvim_win_get_cursor(0)

  -- Check current buffer first
  local found = vim.fn.search(pattern, 'c')

  if found == 0 then
    -- Get visible buffers if needed
    local visible_buffers = cross_buffer.get_visible_buffers(cfg.cross_buffer.include_hidden)

    -- Search other buffers
    found = cross_buffer.search_other_buffers(pattern, start_buf, pending, visible_buffers)

    if found == 0 then
      cross_buffer.handle_not_found(start_buf)
      M.BeamSearchOperatorPending = {}
      return 0
    end
  end

  -- Update saved position based on cross-buffer result
  cross_buffer.update_saved_position(start_buf, start_pos, pending)
  return found
end

---Setup operator state
---@param pattern string
---@param pending table
function M.setup_operator_state(pattern, pending)
  vim.g.beam_search_operator_pattern = pattern
  vim.g.beam_search_operator_saved_pos = pending.saved_pos_for_yank
  vim.g.beam_search_operator_saved_buf = pending.saved_buf
  vim.g.beam_search_operator_textobj = pending.textobj
  vim.g.beam_search_operator_action = pending.action

  M.BeamSearchOperatorPending = {}
  _G.BeamSearchOperatorPending = nil
end

---Execute the operator
function M.execute_operator()
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

---Cleanup pending state
function M.cleanup_pending_state()
  M.BeamSearchOperatorPending = {}
  _G.BeamSearchOperatorPending = nil
  vim.g.beam_search_operator_indicator = nil
  vim.cmd('redrawstatus')
end

function M.create_setup_function(action, save_pos)
  return function(textobj)
    M.setup_pending_operation(action, textobj, save_pos)
    vim.g.beam_search_operator_indicator = action .. '[' .. textobj .. ']'

    local cfg = config.current
    local smart_result = smart_search.setup_smart_highlighting(textobj, cfg)

    if smart_result ~= nil then
      vim.cmd('redrawstatus')
      return smart_result
    end

    -- Standard search (no smart highlighting)
    smart_search.setup_standard_autocmds()
    vim.cmd('redrawstatus')
    return '/'
  end
end

---Setup pending operation state
---@param action string
---@param textobj string
---@param save_pos boolean
function M.setup_pending_operation(action, textobj, save_pos)
  M.BeamSearchOperatorPending = {
    action = action,
    textobj = textobj,
    saved_pos_for_yank = save_pos and vim.fn.getpos('.') or nil,
    saved_buf = save_pos and vim.api.nvim_get_current_buf() or nil,
  }
end

---Check if multiple buffers are open
---@return boolean
function M.has_multiple_buffers()
  local cfg = config.current
  if not M.is_cross_buffer_enabled(cfg) then
    return false
  end

  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  local visible_buffers = M.get_visible_buffer_set(cfg)
  return M.count_eligible_buffers(buffers, visible_buffers) > 1
end

---Check if cross-buffer is enabled
---@param cfg table
---@return boolean
function M.is_cross_buffer_enabled(cfg)
  return cfg.cross_buffer and cfg.cross_buffer.enabled
end

---Get set of visible buffers
---@param cfg table
---@return table|nil
function M.get_visible_buffer_set(cfg)
  local include_hidden = cfg.cross_buffer.include_hidden
  if include_hidden == false or include_hidden == 'false' then
    local visible_buffers = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local bufnr = vim.api.nvim_win_get_buf(win)
      visible_buffers[bufnr] = true
    end
    return visible_buffers
  end
  return nil
end

---Count eligible buffers
---@param buffers table
---@param visible_buffers table|nil
---@return number
function M.count_eligible_buffers(buffers, visible_buffers)
  local count = 0
  for _, buf in ipairs(buffers) do
    if M.is_buffer_eligible(buf, visible_buffers) then
      count = count + 1
      if count > 1 then
        return count
      end
    end
  end
  return count
end

---Check if buffer is eligible
---@param buf table
---@param visible_buffers table|nil
---@return boolean
function M.is_buffer_eligible(buf, visible_buffers)
  if not vim.api.nvim_buf_is_loaded(buf.bufnr) then
    return false
  end
  if visible_buffers then
    return visible_buffers[buf.bufnr] == true
  end
  return true
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

---Setup yank operation with search
---@param textobj string Text object to yank (e.g., 'iw', 'ap')
---@return string Returns '/' to trigger search mode
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

---Setup delete operation with search
---@param textobj string Text object to delete
---@return string Returns '/' to trigger search mode
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

---Setup change operation with search
---@param textobj string Text object to change
---@return string Returns '/' to trigger search mode
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

---Setup visual selection with search
---@param textobj string Text object to select
---@return string Returns '/' to trigger search mode
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
---Setup yank line operation with search
---@return string|nil Returns '/' to trigger search or nil for cross-buffer
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

---Setup delete line operation with search
---@return string|nil Returns '/' to trigger search or nil for cross-buffer
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

---Setup change line operation with search
---@return string|nil Returns '/' to trigger search or nil for cross-buffer
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

---Setup visual line selection with search
---@return string|nil Returns '/' to trigger search or nil for cross-buffer
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
