-- Minimal cross-buffer search with Telescope for beam.nvim
local M = {}

-- Simple cross-buffer search + yank
M.search_and_yank = function(textobj)
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.notify('Telescope not found', vim.log.levels.WARN)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Save current position
  local start_pos = vim.fn.getpos('.')
  local start_buf = vim.api.nvim_get_current_buf()

  -- Collect all lines from all buffers with their locations
  local items = {}
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf.bufnr) then
      local lines = vim.api.nvim_buf_get_lines(buf.bufnr, 0, -1, false)
      local bufname = vim.fn.fnamemodify(buf.name, ':t') or '[No Name]'

      for lnum, line in ipairs(lines) do
        if line ~= '' then -- Skip empty lines
          table.insert(items, {
            bufnr = buf.bufnr,
            bufname = bufname,
            lnum = lnum,
            line = line,
            display = string.format('%s:%d: %s', bufname, lnum, line),
          })
        end
      end
    end
  end

  -- Create picker
  pickers
    .new({}, {
      prompt_title = 'Beam Cross-Buffer Yank: ' .. textobj,
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.display,
            ordinal = item.line,
            bufnr = item.bufnr,
            lnum = item.lnum,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            actions.close(prompt_bufnr)
            return
          end

          actions.close(prompt_bufnr)

          -- Jump to selected location
          vim.api.nvim_set_current_buf(selection.value.bufnr)
          vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })

          -- Position cursor at the beginning of the line first
          vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })

          -- Find first non-whitespace character on the line if searching for a word
          if textobj == 'iw' or textobj == 'aw' then
            vim.cmd('normal! ^')
          end

          -- Execute yank with text object - use visual mode to be more precise
          local ok, err = pcall(vim.cmd, 'normal! v' .. textobj .. 'y')
          if not ok then
            vim.notify('Failed to yank: ' .. err, vim.log.levels.ERROR)
          else
            -- Return to original position
            vim.api.nvim_set_current_buf(start_buf)
            vim.fn.setpos('.', start_pos)

            local yanked = vim.fn.getreg('"')
            vim.notify('Yanked: ' .. (yanked:sub(1, 50) .. (yanked:len() > 50 and '...' or '')))
          end
        end)
        return true
      end,
    })
    :find()
end

-- Test it
M.setup = function()
  vim.keymap.set('n', '<leader>bty', function()
    M.search_and_yank('iw') -- Yank word
  end, { desc = 'Beam telescope yank word' })

  vim.keymap.set('n', '<leader>bt"', function()
    M.search_and_yank('i"') -- Yank inside quotes
  end, { desc = 'Beam telescope yank quotes' })
end

return M
