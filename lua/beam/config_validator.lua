---@class BeamConfigValidator
local M = {}

---Validate a path in the config table
---@param path string The path to the field being validated
---@param tbl table The table to validate
---@return boolean is_valid
---@return string|nil error_message
local function validate_path(path, tbl)
  local ok, err = pcall(vim.validate, tbl)
  return ok, err and path .. '.' .. err
end

---Validate cross-buffer config
---@param cfg BeamInternalCrossBufferConfig
---@param path string
---@return boolean is_valid
---@return string|nil error_message
local function validate_cross_buffer(cfg, path)
  return validate_path(path, {
    enabled = { cfg.enabled, 'boolean' },
    fuzzy_finder = {
      cfg.fuzzy_finder,
      function(v)
        return v == 'telescope' or v == 'fzf-lua' or v == 'mini.pick'
      end,
      'one of: telescope, fzf-lua, mini.pick',
    },
    include_hidden = { cfg.include_hidden, 'boolean' },
  })
end

---Validate beam scope config
---@param cfg BeamInternalScopeConfig
---@param path string
---@return boolean is_valid
---@return string|nil error_message
local function validate_beam_scope(cfg, path)
  local ok, err = validate_path(path, {
    enabled = { cfg.enabled, 'boolean' },
    scoped_text_objects = { cfg.scoped_text_objects, 'table' },
    custom_scoped_text_objects = { cfg.custom_scoped_text_objects, 'table' },
    preview_context = { cfg.preview_context, 'number' },
    window_width = { cfg.window_width, 'number' },
  })

  if not ok then
    return false, err
  end

  -- Additional validation for arrays
  for i, obj in ipairs(cfg.scoped_text_objects) do
    if type(obj) ~= 'string' then
      return false, path .. '.scoped_text_objects[' .. i .. ']: expected string, got ' .. type(obj)
    end
  end

  for i, obj in ipairs(cfg.custom_scoped_text_objects) do
    if type(obj) ~= 'string' then
      return false,
        path .. '.custom_scoped_text_objects[' .. i .. ']: expected string, got ' .. type(obj)
    end
  end

  -- Validate numeric ranges
  if cfg.preview_context < 0 then
    return false, path .. '.preview_context: must be non-negative'
  end

  if cfg.window_width < 10 or cfg.window_width > 200 then
    return false, path .. '.window_width: must be between 10 and 200'
  end

  return true
end

---Validate experimental config
---@param cfg BeamInternalExperimentalConfig
---@param path string
---@return boolean is_valid
---@return string|nil error_message
local function validate_experimental(cfg, path)
  return validate_path(path, {
    dot_repeat = { cfg.dot_repeat, 'boolean' },
    count_support = { cfg.count_support, 'boolean' },
    telescope_single_buffer = { cfg.telescope_single_buffer, 'table' },
  })
end

---Validate string array field
---@param arr table
---@param field_name string
---@return boolean is_valid
---@return string|nil error_message
local function validate_string_array(arr, field_name)
  for i, item in ipairs(arr) do
    if type(item) ~= 'string' then
      return false, field_name .. '[' .. i .. ']: expected string, got ' .. type(item)
    end
  end
  return true
end

---Validate main config fields
---@param cfg BeamInternalConfig
---@return boolean is_valid
---@return string|nil error_message
local function validate_main_fields(cfg)
  return validate_path('beam.config', {
    prefix = { cfg.prefix, 'string' },
    visual_feedback_duration = { cfg.visual_feedback_duration, 'number' },
    clear_highlight = { cfg.clear_highlight, 'boolean' },
    clear_highlight_delay = { cfg.clear_highlight_delay, 'number' },
    enable_default_text_objects = { cfg.enable_default_text_objects, 'boolean' },
    custom_text_objects = { cfg.custom_text_objects, 'table' },
    auto_discover_custom_text_objects = { cfg.auto_discover_custom_text_objects, 'boolean' },
    show_discovery_notification = { cfg.show_discovery_notification, 'boolean' },
    excluded_text_objects = { cfg.excluded_text_objects, 'table' },
    excluded_motions = { cfg.excluded_motions, 'table' },
    resolved_conflicts = { cfg.resolved_conflicts, 'table' },
    smart_highlighting = { cfg.smart_highlighting, 'boolean' },
  })
end

---Validate config ranges
---@param cfg BeamInternalConfig
---@return boolean is_valid
---@return string|nil error_message
local function validate_ranges(cfg)
  if #cfg.prefix ~= 1 then
    return false, 'beam.config.prefix: must be a single character'
  end

  if cfg.visual_feedback_duration < 0 or cfg.visual_feedback_duration > 1000 then
    return false, 'beam.config.visual_feedback_duration: must be between 0 and 1000'
  end

  if cfg.clear_highlight_delay < 0 or cfg.clear_highlight_delay > 5000 then
    return false, 'beam.config.clear_highlight_delay: must be between 0 and 5000'
  end

  return true
end

---Validate the main configuration
---@param cfg BeamInternalConfig
---@return boolean is_valid
---@return string|nil error_message
function M.validate(cfg)
  -- Validate main fields
  local ok, err = validate_main_fields(cfg)
  if not ok then
    return false, err
  end

  -- Validate ranges
  ok, err = validate_ranges(cfg)
  if not ok then
    return false, err
  end

  -- Validate nested configs
  local validators = {
    { validate_cross_buffer, cfg.cross_buffer, 'beam.config.cross_buffer' },
    { validate_beam_scope, cfg.beam_scope, 'beam.config.beam_scope' },
    { validate_experimental, cfg.experimental, 'beam.config.experimental' },
  }

  for _, validator in ipairs(validators) do
    ok, err = validator[1](validator[2], validator[3])
    if not ok then
      return false, err
    end
  end

  -- Validate string arrays
  local arrays = {
    { cfg.excluded_text_objects, 'beam.config.excluded_text_objects' },
    { cfg.excluded_motions, 'beam.config.excluded_motions' },
    { cfg.resolved_conflicts, 'beam.config.resolved_conflicts' },
  }

  for _, array_info in ipairs(arrays) do
    ok, err = validate_string_array(array_info[1], array_info[2])
    if not ok then
      return false, err
    end
  end

  return true
end

---Warn about unknown fields in user config
---@param user_config table
---@param known_fields table<string, boolean>
---@param path string
---@return string[] warnings
function M.check_unknown_fields(user_config, known_fields, path)
  local warnings = {}

  for key, _ in pairs(user_config) do
    if not known_fields[key] then
      table.insert(warnings, path .. '.' .. key .. ': unknown field (possible typo?)')
    end
  end

  return warnings
end

---Get known fields for the config
---@return table<string, table<string, boolean>>
function M.get_known_fields()
  return {
    root = {
      prefix = true,
      visual_feedback_duration = true,
      clear_highlight = true,
      clear_highlight_delay = true,
      cross_buffer = true,
      enable_default_text_objects = true,
      custom_text_objects = true,
      auto_discover_custom_text_objects = true,
      show_discovery_notification = true,
      excluded_text_objects = true,
      excluded_motions = true,
      resolved_conflicts = true,
      smart_highlighting = true,
      beam_scope = true,
      experimental = true,
    },
    cross_buffer = {
      enabled = true,
      fuzzy_finder = true,
      include_hidden = true,
    },
    beam_scope = {
      enabled = true,
      scoped_text_objects = true,
      custom_scoped_text_objects = true,
      preview_context = true,
      window_width = true,
    },
    experimental = {
      dot_repeat = true,
      count_support = true,
      telescope_single_buffer = true,
    },
  }
end

return M
