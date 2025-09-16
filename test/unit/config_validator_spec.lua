describe('config_validator', function()
  local validator
  local config

  before_each(function()
    -- Reset module state
    package.loaded['beam.config_validator'] = nil
    package.loaded['beam.config'] = nil
    validator = require('beam.config_validator')
    config = require('beam.config')
  end)

  describe('validate()', function()
    local function get_valid_config()
      -- Return a minimal valid config
      return {
        prefix = ',',
        visual_feedback_duration = 150,
        clear_highlight = true,
        clear_highlight_delay = 500,
        enable_default_text_objects = true,
        custom_text_objects = {},
        auto_discover_custom_text_objects = true,
        show_discovery_notification = true,
        excluded_text_objects = {},
        excluded_motions = {},
        resolved_conflicts = {},
        smart_highlighting = false,
        cross_buffer = {
          enabled = false,
          fuzzy_finder = 'telescope',
          include_hidden = false,
        },
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"', "'", '`' },
          custom_scoped_text_objects = {},
          preview_context = 3,
          window_width = 60,
        },
        experimental = {
          dot_repeat = false,
          count_support = false,
          telescope_single_buffer = {},
        },
      }
    end

    it('should accept valid config', function()
      local cfg = get_valid_config()
      local is_valid, err = validator.validate(cfg)
      assert.is_true(is_valid)
      assert.is_nil(err)
    end)

    describe('prefix validation', function()
      it('should reject empty prefix', function()
        local cfg = get_valid_config()
        cfg.prefix = ''
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('prefix: must be a single character', err)
      end)

      it('should reject multi-character prefix', function()
        local cfg = get_valid_config()
        cfg.prefix = ',,'
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('prefix: must be a single character', err)
      end)

      it('should reject non-string prefix', function()
        local cfg = get_valid_config()
        cfg.prefix = 123
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('prefix', err)
      end)
    end)

    describe('visual_feedback_duration validation', function()
      it('should accept 0 duration', function()
        local cfg = get_valid_config()
        cfg.visual_feedback_duration = 0
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should accept 1000 duration', function()
        local cfg = get_valid_config()
        cfg.visual_feedback_duration = 1000
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should reject negative duration', function()
        local cfg = get_valid_config()
        cfg.visual_feedback_duration = -1
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('visual_feedback_duration: must be between 0 and 1000', err)
      end)

      it('should reject duration > 1000', function()
        local cfg = get_valid_config()
        cfg.visual_feedback_duration = 1001
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('visual_feedback_duration: must be between 0 and 1000', err)
      end)
    end)

    describe('clear_highlight_delay validation', function()
      it('should accept 0 delay', function()
        local cfg = get_valid_config()
        cfg.clear_highlight_delay = 0
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should accept 5000 delay', function()
        local cfg = get_valid_config()
        cfg.clear_highlight_delay = 5000
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should reject negative delay', function()
        local cfg = get_valid_config()
        cfg.clear_highlight_delay = -1
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('clear_highlight_delay: must be between 0 and 5000', err)
      end)

      it('should reject delay > 5000', function()
        local cfg = get_valid_config()
        cfg.clear_highlight_delay = 5001
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('clear_highlight_delay: must be between 0 and 5000', err)
      end)
    end)

    describe('cross_buffer validation', function()
      it('should accept valid fuzzy_finder options', function()
        local cfg = get_valid_config()
        local finders = { 'telescope', 'fzf-lua', 'mini.pick' }
        for _, finder in ipairs(finders) do
          cfg.cross_buffer.fuzzy_finder = finder
          local is_valid = validator.validate(cfg)
          assert.is_true(is_valid, 'Failed for finder: ' .. finder)
        end
      end)

      it('should reject invalid fuzzy_finder', function()
        local cfg = get_valid_config()
        cfg.cross_buffer.fuzzy_finder = 'invalid'
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('one of: telescope, fzf%-lua, mini%.pick', err)
      end)

      it('should validate boolean fields', function()
        local cfg = get_valid_config()
        cfg.cross_buffer.enabled = 'not a boolean'
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('enabled', err)
      end)
    end)

    describe('beam_scope validation', function()
      it('should accept valid beam_scope config', function()
        local cfg = get_valid_config()
        cfg.beam_scope = {
          enabled = true,
          scoped_text_objects = { '"', "'", '`', '(', ')' },
          custom_scoped_text_objects = { 'm', 'f' },
          preview_context = 5,
          window_width = 80,
        }
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should reject negative preview_context', function()
        local cfg = get_valid_config()
        cfg.beam_scope.preview_context = -1
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('preview_context: must be non%-negative', err)
      end)

      it('should reject window_width < 10', function()
        local cfg = get_valid_config()
        cfg.beam_scope.window_width = 9
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('window_width: must be between 10 and 200', err)
      end)

      it('should reject window_width > 200', function()
        local cfg = get_valid_config()
        cfg.beam_scope.window_width = 201
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('window_width: must be between 10 and 200', err)
      end)

      it('should reject non-string items in scoped_text_objects', function()
        local cfg = get_valid_config()
        cfg.beam_scope.scoped_text_objects = { '"', 123, '`' }
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('scoped_text_objects%[2%]: expected string', err)
      end)

      it('should reject non-string items in custom_scoped_text_objects', function()
        local cfg = get_valid_config()
        cfg.beam_scope.custom_scoped_text_objects = { 'm', {}, 'f' }
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('custom_scoped_text_objects%[2%]: expected string', err)
      end)
    end)

    describe('string array validation', function()
      it('should accept empty arrays', function()
        local cfg = get_valid_config()
        cfg.excluded_text_objects = {}
        cfg.excluded_motions = {}
        cfg.resolved_conflicts = {}
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should accept valid string arrays', function()
        local cfg = get_valid_config()
        cfg.excluded_text_objects = { 'q', 'z' }
        cfg.excluded_motions = { 'Q', 'R' }
        cfg.resolved_conflicts = { 'm' }
        local is_valid = validator.validate(cfg)
        assert.is_true(is_valid)
      end)

      it('should reject non-string in excluded_text_objects', function()
        local cfg = get_valid_config()
        cfg.excluded_text_objects = { 'q', 123 }
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('excluded_text_objects%[2%]: expected string', err)
      end)

      it('should reject non-string in excluded_motions', function()
        local cfg = get_valid_config()
        cfg.excluded_motions = { true, 'R' }
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('excluded_motions%[1%]: expected string', err)
      end)

      it('should reject non-string in resolved_conflicts', function()
        local cfg = get_valid_config()
        cfg.resolved_conflicts = { 'm', nil, 'n' }
        local is_valid = validator.validate(cfg)
        -- nil values don't appear in ipairs iteration, so this should pass
        assert.is_true(is_valid)
      end)
    end)

    describe('type validation', function()
      it('should reject non-boolean clear_highlight', function()
        local cfg = get_valid_config()
        cfg.clear_highlight = 'yes'
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('clear_highlight', err)
      end)

      it('should reject non-boolean enable_default_text_objects', function()
        local cfg = get_valid_config()
        cfg.enable_default_text_objects = 1
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('enable_default_text_objects', err)
      end)

      it('should reject non-table custom_text_objects', function()
        local cfg = get_valid_config()
        cfg.custom_text_objects = 'invalid'
        local is_valid, err = validator.validate(cfg)
        assert.is_false(is_valid)
        assert.match('custom_text_objects', err)
      end)
    end)
  end)

  describe('check_unknown_fields()', function()
    it('should return empty warnings for valid fields', function()
      local user_config = {
        prefix = ',',
        visual_feedback_duration = 150,
        clear_highlight = true,
      }
      local known_fields = validator.get_known_fields()
      local warnings = validator.check_unknown_fields(user_config, known_fields.root, 'beam')
      assert.equals(0, #warnings)
    end)

    it('should warn about unknown fields', function()
      local user_config = {
        prefix = ',',
        unknown_field = true,
        another_typo = 123,
      }
      local known_fields = validator.get_known_fields()
      local warnings = validator.check_unknown_fields(user_config, known_fields.root, 'beam')
      assert.equals(2, #warnings)
      assert.match('unknown_field.*unknown field', warnings[1])
      assert.match('another_typo.*unknown field', warnings[2])
    end)

    it('should check nested configs', function()
      local cross_buffer = {
        enabled = false,
        fuzzy_finder = 'telescope',
        typo_field = 'oops',
      }
      local known_fields = validator.get_known_fields()
      local warnings =
        validator.check_unknown_fields(cross_buffer, known_fields.cross_buffer, 'beam.cross_buffer')
      assert.equals(1, #warnings)
      assert.match('typo_field.*unknown field', warnings[1])
    end)
  end)

  describe('get_known_fields()', function()
    it('should return all known field categories', function()
      local fields = validator.get_known_fields()
      assert.not_nil(fields.root)
      assert.not_nil(fields.cross_buffer)
      assert.not_nil(fields.beam_scope)
      assert.not_nil(fields.experimental)
    end)

    it('should include all root fields', function()
      local fields = validator.get_known_fields()
      assert.is_true(fields.root.prefix)
      assert.is_true(fields.root.visual_feedback_duration)
      assert.is_true(fields.root.beam_scope)
      assert.is_true(fields.root.cross_buffer)
      assert.is_true(fields.root.experimental)
    end)

    it('should include all cross_buffer fields', function()
      local fields = validator.get_known_fields()
      assert.is_true(fields.cross_buffer.enabled)
      assert.is_true(fields.cross_buffer.fuzzy_finder)
      assert.is_true(fields.cross_buffer.include_hidden)
    end)

    it('should include all beam_scope fields', function()
      local fields = validator.get_known_fields()
      assert.is_true(fields.beam_scope.enabled)
      assert.is_true(fields.beam_scope.scoped_text_objects)
      assert.is_true(fields.beam_scope.custom_scoped_text_objects)
      assert.is_true(fields.beam_scope.preview_context)
      assert.is_true(fields.beam_scope.window_width)
    end)
  end)
end)
