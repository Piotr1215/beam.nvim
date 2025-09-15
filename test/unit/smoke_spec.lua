-- Smoke tests using real Plenary busted
local beam = require('beam')

describe('beam.nvim', function()
  describe('plugin loading', function()
    it('loads successfully', function()
      local ok = pcall(require, 'beam')
      assert.is_true(ok)
    end)
  end)

  describe('setup()', function()
    it('configures plugin correctly', function()
      beam.setup({ prefix = ',' })
      local config = beam.get_config()
      assert.equals(',', config.prefix)
      assert.equals(150, config.visual_feedback_duration)
    end)
  end)

  describe('operator functions', function()
    it('creates global operator functions', function()
      local operators = require('beam.operators')
      assert.is_not_nil(operators.BeamSearchOperator)
      assert.is_not_nil(operators.BeamYankSearchSetup)
      assert.is_not_nil(operators.BeamDeleteSearchSetup)
      assert.is_not_nil(operators.BeamChangeSearchSetup)
      assert.is_not_nil(operators.BeamVisualSearchSetup)
    end)
  end)

  describe('keymaps', function()
    it('registers keymaps for common text objects', function()
      local keymaps = vim.api.nvim_get_keymap('n')
      local required_mappings = { ',yi"', ',ya"', ',yip', ',yiw', ',Y', ',D' }
      local found = {}

      for _, map in ipairs(keymaps) do
        for _, req in ipairs(required_mappings) do
          if map.lhs == req then
            found[req] = true
          end
        end
      end

      for _, req in ipairs(required_mappings) do
        assert.is_true(found[req], 'Mapping ' .. req .. ' not created')
      end
    end)
  end)

  describe('custom text objects', function()
    it('allows registering custom text objects', function()
      beam.register_text_object('z', 'test object')
      local config_module = require('beam.config')
      -- Check active_text_objects instead of text_objects
      assert.equals('test object', config_module.active_text_objects['z'])
    end)
  end)

  describe('pending operation state', function()
    it('sets pending operation state correctly', function()
      -- Disable BeamScope for this test
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = false },
      })
      local operators = require('beam.operators')
      operators.BeamYankSearchSetup('i"')
      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.equals('yank', operators.BeamSearchOperatorPending.action)
      assert.equals('i"', operators.BeamSearchOperatorPending.textobj)
    end)
  end)
end)
