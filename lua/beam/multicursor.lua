---@class BeamMulticursor
---Runs a beam operation at every search match through Neovim's native
---multicursor (`:help zq`), available on Neovim 0.13+ builds that ship `zq`.
local M = {}

local mc_ns = vim.api.nvim_create_namespace('nvim.multicursor')
local origin_ns = vim.api.nvim_create_namespace('beam.multicursor.origin')

---Operator key fed after the Visual selection, per text object action
---@type table<string, string>
local op_keys = { yank = 'y', delete = 'd', change = 'c', visual = '' }

---Keys fed for line actions
---@type table<string, string>
local line_keys = { yankline = 'yy', deleteline = 'dd', changeline = 'cc', visualline = 'V' }

---Actions that end the multicursor session and return to the origin
---@type table<string, boolean>
local returns_to_origin = { yank = true, delete = true, yankline = true, deleteline = true }

---@type boolean|nil
local cached

---Count multicursors in a buffer
---@param buf? integer
---@return integer
function M.count(buf)
  return #vim.api.nvim_buf_get_extmarks(buf or 0, mc_ns, 0, -1, {})
end

---Clear multicursors in a buffer, which ends the multicursor session
---@param buf? integer
function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf or 0, mc_ns, 0, -1)
end

---Check that `zq` places cursors, in a scratch buffer
---@return boolean
local function probe()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'beam beam' })
  local search = vim.fn.getreg('/')
  local placed = 0
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.fn.setreg('/', 'beam')
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    pcall(vim.cmd, 'silent! normal! zqgn')
    placed = M.count(buf)
    if vim.fn.mode():match('^[vV\22]') then
      vim.cmd('silent! normal! \27')
    end
  end)
  vim.fn.setreg('/', search)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  return placed > 0
end

---Whether this Neovim has the `zq` multicursor operator. The result is cached.
---@return boolean
function M.available()
  if cached == nil then
    cached = vim.fn.has('nvim-0.13') == 1 and probe()
  end
  return cached
end

---Reset the cached detection result (for tests)
function M.reset()
  cached = nil
end

---Whether a text object is one of Neovim's own (iw, a", i(, ...)
---@param textobj string
---@return boolean
function M.is_native_text_object(textobj)
  return textobj:match('^[ia][wWsp"\'`()b%[%]{}B<>t]$') ~= nil
end

---Feed keys as typed input, so the multicursor cascade replays them
---@param keys string
---@param mode string feedkeys mode without the 't' flag
local function feed(keys, mode)
  vim.api.nvim_feedkeys(vim.keycode(keys), mode .. 't', false)
end

---After the next input atom (and its cascade), end the session and go back to the origin
---@param buf integer
---@param mark integer|nil Extmark holding the origin position
local function finish_after_atom(buf, mark)
  vim.api.nvim_create_autocmd('CmdAtom', {
    once = true,
    callback = function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      M.clear(buf)
      if mark then
        local pos = vim.api.nvim_buf_get_extmark_by_id(buf, origin_ns, mark, {})
        vim.api.nvim_buf_del_extmark(buf, origin_ns, mark)
        if pos[1] and vim.api.nvim_get_current_buf() == buf then
          pcall(vim.api.nvim_win_set_cursor, 0, { pos[1] + 1, pos[2] })
        end
      end
    end,
  })
end

---Remember the origin in an extmark, so edits above it do not shift it
---@param buf integer
---@param saved_pos table|nil getpos() result
---@return integer|nil mark
local function mark_origin(buf, saved_pos)
  if not saved_pos then
    return nil
  end
  return vim.api.nvim_buf_set_extmark(buf, origin_ns, saved_pos[2] - 1, saved_pos[3] - 1, {})
end

---Move back to the origin and drop its extmark
---@param buf integer
---@param mark integer|nil
local function back_to_origin(buf, mark)
  if not mark then
    return
  end
  local pos = vim.api.nvim_buf_get_extmark_by_id(buf, origin_ns, mark, {})
  vim.api.nvim_buf_del_extmark(buf, origin_ns, mark)
  if pos[1] then
    vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
  end
end

---Run the action at the placed cursors
---@param buf integer
---@param mark integer|nil Origin extmark
---@param context table action, textobj
local function apply(buf, mark, context)
  if returns_to_origin[context.action] then
    finish_after_atom(buf, mark)
  elseif mark then
    vim.api.nvim_buf_del_extmark(buf, origin_ns, mark)
  end

  local line = line_keys[context.action]
  if line then
    -- Linewise edits drop the cursor below the primary when they sit on
    -- adjacent lines (nightly 2026-10-11), so start from the last cursor.
    vim.cmd('silent! normal! [C')
    feed(line, 'n')
  else
    -- Native objects skip remapping: plugins that take over i/a (mini.ai)
    -- read their keys in ways the cascade does not replay per cursor.
    -- Anything else may only exist as a plugin mapping.
    feed('v' .. context.textobj, M.is_native_text_object(context.textobj) and 'n' or 'm')
    if op_keys[context.action] ~= '' then
      feed(op_keys[context.action], 'n')
    end
  end
end

---Place a cursor at every match of the pattern and run the action at each.
---Yank and delete end the session and return to the origin; the yanks are
---joined linewise. Change and visual leave the cursors for the user.
---@param context table Operator context: pattern, action, textobj, saved_pos
---@return boolean placed Whether any cursor was placed
function M.run(context)
  local buf = vim.api.nvim_get_current_buf()
  local mark = mark_origin(buf, context.saved_pos)

  vim.fn.setreg('/', context.pattern)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd('silent! normal! zqgn')

  if M.count(buf) == 0 then
    back_to_origin(buf, mark)
    return false
  end
  apply(buf, mark, context)
  return true
end

---Place a cursor at each position and run the action at each, like run()
---@param positions table[] {line, col} pairs, 1-indexed line and 0-indexed col
---@param context table action, textobj, saved_pos
---@return boolean placed Whether any cursor was placed
function M.run_at(positions, context)
  local buf = vim.api.nvim_get_current_buf()
  local mark = mark_origin(buf, context.saved_pos)

  for _, pos in ipairs(positions) do
    if pcall(vim.api.nvim_win_set_cursor, 0, pos) then
      vim.cmd('silent! normal! 1Q')
    end
  end

  if M.count(buf) == 0 then
    back_to_origin(buf, mark)
    return false
  end
  apply(buf, mark, context)
  return true
end

return M
