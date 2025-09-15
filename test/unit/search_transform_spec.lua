-- Search transform tests using Plenary busted
local search_transform = require('beam.search_transform')

describe('beam.nvim search_transform', function()
  local config = { smart_highlighting = true }
  local config_disabled = { smart_highlighting = false }

  describe('has_constraints', function()
    it('returns true for quotes', function()
      assert.is_true(search_transform.has_constraints('i"'))
      assert.is_true(search_transform.has_constraints('a"'))
      assert.is_true(search_transform.has_constraints("i'"))
      assert.is_true(search_transform.has_constraints('i`'))
    end)

    it('returns true for brackets', function()
      assert.is_true(search_transform.has_constraints('i{'))
      assert.is_true(search_transform.has_constraints('i('))
      assert.is_true(search_transform.has_constraints('i['))
      assert.is_true(search_transform.has_constraints('i<'))
    end)

    it('returns false for word/paragraph', function()
      assert.is_false(search_transform.has_constraints('iw'))
      assert.is_false(search_transform.has_constraints('ip'))
      assert.is_false(search_transform.has_constraints('is'))
    end)
  end)

  describe('transform_search_pattern', function()
    it('transforms pattern for double quotes', function()
      local result = search_transform.transform_search_pattern('test', 'i"', config)
      assert.equals([[\v"[^"]*\zstest\ze[^"]*"]], result)
    end)

    it('returns original when disabled', function()
      local result = search_transform.transform_search_pattern('test', 'i"', config_disabled)
      assert.equals('test', result)
    end)
  end)
end)
