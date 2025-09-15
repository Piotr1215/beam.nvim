---@class BeamModule
---@field registered_text_objects table<string, boolean> Track registered text objects
---@field setup fun(opts?: BeamConfig|table) Setup function
---@field is_text_object_registered fun(key: string): boolean Check if text object is registered
---@field register_text_object fun(key: string, description: string|table): boolean Register a text object
---@field register_text_objects fun(objects: table<string, string|table>) Register multiple text objects
---@field get_config fun(): BeamConfig Get current configuration
local M = {}

local config = require('beam.config')
local operators = require('beam.operators')
local mappings = require('beam.mappings')
local text_objects = require('beam.text_objects')

---@type table<string, boolean>
-- Track registered text objects to avoid duplicates
M.registered_text_objects = {}

---Check and warn about incompatible configuration options
local function check_config_compatibility()
  if
    config.current.beam_scope
    and config.current.beam_scope.enabled
    and config.current.cross_buffer
    and config.current.cross_buffer.enabled
  then
    vim.notify(
      'Beam.nvim: BeamScope is disabled when cross_buffer is enabled (incompatible features)',
      vim.log.levels.WARN,
      { title = 'Beam.nvim' }
    )
  end
end

---Register custom text objects from configuration
---@param opts table|nil User configuration options
local function register_custom_text_objects(opts)
  if not opts or not opts.custom_text_objects then
    return
  end

  for key, obj in pairs(opts.custom_text_objects) do
    if type(obj) == 'table' and obj.select then
      text_objects.register_custom_text_object(key, obj)
    end
  end
end

---Handle text object discovery notifications
---@param result table Discovery result
---@param unresolved_count number Number of unresolved conflicts
---@param resolved_count number Number of resolved conflicts
local function handle_discovery_notifications(result, unresolved_count, resolved_count)
  if unresolved_count > 0 then
    local msg = string.format(
      'Beam.nvim: Found %d unresolved text object conflicts. Run :checkhealth beam for details.',
      unresolved_count
    )
    vim.notify(msg, vim.log.levels.WARN, { title = 'Beam.nvim' })
  elseif config.current.show_discovery_notification and result then
    local msg = string.format(
      '[beam.nvim] Discovered %d custom text objects, %d motions (%d total available)',
      result.registered or 0,
      result.motions_registered or 0,
      (result.total or 0) + (result.motions_total or 0)
    )
    if resolved_count > 0 then
      msg = msg .. string.format(' (%d conflicts marked as resolved)', resolved_count)
    end
    vim.notify(msg, vim.log.levels.INFO)
  end
end

---Setup WhichKey integration if available
local function setup_which_key()
  local has_which_key, which_key = pcall(require, 'which-key')
  if not has_which_key then
    return
  end

  local prefix = config.current.prefix or ','
  which_key.add({
    { prefix, group = 'Remote Operators' },
    { prefix .. 'y', group = 'Yank' },
    { prefix .. 'd', group = 'Delete' },
    { prefix .. 'c', group = 'Change' },
    { prefix .. 'v', group = 'Visual' },
  })
end

---Perform auto-discovery of text objects from other plugins
local function auto_discover_text_objects()
  if not config.current.auto_discover_custom_text_objects then
    return
  end

  local discovery = require('beam.text_object_discovery')

  -- Delay discovery slightly to allow plugins to load
  vim.defer_fn(function()
    local result = discovery.auto_register_text_objects({
      conflict_resolution = 'skip', -- Always skip conflicts for auto-discovery
      show_conflicts = false,
    })

    local unresolved_count, resolved_count = discovery.check_unresolved_conflicts()
    handle_discovery_notifications(result, unresolved_count, resolved_count)
  end, 500)
end

---@param opts BeamConfig|table|nil User configuration options
function M.setup(opts)
  config.setup(opts)
  check_config_compatibility()

  if opts and opts.enable_default_text_objects ~= false then
    text_objects.setup_defaults()
  end

  register_custom_text_objects(opts)
  mappings.setup()

  -- Always register Vim's built-in text objects
  local discovery = require('beam.text_object_discovery')
  discovery.register_builtin_text_objects()

  auto_discover_text_objects()

  -- Expose core functions globally for health check and operator functionality
  _G.BeamSearchOperator = operators.BeamSearchOperator
  _G.BeamExecuteSearchOperator = operators.BeamExecuteSearchOperator

  -- Mark plugin as loaded
  vim.g.loaded_beam = true

  setup_which_key()
end

---@param key string Text object key to check
---@return boolean
function M.is_text_object_registered(key)
  -- Check active text objects (includes both config and discovered)
  return config.active_text_objects[key] ~= nil
end

---@param key string Text object key
---@param description string|table Text object description or definition
---@return boolean success Whether registration was successful
function M.register_text_object(key, description)
  -- Avoid duplicate registrations
  if M.is_text_object_registered(key) then
    return false
  end

  if type(description) == 'table' and description.select then
    text_objects.register_custom_text_object(key, description)
  end

  config.register_text_object(key, type(description) == 'table' and description.desc or description)
  mappings.create_custom_mappings({
    [key] = type(description) == 'table' and description.desc or description,
  })

  M.registered_text_objects[key] = true
  return true
end

---@param objects table<string, string|table> Text objects to register
function M.register_text_objects(objects)
  for key, obj in pairs(objects) do
    M.register_text_object(key, obj)
  end
end

---@return BeamConfig Current configuration
function M.get_config()
  return config.current
end

return M
