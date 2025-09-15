local M = {}
local config = require('beam.config')

-- Try to load common text object plugins to ensure they're available
local function ensure_plugins_loaded()
  -- Trigger VeryLazy event to load lazy-loaded plugins
  vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })

  -- Also try to directly load known text object plugins
  local plugins_to_load = {
    'various-textobjs',
    'mini.ai',
    'nvim-treesitter.configs',
    'nvim-treesitter-textobjects',
    'targets.vim',
  }

  for _, plugin in ipairs(plugins_to_load) do
    pcall(require, plugin)
  end

  -- Give plugins a moment to register their mappings
  vim.wait(50)
end

-- List of common text objects to check for
-- Format: { keymap = "text object key", desc = "description" }
local COMMON_TEXT_OBJECTS = {
  -- Built-in Vim text objects
  { keymap = 'iw', desc = 'inner word' },
  { keymap = 'aw', desc = 'around word' },
  { keymap = 'iW', desc = 'inner WORD' },
  { keymap = 'aW', desc = 'around WORD' },
  { keymap = 'is', desc = 'inner sentence' },
  { keymap = 'as', desc = 'around sentence' },
  { keymap = 'ip', desc = 'inner paragraph' },
  { keymap = 'ap', desc = 'around paragraph' },
  { keymap = 'i"', desc = 'inner double quotes' },
  { keymap = 'a"', desc = 'around double quotes' },
  { keymap = "i'", desc = 'inner single quotes' },
  { keymap = "a'", desc = 'around single quotes' },
  { keymap = 'i`', desc = 'inner backticks' },
  { keymap = 'a`', desc = 'around backticks' },
  { keymap = 'i(', desc = 'inner parentheses' },
  { keymap = 'a(', desc = 'around parentheses' },
  { keymap = 'ib', desc = 'inner parentheses' },
  { keymap = 'ab', desc = 'around parentheses' },
  { keymap = 'i[', desc = 'inner brackets' },
  { keymap = 'a[', desc = 'around brackets' },
  { keymap = 'i{', desc = 'inner braces' },
  { keymap = 'a{', desc = 'around braces' },
  { keymap = 'iB', desc = 'inner braces' },
  { keymap = 'aB', desc = 'around braces' },
  { keymap = 'i<', desc = 'inner angle brackets' },
  { keymap = 'a<', desc = 'around angle brackets' },
  { keymap = 'it', desc = 'inner tag' },
  { keymap = 'at', desc = 'around tag' },

  -- nvim-various-textobjs (only actual text objects, not motions)
  { keymap = 'iq', desc = 'inner any quote' },
  { keymap = 'aq', desc = 'around any quote' },
  { keymap = 'ii', desc = 'inner indentation' },
  { keymap = 'ai', desc = 'around indentation' },
  { keymap = 'iI', desc = 'inner indentation (with line above)' },
  { keymap = 'aI', desc = 'around indentation (with lines above/below)' },
  -- Removed: R, r, Q, |, L - these are motions, not text objects
  { keymap = 'ig', desc = 'inner entire buffer' },
  { keymap = 'ag', desc = 'around entire buffer' },
  { keymap = 'in', desc = 'inner near end of line' },
  { keymap = 'an', desc = 'around near end of line' },
  { keymap = 'iS', desc = 'inner subword' },
  { keymap = 'aS', desc = 'around subword' },
  { keymap = 'iv', desc = 'inner value' },
  { keymap = 'av', desc = 'around value' },
  { keymap = 'ik', desc = 'inner key' },
  { keymap = 'ak', desc = 'around key' },
  { keymap = 'in', desc = 'inner number' },
  { keymap = 'an', desc = 'around number' },
  { keymap = 'id', desc = 'inner diagnostic' },
  { keymap = 'ad', desc = 'around diagnostic' },
  { keymap = 'iz', desc = 'inner fold' },
  { keymap = 'az', desc = 'around fold' },
  { keymap = 'ie', desc = 'inner entire visible' },
  { keymap = 'ae', desc = 'around entire visible' },
  { keymap = 'iC', desc = 'inner css selector' },
  { keymap = 'aC', desc = 'around css selector' },
  { keymap = 'ix', desc = 'inner html attribute' },
  { keymap = 'ax', desc = 'around html attribute' },
  { keymap = 'iD', desc = 'inner double square brackets' },
  { keymap = 'aD', desc = 'around double square brackets' },
  { keymap = 'iP', desc = 'inner python triple quotes' },
  { keymap = 'aP', desc = 'around python triple quotes' },
  { keymap = 'iJ', desc = 'inner javascript regex' },
  { keymap = 'aJ', desc = 'around javascript regex' },
  { keymap = 'iA', desc = 'inner shell pipe' },
  { keymap = 'aA', desc = 'around shell pipe' },

  -- Treesitter text objects
  { keymap = 'if', desc = 'inner function' },
  { keymap = 'af', desc = 'around function' },
  { keymap = 'ic', desc = 'inner class' },
  { keymap = 'ac', desc = 'around class' },
  { keymap = 'ia', desc = 'inner parameter' },
  { keymap = 'aa', desc = 'around parameter' },
  { keymap = 'il', desc = 'inner loop' },
  { keymap = 'al', desc = 'around loop' },
  { keymap = 'io', desc = 'inner conditional' },
  { keymap = 'ao', desc = 'around conditional' },
  { keymap = 'ih', desc = 'inner markdown header' },
  { keymap = 'ah', desc = 'around markdown header' },

  -- mini.ai additions
  { keymap = 'i_', desc = 'inner underscore' },
  { keymap = 'a_', desc = 'around underscore' },
  { keymap = 'i-', desc = 'inner dash' },
  { keymap = 'a-', desc = 'around dash' },
  { keymap = 'i/', desc = 'inner slash' },
  { keymap = 'a/', desc = 'around slash' },
  { keymap = 'i=', desc = 'inner equals' },
  { keymap = 'a=', desc = 'around equals' },

  -- targets.vim style
  { keymap = 'in(', desc = 'inner next parentheses' },
  { keymap = 'il(', desc = 'inner last parentheses' },
  { keymap = 'in{', desc = 'inner next braces' },
  { keymap = 'il{', desc = 'inner last braces' },
  { keymap = 'in[', desc = 'inner next brackets' },
  { keymap = 'il[', desc = 'inner last brackets' },
}

