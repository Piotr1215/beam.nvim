local M = {}

local health = vim.health or require('health')
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

function M.check()
  start('beam.nvim')

  -- Check if beam is loaded
  local beam_loaded = pcall(require, 'beam')
  if not beam_loaded then
    error('beam.nvim is not loaded')
    return
  end

  ok('beam.nvim is loaded')

  -- Check configuration
  local config = require('beam.config')
  if config.current and config.current.prefix then
    ok('Configuration loaded with prefix: ' .. config.current.prefix)
  else
    error('Configuration not properly loaded')
  end

  -- Check text object discovery
  start('Text Object Conflicts')

  local discovery = require('beam.text_object_discovery')
  local conflicts = discovery.get_conflict_report()

  -- Filter out resolved conflicts
  local unresolved_conflicts = {}
  local resolved_count = 0
  for _, conflict in ipairs(conflicts) do
    if vim.tbl_contains(config.current.resolved_conflicts or {}, conflict.suffix) then
      resolved_count = resolved_count + 1
    else
      table.insert(unresolved_conflicts, conflict)
    end
  end

  if #unresolved_conflicts == 0 and resolved_count == 0 then
    ok('No text object conflicts detected')
  elseif #unresolved_conflicts == 0 and resolved_count > 0 then
    ok(string.format('All %d conflicts marked as resolved', resolved_count))
  else
    warn(string.format('Found %d unresolved text object conflicts', #unresolved_conflicts))
    if resolved_count > 0 then
      info(string.format('(%d conflicts marked as resolved)', resolved_count))
    end

    for _, conflict in ipairs(unresolved_conflicts) do
      info('')
      warn('Conflict for "' .. conflict.suffix .. '":')
      for _, source in ipairs(conflict.sources) do
        -- Built-in and beam-config have priority
        local is_active = source.source == 'beam-config' or source.source == 'builtin'
        local prefix = is_active and '  [ACTIVE] ' or '  [SKIPPED] '
        info(prefix .. source.desc .. ' (from ' .. source.source .. ')')
      end
    end

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

  -- Check for plugin integration
  start('Plugin Integration')

  -- Count discovered objects by source
  local available = discovery.discover_text_objects()
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

  -- Simple summary
  if custom_count > 0 then
    ok(string.format('Discovered %d custom text objects', custom_count))
    if mini_ai_count > 0 then
      info(string.format('  Including %d from mini.ai', mini_ai_count))
    end
  else
    info('No custom text objects discovered')
  end

  -- If custom discovery is enabled, show what was discovered
  if config.current.auto_discover_custom_text_objects and custom_count > 0 then
    info('')
    info('Available custom text objects:')
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

    local output = {}
    for _, key in ipairs(sorted_keys) do
      table.insert(output, key .. ' (' .. custom_objects[key] .. ')')
    end

    -- Display in columns for readability
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

  -- Report on registered text objects
  start('Summary')

  local text_object_count = vim.tbl_count(config.active_text_objects)
  ok(string.format('%d text objects registered with beam', text_object_count))

  -- Check if custom text object discovery is enabled
  if config.current.auto_discover_custom_text_objects then
    ok('Custom text object discovery is ENABLED')
  else
    info('Custom text object discovery is DISABLED')
    info('  Enable with: auto_discover_custom_text_objects = true')
  end

  -- Check excluded text objects
  if config.current.excluded_text_objects and #config.current.excluded_text_objects > 0 then
    local excluded_list = table.concat(config.current.excluded_text_objects, ', ')
    info('Excluded text objects: ' .. excluded_list)

    -- Check if '?' was actually found somewhere
    if vim.tbl_contains(config.current.excluded_text_objects, '?') then
      info("  '?' is interactive prompt from mini.ai (requires user input)")
    end
  else
    info('No text objects excluded')
  end
end

return M
