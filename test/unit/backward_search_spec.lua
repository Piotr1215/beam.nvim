-- Unit tests for backward search functionality
-- Tests the ? search direction support

describe('backward search', function()
  local config
  local operators
  local beam

  before_each(function()
    -- Clear module cache
    package.loaded['beam.config'] = nil
    package.loaded['beam'] = nil
    package.loaded['beam.operators'] = nil
    package.loaded['beam.mappings'] = nil
    package.loaded['beam.smart_search'] = nil

    config = require('beam.config')
    operators = require('beam.operators')
    beam = require('beam')
  end)

  describe('config', function()
    it('should have backward_prefix as nil by default', function()
      assert.is_nil(config.defaults.backward_prefix)
    end)

    it('should allow setting backward_prefix', function()
      beam.setup({ backward_prefix = ';' })
      local current = beam.get_config()
      assert.equals(';', current.backward_prefix)
    end)

    it('should not affect forward prefix when backward_prefix is set', function()
      beam.setup({ prefix = ',', backward_prefix = ';' })
      local current = beam.get_config()
      assert.equals(',', current.prefix)
      assert.equals(';', current.backward_prefix)
    end)
  end)

  describe('operators.beam_search_direction', function()
    it('should default to forward search', function()
      assert.equals('/', operators.beam_search_direction)
    end)

    it('should be reset to forward after cleanup', function()
      operators.beam_search_direction = '?'
      operators.cleanup_pending_state()
      assert.equals('/', operators.beam_search_direction)
    end)
  end)

  describe('perform_search flags', function()
    local original_search

    before_each(function()
      -- Mock vim.fn.search to capture flags
      original_search = vim.fn.search
    end)

    after_each(function()
      vim.fn.search = original_search
      operators.beam_search_direction = '/'
    end)

    it('should use "c" flag for forward search', function()
      local captured_flags
      vim.fn.search = function(pattern, flags)
        captured_flags = flags
        return 1 -- Found
      end

      beam.setup({})
      operators.beam_search_direction = '/'

      local pending = { saved_pos_for_yank = nil }
      operators.perform_search('test', pending, beam.get_config())

      assert.equals('c', captured_flags)
    end)

    it('should use "bc" flags for backward search', function()
      local captured_flags
      vim.fn.search = function(pattern, flags)
        captured_flags = flags
        return 1 -- Found
      end

      beam.setup({})
      operators.beam_search_direction = '?'

      local pending = { saved_pos_for_yank = nil }
      operators.perform_search('test', pending, beam.get_config())

      assert.equals('bc', captured_flags)
    end)
  end)
end)
