---@class BeamCrossBufferSearch
local M = {}

---Get visible buffers set
---@param include_hidden boolean|string
---@return table|nil visible_buffers
function M.get_visible_buffers(include_hidden)
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

---Switch to buffer for operation
---@param buf_info table Buffer info from getbufinfo
---@param action string Operation action
---@param start_buf number Original buffer
---@return boolean success
function M.switch_to_buffer(buf_info, action, start_buf)
  local bufnr = buf_info.bufnr

  if action == 'change' or action == 'visual' then
    -- Check if buffer is already visible in a window
    local win_id = vim.fn.bufwinnr(bufnr)

    if win_id > 0 then
      -- Buffer is visible, switch to that window
      vim.cmd(win_id .. 'wincmd w')
    else
      -- Open in a split for editing
      vim.cmd('split | buffer ' .. bufnr)
    end
  else
    -- For yank/delete, just temporarily switch in current window
    vim.cmd('buffer ' .. bufnr)
  end

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return true
end

---Restore buffer after failed search
---@param action string Operation action
---@param start_buf number Original buffer
function M.restore_after_failed_search(action, start_buf)
  if action == 'change' or action == 'visual' then
    -- Close the split we just opened
    vim.cmd('close')
  else
    -- Switch back to original buffer
    vim.cmd('buffer ' .. start_buf)
  end
end

---Check if buffer is searchable
---@param bufnr number Buffer number
---@param start_buf number Starting buffer
---@param visible_buffers table|nil Set of visible buffers
---@return boolean
function M.is_searchable_buffer(bufnr, start_buf, visible_buffers)
  -- Skip hidden buffers if include_hidden is false
  if visible_buffers and not visible_buffers[bufnr] then
    return false
  end

  return bufnr ~= start_buf
    and vim.api.nvim_buf_is_valid(bufnr)
    and vim.api.nvim_buf_is_loaded(bufnr)
end

---Search in other buffers
---@param pattern string Search pattern
---@param start_buf number Starting buffer
---@param pending table Pending operation
---@param visible_buffers table|nil Set of visible buffers
---@return number found Line number if found, 0 otherwise
function M.search_other_buffers(pattern, start_buf, pending, visible_buffers)
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })

  for _, buf in ipairs(buffers) do
    if M.is_searchable_buffer(buf.bufnr, start_buf, visible_buffers) then
      M.switch_to_buffer(buf, pending.action, start_buf)

      -- Search in this buffer
      local found = vim.fn.search(pattern, 'c')
      if found > 0 then
        return found
      else
        -- Didn't find in this buffer, restore
        M.restore_after_failed_search(pending.action, start_buf)
      end
    end
  end

  return 0
end

---Update saved position based on cross-buffer result
---@param start_buf number Starting buffer
---@param start_pos table Starting position
---@param pending table Pending operation
function M.update_saved_position(start_buf, start_pos, pending)
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
end

---Handle pattern not found
---@param start_buf number Starting buffer
function M.handle_not_found(start_buf)
  if vim.api.nvim_buf_is_valid(start_buf) then
    vim.api.nvim_set_current_buf(start_buf)
  end
  _G.BeamSearchOperatorPending = nil
  vim.cmd('silent! autocmd! BeamSearchOperatorExecute')
  vim.g.beam_search_operator_indicator = nil
  vim.cmd('redrawstatus')
end

return M
