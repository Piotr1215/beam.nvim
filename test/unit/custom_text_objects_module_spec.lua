describe('custom_text_objects module', function()
  local custom_text_objects

  before_each(function()
    package.loaded['beam.custom_text_objects'] = nil
    custom_text_objects = require('beam.custom_text_objects')
  end)

  describe('is_custom()', function()
    it('should return true for markdown code blocks (m)', function()
      assert.is_true(custom_text_objects.is_custom('m'))
    end)

    it('should return true for markdown headers (h)', function()
      assert.is_true(custom_text_objects.is_custom('h'))
    end)

    it('should return false for non-custom text objects', function()
      assert.is_false(custom_text_objects.is_custom('w'))
      assert.is_false(custom_text_objects.is_custom('p'))
      assert.is_false(custom_text_objects.is_custom('"'))
    end)

    it('should return false for nil', function()
      assert.is_false(custom_text_objects.is_custom(nil))
    end)
  end)

  describe('get()', function()
    it('should return definition for markdown code blocks', function()
      local obj = custom_text_objects.get('m')
      assert.not_nil(obj)
      assert.equals('beam.nvim', obj.source)
      assert.equals('markdown code block', obj.description)
      assert.equals('linewise', obj.visual_mode)
      assert.is_function(obj.find)
      assert.is_function(obj.select)
      assert.is_function(obj.format)
    end)

    it('should return definition for markdown headers', function()
      local obj = custom_text_objects.get('h')
      assert.not_nil(obj)
      assert.equals('beam.nvim', obj.source)
      assert.equals('markdown header', obj.description)
      assert.equals('linewise', obj.visual_mode)
      assert.is_function(obj.find)
      assert.is_function(obj.select)
      assert.is_function(obj.format)
    end)

    it('should return nil for non-custom text objects', function()
      assert.is_nil(custom_text_objects.get('w'))
      assert.is_nil(custom_text_objects.get('unknown'))
    end)
  end)

  describe('markdown code blocks (m)', function()
    local function create_test_buffer(lines)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      return buf
    end

    describe('find_all()', function()
      it('should find single code block', function()
        local buf = create_test_buffer({
          '# Header',
          '```lua',
          'local x = 1',
          '```',
          'Some text',
        })

        local instances = custom_text_objects.find_all('m', buf)
        assert.equals(1, #instances)
        assert.equals(2, instances[1].start_line)
        assert.equals(4, instances[1].end_line)
        assert.equals('local x = 1', instances[1].preview)
        assert.equals('lua', instances[1].language)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should find multiple code blocks', function()
        local buf = create_test_buffer({
          '```python',
          'print("hello")',
          '```',
          'Text',
          '```js',
          'console.log("world")',
          '```',
        })

        local instances = custom_text_objects.find_all('m', buf)
        assert.equals(2, #instances)

        assert.equals(1, instances[1].start_line)
        assert.equals(3, instances[1].end_line)
        assert.equals('python', instances[1].language)

        assert.equals(5, instances[2].start_line)
        assert.equals(7, instances[2].end_line)
        assert.equals('js', instances[2].language)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle empty code blocks', function()
        local buf = create_test_buffer({
          '```',
          '```',
        })

        local instances = custom_text_objects.find_all('m', buf)
        assert.equals(1, #instances)
        assert.equals('[empty code block]', instances[1].preview)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle code blocks without language', function()
        local buf = create_test_buffer({
          '```',
          'some code',
          '```',
        })

        local instances = custom_text_objects.find_all('m', buf)
        assert.equals(1, #instances)
        assert.equals('', instances[1].language)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should return empty for buffer without code blocks', function()
        local buf = create_test_buffer({
          '# Just text',
          'No code blocks here',
        })

        local instances = custom_text_objects.find_all('m', buf)
        assert.equals(0, #instances)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end)

    describe('select()', function()
      local instance = {
        start_line = 2,
        end_line = 5,
        start_col = 0,
        end_col = 3,
      }

      it('should select inner code block (i variant)', function()
        local bounds = custom_text_objects.select('m', instance, 'yank', 'i')
        assert.not_nil(bounds)
        assert.same({ 3, 0 }, bounds.start) -- Line after opening ```
        assert.same({ 4, 999 }, bounds.end_) -- Line before closing ```
      end)

      it('should select around code block (a variant)', function()
        local bounds = custom_text_objects.select('m', instance, 'yank', 'a')
        assert.not_nil(bounds)
        assert.same({ 2, 0 }, bounds.start) -- Including opening ```
        assert.same({ 5, 3 }, bounds.end_) -- Including closing ```
      end)
    end)

    describe('format()', function()
      it('should format code block with language', function()
        local obj = custom_text_objects.get('m')
        local instance = {
          language = 'lua',
          preview = 'local x = 1\nreturn x',
        }

        local lines = obj.format(instance)
        assert.equals('```lua', lines[1])
        assert.equals('local x = 1', lines[2])
        assert.equals('return x', lines[3])
        assert.equals('```', lines[4])
      end)

      it('should format code block without language', function()
        local obj = custom_text_objects.get('m')
        local instance = {
          language = '',
          preview = 'some text',
        }

        local lines = obj.format(instance)
        assert.equals('```', lines[1])
        assert.equals('some text', lines[2])
        assert.equals('```', lines[3])
      end)
    end)
  end)

  describe('markdown headers (h)', function()
    local function create_test_buffer(lines)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      return buf
    end

    describe('find_all()', function()
      it('should find single header', function()
        local buf = create_test_buffer({
          '# Header 1',
          'Content under header',
          'More content',
        })

        local instances = custom_text_objects.find_all('h', buf)
        assert.equals(1, #instances)
        assert.equals(1, instances[1].start_line)
        assert.equals(3, instances[1].end_line)
        assert.equals('# Header 1', instances[1].preview)
        assert.equals(1, instances[1].level)
        assert.is_true(instances[1].has_content)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should find multiple headers with hierarchy', function()
        local buf = create_test_buffer({
          '# Header 1',
          'Content 1',
          '## Header 2',
          'Content 2',
          '### Header 3',
          'Content 3',
        })

        local instances = custom_text_objects.find_all('h', buf)
        assert.equals(3, #instances)

        assert.equals(1, instances[1].level)
        assert.equals(1, instances[1].start_line)
        assert.equals(2, instances[1].end_line)

        assert.equals(2, instances[2].level)
        assert.equals(3, instances[2].start_line)
        assert.equals(4, instances[2].end_line)

        assert.equals(3, instances[3].level)
        assert.equals(5, instances[3].start_line)
        assert.equals(6, instances[3].end_line)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle headers without content', function()
        local buf = create_test_buffer({
          '# Header 1',
          '',
          '## Header 2',
        })

        local instances = custom_text_objects.find_all('h', buf)
        assert.equals(2, #instances)
        assert.is_false(instances[1].has_content)
        assert.is_false(instances[2].has_content)

        vim.api.nvim_buf_delete(buf, { force = true })
      end)

      it('should handle last header extending to end of file', function()
        local buf = create_test_buffer({
          '# Header',
          'Content',
          'More',
          'Lines',
        })

        local instances = custom_text_objects.find_all('h', buf)
        assert.equals(1, #instances)
        assert.equals(4, instances[1].end_line) -- Should extend to last line

        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end)

    describe('select()', function()
      it('should select inner header with content (i variant)', function()
        local instance = {
          start_line = 1,
          end_line = 5,
          content_start = 2,
          has_content = true,
        }

        local bounds = custom_text_objects.select('h', instance, 'yank', 'i')
        assert.not_nil(bounds)
        assert.same({ 2, 0 }, bounds.start) -- Content start
        assert.same({ 5, 999 }, bounds.end_) -- Content end
      end)

      it('should select header line when no content (i variant)', function()
        local instance = {
          start_line = 3,
          end_line = 3,
          content_start = 4,
          has_content = false,
        }

        local bounds = custom_text_objects.select('h', instance, 'yank', 'i')
        assert.not_nil(bounds)
        assert.same({ 3, 0 }, bounds.start) -- Just the header line
        assert.same({ 3, 999 }, bounds.end_)
      end)

      it('should select around header (a variant)', function()
        local instance = {
          start_line = 1,
          end_line = 5,
          content_start = 2,
          has_content = true,
        }

        local bounds = custom_text_objects.select('h', instance, 'yank', 'a')
        assert.not_nil(bounds)
        assert.same({ 1, 0 }, bounds.start) -- Including header
        assert.same({ 5, 999 }, bounds.end_) -- Including all content
      end)
    end)

    describe('format()', function()
      it('should format header for display', function()
        local obj = custom_text_objects.get('h')
        local instance = {
          preview = '## Section Title',
          first_line = '## Section Title',
        }

        local lines = obj.format(instance)
        assert.equals(1, #lines)
        assert.equals('## Section Title', lines[1])
      end)

      it('should handle missing preview', function()
        local obj = custom_text_objects.get('h')
        local instance = {
          first_line = '# Title',
        }

        local lines = obj.format(instance)
        assert.equals(1, #lines)
        assert.equals('# Title', lines[1])
      end)
    end)
  end)

  describe('edge cases', function()
    it('should handle nil buffer in find_all', function()
      -- Create a valid buffer for testing
      local buf = vim.api.nvim_create_buf(false, true)
      local instances = custom_text_objects.find_all('m', buf)
      -- Empty buffer should return empty
      assert.equals(0, #instances)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should handle invalid text object key in find_all', function()
      local buf = vim.api.nvim_create_buf(false, true)
      local instances = custom_text_objects.find_all('invalid', buf)
      assert.equals(0, #instances)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should return nil for invalid text object in select', function()
      local instance = {
        start_line = 1,
        end_line = 3,
        start_col = 0,
        end_col = 10,
      }
      local bounds = custom_text_objects.select('invalid', instance, 'yank', 'i')
      assert.is_nil(bounds)
    end)
  end)
end)
