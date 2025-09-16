describe('custom_motions', function()
  local custom_motions

  before_each(function()
    package.loaded['beam.custom_motions'] = nil
    custom_motions = require('beam.custom_motions')
  end)

  describe('is_custom()', function()
    it('should return true for URL motion (L)', function()
      assert.is_true(custom_motions.is_custom('L'))
    end)

    it('should return false for non-custom motions', function()
      assert.is_false(custom_motions.is_custom('w'))
      assert.is_false(custom_motions.is_custom('e'))
      assert.is_false(custom_motions.is_custom('b'))
      assert.is_false(custom_motions.is_custom('Q'))
      assert.is_false(custom_motions.is_custom('R'))
    end)

    it('should return false for nil', function()
      assert.is_false(custom_motions.is_custom(nil))
    end)

    it('should return false for empty string', function()
      assert.is_false(custom_motions.is_custom(''))
    end)
  end)

  describe('get()', function()
    it('should return definition for URL motion', function()
      local motion = custom_motions.get('L')
      assert.not_nil(motion)
      assert.equals('nvim-various-textobjs (pattern only)', motion.source)
      assert.equals('URL', motion.description)
      assert.equals('characterwise', motion.visual_mode)
      assert.equals('simple', motion.format_style)
      assert.is_function(motion.find)
      assert.is_function(motion.select)
      assert.is_function(motion.format)
    end)

    it('should return nil for non-custom motions', function()
      assert.is_nil(custom_motions.get('w'))
      assert.is_nil(custom_motions.get('unknown'))
      assert.is_nil(custom_motions.get(''))
      assert.is_nil(custom_motions.get(nil))
    end)
  end)

  describe('URL motion (L)', function()
    local function create_test_buffer(lines)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      return buf
    end

    describe('find_all()', function()
      it('should find single URL', function()
        local buf = create_test_buffer({
          'Check out https://github.com/user/repo for more info',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(1, #instances)
        assert.equals('https://github.com/user/repo', instances[1].preview)
        assert.equals(1, instances[1].start_line)
        assert.equals(1, instances[1].end_line)
        assert.equals(10, instances[1].start_col) -- 0-based indexing

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should find multiple URLs on same line', function()
        local buf = create_test_buffer({
          'Visit http://example.com and https://test.org today',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(2, #instances)
        assert.equals('http://example.com', instances[1].preview)
        assert.equals('https://test.org', instances[2].preview)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should find URLs across multiple lines', function()
        local buf = create_test_buffer({
          'First URL: https://first.com',
          'No URL here',
          'Second URL: http://second.net',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(2, #instances)
        assert.equals('https://first.com', instances[1].preview)
        assert.equals(1, instances[1].start_line)
        assert.equals('http://second.net', instances[2].preview)
        assert.equals(3, instances[2].start_line)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle various URL schemes', function()
        local buf = create_test_buffer({
          'http://example.com',
          'https://secure.site',
          'ftp://files.server.com',
          'ssh://git@github.com',
          'file:///home/user/file.txt',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(5, #instances)
        assert.equals('http://example.com', instances[1].preview)
        assert.equals('https://secure.site', instances[2].preview)
        assert.equals('ftp://files.server.com', instances[3].preview)
        assert.equals('ssh://git@github.com', instances[4].preview)
        assert.equals('file:///home/user/file.txt', instances[5].preview)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should stop URL at appropriate boundaries', function()
        local buf = create_test_buffer({
          '(https://url.in.parens)',
          '[https://url.in.brackets]',
          '{https://url.in.braces}',
          '"https://url.in.quotes"',
          "'https://url.in.single'",
          '`https://url.in.backticks`',
          '<https://url.in.angles>',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(7, #instances)
        -- The pattern correctly stops at these boundaries
        assert.equals('https://url.in.parens', instances[1].preview)
        assert.equals('https://url.in.brackets', instances[2].preview)
        assert.equals('https://url.in.braces', instances[3].preview)
        assert.equals('https://url.in.quotes', instances[4].preview)
        assert.equals('https://url.in.single', instances[5].preview)
        assert.equals('https://url.in.backticks', instances[6].preview)
        assert.equals('https://url.in.angles', instances[7].preview)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle URLs with paths and query strings', function()
        local buf = create_test_buffer({
          'https://example.com/path/to/page?query=value&param=123#anchor',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(1, #instances)
        assert.equals(
          'https://example.com/path/to/page?query=value&param=123#anchor',
          instances[1].preview
        )

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should return empty for buffer without URLs', function()
        local buf = create_test_buffer({
          'Just plain text here',
          'No URLs at all',
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(0, #instances)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should not match invalid URLs', function()
        local buf = create_test_buffer({
          'ht://invalid', -- Too short scheme
          'a://short', -- Too short scheme
          'http:/missing', -- Only one slash
          'http//missing', -- No colon
        })

        local instances = custom_motions.find_all('L', buf)
        assert.equals(0, #instances)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end)

    describe('select()', function()
      it('should select exact URL range', function()
        local instance = {
          start_line = 1,
          end_line = 1,
          start_col = 10,
          end_col = 25,
        }

        local bounds = custom_motions.select('L', instance, 'yank')
        assert.not_nil(bounds)
        assert.same({ 1, 10 }, bounds.start)
        assert.same({ 1, 25 }, bounds.end_)
      end)

      it('should work for all action types', function()
        local instance = {
          start_line = 5,
          end_line = 5,
          start_col = 0,
          end_col = 20,
        }

        local actions = { 'yank', 'delete', 'change', 'visual' }
        for _, action in ipairs(actions) do
          local bounds = custom_motions.select('L', instance, action)
          assert.not_nil(bounds, 'Failed for action: ' .. action)
          assert.same({ 5, 0 }, bounds.start)
          assert.same({ 5, 20 }, bounds.end_)
        end
      end)
    end)

    describe('format()', function()
      it('should format URL for display', function()
        local motion = custom_motions.get('L')
        local instance = {
          preview = 'https://github.com/user/repo',
          first_line = 'https://github.com/user/repo',
        }

        local lines = motion.format(instance)
        assert.equals(1, #lines)
        assert.equals('https://github.com/user/repo', lines[1])
      end)

      it('should handle missing preview', function()
        local motion = custom_motions.get('L')
        local instance = {
          first_line = 'http://example.com',
        }

        local lines = motion.format(instance)
        assert.equals(1, #lines)
        assert.equals('http://example.com', lines[1])
      end)

      it('should handle empty instance', function()
        local motion = custom_motions.get('L')
        local instance = {}

        local lines = motion.format(instance)
        assert.equals(1, #lines)
        assert.equals('', lines[1])
      end)
    end)
  end)

  describe('list()', function()
    it('should return all custom motions', function()
      local list = custom_motions.list()
      assert.not_nil(list)
      assert.equals(1, #list) -- Currently only URL motion

      local url_motion = list[1]
      assert.equals('L', url_motion.key)
      assert.equals('URL', url_motion.description)
      assert.not_nil(url_motion.source)
      assert.not_nil(url_motion.why)
    end)

    it('should include metadata for each motion', function()
      local list = custom_motions.list()
      for _, motion in ipairs(list) do
        assert.not_nil(motion.key)
        assert.not_nil(motion.description)
        assert.not_nil(motion.source)
        assert.not_nil(motion.why)
      end
    end)
  end)

  describe('edge cases', function()
    it('should handle empty buffer in find_all', function()
      local buf = vim.api.nvim_create_buf(false, true)
      local instances = custom_motions.find_all('L', buf)
      assert.equals(0, #instances)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should handle invalid motion key in find_all', function()
      local buf = vim.api.nvim_create_buf(false, true)
      local instances = custom_motions.find_all('invalid', buf)
      assert.equals(0, #instances)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should return nil for invalid motion in select', function()
      local instance = {
        start_line = 1,
        end_line = 1,
        start_col = 0,
        end_col = 10,
      }
      local bounds = custom_motions.select('invalid', instance, 'yank')
      assert.is_nil(bounds)
    end)

    it('should handle nil parameters gracefully', function()
      -- find_all with invalid key returns empty
      local buf = vim.api.nvim_create_buf(false, true)
      local instances = custom_motions.find_all(nil, buf)
      assert.equals(0, #instances)

      -- select with invalid key returns nil
      local instance = { start_line = 1, end_line = 1, start_col = 0, end_col = 10 }
      local bounds = custom_motions.select(nil, instance, 'yank')
      assert.is_nil(bounds)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
