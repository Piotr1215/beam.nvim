-- Cross-buffer operation tests using real Plenary busted
describe('beam.nvim cross-buffer operations', function()
  local beam, operators
  local buf1, buf2, buf3

  before_each(function()
    -- Clear state
    package.loaded['beam'] = nil
    package.loaded['beam.operators'] = nil
    package.loaded['beam.config'] = nil

    beam = require('beam')
    operators = require('beam.operators')

    -- Enable test mode for synchronous execution
    vim.g.beam_test_mode = true

    -- Create test buffers
    buf1 = vim.api.nvim_get_current_buf()
    buf2 = vim.api.nvim_create_buf(true, false) -- listed buffer
    buf3 = vim.api.nvim_create_buf(true, false) -- listed buffer
  end)

  after_each(function()
    -- Clean up test mode
    vim.g.beam_test_mode = false

    -- Clean up buffers
    for _, buf in ipairs({ buf2, buf3 }) do
      if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  local function set_buffer(buf, text)
    vim.api.nvim_set_current_buf(buf)
    local lines = type(text) == 'string' and { text } or text
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  describe('with cross_buffer = true', function()
    before_each(function()
      beam.setup({ prefix = ',', cross_buffer = true })
    end)

    it('finds matches in other buffers', function()
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'buffer two "target text" more' })
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'buffer one content' })
      vim.api.nvim_set_current_buf(buf1)

      -- Test that cross-buffer search can find text in buf2
      local found = false
      for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if buf.bufnr == buf2 then
          vim.api.nvim_set_current_buf(buf2)
          found = vim.fn.search('target', 'c') > 0
          break
        end
      end

      assert.is_true(found, 'Should find match in other buffer')
    end)

    it('enables cross-buffer config option', function()
      local config = beam.get_config()
      assert.is_true(config.cross_buffer)
    end)

    it('yanks from another buffer and returns', function()
      -- Clear register first to ensure clean state
      vim.fn.setreg('"', '')

      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'buffer one' })
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'text "yank this" more' })
      vim.api.nvim_set_current_buf(buf1)

      local start_buf = vim.api.nvim_get_current_buf()
      local start_pos = vim.fn.getpos('.')

      -- Setup yank operation
      operators.BeamSearchOperatorPending = {
        action = 'yank',
        textobj = 'i"',
        saved_pos_for_yank = start_pos,
        saved_buf = start_buf,
      }

      vim.fn.setreg('/', 'yank this')
      operators.BeamExecuteSearchOperator()

      -- Should have yanked the text
      assert.equals('yank this', vim.fn.getreg('"'))
      -- Should return to original buffer
      assert.equals(start_buf, vim.api.nvim_get_current_buf())
    end)

    it('handles change operation staying in target buffer', function()
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'start buffer' })
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'change "this text" here' })
      vim.api.nvim_set_current_buf(buf1)

      local start_buf = vim.api.nvim_get_current_buf()

      -- Setup change operation
      operators.BeamSearchOperatorPending = {
        action = 'change',
        textobj = 'i"',
        saved_pos_for_yank = nil,
        saved_buf = nil,
      }

      vim.fn.setreg('/', 'this text')
      operators.BeamExecuteSearchOperator()

      -- Should stay in target buffer for change
      assert.are_not.equals(start_buf, vim.api.nvim_get_current_buf())
    end)

    it('handles pattern not found gracefully', function()
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'buffer one' })
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'buffer two' })
      vim.api.nvim_set_current_buf(buf1)

      local start_buf = vim.api.nvim_get_current_buf()

      operators.BeamSearchOperatorPending = {
        action = 'yank',
        textobj = 'iw',
        saved_pos_for_yank = vim.fn.getpos('.'),
        saved_buf = start_buf,
      }

      vim.fn.setreg('/', 'nonexistent_pattern')
      operators.BeamExecuteSearchOperator()

      -- Should stay in original buffer
      assert.equals(start_buf, vim.api.nvim_get_current_buf())
      -- Pending operation should be cleared
      assert.are.same({}, operators.BeamSearchOperatorPending)
    end)

    it('ignores unlisted buffers', function()
      local unlisted_buf = vim.api.nvim_create_buf(false, false) -- unlisted
      vim.api.nvim_buf_set_lines(unlisted_buf, 0, -1, false, { 'unlisted "secret" content' })
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'normal buffer' })
      vim.api.nvim_set_current_buf(buf1)

      local start_buf = vim.api.nvim_get_current_buf()

      -- Clear register first
      vim.fn.setreg('"', '')

      operators.BeamSearchOperatorPending = {
        action = 'yank',
        textobj = 'i"',
        saved_pos_for_yank = vim.fn.getpos('.'),
        saved_buf = start_buf,
      }

      vim.fn.setreg('/', 'secret')
      operators.BeamExecuteSearchOperator()

      -- Should not find pattern in unlisted buffer
      assert.equals('', vim.fn.getreg('"'))
      assert.equals(start_buf, vim.api.nvim_get_current_buf())

      -- Cleanup
      if vim.api.nvim_buf_is_valid(unlisted_buf) then
        vim.api.nvim_buf_delete(unlisted_buf, { force = true })
      end
    end)
  end)

  describe('with cross_buffer = false', function()
    before_each(function()
      beam.setup({ prefix = ',', cross_buffer = false })
    end)

    it('restricts operations to current buffer', function()
      set_buffer(buf2, 'other buffer "content"')
      set_buffer(buf1, 'current buffer')

      operators.BeamYankSearchSetup('i"')
      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.is_false(operators.BeamSearchOperatorPending.cross_buffer or false)
    end)

    it('does not search other buffers', function()
      vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { 'current buffer' })
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { 'other "target" buffer' })
      vim.api.nvim_set_current_buf(buf1)
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Position at start

      local start_buf = vim.api.nvim_get_current_buf()

      -- Clear register first
      vim.fn.setreg('"', '')

      operators.BeamSearchOperatorPending = {
        action = 'yank',
        textobj = 'i"',
        saved_pos_for_yank = vim.fn.getpos('.'),
        saved_buf = start_buf,
      }

      vim.fn.setreg('/', 'target')
      operators.BeamExecuteSearchOperator()

      -- Should not find or yank anything
      assert.equals('', vim.fn.getreg('"'))
      assert.equals(start_buf, vim.api.nvim_get_current_buf())
    end)
  end)

  describe('with cross_buffer unset (default)', function()
    it('defaults to false', function()
      beam.setup({ prefix = ',' })

      operators.BeamYankSearchSetup('i"')
      assert.is_not_nil(operators.BeamSearchOperatorPending)
      assert.is_false(operators.BeamSearchOperatorPending.cross_buffer or false)
    end)
  end)
end)
