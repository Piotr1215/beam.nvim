describe('BeamScope', function()
  local scope = require('beam.scope')

  before_each(function()
    -- Reset state
    scope.scope_state = {
      buffer = nil,
      window = nil,
      source_buffer = nil,
      node_map = {},
      line_to_instance = {},
      action = nil,
      textobj = nil,
      saved_pos = nil,
      saved_buf = nil,
    }
  end)

  describe('find_text_objects', function()
    it('should find markdown code blocks', function()
      -- Create a test buffer with markdown code blocks
      local buf = vim.api.nvim_create_buf(false, true)
      local lines = {
        '# Test',
        '',
        '```javascript',
        'console.log("test");',
        '```',
        '',
        '```python',
        'print("hello")',
        '```',
      }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      -- Find markdown code blocks
      local instances = scope.find_text_objects('m', buf)

      -- Should find 2 code blocks
      assert.equals(2, #instances)

      -- First block should be JavaScript
      assert.equals(3, instances[1].start_line)
      assert.equals(5, instances[1].end_line)
      assert.equals('javascript', instances[1].language)

      -- Second block should be Python
      assert.equals(7, instances[2].start_line)
      assert.equals(9, instances[2].end_line)
      assert.equals('python', instances[2].language)

      -- Clean up
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should handle code blocks without language', function()
      local buf = vim.api.nvim_create_buf(false, true)
      local lines = {
        '```',
        'plain text',
        '```',
      }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      local instances = scope.find_text_objects('m', buf)

      assert.equals(1, #instances)
      assert.equals('', instances[1].language)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('format_instance_lines', function()
    it('should format markdown code blocks with language', function()
      local instance = {
        start_line = 1,
        end_line = 3,
        language = 'lua',
        preview = 'local x = 1\nlocal y = 2',
        first_line = 'local x = 1',
      }

      local lines = scope.format_instance_lines(instance, 1, 'm')
      assert.equals('```lua', lines[1])
      assert.equals('local x = 1', lines[2])
      assert.equals('local y = 2', lines[3])
      assert.equals('```', lines[4])
      -- No empty line separator anymore
    end)

    it('should format markdown code blocks without language', function()
      local instance = {
        start_line = 1,
        end_line = 3,
        language = '',
        preview = 'some text',
        first_line = 'some text',
      }

      local lines = scope.format_instance_lines(instance, 2, 'm')
      assert.equals('```', lines[1])
      assert.equals('some text', lines[2])
      assert.equals('```', lines[3])
      -- No empty line separator anymore
    end)
  end)

  describe('should_use_scope', function()
    it('should return true for configured text objects', function()
      local config = require('beam.config')
      config.current.beam_scope = {
        enabled = true,
        scoped_text_objects = { 'm', 'f' },
      }

      assert.is_true(scope.should_use_scope('im'))
      assert.is_true(scope.should_use_scope('am'))
      assert.is_true(scope.should_use_scope('if'))
      assert.is_false(scope.should_use_scope('iw'))
    end)

    it('should return false when BeamScope is disabled', function()
      local config = require('beam.config')
      config.current.beam_scope = {
        enabled = false,
        scoped_text_objects = { 'm' },
      }

      assert.is_false(scope.should_use_scope('im'))
    end)
  end)

  describe('create_scope_buffer', function()
    it('should create a buffer with formatted instances', function()
      local source_buf = vim.api.nvim_create_buf(false, true)
      local instances = {
        {
          start_line = 1,
          end_line = 3,
          language = 'bash',
          preview = 'make install-hooks',
          first_line = 'make install-hooks',
        },
        {
          start_line = 5,
          end_line = 7,
          language = 'bash',
          preview = 'git config core.hooksPath .githooks',
          first_line = 'git config core.hooksPath .githooks',
        },
      }

      local buf = scope.create_scope_buffer(instances, 'm', source_buf)

      -- Check buffer properties
      assert.equals('nofile', vim.api.nvim_buf_get_option(buf, 'buftype'))
      assert.is_true(vim.api.nvim_buf_get_option(buf, 'readonly'))

      -- Check buffer content (no empty line separators)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals('```bash', lines[1])
      assert.equals('make install-hooks', lines[2])
      assert.equals('```', lines[3])
      assert.equals('```bash', lines[4])
      assert.equals('git config core.hooksPath .githooks', lines[5])
      assert.equals('```', lines[6])

      -- Check state is properly set
      assert.equals(buf, scope.scope_state.buffer)
      assert.equals(source_buf, scope.scope_state.source_buffer)
      assert.equals(2, #scope.scope_state.node_map)

      -- Clean up
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.api.nvim_buf_delete(source_buf, { force = true })
    end)
  end)

  describe('update_preview', function()
    it('should highlight code block in source buffer', function()
      -- Setup test state
      local source_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
        '# Test',
        '',
        '```bash',
        'echo "test"',
        '```',
        '',
        'Some text',
      })

      scope.scope_state = {
        source_buffer = source_buf,
        node_map = {
          {
            start_line = 3,
            end_line = 5,
            start_col = 0,
            end_col = 3,
          },
        },
        line_to_instance = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1 },
      }

      -- Create a scope window to work with
      local scope_win = vim.api.nvim_get_current_win()
      scope.scope_state.window = scope_win

      -- Update preview for first instance
      scope.update_preview(1)

      -- Check that highlight namespace was created
      assert.is_not_nil(scope.scope_state.highlight_ns)

      -- Check that source window is set
      assert.is_not_nil(scope.scope_state.source_window)

      -- Clean up
      scope.cleanup_scope()
      vim.api.nvim_buf_delete(source_buf, { force = true })
    end)
  end)

  describe('cleanup_scope', function()
    it('should properly clean up all state', function()
      -- Create some state
      scope.scope_state.buffer = vim.api.nvim_create_buf(false, true)
      scope.scope_state.window = vim.api.nvim_get_current_win()
      scope.scope_state.action = 'yank'
      scope.scope_state.textobj = 'im'

      -- Clean up
      scope.cleanup_scope()

      -- Verify state is reset
      assert.is_nil(scope.scope_state.buffer)
      assert.is_nil(scope.scope_state.window)
      assert.is_nil(scope.scope_state.action)
      assert.is_nil(scope.scope_state.textobj)
      assert.same({}, scope.scope_state.node_map)
      assert.same({}, scope.scope_state.line_to_instance)
    end)
  end)
end)
