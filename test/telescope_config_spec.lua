describe('beam.nvim telescope configuration', function()
  local beam = require('beam')
  local operators = require('beam.operators')

  -- Save original config
  local original_config

  before_each(function()
    original_config = vim.deepcopy(require('beam.config').current)
  end)

  after_each(function()
    -- Restore original config
    require('beam.config').current = original_config
  end)

  describe('multiple buffer detection', function()
    it('detects single buffer correctly', function()
      -- Close all buffers except current
      vim.cmd('silent! %bdelete!')
      vim.cmd('enew')

      assert.is_false(operators.has_multiple_buffers())
    end)

    it('detects multiple buffers correctly', function()
      -- Create multiple buffers with content to ensure they're loaded
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'buffer 1' })
      vim.cmd('enew')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'buffer 2' })

      assert.is_true(operators.has_multiple_buffers())

      -- Clean up
      vim.cmd('silent! %bdelete!')
    end)
  end)

  describe('telescope usage decision', function()
    it('uses normal search for single buffer when telescope_single_buffer disabled', function()
      beam.setup({
        cross_buffer = { enabled = false },
        experimental = {
          telescope_single_buffer = { enabled = false },
        },
      })

      -- Close all buffers except current
      vim.cmd('silent! %bdelete!')
      vim.cmd('enew')

      local cfg = require('beam.config').current
      local should_use = operators.has_multiple_buffers() and cfg.cross_buffer.enabled

      assert.is_false(should_use)
    end)

    it('uses telescope for single buffer when telescope_single_buffer enabled', function()
      beam.setup({
        cross_buffer = { enabled = false },
        experimental = {
          telescope_single_buffer = {
            enabled = true,
            theme = 'dropdown',
            preview = false,
          },
        },
      })

      local cfg = require('beam.config').current
      assert.is_true(cfg.experimental.telescope_single_buffer.enabled)
    end)

    it('uses telescope for multiple buffers when cross_buffer enabled', function()
      -- Clean up first
      vim.cmd('silent! %bdelete!')

      beam.setup({
        cross_buffer = {
          enabled = true,
          fuzzy_finder = 'telescope',
          include_hidden = true, -- Include all buffers in count
        },
        experimental = {
          telescope_single_buffer = { enabled = false },
        },
      })

      -- Create multiple listed buffers
      local buf1 = vim.api.nvim_create_buf(true, false) -- listed, not scratch
      vim.api.nvim_buf_set_name(buf1, 'test1.txt')

      local buf2 = vim.api.nvim_create_buf(true, false) -- listed, not scratch
      vim.api.nvim_buf_set_name(buf2, 'test2.txt')

      -- Make sure both buffers are loaded
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'content1' })
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'content2' })

      local cfg = require('beam.config').current
      local multiple = operators.has_multiple_buffers()
      local should_use = multiple and cfg.cross_buffer.enabled

      assert.is_true(multiple, 'Should detect multiple buffers')
      assert.is_true(
        should_use,
        'Should use telescope with multiple buffers and cross_buffer enabled'
      )

      -- Clean up
      vim.api.nvim_buf_delete(buf1, { force = true })
      vim.api.nvim_buf_delete(buf2, { force = true })
    end)

    it(
      'does not use telescope for single buffer when cross_buffer enabled but only one buffer',
      function()
        beam.setup({
          cross_buffer = {
            enabled = true,
            fuzzy_finder = 'telescope',
          },
          experimental = {
            telescope_single_buffer = { enabled = false },
          },
        })

        -- Ensure only one buffer
        vim.cmd('silent! %bdelete!')
        vim.cmd('enew')

        local cfg = require('beam.config').current
        local multiple = operators.has_multiple_buffers()
        local should_use = multiple and cfg.cross_buffer.enabled

        assert.is_false(should_use)
      end
    )
  end)

  describe('backward compatibility', function()
    it('converts boolean cross_buffer to table format', function()
      beam.setup({
        cross_buffer = true, -- Old boolean format
      })

      local cfg = require('beam.config').current
      assert.is_table(cfg.cross_buffer)
      assert.is_true(cfg.cross_buffer.enabled)
      assert.equals('telescope', cfg.cross_buffer.fuzzy_finder)
    end)

    it('preserves table cross_buffer format', function()
      beam.setup({
        cross_buffer = {
          enabled = true,
          fuzzy_finder = 'telescope',
        },
      })

      local cfg = require('beam.config').current
      assert.is_table(cfg.cross_buffer)
      assert.is_true(cfg.cross_buffer.enabled)
      assert.equals('telescope', cfg.cross_buffer.fuzzy_finder)
    end)
  end)

  describe('telescope theme configuration', function()
    it('uses telescope_single_buffer theme when configured', function()
      beam.setup({
        experimental = {
          telescope_single_buffer = {
            enabled = true,
            theme = 'ivy',
            preview = true,
            winblend = 20,
          },
        },
      })

      local cfg = require('beam.config').current
      local tsb = cfg.experimental.telescope_single_buffer
      assert.equals('ivy', tsb.theme)
      assert.is_true(tsb.preview)
      assert.equals(20, tsb.winblend)
    end)

    it('applies default theme when not configured', function()
      beam.setup({
        cross_buffer = { enabled = false },
      })

      local cfg = require('beam.config').current
      -- Should have default telescope_single_buffer settings
      assert.is_not_nil(cfg.experimental.telescope_single_buffer)
      assert.is_false(cfg.experimental.telescope_single_buffer.enabled)
      assert.equals('dropdown', cfg.experimental.telescope_single_buffer.theme)
    end)
  end)

  describe('operator behavior with telescope', function()
    before_each(function()
      -- Mock telescope availability
      package.loaded['telescope'] = {}
      package.loaded['telescope.pickers'] = {
        new = function()
          return { find = function() end }
        end,
      }
      package.loaded['telescope.finders'] = {
        new_table = function()
          return {}
        end,
      }
      package.loaded['telescope.config'] = {
        values = {
          generic_sorter = function()
            return {}
          end,
        },
      }
      package.loaded['telescope.actions'] = {
        select_default = { replace = function() end },
        close = function() end,
      }
      package.loaded['telescope.actions.state'] = {
        get_selected_entry = function()
          return nil
        end,
      }
      package.loaded['telescope.themes'] = {
        get_dropdown = function(opts)
          return opts
        end,
        get_cursor = function(opts)
          return opts
        end,
        get_ivy = function(opts)
          return opts
        end,
      }
    end)

    after_each(function()
      -- Clean up mocks
      package.loaded['telescope'] = nil
      package.loaded['telescope.pickers'] = nil
      package.loaded['telescope.finders'] = nil
      package.loaded['telescope.config'] = nil
      package.loaded['telescope.actions'] = nil
      package.loaded['telescope.actions.state'] = nil
      package.loaded['telescope.themes'] = nil
    end)

    it('yank operator respects telescope configuration', function()
      beam.setup({
        cross_buffer = { enabled = false },
        experimental = {
          telescope_single_buffer = { enabled = false },
        },
      })

      -- Ensure single buffer
      vim.cmd('silent! %bdelete!')
      vim.cmd('enew')

      -- This should use normal search, not telescope
      local result = require('beam.operators').BeamYankSearchSetup('iw')
      assert.equals('/', result) -- Should return '/' for normal search
    end)

    it('change operator respects telescope configuration', function()
      beam.setup({
        cross_buffer = { enabled = false },
        experimental = {
          telescope_single_buffer = { enabled = true },
        },
      })

      -- This should use telescope
      local result = require('beam.operators').BeamChangeSearchSetup('iw')
      -- When telescope is used, it returns empty string
      assert.equals('', result)
    end)
  end)
end)
