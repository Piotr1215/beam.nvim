---@class BeamHealth
local M = {}

local health = vim.health or require('health')
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

---Check if beam.nvim is loaded and configured
---@return boolean success
local function check_plugin_loaded()
  local beam_loaded = pcall(require, 'beam')
  if not beam_loaded then
    error('beam.nvim is not loaded')
    return false
  end
  ok('beam.nvim is loaded')

  local config = require('beam.config')
  if config.current and config.current.prefix then
    ok('Configuration loaded with prefix: ' .. config.current.prefix)
    return true
  else
    error('Configuration not properly loaded')
    return false
  end
end

---Display conflict resolution help
local function show_conflict_help()
  info('')
  info('To resolve conflicts, you can:')
  info('  1. Mark as intentional/resolved (both implementations coexist):')
  info('     resolved_conflicts = { "m" }')
  info('  2. Add to excluded_text_objects to skip discovery:')
  info('     excluded_text_objects = { "b", "f" }')
  info('  3. Override in custom_text_objects to prefer plugin version:')
  info('     custom_text_objects = { b = "any bracket (mini.ai)" }')
  info('  4. Keep current defaults (builtin and beam-config have priority)')
end

---Display a single conflict
---@param conflict table Conflict details
local function display_conflict(conflict)
  info('')
  warn('Conflict for "' .. conflict.suffix .. '":')
  for _, source in ipairs(conflict.sources) do
    local is_active = source.source == 'beam-config' or source.source == 'builtin'
    local prefix = is_active and '  [ACTIVE] ' or '  [SKIPPED] '
    info(prefix .. source.desc .. ' (from ' .. source.source .. ')')
  end
end

---Report text object conflicts
---@param conflicts table List of conflicts
---@param resolved_count number Number of resolved conflicts
local function report_conflicts(conflicts, resolved_count)
  if #conflicts == 0 and resolved_count == 0 then
    ok('No text object conflicts detected')
    return
  end

  if #conflicts == 0 and resolved_count > 0 then
    ok(string.format('All %d conflicts marked as resolved', resolved_count))
    return
  end

  warn(string.format('Found %d unresolved text object conflicts', #conflicts))
  if resolved_count > 0 then
    info(string.format('(%d conflicts marked as resolved)', resolved_count))
  end

  for _, conflict in ipairs(conflicts) do
    display_conflict(conflict)
  end

  show_conflict_help()
end

---Check text object conflicts
local function check_text_object_conflicts()
  local config = require('beam.config')
  local discovery = require('beam.text_object_discovery')
  local conflicts = discovery.get_conflict_report()

  local unresolved_conflicts = {}
  local resolved_count = 0

  for _, conflict in ipairs(conflicts) do
    if vim.tbl_contains(config.current.resolved_conflicts or {}, conflict.suffix) then
      resolved_count = resolved_count + 1
    else
      table.insert(unresolved_conflicts, conflict)
    end
  end

  report_conflicts(unresolved_conflicts, resolved_count)
end

---Count custom text objects by source
---@param available table List of available text objects
---@return number custom_count Number of custom text objects
---@return number mini_ai_count Number of mini.ai text objects
local function count_custom_objects(available)
  local custom_count = 0
  local mini_ai_count = 0

  for _, obj in ipairs(available) do
    if obj.source ~= 'builtin' and obj.keymap:sub(1, 1) == 'i' then
      custom_count = custom_count + 1
      if obj.source == 'mini.ai' then
        mini_ai_count = mini_ai_count + 1
      end
    end
  end

  return custom_count, mini_ai_count
end

---Display custom text objects in columns
---@param available table List of available text objects
local function display_custom_objects(available)
  local custom_objects = {}

  for _, obj in ipairs(available) do
    if obj.source ~= 'builtin' and obj.keymap:sub(1, 1) == 'i' then
      local suffix = obj.keymap:sub(2)
      if not custom_objects[suffix] then
        custom_objects[suffix] = obj.desc:gsub('^inner ', '')
      end
    end
  end

  local sorted_keys = {}
  for k in pairs(custom_objects) do
    table.insert(sorted_keys, k)
  end
  table.sort(sorted_keys)

  info('')
  info('Available custom text objects:')

  local output = {}
  for _, key in ipairs(sorted_keys) do
    table.insert(output, key .. ' (' .. custom_objects[key] .. ')')
  end

  for i = 1, #output, 3 do
    local line = '  '
    for j = 0, 2 do
      if output[i + j] then
        line = line .. string.format('%-25s', output[i + j])
      end
    end
    info(line)
  end
end

---Report plugin integration status
local function check_plugin_integration()
  local config = require('beam.config')
  local discovery = require('beam.text_object_discovery')
  local available = discovery.discover_text_objects()

  local custom_count, mini_ai_count = count_custom_objects(available)

  if custom_count > 0 then
    ok(string.format('Discovered %d custom text objects', custom_count))
    if mini_ai_count > 0 then
      info(string.format('  Including %d from mini.ai', mini_ai_count))
    end
  else
    info('No custom text objects discovered')
  end

  -- Show discovered custom text objects if enabled
  if config.current.auto_discover_custom_text_objects and custom_count > 0 then
    display_custom_objects(available)
  end
end

---Report summary statistics
local function report_summary()
  local config = require('beam.config')
  local text_object_count = vim.tbl_count(config.active_text_objects)
  ok(string.format('%d text objects registered with beam', text_object_count))

  if config.current.auto_discover_custom_text_objects then
    ok('Custom text object discovery is ENABLED')
  else
    info('Custom text object discovery is DISABLED')
    info('  Enable with: auto_discover_custom_text_objects = true')
  end

  if config.current.excluded_text_objects and #config.current.excluded_text_objects > 0 then
    local excluded_list = table.concat(config.current.excluded_text_objects, ', ')
    info('Excluded text objects: ' .. excluded_list)
    if vim.tbl_contains(config.current.excluded_text_objects, '?') then
      info("  '?' is interactive prompt from mini.ai (requires user input)")
    end
  else
    info('No text objects excluded')
  end
end

---Check feature compatibility
local function check_feature_compatibility()
  local config = require('beam.config')
  local beam_scope_enabled = config.current.beam_scope and config.current.beam_scope.enabled
  local cross_buffer_enabled = config.current.cross_buffer and config.current.cross_buffer.enabled

  if beam_scope_enabled and cross_buffer_enabled then
    warn('BeamScope and cross-buffer are both enabled but are incompatible')
    info('  BeamScope will be automatically disabled when cross-buffer is active')
    info('  Consider disabling one of these features in your config')
  elseif beam_scope_enabled then
    ok('BeamScope is enabled (visual text object selection)')
  elseif cross_buffer_enabled then
    ok('Cross-buffer operations are enabled')
  else
    info('Both BeamScope and cross-buffer operations are disabled')
  end
end

---Run health checks for beam.nvim
---@return nil
function M.check()
  start('beam.nvim')

  if not check_plugin_loaded() then
    return
  end

  start('Text Object Conflicts')
  check_text_object_conflicts()

  start('Plugin Integration')
  check_plugin_integration()

  start('Summary')
  report_summary()

  start('Feature Compatibility')
  check_feature_compatibility()
end

return M
