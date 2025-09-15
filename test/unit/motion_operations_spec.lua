-- Motion-based beam operations tests using real Plenary busted
describe('beam.nvim motion operations', function()
  local beam, config, mappings

  before_each(function()
    -- Clear state
    package.loaded['beam'] = nil
    package.loaded['beam.config'] = nil
    package.loaded['beam.mappings'] = nil
    vim.cmd('mapclear')

    beam = require('beam')
    beam.setup({
      prefix = ',',
      auto_discover_text_objects = false, -- Manual control for testing
    })

    config = require('beam.config')
    mappings = require('beam.mappings')
  end)

  describe('motion registration', function()
    it('can register motions in config', function()
      config.motions['L'] = 'url'
      config.motions['Q'] = 'to next quote'
      config.motions['R'] = 'rest of paragraph'

      assert.equals('url', config.motions['L'])
      assert.equals('to next quote', config.motions['Q'])
      assert.equals('rest of paragraph', config.motions['R'])
    end)
  end)

  describe('motion mappings', function()
    it('creates mappings without i/a prefix', function()
      -- Register motions
      config.motions['L'] = 'url'
      config.motions['Q'] = 'to next quote'
      config.motions['R'] = 'rest of paragraph'

      -- Re-setup mappings after adding motions
      mappings.setup()

      local keymaps = vim.api.nvim_get_keymap('n')
      local found = {}

      for _, map in ipairs(keymaps) do
        found[map.lhs] = true
      end

      -- Should have motion mappings WITHOUT i/a prefix
      assert.is_true(found[',yL'] or false, ',yL mapping should exist')
      assert.is_true(found[',dQ'] or false, ',dQ mapping should exist')
      assert.is_true(found[',cR'] or false, ',cR mapping should exist')

      -- Should NOT have i/a prefixed versions
      assert.is_false(found[',yiL'] or false, ',yiL should NOT exist for motions')
      assert.is_false(found[',yaL'] or false, ',yaL should NOT exist for motions')
    end)

    it('creates only operator+motion combinations', function()
      config.motions['M'] = 'test motion'
      mappings.setup()

      local keymaps = vim.api.nvim_get_keymap('n')
      local found = {}

      for _, map in ipairs(keymaps) do
        found[map.lhs] = true
      end

      -- Should have all operator variations
      assert.is_true(found[',yM'] or false, 'yank motion should exist')
      assert.is_true(found[',dM'] or false, 'delete motion should exist')
      assert.is_true(found[',cM'] or false, 'change motion should exist')
      assert.is_true(found[',vM'] or false, 'visual motion should exist')
    end)
  end)

  describe('motion vs text object distinction', function()
    it('handles both motions and text objects correctly', function()
      -- Register a motion
      config.motions['K'] = 'to next keyword'
      -- Text objects should still work normally
      config.text_objects['w'] = 'word'

      mappings.setup()

      local keymaps = vim.api.nvim_get_keymap('n')
      local found = {}

      for _, map in ipairs(keymaps) do
        found[map.lhs] = true
      end

      -- Motion: no i/a prefix
      assert.is_true(found[',yK'] or false, 'motion should have ,yK')
      assert.is_false(found[',yiK'] or false, 'motion should NOT have ,yiK')

      -- Text object: has i/a prefix
      assert.is_true(found[',yiw'] or false, 'text object should have ,yiw')
      assert.is_true(found[',yaw'] or false, 'text object should have ,yaw')
    end)
  end)

  describe('line motions', function()
    it('includes special line motions Y and D', function()
      mappings.setup()

      local keymaps = vim.api.nvim_get_keymap('n')
      local found = {}

      for _, map in ipairs(keymaps) do
        found[map.lhs] = true
      end

      assert.is_true(found[',Y'] or false, ',Y (yank line) should exist')
      assert.is_true(found[',D'] or false, ',D (delete line) should exist')
    end)
  end)
end)
