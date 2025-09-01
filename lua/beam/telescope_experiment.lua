-- Experimental Telescope integration for beam.nvim
-- Just a proof of concept!

local M = {}

-- Simple function to test Telescope search + yank
M.telescope_yank = function(textobj)
  -- Check if Telescope is available
  local ok, telescope = pcall(require, 'telescope.builtin')
  if not ok then
    vim.notify('Telescope not found, falling back to regular search', vim.log.levels.INFO)
    -- Fall back to regular beam behavior
    require('beam.operators').BeamYankSearchSetup(textobj)
    return
  end

  -- Store the text object and position for later
  local start_pos = vim.fn.getpos('.')
  local start_buf = vim.api.nvim_get_current_buf()

  -- Use Telescope's live_grep but only for loaded buffers
  -- This gives us cross-buffer search with preview!
  telescope.live_grep({
    prompt_title = 'Beam Yank (cross-buffer): ' .. textobj,
    search_dirs = {}, -- Empty means search all buffers
    grep_open_files = true, -- Only search in open buffers
    attach_mappings = function(prompt_bufnr, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      -- Override enter to execute yank at selected location
      map('i', '<CR>', function()
        local selection = action_state.get_selected_entry()
        if not selection then
          actions.close(prompt_bufnr)
          return
        end

        -- Close telescope
        actions.close(prompt_bufnr)

        -- Jump to the selected file and line
        vim.cmd('edit ' .. selection.filename)
        vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col - 1 })

        -- Execute the yank operation
        vim.cmd('normal! y' .. textobj)

        -- Return to original position
        vim.api.nvim_set_current_buf(start_buf)
        vim.fn.setpos('.', start_pos)

        vim.notify('Yanked with ' .. textobj .. ' from ' .. selection.filename, vim.log.levels.INFO)
      end)

      return true
    end,
  })
end

-- Test mapping - just for experimentation
M.setup_test = function()
  -- Create a test mapping for telescope yank
  vim.keymap.set('n', '<leader>ty', function()
    -- Prompt for text object
    vim.ui.input({ prompt = 'Text object: ' }, function(textobj)
      if textobj and textobj ~= '' then
        M.telescope_yank(textobj)
      end
    end)
  end, { desc = 'Telescope yank experiment' })

  -- Or with a specific text object
  vim.keymap.set('n', '<leader>tyi"', function()
    M.telescope_yank('i"')
  end, { desc = 'Telescope yank inside quotes' })

  vim.keymap.set('n', '<leader>tyiw', function()
    M.telescope_yank('iw')
  end, { desc = 'Telescope yank word' })
end

return M
