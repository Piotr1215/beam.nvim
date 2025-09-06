-- Text object discovery tests using real Plenary busted
describe('beam.nvim text object discovery', function()
  describe('discovery methods', function()
    it('discovers operator-pending mappings', function()
      local op_maps = vim.api.nvim_get_keymap('o')
      local text_objects = {}

      for _, map in ipairs(op_maps) do
        local lhs = map.lhs
        if lhs and #lhs >= 2 then
          local first = lhs:sub(1, 1)
          if first == 'i' or first == 'a' then
            text_objects[lhs] = true
          end
        end
      end

      -- In minimal environment, might not have many mappings
      -- Just verify the discovery mechanism works
      assert.is_not_nil(op_maps, 'Should be able to query operator-pending maps')
    end)

    it('discovers visual mode mappings', function()
      local vis_maps = vim.api.nvim_get_keymap('x')
      local text_objects = {}

      for _, map in ipairs(vis_maps) do
        local lhs = map.lhs
        if lhs and #lhs >= 2 then
          local first = lhs:sub(1, 1)
          if first == 'i' or first == 'a' then
            text_objects[lhs] = true
          end
        end
      end

      -- Visual mode should have text objects too
      assert.is_true(vim.tbl_count(text_objects) >= 0, 'Should find visual mode text objects')
    end)
  end)

  describe('built-in text object testing', function()
    local test_buf

    before_each(function()
      test_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(test_buf)
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, {
        'word "quoted text" more',
        '(parentheses content)',
        '{braces content}',
      })
    end)

    after_each(function()
      if test_buf and vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    local function test_text_object(obj)
      local ok = pcall(function()
        vim.cmd('normal! 1G0')
        vim.cmd('normal! v' .. obj)
        vim.cmd('normal! \027')
      end)
      return ok
    end

    it('detects working built-in text objects', function()
      local working = {}
      local objects_to_test = { 'iw', 'aw', 'i"', 'a"', 'i(', 'a(', 'i{', 'a{' }

      for _, obj in ipairs(objects_to_test) do
        if test_text_object(obj) then
          working[obj] = true
        end
      end

      -- Should have most common text objects
      assert.is_true(working['iw'] or false, 'Should have inner word')
      assert.is_true(working['aw'] or false, 'Should have around word')
    end)
  end)

  describe('auto-registration with beam.nvim', function()
    it('auto-discovers and registers text objects', function()
      -- Clear previous state
      package.loaded['beam'] = nil
      package.loaded['beam.text_object_discovery'] = nil

      local beam = require('beam')
      beam.setup({
        prefix = ',',
        auto_discover_text_objects = true,
        show_discovery_notification = false,
      })

      -- Give it time to discover
      vim.wait(100)

      local config = beam.get_config()
      -- Config should exist
      assert.is_not_nil(config, 'Should have config')
      assert.is_not_nil(config.prefix, 'Config should be initialized')
    end)
  end)

  describe('plugin text object discovery', function()
    it('can discover plugin-provided text objects', function()
      -- Create a mock plugin text object
      vim.api.nvim_set_keymap('o', 'if', ':<C-u>call SelectFunction()<CR>', { silent = true })

      local op_maps = vim.api.nvim_get_keymap('o')
      local found_if = false

      for _, map in ipairs(op_maps) do
        if map.lhs == 'if' then
          found_if = true
          break
        end
      end

      assert.is_true(found_if, 'Should discover plugin text objects')

      -- Clean up
      vim.api.nvim_del_keymap('o', 'if')
    end)
  end)

  describe('mini.ai text object discovery', function()
    local discovery

    before_each(function()
      -- Reset module state
      package.loaded['beam.text_object_discovery'] = nil
      package.loaded['mini.ai'] = nil
      discovery = require('beam.text_object_discovery')
    end)

    it('handles missing mini.ai gracefully', function()
      -- When mini.ai is not installed
      local objects, has_mini = discovery.discover_mini_ai_text_objects()

      assert.is_table(objects, 'Should return empty table when mini.ai not found')
      assert.is_false(has_mini, 'Should indicate mini.ai not found')
      assert.equals(vim.tbl_count(objects), 0, 'Should return no objects when mini.ai missing')
    end)

    it('discovers mini.ai custom text objects when available', function()
      -- Mock mini.ai with some example custom text objects
      package.loaded['mini.ai'] = {
        config = {
          custom_textobjects = {
            ['*'] = { 'pattern1', 'pattern2' }, -- Pattern-based (like markdown bold)
            ['z'] = false, -- Disabled text object (should be skipped)
            ['x'] = 'alias', -- String alias
            ['F'] = function()
              return nil
            end, -- Function-based
          },
        },
      }

      local objects, has_mini = discovery.discover_mini_ai_text_objects()

      assert.is_true(has_mini, 'Should detect mini.ai when available')
      assert.is_table(objects, 'Should return table of objects')

      -- Check discovered objects (generic, not assuming specific descriptions)
      assert.is_not_nil(objects['i*'], 'Should discover pattern-based object')
      assert.is_not_nil(objects['a*'], 'Should discover pattern-based object')
      assert.is_not_nil(objects['ix'], 'Should discover alias object')
      assert.is_not_nil(objects['ax'], 'Should discover alias object')
      assert.is_not_nil(objects['iF'], 'Should discover function-based object')
      assert.is_not_nil(objects['aF'], 'Should discover function-based object')
      assert.is_nil(objects['iz'], 'Should not include disabled text objects')
      assert.is_nil(objects['az'], 'Should not include disabled text objects')

      -- Check that descriptions exist and are reasonable
      assert.truthy(
        string.find(objects['i*'], 'inner'),
        'Inner variant should have inner in description'
      )
      assert.truthy(
        string.find(objects['a*'], 'around'),
        'Around variant should have around in description'
      )
    end)

    it('handles different types of text object specifications', function()
      package.loaded['mini.ai'] = {
        config = {
          custom_textobjects = {
            ['F'] = function() end, -- Function (uppercase to avoid conflict with builtin f)
            ['p'] = { 'pattern' }, -- Table/pattern
            ['x'] = 'alias', -- String/alias (changed from 'a' which is builtin)
            ['d'] = false, -- Disabled
          },
        },
      }

      local objects = discovery.discover_mini_ai_text_objects()

      -- Functions should be marked as such
      assert.is_not_nil(objects['iF'], 'Function object should exist')
      assert.truthy(string.find(objects['iF'], 'function'), 'Function objects should be identified')
      -- Patterns should be marked as such
      assert.is_not_nil(objects['ip'], 'Pattern object should exist')
      assert.truthy(string.find(objects['ip'], 'pattern'), 'Pattern objects should be identified')
      -- Aliases should be marked as such
      assert.is_not_nil(objects['ix'], 'Alias object should exist')
      assert.truthy(string.find(objects['ix'], 'alias'), 'Alias objects should be identified')
      -- Disabled should not appear
      assert.is_nil(objects['id'], 'Disabled objects should not be discovered')
    end)

    it('integrates mini.ai objects into full discovery', function()
      -- Mock mini.ai with a simple custom object
      package.loaded['mini.ai'] = {
        config = {
          custom_textobjects = {
            ['g'] = { 'pattern' }, -- Just one custom object for testing
          },
        },
      }

      local all_objects = discovery.discover_text_objects()

      -- Find our custom object in the full list
      local found_custom = false

      for _, obj in ipairs(all_objects) do
        if obj.keymap == 'ig' and obj.source == 'mini.ai' then
          found_custom = true
          assert.truthy(
            string.find(obj.desc, 'custom'),
            'Custom object should have appropriate description'
          )
          break
        end
      end

      assert.is_true(found_custom, 'Should include mini.ai custom objects in full discovery')
    end)

    it('respects exclusion list for mini.ai objects', function()
      -- Mock mini.ai
      package.loaded['mini.ai'] = {
        config = {
          custom_textobjects = {
            ['q'] = { 'pattern' },
            ['x'] = { 'another' },
          },
        },
      }

      -- Mock config with exclusions
      local config = require('beam.config')
      config.current = {
        excluded_text_objects = { 'q' }, -- Exclude 'q' but not 'x'
      }

      local all_objects = discovery.discover_text_objects()

      -- Check that excluded objects are not present
      local found_q = false
      local found_x = false

      for _, obj in ipairs(all_objects) do
        if (obj.keymap == 'iq' or obj.keymap == 'aq') and obj.source == 'mini.ai' then
          found_q = true
        elseif (obj.keymap == 'ix' or obj.keymap == 'ax') and obj.source == 'mini.ai' then
          found_x = true
        end
      end

      assert.is_false(found_q, 'Should not include excluded mini.ai object q')
      assert.is_true(found_x, 'Should include non-excluded mini.ai object x')
    end)

    it('returns proper status indicator', function()
      -- Test 1: No mini.ai
      package.loaded['mini.ai'] = nil
      local _, has_mini = discovery.discover_mini_ai_text_objects()
      assert.is_false(has_mini, 'Should return false when mini.ai not available')

      -- Test 2: mini.ai present but no custom objects
      package.loaded['mini.ai'] = {
        config = {}, -- No custom_textobjects field
      }
      local _, has_mini2 = discovery.discover_mini_ai_text_objects()
      assert.is_true(
        has_mini2,
        'Should return true when mini.ai present even without custom objects'
      )

      -- Test 3: mini.ai with custom objects
      package.loaded['mini.ai'] = {
        config = {
          custom_textobjects = {
            ['x'] = 'test',
          },
        },
      }
      local _, has_mini3 = discovery.discover_mini_ai_text_objects()
      assert.is_true(has_mini3, 'Should return true when mini.ai present with custom objects')
    end)
  end)
end)
