local M = {}

-- Default configuration for beam.nvim
-- This is the source of truth for all available options
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
  enable_default_text_objects = true, -- Enable beam's custom text objects (im/am for markdown code blocks)
  custom_text_objects = {},
  auto_discover_custom_text_objects = false, -- Auto-discover custom text objects from plugins (mini.ai, treesitter, etc.)
  show_discovery_notification = false, -- Show notification about discovered text objects
  excluded_text_objects = { '?' }, -- List of text object keys to exclude from discovery (e.g., {'q', 'z'}). ? is excluded by default as it's interactive
  excluded_motions = {}, -- List of motion keys to exclude from discovery (e.g., {'Q', 'R'})
  resolved_conflicts = {}, -- List of text object keys where conflicts are intentional (e.g., {'m'})
  smart_highlighting = false, -- Enable real-time highlighting for delimiter-based text objects
  beam_scope = {
    enabled = true, -- Enable BeamScope for scoped text objects (enabled by default for better UX)
    -- Default scoped objects are delimited text objects that naturally benefit from BeamScope
    scoped_text_objects = {
      -- Delimited text objects (enabled by default)
      '"',
      "'",
      '`', -- Quotes
      '(',
      ')',
      '[',
      ']',
      '{',
      '}',
      '<',
      '>', -- Brackets
      'b',
      'B', -- Aliases for () and {}
      't', -- Tags
      -- Note: We exclude w, W, s, p as they are ubiquitous
      -- Custom text objects like 'm' should be added by users if desired
    },
    -- Additional custom text objects can be added by users
    custom_scoped_text_objects = {
      -- Example: 'm' for markdown code blocks
      -- Add any plugin-specific or custom text objects here
    },
    preview_context = 3, -- Number of context lines to show before/after in preview
    window_width = 80, -- Maximum width of the BeamScope window (increased for full content)
  },
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

-- Registry of ALL active text objects (config + discovered)
-- This is what actually gets used for mappings
M.active_text_objects = {}

-- Only keep beam-specific text objects
-- Everything else will be auto-discovered from Vim built-ins or other plugins
M.text_objects = {
  ['m'] = 'markdown code block', -- The only truly beam-specific text object (im/am)
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
      include_hidden = false, -- Set default value explicitly
    }
  end

  -- Backward compatibility: rename auto_discover_text_objects to auto_discover_custom_text_objects
  if
    opts
    and opts.auto_discover_text_objects ~= nil
    and opts.auto_discover_custom_text_objects == nil
  then
    M.current.auto_discover_custom_text_objects = opts.auto_discover_text_objects
  end

  if M.current.custom_text_objects then
    M.text_objects = vim.tbl_extend('force', M.text_objects, M.current.custom_text_objects)
  end

  -- Initialize active_text_objects
  -- Only use default text_objects if auto-discovery is disabled
  if M.current.auto_discover_text_objects then
    -- Start with empty, will be populated by discovery
    M.active_text_objects = {}
  else
    -- Use defaults when discovery is disabled
    M.active_text_objects = vim.tbl_deep_extend('force', {}, M.text_objects)
  end

  return M.current
end

function M.register_text_object(key, description)
  -- Add to active registry, NOT to config
  M.active_text_objects[key] = description
end

function M.register_text_objects(objects)
  -- Add to active registry, NOT to config
  M.active_text_objects = vim.tbl_extend('force', M.active_text_objects, objects)
end

return M