-- Check if a text object is available
function M.is_text_object_available(text_obj)
  -- Method 1: Check operator-pending mode mappings
  for _, map in ipairs(vim.api.nvim_get_keymap('o')) do
    if map.lhs == text_obj then
      return true, 'mapped'
    end
  end

  -- Method 2: Check visual mode mappings
  for _, map in ipairs(vim.api.nvim_get_keymap('x')) do
    if map.lhs == text_obj then
      return true, 'mapped'
    end
  end

  -- Method 3: Test if it actually works (for built-ins)
  -- Only test known built-in text objects to avoid side effects
  local known_builtins = {
    'iw',
    'aw',
    'iW',
    'aW',
    'is',
    'as',
    'ip',
    'ap',
    'i"',
    'a"',
    "i'",
    "a'",
    'i`',
    'a`',
    'i(',
    'a(',
    'i)',
    'a)',
    'ib',
    'ab',
    'i[',
    'a[',
    'i]',
    'a]',
    'i{',
    'a{',
    'i}',
    'a}',
    'iB',
    'aB',
    'i<',
    'a<',
    'i>',
    'a>',
    'it',
    'at',
  }

  for _, builtin in ipairs(known_builtins) do
    if text_obj == builtin then
      return true, 'builtin'
    end
  end

  return false, nil
end

