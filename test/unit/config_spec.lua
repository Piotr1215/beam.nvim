-- Unit test for config module using Busted
-- This test runs inside Neovim but doesn't need an embedded instance

describe('beam.config', function()
  local config
  local beam

  before_each(function()
    -- Clear the module cache before each test
    package.loaded['beam.config'] = nil
    package.loaded['beam'] = nil
    package.loaded['beam.operators'] = nil
    package.loaded['beam.mappings'] = nil
    package.loaded['beam.text_objects'] = nil
    package.loaded['beam.text_object_discovery'] = nil

    config = require('beam.config')
    beam = require('beam')
  end)

  describe('default configuration', function()
    it('should have sensible defaults', function()
      assert.equals(',', config.defaults.prefix)
      assert.equals(150, config.defaults.visual_feedback_duration)
      assert.is_true(config.defaults.clear_highlight)
      assert.equals(500, config.defaults.clear_highlight_delay)
    end)

    it('should have cross-buffer disabled by default', function()
      assert.is_false(config.defaults.cross_buffer.enabled)
      assert.equals('telescope', config.defaults.cross_buffer.fuzzy_finder)
    end)

    it('should enable default text objects', function()
      assert.is_true(config.defaults.enable_default_text_objects)
    end)

    it('should have beam_scope enabled by default', function()
      assert.is_true(config.defaults.beam_scope.enabled)
      assert.is_table(config.defaults.beam_scope.scoped_text_objects)
    end)
  end)

  describe('setup configuration', function()
    it('should merge user config with defaults', function()
      local user_config = {
        prefix = ';',
        visual_feedback_duration = 300,
      }

      beam.setup(user_config)
      local current = beam.get_config()

      -- User settings should override
      assert.equals(';', current.prefix)
      assert.equals(300, current.visual_feedback_duration)

      -- Other defaults should remain
      assert.is_true(current.clear_highlight)
      assert.equals(500, current.clear_highlight_delay)
    end)

    it('should handle nested config merging', function()
      local user_config = {
        cross_buffer = {
          enabled = true,
          -- fuzzy_finder not specified, should use default
        },
      }

      beam.setup(user_config)
      local current = beam.get_config()

      assert.is_true(current.cross_buffer.enabled)
      assert.equals('telescope', current.cross_buffer.fuzzy_finder)
    end)

    it('should handle empty user config', function()
      beam.setup({})
      local current = beam.get_config()

      -- Should just use defaults
      assert.equals(',', current.prefix)
      assert.is_false(current.cross_buffer.enabled)
    end)
  end)

  describe('text object management', function()
    it('should have active text objects', function()
      beam.setup({})

      -- After setup, builtin text objects should be registered
      assert.is_table(config.active_text_objects)
      -- At minimum, beam's custom 'm' text object should exist
      assert.is_not_nil(config.active_text_objects['m'])

      -- Builtin text objects are registered via discovery module
      -- Check using the public API
      assert.is_true(beam.is_text_object_registered('('))
      assert.is_true(beam.is_text_object_registered('"'))
    end)

    it('should merge custom text objects', function()
      local user_config = {
        custom_text_objects = {
          x = 'custom X object',
        },
      }

      beam.setup(user_config)

      -- Custom object should be added
      assert.equals('custom X object', config.active_text_objects.x)
      -- Beam's default 'm' object should still exist
      assert.is_not_nil(config.active_text_objects['m'])
      -- Check builtin via public API
      assert.is_true(beam.is_text_object_registered('('))
    end)
  end)

  describe('beam_scope interaction', function()
    it('should disable beam_scope when cross_buffer is enabled', function()
      local user_config = {
        cross_buffer = { enabled = true },
        beam_scope = { enabled = true }, -- Try to enable both
      }

      beam.setup(user_config)
      local current = beam.get_config()

      -- beam_scope should be forced off
      assert.is_false(current.beam_scope.enabled)
    end)

    it('should allow beam_scope when cross_buffer is disabled', function()
      local user_config = {
        cross_buffer = { enabled = false },
        beam_scope = { enabled = true },
      }

      beam.setup(user_config)
      local current = beam.get_config()

      assert.is_true(current.beam_scope.enabled)
    end)
  end)
end)
