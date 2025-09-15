---@meta
-- Type definitions for beam.nvim

---@class BeamCrossBufferOptions
---@field enabled? boolean Whether cross-buffer operations are enabled
---@field fuzzy_finder? 'telescope'|'fzf-lua'|'mini.pick' Fuzzy finder to use
---@field include_hidden? boolean Include hidden buffers in search

---@class BeamScopeOptions
---@field enabled? boolean Enable BeamScope for scoped text objects
---@field scoped_text_objects? string[] List of text objects to enable BeamScope for
---@field custom_scoped_text_objects? string[] Additional custom text objects for BeamScope
---@field preview_context? number Number of context lines to show before/after in preview
---@field window_width? number Maximum width of the BeamScope window

---@class BeamExperimentalOptions
---@field dot_repeat? boolean Enable dot repeat support (experimental)
---@field count_support? boolean Enable count support (experimental)
---@field telescope_single_buffer? table Optional Telescope configuration for single buffer

---User-facing configuration options (all optional)
---@class BeamOptions
---@field prefix? string Prefix for all mappings
---@field visual_feedback_duration? number Duration of visual feedback in milliseconds
---@field clear_highlight? boolean Clear search highlight after operation
---@field clear_highlight_delay? number Delay before clearing highlight in milliseconds
---@field cross_buffer? BeamCrossBufferOptions Cross-buffer operation settings
---@field enable_default_text_objects? boolean Enable beam's custom text objects
---@field custom_text_objects? table<string, string|table> Custom text objects to register
---@field auto_discover_custom_text_objects? boolean Auto-discover text objects from plugins
---@field show_discovery_notification? boolean Show notification about discovered text objects
---@field excluded_text_objects? string[] Text object keys to exclude from discovery
---@field excluded_motions? string[] Motion keys to exclude from discovery
---@field resolved_conflicts? string[] Text object keys where conflicts are intentional
---@field smart_highlighting? boolean Enable real-time highlighting for delimiter-based text objects
---@field beam_scope? BeamScopeOptions BeamScope configuration
---@field experimental? BeamExperimentalOptions Experimental features

---Internal configuration (all fields guaranteed)
---@class BeamInternalCrossBufferConfig
---@field enabled boolean
---@field fuzzy_finder 'telescope'|'fzf-lua'|'mini.pick'
---@field include_hidden boolean

---@class BeamInternalScopeConfig
---@field enabled boolean
---@field scoped_text_objects string[]
---@field custom_scoped_text_objects string[]
---@field preview_context number
---@field window_width number

---@class BeamInternalExperimentalConfig
---@field dot_repeat boolean
---@field count_support boolean
---@field telescope_single_buffer table

---@class BeamInternalConfig
---@field prefix string
---@field visual_feedback_duration number
---@field clear_highlight boolean
---@field clear_highlight_delay number
---@field cross_buffer BeamInternalCrossBufferConfig
---@field enable_default_text_objects boolean
---@field custom_text_objects table<string, string|table>
---@field auto_discover_custom_text_objects boolean
---@field show_discovery_notification boolean
---@field excluded_text_objects string[]
---@field excluded_motions string[]
---@field resolved_conflicts string[]
---@field smart_highlighting boolean
---@field beam_scope BeamInternalScopeConfig
---@field experimental BeamInternalExperimentalConfig

---Operation context for beam operations
---@class BeamOperationContext
---@field pattern string|nil Search pattern
---@field saved_pos table|nil Saved cursor position
---@field saved_buf number|nil Saved buffer number
---@field textobj string Text object to operate on
---@field action string Operation action (yank/delete/change/visual)

---Editor state for restoration
---@class BeamEditorState
---@field reg string Default register content
---@field reg_type string Register type
---@field search string Search register content

---Pending operation state
---@class BeamPendingOperation
---@field action string Operation to perform
---@field textobj string Text object to operate on
---@field saved_pos_for_yank table|nil Position to restore after yank
---@field saved_buf number|nil Buffer to restore to

---Text object constraint for smart highlighting
---@class BeamTextObjectConstraint
---@field wrap_pattern fun(pattern: string): string Function to wrap pattern
---@field description string Description of the constraint

---Discovery result for text objects
---@class BeamDiscoveryResult
---@field discovered table<string, boolean> Discovered text objects
---@field mini_ai_objects table<string, any> Mini.ai specific objects
---@field conflict_report string[] Conflict report messages

---Scope instance for BeamScope
---@class BeamScopeInstance
---@field line number Line number
---@field col number Column position
---@field text string Text content
---@field highlight_start number Highlight start position
---@field highlight_end number Highlight end position

return {}
