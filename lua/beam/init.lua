local M = {}

local config = require('beam.config')
local operators = require('beam.operators')
local mappings = require('beam.mappings')
local text_objects = require('beam.text_objects')

-- Track registered text objects to avoid duplicates
M.registered_text_objects = {}

function M.setup(opts)
  config.setup(opts)

  -- Warn about incompatible configuration
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

  if opts and opts.enable_default_text_objects ~= false then
    text_objects.setup_defaults()
  end

  if opts and opts.custom_text_objects then
    for key, obj in pairs(opts.custom_text_objects) do
      if type(obj) == 'table' and obj.select then
        text_objects.register_custom_text_object(key, obj)
      end
    end
  end

  mappings.setup()

  -- Always register Vim's built-in text objects
  local discovery = require('beam.text_object_discovery')
  discovery.register_builtin_text_objects()

  -- Auto-discover custom text objects from plugins if enabled
  if config.current.auto_discover_custom_text_objects then
    -- Delay discovery slightly to allow plugins to load
    vim.defer_fn(function()
      local result = discovery.auto_register_text_objects({
        conflict_resolution = config.current.discovery_conflict_resolution or 'skip',
        show_conflicts = false, -- Don't show conflicts during registration
      })

      -- Check for unresolved conflicts after registration
      local unresolved_count, resolved_count = discovery.check_unresolved_conflicts()

      -- Show appropriate notification based on what happened
      if unresolved_count > 0 then
        -- Only show warning if there are actual unresolved conflicts
        local msg = string.format(
          'Beam.nvim: Found %d unresolved text object conflicts. Run :checkhealth beam for details.',
          unresolved_count
        )
        vim.notify(msg, vim.log.levels.WARN, { title = 'Beam.nvim' })
      elseif config.current.show_discovery_notification and result then
        -- Show success message only if requested and no issues
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
    end, 500) -- Wait for lazy-loaded plugins
  end

  -- Expose core functions globally for health check and operator functionality
  _G.BeamSearchOperator = operators.BeamSearchOperator
  _G.BeamExecuteSearchOperator = operators.BeamExecuteSearchOperator

  -- Mark plugin as loaded
  vim.g.loaded_beam = true

  local has_which_key, which_key = pcall(require, 'which-key')
  if has_which_key then
    local prefix = config.current.prefix or ','
    which_key.add({
      { prefix, group = 'Remote Operators' },
      { prefix .. 'y', group = 'Yank' },
      { prefix .. 'd', group = 'Delete' },
      { prefix .. 'c', group = 'Change' },
      { prefix .. 'v', group = 'Visual' },
    })
  end
end

function M.is_text_object_registered(key)
  -- Check active text objects (includes both config and discovered)
  return config.active_text_objects[key] ~= nil
end

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

function M.register_text_objects(objects)
  for key, obj in pairs(objects) do
    M.register_text_object(key, obj)
  end
end

function M.get_config()
  return config.current
end

return M
