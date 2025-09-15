---@class BeamOperationStrategies
local M = {}
local constants = require('beam.constants')

---@class OperationStrategy
---@field execute fun(textobj: string, feedback_duration: number): boolean
---@field returns_to_origin boolean
---@field clears_highlight boolean
---@field enters_insert boolean

---Execute yank operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function yank_strategy(textobj, feedback_duration)
  vim.cmd('normal v' .. textobj)
  vim.cmd('redraw')
  vim.cmd('sleep ' .. feedback_duration .. 'm')
  vim.cmd('normal! y')
  return true
end

---Execute delete operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function delete_strategy(textobj, feedback_duration)
  vim.cmd('normal v' .. textobj)
  vim.cmd('redraw')
  vim.cmd('sleep ' .. feedback_duration .. 'm')
  vim.cmd('normal! d')
  return true
end

---Execute change operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function change_strategy(textobj, feedback_duration)
  vim.cmd('normal! v' .. textobj .. 'd')
  vim.cmd('normal a')
  vim.cmd('startinsert')
  return true
end

---Execute visual operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function visual_strategy(textobj, feedback_duration)
  vim.cmd('normal v' .. textobj)
  return true
end

---Execute line yank operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function yankline_strategy(textobj, feedback_duration)
  vim.cmd('normal! yy')
  return true
end

---Execute line delete operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function deleteline_strategy(textobj, feedback_duration)
  vim.cmd('normal! dd')
  return true
end

---Execute line change operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function changeline_strategy(textobj, feedback_duration)
  vim.cmd('normal! cc')
  vim.cmd('startinsert')
  return true
end

---Execute visual line operation
---@param textobj string
---@param feedback_duration number
---@return boolean success
local function visualline_strategy(textobj, feedback_duration)
  vim.cmd('normal! V')
  return true
end

---@type table<string, OperationStrategy>
M.strategies = {
  yank = {
    execute = yank_strategy,
    returns_to_origin = true,
    clears_highlight = true,
    enters_insert = false,
  },
  delete = {
    execute = delete_strategy,
    returns_to_origin = true,
    clears_highlight = true,
    enters_insert = false,
  },
  change = {
    execute = change_strategy,
    returns_to_origin = false,
    clears_highlight = false,
    enters_insert = true,
  },
  visual = {
    execute = visual_strategy,
    returns_to_origin = false,
    clears_highlight = false,
    enters_insert = false,
  },
  yankline = {
    execute = yankline_strategy,
    returns_to_origin = true,
    clears_highlight = true,
    enters_insert = false,
  },
  deleteline = {
    execute = deleteline_strategy,
    returns_to_origin = true,
    clears_highlight = true,
    enters_insert = false,
  },
  changeline = {
    execute = changeline_strategy,
    returns_to_origin = false,
    clears_highlight = false,
    enters_insert = true,
  },
  visualline = {
    execute = visualline_strategy,
    returns_to_origin = false,
    clears_highlight = false,
    enters_insert = false,
  },
}

---Handle markdown code block operations
---@param action string
---@param textobj string
---@param feedback_duration number
---@return boolean success
function M.handle_markdown_codeblock(action, textobj, feedback_duration)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local last_line = vim.api.nvim_buf_line_count(0)

  -- Find code block boundaries
  local start_line, end_line = M.find_markdown_codeblock_bounds(cursor_line, last_line)
  if not start_line or not end_line then
    return false
  end

  -- Adjust boundaries for inner/around
  if textobj == constants.SPECIAL_TEXTOBJS.MARKDOWN_CODE_INNER then
    start_line = start_line + 1
    end_line = end_line - 1
  end

  if start_line > end_line then
    return false
  end

  -- Execute action on code block
  return M.execute_codeblock_action(action, start_line, end_line, feedback_duration)
end

---Find markdown code block boundaries
---@param cursor_line number
---@param last_line number
---@return number|nil start_line
---@return number|nil end_line
function M.find_markdown_codeblock_bounds(cursor_line, last_line)
  local start_line = nil
  local end_line = nil

  -- Search backward for opening ```
  for i = cursor_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if line:match('^%s*```') then
      start_line = i
      break
    end
  end

  if not start_line then
    return nil, nil
  end

  -- Search forward for closing ```
  for i = start_line + 1, last_line do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if line:match('^%s*```') then
      end_line = i
      break
    end
  end

  return start_line, end_line
end

---Execute action on code block
---@param action string
---@param start_line number
---@param end_line number
---@param feedback_duration number
---@return boolean success
function M.execute_codeblock_action(action, start_line, end_line, feedback_duration)
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })

  if action == 'yank' then
    vim.cmd('normal! V' .. end_line .. 'G')
    vim.cmd('redraw')
    vim.cmd('sleep ' .. feedback_duration .. 'm')
    vim.cmd('normal! y')
  elseif action == 'delete' then
    vim.cmd('normal! V' .. end_line .. 'Gd')
  elseif action == 'change' then
    vim.api.nvim_feedkeys('V' .. end_line .. 'Gc', 'n', false)
  elseif action == 'visual' then
    vim.cmd('normal! V' .. end_line .. 'G')
  else
    return false
  end

  return true
end

---Get strategy for action
---@param action string
---@return OperationStrategy|nil
function M.get_strategy(action)
  return M.strategies[action]
end

---Check if action should return to origin
---@param action string
---@return boolean
function M.should_return_to_origin(action)
  local strategy = M.strategies[action]
  return strategy and strategy.returns_to_origin or false
end

---Check if action should clear highlight
---@param action string
---@return boolean
function M.should_clear_highlight(action)
  local strategy = M.strategies[action]
  return strategy and strategy.clears_highlight or false
end

return M