-- Discover all mini.ai text objects (built-in and custom)
function M.discover_mini_ai_text_objects()
  -- Check if mini.ai is available
  local has_mini_ai = vim.fn.exists('*mini#ai#config') == 1 or pcall(require, 'mini.ai')
  if not has_mini_ai then
    return {}, false -- Return empty table and false to indicate mini.ai not found
  end

  -- Try to load mini.ai
  local ok, mini_ai = pcall(require, 'mini.ai')
  if not ok then
    return {}, false
  end

  local text_objects = {}

  -- Define known built-in text objects with descriptions
  local builtin_descriptions = {
    ['?'] = 'user prompt',
    ['a'] = 'argument',
    ['f'] = 'function call',
    ['t'] = 'tag',
    ['q'] = 'any quote',
    ['b'] = 'any bracket',
  }

  -- First, add built-in text objects that mini.ai provides
  -- These are always available when mini.ai is loaded
  for key, desc in pairs(builtin_descriptions) do
    -- Check if not disabled in custom_textobjects
    local custom = mini_ai.config and mini_ai.config.custom_textobjects
    if not custom or custom[key] ~= false then
      text_objects['i' .. key] = 'inner ' .. desc .. ' (mini.ai)'
      text_objects['a' .. key] = 'around ' .. desc .. ' (mini.ai)'
    end
  end

  -- Then add custom text objects
  local config = mini_ai.config
  if config and config.custom_textobjects then
    for key, spec in pairs(config.custom_textobjects) do
      -- Skip disabled text objects (false values) and already processed builtins
      if spec ~= false and not builtin_descriptions[key] then
        local desc = 'custom'

        -- Identify the type of text object
        if type(spec) == 'function' then
          desc = 'custom function'
        elseif type(spec) == 'table' then
          desc = 'custom pattern'
        elseif type(spec) == 'string' then
          desc = 'custom alias'
        end

        -- Add both inner and around variants
        text_objects['i' .. key] = 'inner ' .. desc .. ' (mini.ai)'
        text_objects['a' .. key] = 'around ' .. desc .. ' (mini.ai)'
      end
    end
  end

  return text_objects, true -- Return objects and true to indicate mini.ai was found
end

---Build exclusion set for text objects
---@param excluded_list table List of excluded text object keys
---@return table excluded Set of excluded keys
local function build_exclusion_set(excluded_list)
  local excluded = {}
  for _, key in ipairs(excluded_list or {}) do
    -- Handle both the suffix (e.g., 'q') and full forms (e.g., 'iq', 'aq')
    excluded[key] = true
    excluded['i' .. key] = true
    excluded['a' .. key] = true
  end
  return excluded
end

---Check if text object should be included
---@param keymap string Text object keymap
---@param excluded table Exclusion set
---@param seen table Already seen text objects
---@return boolean
local function should_include_text_object(keymap, excluded, seen)
  if seen[keymap] then
    return false
  end

  -- Check both the full keymap and its suffix
  if excluded[keymap] then
    return false
  end

  local suffix = keymap:sub(2)
  if #keymap > 1 and excluded[suffix] then
    return false
  end

  return true
end

---Identify source from mapping description
---@param desc string Mapping description
---@return string source Source identifier
local function identify_source_from_desc(desc)
  -- Table-driven source identification
  local patterns = {
    treesitter = { 'treesitter', 'TS', 'function', 'class', 'parameter', 'conditional' },
    various = { 'various', 'indentation', 'subword', 'diagnostic', 'entire', 'value', 'key' },
  }

  for source, keywords in pairs(patterns) do
    for _, keyword in ipairs(keywords) do
      if desc:match(keyword) then
        return source
      end
    end
  end

  return 'mapped'
end

-- Discover all available text objects
function M.discover_text_objects()
  -- Ensure plugins are loaded first
  ensure_plugins_loaded()

  local available = {}
  local seen = {}
  local config = require('beam.config')

  -- Build exclusion set for faster lookups
  local excluded = build_exclusion_set(config.current.excluded_text_objects)

  -- FIRST: Try to discover mini.ai text objects (if available)
  -- These should take priority over beam's hardcoded defaults
  local mini_ai_objects, has_mini_ai = M.discover_mini_ai_text_objects()
  if has_mini_ai and next(mini_ai_objects) then
    -- mini.ai is available and has objects
    for keymap, desc in pairs(mini_ai_objects) do
      if should_include_text_object(keymap, excluded, seen) then
        -- Check if this is a built-in mini.ai object that should override beam's default
        local is_mini_builtin = keymap:match('^[ia][bfqta]$') -- mini.ai built-ins: b, f, q, t, a

        table.insert(available, {
          keymap = keymap,
          desc = desc,
          source = 'mini.ai',
          priority = is_mini_builtin and 1 or 2, -- Higher priority for mini.ai built-ins
        })
        seen[keymap] = true
      end
    end
  end

  -- Then, check our curated list of common text objects
  for _, text_obj in ipairs(COMMON_TEXT_OBJECTS) do
    if should_include_text_object(text_obj.keymap, excluded, seen) then
      local is_available, source = M.is_text_object_available(text_obj.keymap)
      if is_available then
        text_obj.source = source
        table.insert(available, text_obj)
        seen[text_obj.keymap] = true
      end
    end
  end

  -- Additionally, discover from actual mappings (only real text objects with i/a prefix)
  for _, map in ipairs(vim.api.nvim_get_keymap('o')) do
    local lhs = map.lhs
    -- Text objects must be at least 2 chars (i/a + something) and start with i or a
    if lhs and #lhs >= 2 and #lhs <= 3 and not seen[lhs] then
      local first = lhs:sub(1, 1)
      if first == 'i' or first == 'a' then
        -- Only add if it looks like a reasonable text object
        local suffix = lhs:sub(2)
        -- Skip if suffix contains special characters that don't make sense
        if not suffix:match('[^%w%p]') and #suffix <= 2 then
          -- Try to identify the source from the description
          local desc = map.desc or (first == 'i' and 'inner ' or 'around ') .. suffix
          local source = identify_source_from_desc(desc)

          table.insert(available, {
            keymap = lhs,
            desc = desc,
            source = source,
          })
          seen[lhs] = true
        end
      end
    end
    -- Skip single-letter mappings - they're motions, not text objects!
  end

  return available
