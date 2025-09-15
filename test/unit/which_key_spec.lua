-- Which-key integration tests using real Plenary busted
describe('beam.nvim which-key integration', function()
  local which_key_calls

  before_each(function()
    -- Clear any previous state
    package.loaded['beam'] = nil
    package.loaded['beam.config'] = nil
    package.loaded['beam.operators'] = nil
    package.loaded['beam.mappings'] = nil

    -- Mock which-key
    which_key_calls = {}
    package.loaded['which-key'] = {
      add = function(spec)
        table.insert(which_key_calls, spec)
        return true
      end,
    }
  end)

  describe('new spec format', function()
    it('calls which-key.add with correct format', function()
      local beam = require('beam')
      beam.setup({ prefix = ',' })

      assert.equals(1, #which_key_calls, 'which-key.add should be called once')
    end)

    it('uses array format instead of nested tables', function()
      local beam = require('beam')
      beam.setup({ prefix = ',' })

      local spec = which_key_calls[1]
      assert.is_table(spec)
      assert.equals(5, #spec, 'Should have 5 entries')

      -- Check each entry is array-style
      for _, entry in ipairs(spec) do
        assert.is_string(entry[1], 'First element should be key string')
        assert.is_string(entry.group, 'Should have group field')
      end
    end)

    it('has correct group names', function()
      local beam = require('beam')
      beam.setup({ prefix = ',' })

      local spec = which_key_calls[1]
      local groups = {}
      for _, entry in ipairs(spec) do
        groups[entry[1]] = entry.group
      end

      assert.equals('Remote Operators', groups[','])
      assert.equals('Yank', groups[',y'])
      assert.equals('Delete', groups[',d'])
      assert.equals('Change', groups[',c'])
      assert.equals('Visual', groups[',v'])
    end)

    it('respects custom prefix', function()
      local beam = require('beam')
      beam.setup({ prefix = '<leader>r' })

      local spec = which_key_calls[1]
      local groups = {}
      for _, entry in ipairs(spec) do
        groups[entry[1]] = entry.group
      end

      assert.equals('Remote Operators', groups['<leader>r'])
      assert.equals('Yank', groups['<leader>ry'])
    end)
  end)
end)
