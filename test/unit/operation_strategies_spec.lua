describe('beam.operation_strategies', function()
  local strategies

  before_each(function()
    strategies = require('beam.operation_strategies')
  end)

  describe('Strategy registry', function()
    it('should have all standard operations', function()
      assert.is_not_nil(strategies.strategies.yank)
      assert.is_not_nil(strategies.strategies.delete)
      assert.is_not_nil(strategies.strategies.change)
      assert.is_not_nil(strategies.strategies.visual)
    end)

    it('should have line operations', function()
      assert.is_not_nil(strategies.strategies.yankline)
      assert.is_not_nil(strategies.strategies.deleteline)
      assert.is_not_nil(strategies.strategies.changeline)
      assert.is_not_nil(strategies.strategies.visualline)
    end)
  end)

  describe('Strategy properties', function()
    it('yank should return to origin', function()
      assert.is_true(strategies.should_return_to_origin('yank'))
      assert.is_true(strategies.should_return_to_origin('yankline'))
    end)

    it('delete should return to origin', function()
      assert.is_true(strategies.should_return_to_origin('delete'))
      assert.is_true(strategies.should_return_to_origin('deleteline'))
    end)

    it('change should not return to origin', function()
      assert.is_false(strategies.should_return_to_origin('change'))
      assert.is_false(strategies.should_return_to_origin('changeline'))
    end)

    it('visual should not return to origin', function()
      assert.is_false(strategies.should_return_to_origin('visual'))
      assert.is_false(strategies.should_return_to_origin('visualline'))
    end)
  end)

  describe('Highlight clearing', function()
    it('should clear highlight for yank and delete', function()
      assert.is_true(strategies.should_clear_highlight('yank'))
      assert.is_true(strategies.should_clear_highlight('delete'))
      assert.is_true(strategies.should_clear_highlight('yankline'))
      assert.is_true(strategies.should_clear_highlight('deleteline'))
    end)

    it('should not clear highlight for change and visual', function()
      assert.is_false(strategies.should_clear_highlight('change'))
      assert.is_false(strategies.should_clear_highlight('visual'))
      assert.is_false(strategies.should_clear_highlight('changeline'))
      assert.is_false(strategies.should_clear_highlight('visualline'))
    end)
  end)

  describe('Text objects from mappings', function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'foo max bar' })
      -- A plugin-only text object, like mini.ai's
      vim.keymap.set('x', 'iz', 'iw', { buffer = buf })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })
    end)

    after_each(function()
      vim.cmd('stopinsert')
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('change runs a mapped text object', function()
      strategies.strategies.change.execute('iz', 0)
      assert.same({ 'foo  bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it('change still runs a built-in text object', function()
      strategies.strategies.change.execute('iw', 0)
      assert.same({ 'foo  bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it('change leaves the text when the text object finds nothing', function()
      assert.is_false(strategies.strategies.change.execute('i(', 0))
      assert.same({ 'foo max bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      assert.equals('n', vim.fn.mode())
    end)

    it('delete leaves the text when the text object finds nothing', function()
      assert.is_false(strategies.strategies.delete.execute('i(', 1))
      assert.same({ 'foo max bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it('visual leaves Visual mode when the text object finds nothing', function()
      assert.is_false(strategies.strategies.visual.execute('i(', 0))
      assert.equals('n', vim.fn.mode())
    end)

    it('a mapping that cancels the selection counts as nothing found', function()
      vim.keymap.set('x', 'iq', '<Esc>', { buffer = buf })
      assert.is_false(strategies.strategies.change.execute('iq', 0))
      assert.same({ 'foo max bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it('execute_operation reports a text object that finds nothing', function()
      local operators = require('beam.operators')
      assert.is_false(operators.execute_operation({ action = 'change', textobj = 'i(' }))
      assert.is_true(operators.execute_operation({ action = 'change', textobj = 'iz' }))
    end)

    it('delete runs a mapped text object', function()
      strategies.strategies.delete.execute('iz', 1)
      assert.same({ 'foo  bar' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)
  end)

  describe('Markdown codeblock handling', function()
    it('should find codeblock boundaries', function()
      -- This would need a mock buffer to test properly
      -- Just testing the function exists
      assert.is_function(strategies.find_markdown_codeblock_bounds)
    end)

    it('should handle codeblock operations', function()
      assert.is_function(strategies.handle_markdown_codeblock)
      assert.is_function(strategies.execute_codeblock_action)
    end)
  end)
end)