end

-- Get a formatted list of available text objects
function M.get_available_text_objects()
  local available = M.discover_text_objects()
  local categorized = {
    quotes = {},
    brackets = {},
    words = {},
    functions = {},
    custom = {},
    other = {},
  }

  for _, obj in ipairs(available) do
    local key = obj.keymap
    if key:match('["\']') or key:match('q') then
      table.insert(categorized.quotes, obj)
    elseif key:match('[%(%[%{<]') or key:match('b') or key:match('B') then
      table.insert(categorized.brackets, obj)
    elseif key:match('w') or key:match('W') or key:match('s') or key:match('p') then
      table.insert(categorized.words, obj)
    elseif key:match('f') or key:match('c') or key:match('a') then
      table.insert(categorized.functions, obj)
    elseif #key > 2 then
      table.insert(categorized.custom, obj)
    else
      table.insert(categorized.other, obj)
    end
  end

  return categorized, available
end

-- Discover motions (single-letter operator-pending mappings)
function M.discover_motions()
  ensure_plugins_loaded()

  local motions = {}
  local config = require('beam.config')

  -- Build exclusion set
  local excluded = {}
  for _, key in ipairs(config.current.excluded_motions or {}) do
    excluded[key] = true
  end

  -- Check for single-letter operator-pending mappings
  for _, map in ipairs(vim.api.nvim_get_keymap('o')) do
    local lhs = map.lhs
    -- Single letter mappings that aren't built-in vim motions and not excluded
    if lhs and #lhs == 1 and not lhs:match('[hjklwbeWBE0$^{}()]') and not excluded[lhs] then
      -- These are likely custom motions from plugins
      local desc = map.desc or ('motion to ' .. lhs)
      motions[lhs] = desc
    end
  end

  -- Add known motions from nvim-various-textobjs
  local known_motions = {
    ['L'] = 'url',
    ['Q'] = 'to next quote',
    ['R'] = 'rest of paragraph',
    ['r'] = 'rest of indentation',
    ['|'] = 'column',
  }

  for motion, desc in pairs(known_motions) do
    -- Skip if excluded
    if not excluded[motion] then
      -- Check if it actually exists
      local exists = false
      for _, map in ipairs(vim.api.nvim_get_keymap('o')) do
        if map.lhs == motion then
          exists = true
          motions[motion] = desc
          break
        end
      end
    end
  end

  return motions
end

