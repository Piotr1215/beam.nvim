-- Comprehensive tests for all beam.nvim mode combinations
local beam = require('beam')
local operators = require('beam.operators')
local scope = require('beam.scope')

describe('beam.nvim mode combinations', function()
  -- Test matrix:
  -- 1. BeamScope enabled/disabled
  -- 2. Cross-buffer enabled/disabled
  -- 3. Telescope single buffer enabled/disabled
  -- 4. Different text objects (quotes, brackets, headers, code blocks)

  local function set_buffer(lines)
    vim.cmd('enew!')
    if type(lines) == 'string' then
      lines = { lines }
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  describe('BeamScope disabled (traditional beam)', function()
    before_each(function()
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = false },
        cross_buffer = { enabled = false },
      })
    end)

    it('uses native search for quotes', function()
      set_buffer('foo "bar" baz')

      -- Setup yank operation
      operators.BeamYankSearchSetup('i"')

      -- Should have pending state (not intercepted by BeamScope)
      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.equals('yank', operators.BeamSearchOperatorPending.action)
      assert.equals('i"', operators.BeamSearchOperatorPending.textobj)
    end)

    it('uses native search for brackets', function()
      set_buffer('foo (bar) baz')

      operators.BeamYankSearchSetup('i(')

      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.equals('yank', operators.BeamSearchOperatorPending.action)
    end)
  end)

  describe('BeamScope enabled with default text objects', function()
    before_each(function()
      beam.setup({
        prefix = ',',
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"', '(', '[', '{' },
        },
        cross_buffer = { enabled = false },
      })
    end)

    it('intercepts quotes with BeamScope', function()
      set_buffer({ 'foo "bar" baz', 'test "another" value' })

      -- This should trigger BeamScope
      local result = operators.BeamYankSearchSetup('i"')

      -- BeamScope returns empty string to prevent normal search
      assert.equals('', result)

      -- BeamScope state should be set
      assert.is_not_nil(scope.scope_state.action)
      assert.equals('yank', scope.scope_state.action)

      -- Clean up
      scope.cleanup_scope()
    end)

    it('does NOT intercept word objects', function()
      set_buffer('foo bar baz')

      operators.BeamYankSearchSetup('iw')

      -- Should use normal beam (not BeamScope)
      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.equals('yank', operators.BeamSearchOperatorPending.action)
    end)
  end)

  describe('BeamScope with custom text objects', function()
    before_each(function()
      beam.setup({
        prefix = ',',
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"' },
          custom_scoped_text_objects = { 'm', 'h' },
        },
        cross_buffer = { enabled = false },
      })
    end)

    it('handles markdown code blocks', function()
      set_buffer({
        '```lua',
        'local x = 1',
        '```',
        '',
        '```python',
        'print("hello")',
        '```',
      })

      local result = operators.BeamYankSearchSetup('im')
      assert.equals('', result) -- BeamScope intercepted

      -- Should find 2 code blocks
      local instances = scope.find_text_objects('m', vim.api.nvim_get_current_buf())
      assert.equals(2, #instances)

      scope.cleanup_scope()
    end)

    it('handles markdown headers', function()
      -- Clean up any previous state
      scope.cleanup_scope()

      -- Clear any registers
      vim.fn.setreg('a', '')

      -- Create a fresh buffer for this test
      vim.cmd('enew!')
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        '# Main Header',
        'Content here',
        '## Sub Header',
        'More content',
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local result = operators.BeamYankSearchSetup('ih')
      assert.equals('', result) -- BeamScope intercepted

      -- Should find 2 headers
      local instances = scope.find_text_objects('h', buf)

      -- Debug output if test fails
      if #instances ~= 2 then
        print('Expected 2 headers, found ' .. #instances)
        for i, inst in ipairs(instances) do
          print(string.format('  Header %d: line %d-%d', i, inst.start_line, inst.end_line))
        end
      end

      assert.equals(2, #instances)

      -- Headers should include content
      assert.equals(2, instances[1].end_line) -- Main header extends to line 2
      assert.equals(4, instances[2].end_line) -- Sub header extends to end

      scope.cleanup_scope()
    end)
  end)

  describe('Cross-buffer mode interactions', function()
    before_each(function()
      -- Create multiple buffers
      vim.cmd('enew!')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Buffer 1: "test"' })
      local buf1 = vim.api.nvim_get_current_buf()

      vim.cmd('enew!')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Buffer 2: "another"' })
      local buf2 = vim.api.nvim_get_current_buf()
    end)

    it('BeamScope disabled + cross-buffer enabled = uses Telescope', function()
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = false },
        cross_buffer = { enabled = true },
      })

      -- This should use Telescope (not BeamScope)
      operators.BeamYankSearchSetup('i"')

      -- Should have pending state (BeamScope not intercepting)
      assert.is_not_nil(operators.BeamSearchOperatorPending)
    end)

    it('BeamScope enabled + cross-buffer enabled = disables BeamScope', function()
      beam.setup({
        prefix = ',',
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"' },
        },
        cross_buffer = { enabled = true },
      })

      -- Cross-buffer disables BeamScope, so falls back to search
      local result = operators.BeamYankSearchSetup('i"')
      assert.equals('/', result) -- Normal search (BeamScope disabled due to cross-buffer)

      -- Should have pending state (BeamScope disabled)
      assert.is_not_nil(operators.BeamSearchOperatorPending)
    end)
  end)

  describe('Telescope single buffer mode', function()
    before_each(function()
      set_buffer('foo "bar" baz')
    end)

    it('uses Telescope for single buffer when enabled', function()
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = false },
        cross_buffer = { enabled = false },
        experimental = {
          telescope_single_buffer = {
            enabled = true,
            theme = 'dropdown',
          },
        },
      })

      -- This would use Telescope even for single buffer
      operators.BeamYankSearchSetup('i"')

      -- Should still set pending state
      assert.is_not_nil(operators.BeamSearchOperatorPending)
    end)
  end)

  describe('Priority and precedence', function()
    it('BeamScope > Telescope > Native search', function()
      beam.setup({
        prefix = ',',
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"' },
        },
        cross_buffer = { enabled = true },
        experimental = {
          telescope_single_buffer = { enabled = true },
        },
      })

      set_buffer('foo "bar" baz')

      -- Even with cross-buffer and telescope_single_buffer enabled,
      -- BeamScope should take precedence for quotes
      local result = operators.BeamYankSearchSetup('i"')
      assert.equals('', result) -- BeamScope intercepted

      -- But for non-BeamScope objects, should use Telescope
      operators.BeamYankSearchSetup('iw')
      assert.is_not_nil(operators.BeamSearchOperatorPending)

      scope.cleanup_scope()
    end)
  end)

  describe('Edge cases and special scenarios', function()
    it('handles empty buffers gracefully', function()
      -- Clean up any previous state
      scope.cleanup_scope()

      -- Clear any registers that might contain quotes
      vim.fn.setreg('a', '')
      vim.fn.setreg('"', '')

      -- Create a fresh buffer for this test
      vim.cmd('enew!')
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      beam.setup({
        prefix = ',',
        beam_scope = {
          enabled = true,
          scoped_text_objects = { '"' },
        },
      })

      local result = operators.BeamYankSearchSetup('i"')
      assert.equals('', result) -- BeamScope still intercepts

      -- But should find no instances
      local instances = scope.find_text_objects('"', buf)

      -- Debug output if test fails
      if #instances ~= 0 then
        print('Expected 0 instances in empty buffer, found ' .. #instances)
        for i, inst in ipairs(instances) do
          print(
            string.format(
              "  Instance %d: line %d, preview='%s'",
              i,
              inst.start_line,
              inst.preview or 'nil'
            )
          )
        end
      end

      assert.equals(0, #instances)

      scope.cleanup_scope()
    end)

    it('handles switching between modes', function()
      set_buffer('foo "bar" baz')

      -- Start with BeamScope enabled
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = true, scoped_text_objects = { '"' } },
      })

      local result1 = operators.BeamYankSearchSetup('i"')
      assert.equals('', result1) -- BeamScope
      scope.cleanup_scope()

      -- Switch to BeamScope disabled
      beam.setup({
        prefix = ',',
        beam_scope = { enabled = false },
      })

      operators.BeamYankSearchSetup('i"')
      assert.is_not_nil(operators.BeamSearchOperatorPending) -- Native
    end)
  end)
end)
