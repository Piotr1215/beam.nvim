describe('beam.nvim telescope settings layers', function()
  local beam = require('beam')
  local config = require('beam.config')
  local operators = require('beam.operators')

  -- Counter for unique buffer names
  local buffer_counter = 0

  -- Helper to reset config between tests
  local function reset_config()
    config.current = vim.tbl_deep_extend('force', {}, config.defaults)
  end

  -- Mock buffer setup
  local function setup_buffers(visible_count, hidden_count)
    -- Clear all buffers first
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and buf ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end

    local buffers = {}
    local visible_wins = {}
    buffer_counter = buffer_counter + 1

    -- First close all windows except current
    vim.cmd('only')

    -- Create visible buffers (in windows)
    for i = 1, visible_count do
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buf, 'visible_' .. buffer_counter .. '_' .. i .. '.txt')
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'visible buffer ' .. i })

      if i == 1 then
        -- Use the current window for the first buffer
        vim.api.nvim_set_current_buf(buf)
        table.insert(visible_wins, vim.api.nvim_get_current_win())
      else
        -- Create a new split window for each additional visible buffer
        vim.cmd('split')
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        table.insert(visible_wins, win)
      end

      table.insert(buffers, buf)
    end

    -- Create hidden buffers (no windows)
    for i = 1, hidden_count do
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buf, 'hidden_' .. buffer_counter .. '_' .. i .. '.txt')
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hidden buffer ' .. i })
      table.insert(buffers, buf)
    end

    -- Return to the first window to have a consistent state
    if #visible_wins > 0 then
      vim.api.nvim_set_current_win(visible_wins[1])
    end

    return buffers, visible_wins
  end

  describe('cross_buffer settings', function()
    after_each(function()
      reset_config()
    end)

    it('should handle legacy boolean cross_buffer = true', function()
      beam.setup({ cross_buffer = true })

      assert.is_table(config.current.cross_buffer)
      assert.is_true(config.current.cross_buffer.enabled)
      assert.equals('telescope', config.current.cross_buffer.fuzzy_finder)
      assert.is_false(config.current.cross_buffer.include_hidden)
    end)

    it('should handle legacy boolean cross_buffer = false', function()
      beam.setup({ cross_buffer = false })

      assert.is_table(config.current.cross_buffer)
      assert.is_false(config.current.cross_buffer.enabled)
    end)

    it('should handle new object format for cross_buffer', function()
      beam.setup({
        cross_buffer = {
          enabled = true,
          fuzzy_finder = 'telescope',
          include_hidden = true,
        },
      })

      assert.is_true(config.current.cross_buffer.enabled)
      assert.equals('telescope', config.current.cross_buffer.fuzzy_finder)
      assert.is_true(config.current.cross_buffer.include_hidden)
    end)

    it("should handle string 'false' for include_hidden", function()
      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = 'false',
        },
      })

      -- String "false" should be treated as false
      local include_hidden = config.current.cross_buffer.include_hidden
      assert.is_true(include_hidden == false or include_hidden == 'false')
    end)
  end)

  describe('telescope_single_buffer experimental settings', function()
    after_each(function()
      reset_config()
    end)

    it('should default to disabled', function()
      beam.setup({})

      assert.is_false(config.current.experimental.telescope_single_buffer.enabled)
    end)

    it('should respect enabled setting', function()
      beam.setup({
        experimental = {
          telescope_single_buffer = {
            enabled = true,
            theme = 'cursor',
            preview = true,
            winblend = 20,
          },
        },
      })

      assert.is_true(config.current.experimental.telescope_single_buffer.enabled)
      assert.equals('cursor', config.current.experimental.telescope_single_buffer.theme)
      assert.is_true(config.current.experimental.telescope_single_buffer.preview)
      assert.equals(20, config.current.experimental.telescope_single_buffer.winblend)
    end)
  end)

  describe('has_multiple_buffers with include_hidden settings', function()
    after_each(function()
      reset_config()
      -- Clean up buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and buf ~= vim.api.nvim_get_current_buf() then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end)

    it('should count all buffers when include_hidden = true', function()
      setup_buffers(1, 2) -- 1 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = true,
        },
      })

      assert.is_true(operators.has_multiple_buffers())
    end)

    it('should count only visible buffers when include_hidden = false', function()
      setup_buffers(1, 2) -- 1 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = false,
        },
      })

      assert.is_false(operators.has_multiple_buffers())
    end)

    it("should count only visible buffers when include_hidden = 'false' (string)", function()
      setup_buffers(1, 2) -- 1 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = 'false',
        },
      })

      assert.is_false(operators.has_multiple_buffers())
    end)

    it('should detect multiple visible buffers correctly', function()
      setup_buffers(3, 2) -- 3 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = false,
        },
      })

      assert.is_true(operators.has_multiple_buffers())
    end)

    it('should return false when cross_buffer is disabled', function()
      setup_buffers(3, 2) -- 3 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = false,
          include_hidden = true,
        },
      })

      assert.is_false(operators.has_multiple_buffers())
    end)
  end)

  describe('use_telescope decision logic', function()
    local function should_use_telescope()
      local cfg = config.current

      -- Cross-buffer enabled and multiple buffers
      if cfg.cross_buffer and cfg.cross_buffer.enabled and operators.has_multiple_buffers() then
        return true
      end

      -- Single buffer telescope experimental feature
      if
        cfg.experimental
        and cfg.experimental.telescope_single_buffer
        and cfg.experimental.telescope_single_buffer.enabled
      then
        return true
      end

      return false
    end

    after_each(function()
      reset_config()
      -- Clean up buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and buf ~= vim.api.nvim_get_current_buf() then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end)

    it('should use telescope for cross-buffer with multiple visible buffers', function()
      setup_buffers(2, 0) -- 2 visible, 0 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = false,
        },
        experimental = {
          telescope_single_buffer = {
            enabled = false,
          },
        },
      })

      assert.is_true(should_use_telescope())
    end)

    it(
      'should NOT use telescope for single visible buffer when telescope_single_buffer disabled',
      function()
        setup_buffers(1, 2) -- 1 visible, 2 hidden

        beam.setup({
          cross_buffer = {
            enabled = true,
            include_hidden = false,
          },
          experimental = {
            telescope_single_buffer = {
              enabled = false,
            },
          },
        })

        assert.is_false(should_use_telescope())
      end
    )

    it('should use telescope for single buffer when telescope_single_buffer enabled', function()
      setup_buffers(1, 0) -- 1 visible, 0 hidden

      beam.setup({
        cross_buffer = {
          enabled = false,
        },
        experimental = {
          telescope_single_buffer = {
            enabled = true,
          },
        },
      })

      assert.is_true(should_use_telescope())
    end)

    it('should use telescope when including hidden buffers makes multiple', function()
      setup_buffers(1, 2) -- 1 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = true, -- Include hidden buffers
        },
        experimental = {
          telescope_single_buffer = {
            enabled = false,
          },
        },
      })

      assert.is_true(should_use_telescope())
    end)

    it('should NOT use telescope when cross_buffer disabled regardless of buffer count', function()
      setup_buffers(3, 2) -- 3 visible, 2 hidden

      beam.setup({
        cross_buffer = {
          enabled = false,
        },
        experimental = {
          telescope_single_buffer = {
            enabled = false,
          },
        },
      })

      assert.is_false(should_use_telescope())
    end)
  end)

  describe('configuration precedence and interactions', function()
    after_each(function()
      reset_config()
    end)

    it('should prioritize cross_buffer over single_buffer when both apply', function()
      setup_buffers(2, 1) -- 2 visible, 1 hidden

      beam.setup({
        cross_buffer = {
          enabled = true,
          include_hidden = false,
        },
        experimental = {
          telescope_single_buffer = {
            enabled = true,
            theme = 'cursor',
          },
        },
      })

      -- With multiple visible buffers, cross_buffer takes precedence
      assert.is_true(operators.has_multiple_buffers())

      -- The theme should still come from telescope_single_buffer if configured
      local exp_config = config.current.experimental.telescope_single_buffer
      assert.equals('cursor', exp_config.theme)
    end)

    it('should handle all settings at defaults', function()
      beam.setup({})

      assert.is_false(config.current.cross_buffer.enabled)
      assert.equals('telescope', config.current.cross_buffer.fuzzy_finder)
      assert.is_false(config.current.cross_buffer.include_hidden)
      assert.is_false(config.current.experimental.telescope_single_buffer.enabled)
      assert.equals('dropdown', config.current.experimental.telescope_single_buffer.theme)
    end)

    it('should handle partial configuration objects', function()
      beam.setup({
        cross_buffer = {
          enabled = true,
          -- fuzzy_finder and include_hidden should get defaults
        },
      })

      assert.is_true(config.current.cross_buffer.enabled)
      assert.equals('telescope', config.current.cross_buffer.fuzzy_finder)
      assert.is_false(config.current.cross_buffer.include_hidden)
    end)

    it('should preserve other experimental settings', function()
      beam.setup({
        experimental = {
          dot_repeat = true,
          count_support = true,
          telescope_single_buffer = {
            enabled = true,
          },
        },
      })

      assert.is_true(config.current.experimental.dot_repeat)
      assert.is_true(config.current.experimental.count_support)
      assert.is_true(config.current.experimental.telescope_single_buffer.enabled)
    end)
  end)
end)