-- Find an alternative 2-letter suffix based on source
-- Priority: standard (no suffix), mini.ai (m), treesitter (t), various (v), other (x)
function M.find_alternative_suffix(original_suffix, source)
  -- Determine suffix based on source
  local source_suffix = 'm' -- default to mini.ai

  if source == 'mini.ai' then
    source_suffix = 'm'
  elseif source == 'treesitter' or source:match('treesitter') then
    source_suffix = 't'
  elseif source == 'various' or source:match('various') then
    source_suffix = 'v'
  elseif source == 'targets' then
    source_suffix = 'g' -- g for tarGets
  else
    source_suffix = 'x' -- x for unknown/other
  end

  -- Create the alternative: original + source suffix
  local alt = original_suffix .. source_suffix

  -- Check if this alternative is available
  local test_i = 'i' .. alt
  local test_a = 'a' .. alt

  for _, map in ipairs(vim.api.nvim_get_keymap('o')) do
    if map.lhs == test_i or map.lhs == test_a then
      -- Already taken, try with a number
      for i = 2, 9 do
        alt = original_suffix .. source_suffix .. i
        test_i = 'i' .. alt
        test_a = 'a' .. alt
        local found = false
        for _, m in ipairs(vim.api.nvim_get_keymap('o')) do
          if m.lhs == test_i or m.lhs == test_a then
            found = true
            break
          end
        end
        if not found then
          return alt
        end
      end
      return nil -- Couldn't find alternative
    end
  end

  return alt
end

-- Auto-register discovered text objects with beam
function M.auto_register_text_objects(options)
  options = options or {}
  -- conflict_resolution is not currently used, but kept for future extensibility
  -- local conflict_resolution = options.conflict_resolution or 'skip'

  local available = M.discover_text_objects()
  local beam = require('beam')
  local registered = 0
  local skipped = 0
  local conflicts = {}

  -- Sort by priority:
  -- 1. builtin - Vim's native text objects should take precedence
  -- 2. mini.ai - Popular plugin with good text objects
  -- 3. treesitter - Code-aware text objects
  -- 4. various - Additional text objects
  -- 5. targets - Extended text objects
  -- 6. mapped - Other mapped text objects
  local priority_order = {
    ['builtin'] = 1, -- Built-ins should have highest priority
    ['mini.ai'] = 2,
    ['treesitter'] = 3,
    ['various'] = 4,
    ['targets'] = 5,
    ['mapped'] = 6,
  }

  table.sort(available, function(a, b)
    local a_priority = priority_order[a.source] or 99
    local b_priority = priority_order[b.source] or 99
    if a_priority ~= b_priority then
      return a_priority < b_priority
    end
    -- Same priority, sort by keymap for consistency
    return a.keymap < b.keymap
  end)

  -- Track which suffixes we've seen (to handle i/a pairs)
  local seen_suffixes = {}

  for _, text_obj in ipairs(available) do
    local full_key = text_obj.keymap
    -- prefix would be full_key:sub(1, 1) -- i or a (not used here)
    local suffix = full_key:sub(2) -- the actual text object key

    -- Check if this suffix was already processed
    if not seen_suffixes[suffix] then
      seen_suffixes[suffix] = true

      -- Check for conflicts but don't create alternatives
      if beam.is_text_object_registered(suffix) then
        -- Conflict detected - record it but don't register
        local existing = config.text_objects[suffix] or 'unknown'
        table.insert(conflicts, {
          key = suffix,
          existing = existing,
          existing_source = 'config', -- or could detect source
          new = text_obj.desc,
          new_source = text_obj.source or 'unknown',
        })
        skipped = skipped + 1
      else
        -- No conflict - register normally
        if beam.register_text_object(suffix, text_obj.desc) then
          registered = registered + 1
        else
          skipped = skipped + 1
        end
      end
    end
  end

  -- Also discover and register motions
  local motions = M.discover_motions()
  local motions_registered = 0

  for motion, desc in pairs(motions) do
    if not config.motions[motion] then
      config.motions[motion] = desc
      motions_registered = motions_registered + 1
    end
  end

  -- Re-setup mappings to include newly discovered motions
  if motions_registered > 0 then
    require('beam.mappings').setup()
  end

  local result = {
    registered = registered,
    skipped = skipped,
    total = #available,
    conflicts = conflicts,
    motions_registered = motions_registered,
    motions_total = vim.tbl_count(motions),
  }

  -- Show conflict report if there are conflicts
  if #conflicts > 0 and options.show_conflicts ~= false then
    M.show_conflict_report(conflicts)
  end

  return result
end

-- Check for unresolved conflicts and return count
function M.check_unresolved_conflicts()
  local conflicts = M.get_conflict_report()
  if not conflicts or #conflicts == 0 then
    return 0, 0 -- no conflicts at all
  end

  local config = require('beam.config')
  local resolved_conflicts = config.current.resolved_conflicts or {}
  local unresolved_count = 0
  local resolved_count = 0

  for _, conflict in ipairs(conflicts) do
    if vim.tbl_contains(resolved_conflicts, conflict.suffix) then
      resolved_count = resolved_count + 1
    else
      unresolved_count = unresolved_count + 1
    end
  end

  return unresolved_count, resolved_count
