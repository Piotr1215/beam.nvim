-- Custom text object registration tests using real Plenary busted
describe('beam.nvim custom text objects', function()
  before_each(function()
    -- Clear state between tests
    vim.cmd('mapclear')
    package.loaded['beam'] = nil
    package.loaded['beam.config'] = nil
    package.loaded['beam.operators'] = nil
    package.loaded['beam.mappings'] = nil
    package.loaded['beam.text_objects'] = nil
  end)

  describe('string format', function()
    it('does NOT create actual text object mappings', function()
      local beam = require('beam')
      beam.setup({
        prefix = ',',
        custom_text_objects = {
          ['F'] = 'function (treesitter)',
        },
      })

      local keymaps_o = vim.api.nvim_get_keymap('o')
      local found_iF = false
      for _, map in ipairs(keymaps_o) do
        if map.lhs == 'iF' then
          found_iF = true
          break
        end
      end

      assert.is_false(found_iF, 'String format should NOT create text object mappings')
    end)

    it('creates remote operator mappings for string format', function()
      local beam = require('beam')
      beam.setup({
        prefix = ',',
        custom_text_objects = {
          ['Q'] = 'Query (custom)',
        },
      })

      local keymaps_n = vim.api.nvim_get_keymap('n')
      local mappings_to_check = { ',yiQ', ',yaQ', ',diQ', ',daQ', ',ciQ', ',caQ' }
      local found = {}

      for _, map in ipairs(keymaps_n) do
        for _, expected in ipairs(mappings_to_check) do
          if map.lhs == expected then
            found[expected] = true
          end
        end
      end

      for _, expected in ipairs(mappings_to_check) do
        assert.is_true(found[expected], 'Remote operator mapping ' .. expected .. ' not created')
      end
    end)
  end)

  describe('table format with select function', function()
    it('creates actual text object mappings', function()
      local beam = require('beam')
      beam.setup({
        prefix = ',',
        custom_text_objects = {
          ['R'] = {
            desc = 'Custom range',
            select = function()
              vim.cmd('normal! 0v$')
            end,
          },
        },
      })

      local keymaps_o = vim.api.nvim_get_keymap('o')
      local found_iR = false
      for _, map in ipairs(keymaps_o) do
        if map.lhs == 'iR' then
          found_iR = true
          break
        end
      end

      assert.is_true(found_iR, 'Table format with select should create text object mapping')
    end)
  end)

  describe('multiple registrations', function()
    it('registers all custom text objects in config', function()
      local beam = require('beam')
      beam.setup({
        prefix = ',',
        custom_text_objects = {
          ['X'] = 'Test X',
          ['Y'] = 'Test Y',
          ['Z'] = {
            desc = 'Test Z with function',
            select = function()
              vim.cmd('normal! viw')
            end,
          },
        },
      })

      local config = require('beam.config')

      assert.equals('Test X', config.text_objects['X'])
      assert.equals('Test Y', config.text_objects['Y'])
      assert.is_not_nil(config.text_objects['Z'])
    end)
  end)
end)
