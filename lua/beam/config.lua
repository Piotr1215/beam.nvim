local M = {}

---@class BeamCrossBufferConfig
---@field enabled boolean Whether cross-buffer operations are enabled
---@field fuzzy_finder 'telescope'|'fzf-lua'|'mini.pick' Fuzzy finder to use
---@field include_hidden boolean Include hidden buffers in search

---@class BeamScopeConfig
---@field enabled boolean Enable BeamScope for scoped text objects
---@field scoped_text_objects string[] List of text objects to enable BeamScope for
---@field custom_scoped_text_objects string[] Additional custom text objects for BeamScope
---@field preview_context number Number of context lines to show before/after in preview
---@field window_width number Maximum width of the BeamScope window

---@class BeamExperimentalConfig
---@field dot_repeat boolean Enable dot repeat support (experimental)
---@field count_support boolean Enable count support (experimental)
---@field telescope_single_buffer table Optional Telescope configuration for single buffer

---@class BeamConfig
---@field prefix string Prefix for all mappings
---@field visual_feedback_duration number Duration of visual feedback in milliseconds
---@field clear_highlight boolean Clear search highlight after operation
---@field clear_highlight_delay number Delay before clearing highlight in milliseconds
---@field cross_buffer BeamCrossBufferConfig Cross-buffer operation settings
---@field enable_default_text_objects boolean Enable beam's custom text objects
---@field custom_text_objects table<string, string|table> Custom text objects to register
---@field auto_discover_custom_text_objects boolean Auto-discover text objects from plugins
---@field show_discovery_notification boolean Show notification about discovered text objects
---@field excluded_text_objects string[] Text object keys to exclude from discovery
---@field excluded_motions string[] Motion keys to exclude from discovery
---@field resolved_conflicts string[] Text object keys where conflicts are intentional
---@field smart_highlighting boolean Enable real-time highlighting for delimiter-based text objects
---@field beam_scope BeamScopeConfig BeamScope configuration
---@field experimental BeamExperimentalConfig Experimental features

---@type BeamConfig
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

---@type table<string, string>
M.motions = {} -- Will be populated by discovery

---@type table<string, string|table>
-- Registry of ALL active text objects (config + discovered)
-- This is what actually gets used for mappings
M.active_text_objects = {}

---@type table<string, string>
-- Only keep beam-specific text objects
-- Everything else will be auto-discovered from Vim built-ins or other plugins
M.text_objects = {
  ['m'] = 'markdown code block', -- The only truly beam-specific text object (im/am)
}

---@class BeamOperator
---@field func string Function name suffix (e.g., 'YankSearchSetup')
---@field verb string Verb describing the operation (e.g., 'yank')

---@type table<string, BeamOperator>
M.operators = {
  y = { func = 'YankSearchSetup', verb = 'yank' },
  d = { func = 'DeleteSearchSetup', verb = 'delete' },
  c = { func = 'ChangeSearchSetup', verb = 'change' },
  v = { func = 'VisualSearchSetup', verb = 'select' },
}

---@class BeamLineOperator
---@field action string Action identifier
---@field verb string Verb describing the operation
---@field save_pos boolean Whether to save cursor position

---@type table<string, BeamLineOperator>
M.line_operators = {
  Y = { action = 'yankline', verb = 'yank entire line', save_pos = true },
  D = { action = 'deleteline', verb = 'delete entire line', save_pos = true },
  C = { action = 'changeline', verb = 'change entire line', save_pos = false },
  V = { action = 'visualline', verb = 'select entire line', save_pos = false },
}

---@type BeamConfig
M.current = {}

---Apply backward compatibility transformations
---@param opts table|nil User options
local function apply_backward_compatibility(opts)
  if not opts then
    return
  end

  -- Convert boolean cross_buffer to table format for backward compatibility
  if type(M.current.cross_buffer) == 'boolean' then
    ---@diagnostic disable-next-line: assign-type-mismatch
    local enabled = M.current.cross_buffer == true
    M.current.cross_buffer = {
      enabled = enabled,
      fuzzy_finder = 'telescope',
      include_hidden = false,
    }
  end

  -- Rename auto_discover_text_objects to auto_discover_custom_text_objects
  if opts.auto_discover_text_objects ~= nil and opts.auto_discover_custom_text_objects == nil then
    M.current.auto_discover_custom_text_objects = opts.auto_discover_text_objects
  end
end

---Initialize text objects
local function initialize_text_objects()
  -- Merge custom text objects into base text_objects
  if M.current.custom_text_objects then
    M.text_objects = vim.tbl_extend('force', M.text_objects, M.current.custom_text_objects)
  end

  -- Initialize active_text_objects with all text objects
  M.active_text_objects = vim.tbl_deep_extend('force', {}, M.text_objects)

  -- Ensure custom text objects are in active registry
  if M.current.custom_text_objects then
    M.active_text_objects =
      vim.tbl_extend('force', M.active_text_objects, M.current.custom_text_objects)
  end
end

---Apply feature compatibility rules
local function apply_feature_compatibility()
  -- Disable beam_scope if cross_buffer is enabled (incompatible features)
  if M.current.cross_buffer and M.current.cross_buffer.enabled then
    if M.current.beam_scope then
      M.current.beam_scope.enabled = false
    end
  end
end

---@param opts BeamConfig|table|nil User configuration options
---@return BeamConfig
function M.setup(opts)
  M.current = vim.tbl_deep_extend('force', M.defaults, opts or {})

  apply_backward_compatibility(opts)
  initialize_text_objects()
  apply_feature_compatibility()

  return M.current
end

---@param key string Text object key (single character or multi-character)
---@param description string|table Description or text object definition
function M.register_text_object(key, description)
  -- Add to active registry, NOT to config
  M.active_text_objects[key] = description
end

---@param objects table<string, string|table> Text objects to register
function M.register_text_objects(objects)
  -- Add to active registry, NOT to config
  M.active_text_objects = vim.tbl_extend('force', M.active_text_objects, objects)
end

return M
