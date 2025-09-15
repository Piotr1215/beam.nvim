---@class BeamSmartSearch
local M = {}
local search_transform = require('beam.search_transform')

---Setup smart highlighting for constrained text objects
---@param textobj string
---@param cfg table
---@return string|nil search_prefix
function M.setup_smart_highlighting(textobj, cfg)
  if not cfg.smart_highlighting or not search_transform.has_constraints(textobj) then
    return nil
  end

  local prefix, suffix = M.get_pattern_parts(textobj)
  if not prefix or not suffix then
    return nil
  end

  M.setup_smart_search(prefix, suffix)
  return '' -- Don't return '/' since we're starting search with feedkeys
end

---Get prefix and suffix for text object pattern
---@param textobj string
---@return string|nil prefix
---@return string|nil suffix
function M.get_pattern_parts(textobj)
  local constraint = search_transform.textobj_constraints[textobj]
  if not constraint or not constraint.wrap_pattern then
    return nil, nil
  end

  -- Extract prefix and suffix from the wrap pattern
  local test_pattern = constraint.wrap_pattern('TEST')
  local prefix = test_pattern:match('^(.*)TEST')
  local suffix = test_pattern:match('TEST(.*)$')

  return prefix, suffix
end

---Setup smart search with prefix and suffix
---@param prefix string
---@param suffix string
function M.setup_smart_search(prefix, suffix)
  -- Store suffix for later (use buffer-local to avoid global state)
  vim.b.beam_smart_suffix = suffix

  -- Start search with prefix
  vim.defer_fn(function()
    vim.api.nvim_feedkeys('/' .. prefix, 'n', false)
  end, 10)

  -- Map Enter to add suffix
  M.setup_enter_mapping()

  -- Setup autocmd for execution with pattern capture
  M.setup_smart_autocmds()
end

---Setup Enter key mapping for smart search
function M.setup_enter_mapping()
  vim.cmd([[
    cnoremap <expr> <CR> getcmdtype() == '/' && exists('b:beam_smart_suffix') ?
      \ '<End>' . b:beam_smart_suffix . '<CR>' : '<CR>'
  ]])
end

---Setup autocmds for smart search
function M.setup_smart_autocmds()
  vim.cmd([[
    silent! augroup! BeamSearchOperatorExecute
    augroup BeamSearchOperatorExecute
      autocmd!
      autocmd CmdlineChanged / lua require('beam.operators').beam_search_pattern_from_cmdline =
        \ vim.fn.getcmdline()
      autocmd CmdlineLeave / ++once lua require('beam.operators').BeamExecuteSearchOperator();
        \ vim.g.beam_search_operator_indicator = nil; vim.cmd('redrawstatus');
        \ vim.cmd('silent! cunmap <CR>'); vim.b.beam_smart_suffix = nil;
        \ vim.cmd('silent! autocmd! BeamSearchOperatorExecute CmdlineChanged')
    augroup END
  ]])
end

---Setup standard search autocmds
function M.setup_standard_autocmds()
  vim.cmd([[
    silent! augroup! BeamSearchOperatorExecute
    augroup BeamSearchOperatorExecute
      autocmd!
      autocmd CmdlineChanged / lua require('beam.operators').beam_search_pattern_from_cmdline =
        \ vim.fn.getcmdline()
      autocmd CmdlineLeave / ++once lua require('beam.operators').BeamExecuteSearchOperator();
        \ vim.g.beam_search_operator_indicator = nil; vim.cmd('redrawstatus');
        \ vim.cmd('silent! autocmd! BeamSearchOperatorExecute CmdlineChanged')
    augroup END
  ]])
end

return M
