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
