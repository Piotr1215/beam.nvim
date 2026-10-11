-- Tests for every-match operations through native multicursor (:help zq)

local function reload()
  for _, m in ipairs({
    'beam',
    'beam.config',
    'beam.config_validator',
    'beam.mappings',
    'beam.multicursor',
    'beam.operators',
  }) do
    package.loaded[m] = nil
  end
end

describe('beam.multicursor', function()
  before_each(reload)

  describe('available()', function()
    it('is false before Neovim 0.13', function()
      local multicursor = require('beam.multicursor')
      local has = vim.fn.has
      vim.fn.has = function(feature)
        if feature == 'nvim-0.13' then
          return 0
        end
        return has(feature)
      end
      multicursor.reset()
      local ok = multicursor.available()
      vim.fn.has = has
      multicursor.reset()
      assert.is_false(ok)
    end)

    it('agrees with whether zq places cursors', function()
      local multicursor = require('beam.multicursor')
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'x x' })
      vim.fn.setreg('/', 'x')
      pcall(vim.cmd, 'silent! normal! gg0zqgn')
      local placed = multicursor.count(buf) > 0
      multicursor.clear(buf)
      vim.cmd('silent! normal! \27')

      multicursor.reset()
      assert.equals(vim.fn.has('nvim-0.13') == 1 and placed, multicursor.available())
    end)

    it('keeps the search register', function()
      local multicursor = require('beam.multicursor')
      vim.fn.setreg('/', 'keepme')
      multicursor.reset()
      multicursor.available()
      assert.equals('keepme', vim.fn.getreg('/'))
    end)
  end)

  describe('is_native_text_object()', function()
    it('knows Neovim text objects', function()
      local multicursor = require('beam.multicursor')
      for _, obj in ipairs({ 'iw', 'aW', 'ip', 'i"', "a'", 'i`', 'i(', 'a]', 'iB', 'i<', 'at' }) do
        assert.is_true(multicursor.is_native_text_object(obj), obj)
      end
    end)

    it('treats plugin text objects as mappings', function()
      local multicursor = require('beam.multicursor')
      for _, obj in ipairs({ 'ia', 'if', 'im', 'iq', 'w', '' }) do
        assert.is_false(multicursor.is_native_text_object(obj), obj)
      end
    end)
  end)

  describe('scope.select_instances()', function()
    -- HERE = os.path.dirname(os.path.abspath(__file__))
    -- FULL = os.path.join(HERE, "sim-state.json")
    -- VIEW = os.path.join(HERE, "world-state.json")
    local outer = { start_line = 1, start_col = 23, end_line = 1, end_col = 47 }
    local inner = { start_line = 1, start_col = 39, end_line = 1, end_col = 46 }
    local join1 = { start_line = 2, start_col = 20, end_line = 2, end_col = 41 }
    local join2 = { start_line = 3, start_col = 20, end_line = 3, end_col = 43 }
    local instances = { outer, inner, join1, join2 }
    local line_to_instance = { 1, 2, 3, 4 }
    local list
    local saved_ic, saved_scs

    before_each(function()
      list = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(list, 0, -1, false, {
        '(os.path.abspath(__file__))',
        '(__file__)',
        '(HERE, "sim-state.json")',
        '(HERE, "world-state.json")',
      })
      saved_ic, saved_scs = vim.o.ignorecase, vim.o.smartcase
    end)

    after_each(function()
      vim.o.ignorecase, vim.o.smartcase = saved_ic, saved_scs
      vim.api.nvim_buf_delete(list, { force = true })
    end)

    local function select(pattern)
      return require('beam.scope').select_instances(instances, line_to_instance, list, pattern)
    end

    it('keeps the instances whose listed text matches', function()
      assert.same({ join1, join2 }, select('HERE'))
    end)

    it('takes every instance without a pattern, inner one of a nested pair', function()
      assert.same({ inner, join1, join2 }, select(nil))
    end)

    it('keeps only the inner instance when both nested ones match', function()
      assert.same({ inner }, select('file'))
    end)

    it('returns nothing when no instance matches', function()
      assert.same({}, select('nothing'))
    end)

    it('matches lines of multi-line contents the list does not show', function()
      local call = {
        start_line = 5,
        start_col = 5,
        end_line = 7,
        end_col = 5,
        first_line = 'one,',
        preview = 'one,\n  HERE\n',
      }
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '(one,)' })
      local chosen = require('beam.scope').select_instances({ call }, { 1 }, buf, 'HERE')
      vim.api.nvim_buf_delete(buf, { force = true })
      assert.same({ call }, chosen)
    end)

    it('follows ignorecase and smartcase like a typed search', function()
      vim.o.ignorecase, vim.o.smartcase = true, true
      assert.same({ join1, join2 }, select('here'))
      assert.same({}, select('Here'))
    end)
  end)

  describe('config', function()
    it('defaults multi_key to q', function()
      assert.equals('q', require('beam.config').defaults.multi_key)
    end)

    it('rejects a multi_key longer than one character', function()
      local cfg = vim.deepcopy(require('beam.config').defaults)
      cfg.multi_key = 'qq'
      local ok, err = require('beam.config_validator').validate(cfg)
      assert.is_false(ok)
      assert.matches('multi_key', err)
    end)

    it('accepts false to turn multi_key off', function()
      local cfg = vim.deepcopy(require('beam.config').defaults)
      cfg.multi_key = false
      assert.is_true((require('beam.config_validator').validate(cfg)))
    end)
  end)

  describe('mappings', function()
    local function setup_with(available, opts)
      for _, lhs in ipairs({ ',qyi"', ',qD', ',xyi"' }) do
        pcall(vim.keymap.del, 'n', lhs)
      end
      reload()
      package.loaded['beam.multicursor'] = {
        available = function()
          return available
        end,
      }
      require('beam').setup(opts or { prefix = ',' })
    end

    after_each(function()
      package.loaded['beam.multicursor'] = nil
    end)

    it('creates <prefix>q mappings when zq is available', function()
      setup_with(true)
      assert.not_equals('', vim.fn.maparg(',qyi"', 'n'))
      assert.not_equals('', vim.fn.maparg(',qD', 'n'))
    end)

    it('creates none when zq is missing', function()
      setup_with(false)
      assert.equals('', vim.fn.maparg(',qyi"', 'n'))
      assert.equals('', vim.fn.maparg(',qD', 'n'))
    end)

    it('creates none when multi_key is false', function()
      setup_with(true, { prefix = ',', multi_key = false })
      assert.equals('', vim.fn.maparg(',qyi"', 'n'))
    end)

    it('uses a custom multi_key', function()
      setup_with(true, { prefix = ',', multi_key = 'x' })
      assert.not_equals('', vim.fn.maparg(',xyi"', 'n'))
      assert.equals('', vim.fn.maparg(',qyi"', 'n'))
    end)
  end)

  -- The cascade only replays typed input, so these drive an embedded Neovim
  -- with nvim_input, the way keys arrive from a user.
  describe('every match (embedded Neovim)', function()
    local child
    local has_zq = false
    local lines = { 'log("error: disk")', 'log("ok")', 'warn("error: net")', 'log("error: cpu")' }

    local function req(...)
      return vim.rpcrequest(child, ...)
    end

    local function wait_for(cond)
      return vim.wait(3000, cond, 20)
    end

    local function buffer()
      return req('nvim_buf_get_lines', 0, 0, -1, false)
    end

    ---Type a beam mapping, wait for its search prompt, then type the pattern
    local function beam(lhs, pattern)
      req('nvim_input', lhs)
      assert.is_true(wait_for(function()
        return req('nvim_get_mode').mode == 'c'
      end))
      req('nvim_input', pattern .. '<CR>')
    end

    before_each(function()
      child = vim.fn.jobstart(
        { vim.v.progpath, '--embed', '--headless', '--clean', '-n' },
        { rpc = true }
      )
      has_zq = req(
        'nvim_exec_lua',
        [[
        vim.opt.rtp:prepend(...)
        vim.cmd('runtime plugin/beam.lua')
        require('beam').setup({ prefix = ',', visual_feedback_duration = 0, beam_scope = { enabled = false } })
        return require('beam.multicursor').available()
      ]],
        { vim.fn.getcwd() }
      )
      req('nvim_buf_set_lines', 0, 0, -1, false, lines)
      req('nvim_win_set_cursor', 0, { 2, 0 })
    end)

    after_each(function()
      vim.fn.jobstop(child)
    end)

    local function cursors()
      return req('nvim_exec_lua', "return require('beam.multicursor').count()", {})
    end

    it('yanks at every match, joins the yanks and returns to the origin', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      beam(',qyi"', 'error')
      local joined = 'error: disk\nerror: net\nerror: cpu\n'
      assert.is_true(wait_for(function()
        return req('nvim_call_function', 'getreg', { '"' }) == joined
      end))
      assert.is_true(wait_for(function()
        return cursors() == 0
      end))
      assert.same({ 2, 0 }, req('nvim_win_get_cursor', 0))
      assert.same(lines, buffer())
    end)

    it('deletes at every match and returns to the origin', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      beam(',qdi"', 'error')
      local expected = { 'log("")', 'log("ok")', 'warn("")', 'log("")' }
      assert.is_true(wait_for(function()
        return vim.deep_equal(buffer(), expected)
      end))
      assert.is_true(wait_for(function()
        return cursors() == 0
      end))
      assert.same({ 2, 0 }, req('nvim_win_get_cursor', 0))
    end)

    it('changes at every match and keeps the cursors', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      beam(',qci"', 'error')
      assert.is_true(wait_for(function()
        return req('nvim_get_mode').mode == 'i'
      end))
      req('nvim_input', 'X<Esc>')
      local expected = { 'log("X")', 'log("ok")', 'warn("X")', 'log("X")' }
      assert.is_true(wait_for(function()
        return vim.deep_equal(buffer(), expected)
      end))
      assert.equals(3, cursors())
    end)

    it('deletes every matching line, adjacent ones included', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      req('nvim_win_set_cursor', 0, { 3, 0 })
      beam(',qD', '^log')
      assert.is_true(wait_for(function()
        return vim.deep_equal(buffer(), { 'warn("error: net")' })
      end))
      assert.same({ 1, 0 }, req('nvim_win_get_cursor', 0))
    end)

    it('uses the native text object when a plugin remaps it', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      -- Like mini.ai taking over i": a remap here would select the word instead
      req('nvim_exec_lua', [[vim.keymap.set('x', 'i"', 'iw')]], {})
      beam(',qci"', 'error')
      assert.is_true(wait_for(function()
        return req('nvim_get_mode').mode == 'i'
      end))
      req('nvim_input', 'X<Esc>')
      local expected = { 'log("X")', 'log("ok")', 'warn("X")', 'log("X")' }
      assert.is_true(wait_for(function()
        return vim.deep_equal(buffer(), expected)
      end))
    end)

    describe('scoped objects go through BeamScope', function()
      local scoped = {
        'HERE = os.path.dirname(os.path.abspath(__file__))',
        'FULL = os.path.join(HERE, "sim-state.json")',
        'VIEW = os.path.join(HERE, "world-state.json")',
      }

      before_each(function()
        req(
          'nvim_exec_lua',
          [[require('beam').setup({ prefix = ',', visual_feedback_duration = 0 })]],
          {}
        )
        req('nvim_buf_set_lines', 0, 0, -1, false, scoped)
        req('nvim_win_set_cursor', 0, { 2, 0 })
      end)

      ---Type a beam mapping, wait for the BeamScope list, then type keys in it
      local function scope(lhs, keys)
        req('nvim_input', lhs)
        assert.is_true(wait_for(function()
          return req('nvim_buf_get_name', 0):match('BeamScope') ~= nil
        end))
        req('nvim_input', keys)
      end

      it('changes only the instances the list filter matches', function()
        if not has_zq then
          return pending('needs Neovim with zq')
        end
        scope(',qci(', '/HERE<CR>')
        assert.is_true(wait_for(function()
          return req('nvim_get_mode').mode == 'i'
        end))
        req('nvim_input', 'X<Esc>')
        local expected = {
          'HERE = os.path.dirname(os.path.abspath(__file__))',
          'FULL = os.path.join(X)',
          'VIEW = os.path.join(X)',
        }
        assert.is_true(wait_for(function()
          return vim.deep_equal(buffer(), expected)
        end))
      end)

      it('yanks every instance on Enter and returns to the origin', function()
        if not has_zq then
          return pending('needs Neovim with zq')
        end
        scope(',qyi(', '<CR>')
        local joined = '__file__\nHERE, "sim-state.json"\nHERE, "world-state.json"\n'
        assert.is_true(wait_for(function()
          return req('nvim_call_function', 'getreg', { '"' }) == joined
        end))
        assert.is_true(wait_for(function()
          return cursors() == 0
        end))
        assert.same({ 2, 0 }, req('nvim_win_get_cursor', 0))
        assert.same(scoped, buffer())
      end)

      it('finds a match past the first line of a multi-line pair', function()
        if not has_zq then
          return pending('needs Neovim with zq')
        end
        req(
          'nvim_buf_set_lines',
          0,
          0,
          -1,
          false,
          { 'call(', '  one,', '  HERE', ')', 'other(two)' }
        )
        req('nvim_win_set_cursor', 0, { 5, 0 })
        scope(',qyi(', '/HERE<CR>')
        assert.is_true(wait_for(function()
          return req('nvim_call_function', 'getreg', { '"' }):match('HERE') ~= nil
        end))
        local yanked = req('nvim_call_function', 'getreg', { '"' })
        assert.is_nil(yanked:match('two'))
        assert.truthy(yanked:match('one,'))
      end)

      it('changes nothing when the filter matches no instance', function()
        if not has_zq then
          return pending('needs Neovim with zq')
        end
        scope(',qci(', '/nothing<CR>')
        assert.is_true(wait_for(function()
          return req('nvim_buf_get_name', 0):match('BeamScope') == nil
        end))
        assert.same(scoped, buffer())
        assert.equals(0, cursors())
      end)
    end)

    it('does nothing without a match', function()
      if not has_zq then
        return pending('needs Neovim with zq')
      end
      beam(',qyi"', 'nomatch')
      assert.is_true(wait_for(function()
        return req('nvim_get_mode').mode == 'n'
      end))
      assert.same(lines, buffer())
      assert.equals(0, cursors())
      assert.same({ 2, 0 }, req('nvim_win_get_cursor', 0))
    end)
  end)
end)
