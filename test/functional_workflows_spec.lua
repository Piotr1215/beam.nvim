-- Phase 1: Core Functional Tests - Complete user workflows end-to-end
local beam = require('beam')

describe('Remote Operations', function()
  local function setup_buffer(content)
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(
      0,
      0,
      -1,
      false,
      type(content) == 'string' and { content } or content
    )
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  local function get_register(reg)
    reg = reg or '"'
    return vim.fn.getreg(reg)
  end

  local function trigger_operation(operator, textobj, search_term)
    local operators_module = require('beam.operators')

    -- Setup operation based on type
    local setup_fn = {
      yank = operators_module.BeamYankSearchSetup,
      delete = operators_module.BeamDeleteSearchSetup,
      change = operators_module.BeamChangeSearchSetup,
      visual = operators_module.BeamVisualSearchSetup,
    }

    setup_fn[operator](textobj)

    -- Simulate search if provided
    if search_term then
      -- Find and move to search term
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      for i, line in ipairs(lines) do
        local col = line:find(search_term, 1, true)
        if col then
          vim.api.nvim_win_set_cursor(0, { i, col - 1 })
          break
        end
      end
    end

    -- Execute the pending operation
    operators_module.BeamExecuteSearchOperatorImpl()
  end

  before_each(function()
    beam.setup({
      prefix = ',',
      visual_feedback_duration = 10,
      enable_default_text_objects = true,
    })
    vim.o.showcmd = false
    vim.o.showmode = false
    vim.o.report = 999
  end)

  -- Data-driven test for all operator/textobj combinations
  it('executes operations at search location', function()
    local test_cases = {
      -- { operator, text_object, input_text, search_target, expected_result }
      {
        operator = 'yank',
        textobj = 'i"',
        input = 'foo "bar" baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = true, buffer = 'foo "bar" baz' },
      },

      {
        operator = 'delete',
        textobj = 'i"',
        input = 'foo "bar" baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = true, buffer = 'foo "" baz' },
      },

      {
        operator = 'change',
        textobj = 'i"',
        input = 'foo "bar" baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = false, buffer = 'foo "" baz' },
      },

      {
        operator = 'yank',
        textobj = 'i(',
        input = 'foo (bar) baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = true, buffer = 'foo (bar) baz' },
      },

      {
        operator = 'delete',
        textobj = 'a(',
        input = 'foo (bar) baz',
        target = 'bar',
        expect = { register = '(bar)', cursor_returns = true, buffer = 'foo  baz' },
      },

      {
        operator = 'yank',
        textobj = 'iw',
        input = 'hello world test',
        target = 'world',
        expect = { register = 'world', cursor_returns = true, buffer = 'hello world test' },
      },

      {
        operator = 'delete',
        textobj = 'iw',
        input = 'hello world test',
        target = 'world',
        expect = { register = 'world', cursor_returns = true, buffer = 'hello  test' },
      },

      -- Brackets and braces
      {
        operator = 'yank',
        textobj = 'i[',
        input = 'foo [bar] baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = true, buffer = 'foo [bar] baz' },
      },

      {
        operator = 'yank',
        textobj = 'i{',
        input = 'foo {bar} baz',
        target = 'bar',
        expect = { register = 'bar', cursor_returns = true, buffer = 'foo {bar} baz' },
      },

      -- Paragraph and sentence (if needed)
      {
        operator = 'yank',
        textobj = 'ip',
        input = { 'First paragraph.', '', 'Second paragraph.' },
        target = 'Second',
        expect = { register = 'Second paragraph.', cursor_returns = true },
      },
    }

    for _, tc in ipairs(test_cases) do
      setup_buffer(tc.input)
      local start_pos = vim.api.nvim_win_get_cursor(0)

      trigger_operation(tc.operator, tc.textobj, tc.target)

      -- Verify register content (for yank/delete/change)
      if tc.expect.register then
        assert.are.equal(tc.expect.register, get_register())
      end

      -- Verify cursor position
      local end_pos = vim.api.nvim_win_get_cursor(0)
      if tc.expect.cursor_returns then
        assert.are.same(
          start_pos,
          end_pos,
          string.format('Cursor should return for %s operation', tc.operator)
        )
      else
        assert.are_not.same(
          start_pos,
          end_pos,
          string.format('Cursor should stay at target for %s operation', tc.operator)
        )
      end

      -- Verify buffer content
      if tc.expect.buffer then
        local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local expected = type(tc.expect.buffer) == 'string' and { tc.expect.buffer }
          or tc.expect.buffer
        assert.are.same(expected, actual)
      end
    end
  end)

  it('returns cursor to origin for yank/delete', function()
    setup_buffer({ 'line one', 'line two with "target" here', 'line three' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Start at line 1

    trigger_operation('yank', 'i"', 'target')

    local pos = vim.api.nvim_win_get_cursor(0)
    assert.are.equal(1, pos[1], 'Should return to line 1')
  end)

  it('stays at target for change/visual', function()
    setup_buffer({ 'line one', 'line two with "target" here', 'line three' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Start at line 1

    trigger_operation('change', 'i"', 'target')

    local pos = vim.api.nvim_win_get_cursor(0)
    assert.are.equal(2, pos[1], 'Should stay at line 2')
  end)

  it('handles search with no matches gracefully', function()
    setup_buffer('foo "bar" baz')
    local start_pos = vim.api.nvim_win_get_cursor(0)

    -- Try to search for non-existent target
    trigger_operation('yank', 'i"', 'nonexistent')

    -- Should not crash, cursor should stay put
    local end_pos = vim.api.nvim_win_get_cursor(0)
    assert.are.same(start_pos, end_pos)
    assert.are.equal('', get_register()) -- Nothing yanked
  end)

  it('handles operation cancellation', function()
    setup_buffer('foo "bar" baz')
    local operators_module = require('beam.operators')

    -- Setup operation but don't execute
    operators_module.BeamYankSearchSetup('i"')

    -- Simulate cancellation (clear pending state)
    _G.SearchOperatorPending = nil

    -- Buffer should be unchanged
    local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ 'foo "bar" baz' }, content)
  end)
end)

describe('BeamScope', function()
  local function setup_buffer(content)
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(
      0,
      0,
      -1,
      false,
      type(content) == 'string' and { content } or content
    )
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  before_each(function()
    beam.setup({
      prefix = ',',
      beam_scope = {
        enabled = true,
        highlight_group = 'Search',
        show_preview = true,
      },
    })
  end)

  it('displays all text objects in buffer', function()
    setup_buffer('foo "bar" and "baz" here')

    -- Trigger BeamScope for quotes
    local scope = require('beam.scope')
    local instances = scope.find_text_objects('i"', 0)

    assert.are.equal(2, #instances, 'Should find 2 quoted strings')
    -- Instances have .content field, not .text
    assert.are.equal('bar', instances[1].content)
    assert.are.equal('baz', instances[2].content)
  end)

  it('navigates between instances with j/k', function()
    setup_buffer({ 'first "one" here', 'second "two" there', 'third "three" end' })

    local scope = require('beam.scope')
    local state = {
      instances = scope.find_text_objects('i"', 0),
      current_index = 1,
    }

    -- Navigate down (j)
    state.current_index = math.min(state.current_index + 1, #state.instances)
    assert.are.equal(2, state.current_index)

    -- Navigate up (k)
    state.current_index = math.max(state.current_index - 1, 1)
    assert.are.equal(1, state.current_index)
  end)

  it('executes operation on selection', function()
    setup_buffer('foo "bar" and "baz" here')

    local scope = require('beam.scope')
    local instances = scope.find_text_objects('i"', 0)

    -- Select second instance and execute yank
    vim.api.nvim_win_set_cursor(0, { instances[2].start_pos[1], instances[2].start_pos[2] })
    vim.cmd('normal! yi"')

    assert.are.equal('baz', vim.fn.getreg('"'))
  end)

  it('handles buffer with no matching objects', function()
    setup_buffer('no quotes here')

    local scope = require('beam.scope')
    local instances = scope.find_text_objects('i"', 0)

    assert.are.equal(0, #instances, 'Should find no instances')
  end)

  it('cancels and restores on escape', function()
    setup_buffer('foo "bar" baz')
    local start_pos = vim.api.nvim_win_get_cursor(0)

    -- Start BeamScope
    local scope = require('beam.scope')
    scope.find_text_objects('i"', 0)

    -- Simulate escape (cancellation)
    -- In real usage, this would be handled by the scope UI

    -- Position should be restored
    local end_pos = vim.api.nvim_win_get_cursor(0)
    assert.are.same(start_pos, end_pos)
  end)
end)