end

-- Show a nice conflict report to the user
function M.show_conflict_report(conflicts)
  -- This is now deprecated in favor of check_unresolved_conflicts
  -- but kept for compatibility
  local unresolved_count = M.check_unresolved_conflicts()

  if unresolved_count == 0 then
    return
  end

  local msg = string.format(
    'Beam.nvim: Found %d unresolved text object conflicts. Run :checkhealth beam for details.',
    unresolved_count
  )

  if vim.notify then
    vim.notify(msg, vim.log.levels.WARN, { title = 'Beam.nvim' })
  else
    print(msg)
  end
end

-- Register Vim's built-in text objects (always available)
function M.register_builtin_text_objects()
  local beam = require('beam')
  local registered = 0

  -- These are Vim's built-in text objects - always available
  local builtin_objects = {
    ['"'] = 'double quoted string',
    ["'"] = 'single quoted string',
    ['`'] = 'backticks',
    ['('] = 'parentheses',
    [')'] = 'parentheses',
    ['['] = 'square brackets',
    [']'] = 'square brackets',
    ['{'] = 'curly braces',
    ['}'] = 'curly braces',
    ['<'] = 'angle brackets',
    ['>'] = 'angle brackets',
    ['w'] = 'word',
    ['W'] = 'WORD',
    ['s'] = 'sentence',
    ['p'] = 'paragraph',
    ['b'] = 'parentheses block',
    ['B'] = 'curly braces block',
    ['t'] = 'tag block',
  }

  for key, desc in pairs(builtin_objects) do
    if beam.register_text_object(key, desc) then
      registered = registered + 1
    end
  end

  return registered
end

-- Get conflict report for checkhealth
function M.get_conflict_report()
  local available = M.discover_text_objects()
  local config = require('beam.config')
  local conflicts = {}

  -- Group by suffix AND source to find real conflicts
  -- A conflict only exists when different SOURCES provide the same text object
  local by_suffix = {}
  for _, obj in ipairs(available) do
    local suffix = obj.keymap:sub(2)
    local prefix = obj.keymap:sub(1, 1) -- 'i' or 'a'

    if not by_suffix[suffix] then
      by_suffix[suffix] = {}
    end

    -- Group by source to detect real conflicts
    local source_key = obj.source or 'unknown'
    if not by_suffix[suffix][source_key] then
      by_suffix[suffix][source_key] = {
        source = source_key,
        desc = obj.desc,
        variants = {},
      }
    end
    by_suffix[suffix][source_key].variants[prefix] = true
  end

  -- Only check config text objects if custom discovery is disabled
  -- When custom discovery is enabled, config defaults shouldn't be considered
  if not config.current.auto_discover_custom_text_objects then
    for key, desc in pairs(config.text_objects) do
      if not by_suffix[key] then
        by_suffix[key] = {}
      end
      if not by_suffix[key]['beam-config'] then
        by_suffix[key]['beam-config'] = {
          source = 'beam-config',
          desc = desc,
          variants = { i = true, a = true }, -- Assume both variants
        }
      end
    end
  end

  -- Find real conflicts - where multiple SOURCES provide the same text object
  for suffix, sources in pairs(by_suffix) do
    local source_count = vim.tbl_count(sources)
    if source_count > 1 then
      -- Convert to list format for compatibility
      local source_list = {}
      for source_name, info in pairs(sources) do
        -- Create entries for each variant
        if info.variants.i then
          table.insert(source_list, {
            keymap = 'i' .. suffix,
            desc = info.desc:match('^inner ') and info.desc or ('inner ' .. info.desc),
            source = source_name,
          })
        end
        if info.variants.a then
          table.insert(source_list, {
            keymap = 'a' .. suffix,
            desc = info.desc:match('^around ') and info.desc or ('around ' .. info.desc),
            source = source_name,
          })
        end
      end

      table.insert(conflicts, {
        suffix = suffix,
        sources = source_list,
      })
    end
  end

  return conflicts
end

return M
