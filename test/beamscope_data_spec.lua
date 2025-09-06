describe('BeamScope data-driven tests', function()
  local scope = require('beam.scope')
  local config = require('beam.config')

  before_each(function()
    -- Reset state and enable BeamScope
    scope.cleanup_scope()
    config.current.beam_scope = {
      enabled = true,
      scoped_text_objects = { '"', "'", '`', '(', ')', '[', ']', '{', '}', '<', '>', 'b', 'B', 't' },
      custom_scoped_text_objects = { 'm' },
    }
  end)

  after_each(function()
    scope.cleanup_scope()
  end)

  describe('quotes detection', function()
    local test_cases = {
      {
        name = 'double quotes',
        content = {
          'const msg = "Hello, World!";',
          'const name = "John Doe";',
          'const empty = "";',
        },
        textobj = '"',
        expected_count = 3,
        expected_first = 'Hello, World!',
      },
      {
        name = 'single quotes',
        content = {
          "const msg = 'Hello, World!';",
          "const name = 'John Doe';",
          "const empty = '';",
        },
        textobj = "'",
        expected_count = 3,
        expected_first = 'Hello, World!',
      },
      {
        name = 'backticks',
        content = {
          'const msg = `Hello, World!`;',
          'const name = `John ${lastName}`;',
          'const empty = ``;',
        },
        textobj = '`',
        expected_count = 3,
        expected_first = 'Hello, World!',
      },
      {
        name = 'mixed quotes',
        content = {
          'const a = "double";',
          "const b = 'single';",
          'const c = `backtick`;',
          'const d = "another "nested" quote";',
        },
        textobj = '"',
        expected_count = 4, -- Escaped quotes are detected as separate instances
        expected_first = 'double',
      },
    }

    for _, tc in ipairs(test_cases) do
      it('finds all ' .. tc.name, function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, tc.content)

        local instances = scope.find_text_objects(tc.textobj, buf)

        assert.equals(
          tc.expected_count,
          #instances,
          string.format(
            'Expected %d instances of %s, got %d',
            tc.expected_count,
            tc.name,
            #instances
          )
        )

        if tc.expected_first and #instances > 0 then
          assert.equals(
            tc.expected_first,
            instances[1].preview,
            string.format(
              'First instance should be "%s", got "%s"',
              tc.expected_first,
              instances[1].preview
            )
          )
        end

        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end
  end)

  describe('brackets detection', function()
    local test_cases = {
      {
        name = 'parentheses',
        content = {
          'function add(a, b) {',
          '  return (a + b);',
          '}',
          'const result = add(1, 2);',
        },
        textobj = '(',
        expected_count = 3,
      },
      {
        name = 'square brackets',
        content = {
          'const arr = [1, 2, 3];',
          'const item = arr[0];',
          'const matrix = [[1, 2], [3, 4]];',
        },
        textobj = '[',
        expected_count = 4, -- Nested brackets: outer bracket at [[ is tricky
      },
      {
        name = 'curly braces',
        content = {
          'const obj = { name: "John", age: 30 };',
          'function test() { return true; }',
          'if (true) { console.log("yes"); }',
        },
        textobj = '{',
        expected_count = 3,
      },
      {
        name = 'angle brackets',
        content = {
          'const el = <div>Hello</div>;',
          'type Arr<T> = Array<T>;',
          'const comp = <Component />;',
        },
        textobj = '<',
        expected_count = 5, -- <div>, </div>, <T> (twice), <Component />
      },
    }

    for _, tc in ipairs(test_cases) do
      it('finds all ' .. tc.name, function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, tc.content)

        local instances = scope.find_text_objects(tc.textobj, buf)

        assert.equals(
          tc.expected_count,
          #instances,
          string.format(
            'Expected %d instances of %s, got %d',
            tc.expected_count,
            tc.name,
            #instances
          )
        )

        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end
  end)

  describe('markdown code blocks detection', function()
    it('finds all markdown code blocks', function()
      local content = {
        '# Test Document',
        '',
        '```javascript',
        'console.log("test");',
        '```',
        '',
        'Some text',
        '',
        '```python',
        'print("hello")',
        '```',
        '',
        '```',
        'plain text block',
        '```',
      }

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

      local instances = scope.find_text_objects('m', buf)

      assert.equals(3, #instances, 'Should find 3 code blocks')
      assert.equals('javascript', instances[1].language)
      assert.equals('python', instances[2].language)
      assert.equals('', instances[3].language)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('nested structures', function()
    it('handles nested brackets correctly', function()
      local content = {
        'const nested = {',
        '  arr: [1, [2, 3], 4],',
        '  obj: { inner: { deep: true } }',
        '};',
      }

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

      local curly_instances = scope.find_text_objects('{', buf)
      local square_instances = scope.find_text_objects('[', buf)

      assert.is_true(#curly_instances >= 3, 'Should find at least 3 curly brace pairs')
      assert.is_true(#square_instances >= 2, 'Should find at least 2 square bracket pairs')

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('handles quotes within quotes', function()
      local content = {
        'const str = "He said \'hello\' to me";',
        'const str2 = \'She said "goodbye" to him\';',
        'const str3 = `Template with "double" and \'single\' quotes`;',
      }

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

      local double_instances = scope.find_text_objects('"', buf)
      local single_instances = scope.find_text_objects("'", buf)
      local backtick_instances = scope.find_text_objects('`', buf)

      assert.equals(
        3,
        #double_instances,
        'Should find 3 double quote pairs (including escaped/nested)'
      )
      assert.equals(
        3,
        #single_instances,
        'Should find 3 single quote pairs (including escaped/nested)'
      )
      assert.equals(1, #backtick_instances, 'Should find 1 backtick pair')

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('BeamScope buffer creation', function()
    it('creates properly formatted buffer for quotes', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        'const a = "first";',
        'const b = "second";',
      })

      local instances = {
        { start_line = 1, end_line = 1, preview = 'first', first_line = 'first' },
        { start_line = 2, end_line = 2, preview = 'second', first_line = 'second' },
      }

      local scope_buf = scope.create_scope_buffer(instances, '"', buf)
      local lines = vim.api.nvim_buf_get_lines(scope_buf, 0, -1, false)

      -- Should show the content with delimiters
      assert.equals('"first"', lines[1])
      assert.equals('"second"', lines[2])

      vim.api.nvim_buf_delete(scope_buf, { force = true })
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('navigation', function()
    it('line_to_instance mapping is correct', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        '```lua',
        'code',
        '```',
        '',
        '```python',
        'more',
        '```',
      })

      local instances = scope.find_text_objects('m', buf)
      local scope_buf = scope.create_scope_buffer(instances, 'm', buf)

      -- Check that line_to_instance mapping exists
      assert.is_not_nil(scope.scope_state.line_to_instance)
      assert.equals(2, #scope.scope_state.node_map)

      vim.api.nvim_buf_delete(scope_buf, { force = true })
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
