-- Minimal init for running tests
vim.opt.rtp:prepend('.')

-- Add plenary to rtp if installed in standard location (for CI)
local plenary_path = vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/plenary.nvim')
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.rtp:prepend(plenary_path)
end

-- Disable unnecessary plugins
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Basic vim settings for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.hidden = true
