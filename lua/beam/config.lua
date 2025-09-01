local M = {}

M.defaults = {
  prefix = ',',
  visual_feedback_duration = 150,
  clear_highlight = true,
  clear_highlight_delay = 500,
  cross_buffer = {
    enabled = false, -- Disabled by default for safety
    fuzzy_finder = 'telescope', -- Fuzzy finder to use: 'telescope' (future: 'fzf-lua', 'mini.pick')
    include_hidden = false, -- Include hidden buffers in search (default: only visible buffers)
  },
  custom_text_objects = {},
  auto_discover_text_objects = false, -- Auto-discover and register all available text objects
  show_discovery_notification = false, -- Show notification about discovered text objects
  excluded_text_objects = {}, -- List of text object keys to exclude from discovery (e.g., {'q', 'z'})
  excluded_motions = {}, -- List of motion keys to exclude from discovery (e.g., {'Q', 'R'})
  smart_highlighting = false, -- Enable real-time highlighting for delimiter-based text objects
  experimental = {
    dot_repeat = false,
    count_support = false,
    telescope_single_buffer = { -- Optional: Use Telescope for single buffer search
      enabled = false,
      theme = 'dropdown', -- Theme for picker: 'dropdown', 'cursor', 'ivy', or custom table
      preview = false, -- Show preview in picker
      winblend = 10, -- Window transparency (0-100)
    },
  },
}

M.motions = {} -- Will be populated by discovery

M.text_objects = {
  ['"'] = 'double quotes',
  ["'"] = 'single quotes',
  ['`'] = 'backticks',
  ['('] = 'parentheses',
  [')'] = 'parentheses',
  ['{'] = 'curly braces',
  ['}'] = 'curly braces',
  ['['] = 'square brackets',
  [']'] = 'square brackets',
  ['<'] = 'angle brackets',
  ['>'] = 'angle brackets',
  ['w'] = 'word',
  ['W'] = 'WORD (space-delimited)',
  ['b'] = 'parentheses block',
  ['B'] = 'curly braces block',
  ['l'] = 'line',
  ['e'] = 'entire buffer',
  ['t'] = 'HTML/XML tags',
  ['p'] = 'paragraph',
  ['s'] = 'sentence',
  ['m'] = 'markdown code block',
  ['i'] = 'indentation',
  ['I'] = 'indentation with line above',
  ['f'] = 'function',
  ['c'] = 'class',
  ['a'] = 'argument',
}

M.operators = {
  y = { func = 'YankSearchSetup', verb = 'yank' },
  d = { func = 'DeleteSearchSetup', verb = 'delete' },
  c = { func = 'ChangeSearchSetup', verb = 'change' },
  v = { func = 'VisualSearchSetup', verb = 'select' },
}

M.line_operators = {
  Y = { action = 'yankline', verb = 'yank entire line', save_pos = true },
  D = { action = 'deleteline', verb = 'delete entire line', save_pos = true },
  C = { action = 'changeline', verb = 'change entire line', save_pos = false },
  V = { action = 'visualline', verb = 'select entire line', save_pos = false },
}

M.current = {}

function M.setup(opts)
  M.current = vim.tbl_deep_extend('force', M.defaults, opts or {})

  -- Backward compatibility: convert boolean cross_buffer to table format
  if type(M.current.cross_buffer) == 'boolean' then
    M.current.cross_buffer = {
      enabled = M.current.cross_buffer,
      fuzzy_finder = 'telescope',
    }
  end

  if M.current.custom_text_objects then
    M.text_objects = vim.tbl_extend('force', M.text_objects, M.current.custom_text_objects)
  end

  return M.current
end

function M.register_text_object(key, description)
  M.text_objects[key] = description
end

function M.register_text_objects(objects)
  M.text_objects = vim.tbl_extend('force', M.text_objects, objects)
end

return M
