# beam.nvim

**🖖 Beam me up! Transport your text operations across file moving only when required.**

[![Video Thumbnail](https://img.youtube.com/vi/NYC38m4Z47o/0.jpg)](https://www.youtube.com/watch?v=NYC38m4Z47o)

`beam.nvim` makes it possible to perform text operations (yank, delete, change, visual selection) anywhere in your file using search, while moving only when needed.

Without beam: `[1]/ [2]<type search term> [3]<enter> [4]<text object (cib)>`

With beam***: `[1]/<text objet (,cib)> [2]<type search term> [3]<enter>`

<div align="center">

[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

</div>


## Quick Examples

```vim
,yi"func        " Search for 'func' & yank inside quotes at that location
,dip            " Search & delete inside paragraph
,ci(func        " Search for 'func' & change inside parentheses
,vimclass       " Search for 'class' & select inside code block
,Y              " Search & yank entire line
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

#### Full setup (with Telescope for cross-buffer search)
```lua
{
  "Piotr1215/beam.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",  -- Required by telescope
  },
  config = function()
    require("beam").setup()  -- Uses default prefix ','
  end,
}
```

#### Minimal setup (without cross-buffer search)
```lua
{
  "Piotr1215/beam.nvim",
  config = function()
    require("beam").setup()  -- Single buffer operations only
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Piotr1215/beam.nvim",
  requires = {
    -- Optional but recommended for cross-buffer search
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("beam").setup()  -- Uses default prefix ','
  end,
}
```

**Note:** The plugin uses `,` as the default prefix. All mappings like `,yi"`, `,dap`, etc. are automatically created. You can customize the prefix in the setup (see Configuration section).

## Features

- **Native Search Integration** - Uses Vim's `/` search with incremental highlighting
- **Universal Text Object Support** - Works with ALL text objects from any plugin
- **Motion Support** - Handles single-letter motions (`L` for URL, `Q` for quote, etc.)
- **Cross-Buffer Operations** - Search and operate across all open buffers
- **Auto-Discovery** - Automatically finds and uses all text objects from your plugins
- **Visual Feedback** - Shows selection briefly before operation executes
- **Smart Position Restore** - Yank/delete returns to origin, change/visual stays at target
- **Search Navigation** - Use `Ctrl-G`/`Ctrl-T` to navigate matches while searching
- **Line Operators** - Special `Y`, `D`, `C`, `V` operators for entire lines
- **Statusline Integration** - See pending operations in your statusline
- **Custom Text Objects** - Define your own text objects
- **Telescope Integration** - Optional fuzzy finder for powerful cross-buffer search

## Usage

### How it Works

1. Press `,yi"` (or any operator + text object)
2. Search for your target location
3. Press Enter
4. Operation executes there, cursor returns (for yank/delete)

### Basic Operations

| Keys | Description |
|------|-------------|
| `,yi"` | Search & yank inside quotes |
| `,dap` | Search & delete around paragraph |
| `,ciw` | Search & change inside word |
| `,vi{` | Search & select inside curly braces |

### Search Navigation

While searching:
- `Ctrl-G` - Next match
- `Ctrl-T` - Previous match  
- `Enter` - Execute
- `Esc` - Cancel

### Supported Text Objects

beam.nvim supports ALL Vim/Neovim text objects. Here are the most common ones:

#### Built-in Vim Text Objects
| Text Object | Description | Example Usage |
|------------|-------------|---------------|
| `iw`/`aw` | Inside/around word | `,yiw` - yank word |
| `iW`/`aW` | Inside/around WORD (includes punctuation) | `,diW` - delete WORD |
| `is`/`as` | Inside/around sentence | `,cis` - change sentence |
| `ip`/`ap` | Inside/around paragraph | `,vip` - select paragraph |
| `i"`/`a"` | Inside/around double quotes | `,yi"` - yank quoted text |
| `i'`/`a'` | Inside/around single quotes | `,di'` - delete quoted text |
| `` i` ``/`` a` `` | Inside/around backticks | `` ,ci` `` - change backticked |
| `i(`/`a(`, `i)`/`a)` | Inside/around parentheses | `,yi(` - yank in parens |
| `i[`/`a[`, `i]`/`a]` | Inside/around square brackets | `,di[` - delete in brackets |
| `i{`/`a{`, `i}`/`a}` | Inside/around curly braces | `,ci{` - change in braces |
| `i<`/`a<`, `i>`/`a>` | Inside/around angle brackets | `,vi<` - select in angles |
| `it`/`at` | Inside/around HTML/XML tags | `,yit` - yank tag content |

#### Alternative Syntax (Vim-compatible)
| Text Object | Equivalent to | Description |
|------------|---------------|-------------|
| `ib`/`ab` | `i(`/`a(` | Inside/around parentheses |
| `iB`/`aB` | `i{`/`a{` | Inside/around braces |
| `iq`/`aq` | `i"`/`a"` | Inside/around double quotes |

#### Special Line Operators
| Operator | Description | Example |
|----------|-------------|---------|
| `Y` | Yank entire line at target | `,Y` → search → yank line |
| `D` | Delete entire line at target | `,D` → search → delete line |
| `C` | Change entire line at target | `,C` → search → change line |
| `V` | Select entire line at target | `,V` → search → select line |

#### With Auto-Discovery
When `auto_discover_text_objects = true`, beam automatically finds and uses text objects from:
- **treesitter-textobjects**: `if` (function), `ic` (class), `il` (loop), etc.
- **mini.ai**: Custom text objects you've defined
- **nvim-various-textobjs**: `ii` (indentation), `R` (rest of line), etc.
- **targets.vim**: Seek-able text objects with next/last variants
- Any other plugin that defines text objects!

### Commands

| Command | Description |
|---------|-------------|
| `:BeamReload` | Reload the plugin configuration |
| `:BeamDiscoverNow` | Manually trigger text object discovery |
| `:BeamShowTextObjects` | Display all discovered text objects |

## Configuration

> **Note**: The source of truth for all configuration options is [`lua/beam/config.lua`](lua/beam/config.lua). The examples below show the default values.

### Default Setup

```lua
require('beam').setup({
  prefix = ',',                      -- Your prefix key (mini-leader)
  visual_feedback_duration = 150,    -- ms to show selection
  clear_highlight = true,            -- Clear search highlight after operation
  clear_highlight_delay = 500,       -- ms before clearing
  cross_buffer = {
    enabled = false,                 -- Enable cross-buffer operations
    fuzzy_finder = 'telescope',      -- Fuzzy finder (telescope required when enabled)
    include_hidden = false,          -- Include hidden buffers
  },
  enable_default_text_objects = true, -- Enable beam's custom text objects (im/am for markdown code blocks)
  auto_discover_text_objects = true, -- Auto-discover all available text objects
  show_discovery_notification = true,-- Show notification about discovered objects
  excluded_text_objects = {},       -- Exclude specific text objects (e.g., {'q', 'z'})
  excluded_motions = {},             -- Exclude specific motions (e.g., {'Q', 'R'})
  smart_highlighting = false,        -- Context-aware search highlighting
})
```

### Cross-Buffer Operations & Telescope Integration

beam.nvim integrates with [Telescope](https://github.com/nvim-telescope/telescope.nvim) for powerful fuzzy finding across buffers. The integration is intelligent and context-aware:

#### When Telescope is Used

1. **Cross-buffer with multiple buffers**: When `cross_buffer.enabled = true` and multiple buffers are detected, Telescope is automatically used for fuzzy finding across buffers.

2. **Single-buffer (optional)**: When `experimental.telescope_single_buffer.enabled = true`, Telescope is used even for single-buffer operations.

#### Configuration Layers

```lua
require('beam').setup({
  -- Cross-buffer configuration
  cross_buffer = {
    enabled = false,                 -- Enable cross-buffer operations
    fuzzy_finder = 'telescope',      -- Fuzzy finder to use (currently only telescope)
    include_hidden = false,          -- Include hidden buffers in search
  },
  
  -- Experimental: Use Telescope for single buffer too
  experimental = {
    telescope_single_buffer = {
      enabled = false,               -- Use Telescope for single buffer search
      theme = 'dropdown',            -- Theme: 'dropdown', 'cursor', 'ivy'
      preview = false,               -- Show preview pane
      winblend = 10,                 -- Window transparency (0-100)
    }
  }
})
```

#### Buffer Visibility

When `include_hidden = false` (default), only buffers visible in windows are searched. This prevents accidentally operating on background buffers. Visual indicators in Telescope:
- `●` - Visible buffer (in a window)
- `○` - Hidden buffer (loaded but not visible)

#### Examples

```lua
-- Search only visible buffers (default)
require('beam').setup({
  cross_buffer = {
    enabled = true,
    include_hidden = false  -- Only search visible buffers
  }
})

-- Search all loaded buffers
require('beam').setup({
  cross_buffer = {
    enabled = true,
    include_hidden = true   -- Include hidden buffers
  }
})

-- Use Telescope for everything
require('beam').setup({
  cross_buffer = { enabled = true },
  experimental = {
    telescope_single_buffer = {
      enabled = true,
      theme = 'cursor',     -- Compact cursor theme
      preview = true        -- Show preview
    }
  }
})
```

#### Behavior Notes

- **Navigation**: Ctrl-G/T navigation doesn't work with Telescope (use Telescope's own navigation)
- **Smart gating**: Telescope only activates when truly needed (multiple buffers for cross-buffer mode)
- **Buffer switching**: For change/visual operations, beam opens the target buffer in a split; for yank/delete, it returns to your original position

### Auto-Discovery

With `auto_discover_text_objects = true`, beam automatically discovers and registers:

- **nvim-various-textobjs** - `iq` (any quote), `ih` (headers), `L` (URL motion)
- **mini.ai** - All your custom text objects  
- **treesitter-textobjects** - `if` (function), `ic` (class), etc.
- **Built-in Vim** - All standard text objects

This gives you instant access to 100+ combinations like:
- `,yih` - Search & yank markdown header
- `,ciq` - Search & change any quote type
- `,dL` - Search & delete to URL

### Smart Highlighting (Context-Aware Search)

When `smart_highlighting = true`, beam constrains search results based on the text object you're using. This means when you search with delimiter-based text objects, only matches within those delimiters are highlighted.

**Note**: Smart highlighting only works with native Vim search (`/`). It is not available when using Telescope.

#### Example
```vim
" Without smart highlighting:
,di"  → /test  → highlights ALL occurrences of "test"

" With smart highlighting:  
,di"  → /test  → only highlights "test" inside double quotes
```

This works for quotes, brackets, HTML tags, and more. The search visually shows you exactly what will be operated on.

#### Supported Text Objects for Smart Highlighting
- **Quotes**: `i"`, `a"`, `i'`, `a'`, `` i` ``, `` a` ``
- **Brackets**: `i(`, `a(`, `i[`, `a[`, `i{`, `a{`, `i<`, `a<`
- **Alternative syntax**: 
  - `ib`/`ab` (same as `i(`/`a(` - parentheses)
  - `iB`/`aB` (same as `i{`/`a{` - braces)
  - `iq`/`aq` (same as `i"`/`a"` - double quotes)
- **HTML/XML tags**: `it`, `at`
- **Block comments**: `iC`, `aC`
- **Function arguments**: `ia`

### Excluding Text Objects and Motions

You can exclude specific text objects or motions from auto-discovery:

```lua
require('beam').setup({
  auto_discover_text_objects = true,
  excluded_text_objects = { 'q', 'z' },  -- Exclude iq/aq and iz/az
  excluded_motions = { 'Q', 'R' },       -- Exclude Q and R motions
})
```

### Statusline Integration

Add the pending operation indicator to your statusline:

![Statusline Indicator](static/status-line.png)

```lua
-- Lualine
sections = {
  lualine_x = {
    function() return vim.g.beam_search_operator_indicator or '' end
  }
}

-- Native statusline
vim.opt.statusline:append('%{get(g:,"beam_search_operator_indicator","")}')
```

### Full Configuration with All Options

```lua
require('beam').setup({
  -- Core settings
  prefix = ',',                      -- Prefix for all mappings
  
  -- Visual feedback
  visual_feedback_duration = 150,    -- Duration to show selection before operation
  clear_highlight = true,            -- Clear search highlight after operation
  clear_highlight_delay = 500,       -- Delay before clearing highlight
  
  -- Cross-buffer operations with Telescope
  cross_buffer = {
    enabled = false,                 -- Enable cross-buffer operations
    fuzzy_finder = 'telescope',      -- Fuzzy finder to use (currently only telescope)
    include_hidden = false,          -- Include hidden buffers in search (default: only visible)
  },
  
  -- Text object configuration
  enable_default_text_objects = true, -- Enable beam's custom text objects (im/am for markdown code blocks)
  auto_discover_text_objects = true, -- Discover text objects from all plugins
  show_discovery_notification = true,-- Notify about discovered objects
  excluded_text_objects = {},       -- List of text object keys to exclude (e.g., {'q', 'z'})
  excluded_motions = {},             -- List of motion keys to exclude (e.g., {'Q', 'R'})
  custom_text_objects = {},         -- Define custom text objects (key = description pairs)
  
  -- Search behavior
  smart_highlighting = false,        -- Context-aware search highlighting (native search only)
  
  -- Experimental features
  experimental = {
    telescope_single_buffer = {
      enabled = false,               -- Use Telescope for single buffer search (optional)
      theme = 'dropdown',            -- Theme: 'dropdown', 'cursor', 'ivy'
      preview = false,               -- Show preview pane
      winblend = 10                  -- Window transparency (0-100)
    },
    dot_repeat = false,              -- Enable dot repeat support (experimental)
    count_support = false            -- Enable count support (experimental)
  }
})
```

### Custom Text Objects

beam.nvim can define its own text objects that work with all beam operations. This is useful when you want text objects that don't exist globally but should work with remote operations.

```lua
require('beam').setup({
  prefix = ',',
  enable_default_text_objects = true, -- Enables beam's built-in text objects (currently: im/am for markdown code blocks)
  custom_text_objects = {
    -- Simple format: Just a description for beam operations
    -- NOTE: This assumes the text object already exists (e.g., from treesitter-textobjects)
    -- It only adds beam keymaps like ,yiF but doesn't create the iF/aF text object itself
    ['F'] = 'function (treesitter)',
    
    -- Full format: Creates the actual text object AND adds beam operations
    -- This creates the ir/ar text objects that work everywhere in Vim
    ['r'] = {
      desc = 'Ruby block',
      select = function(inclusive)
        -- Your text object implementation
        -- inclusive: true for 'around', false for 'inside'
        if inclusive then
          vim.cmd('normal! vaB')  -- around block
        else
          vim.cmd('normal! viB')  -- inside block
        end
      end
    }
  }
})

-- Or register them dynamically
require('beam').register_text_object('z', 'custom zone')

-- Register with implementation
require('beam').register_text_object('g', {
  desc = 'git conflict',
  select = function(inclusive)
    -- Implementation to select git conflict markers
  end
})
```

**Built-in Text Objects:**
- `im`/`am` - Inside/around markdown code block (triple backticks) - enabled with `enable_default_text_objects = true`

## Telescope Integration

beam.nvim integrates with [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) to provide a powerful fuzzy finder interface for cross-buffer operations.

### How It Works

- **Single Buffer (default)**: Uses native Vim search (`/`) for fast, lightweight operations
- **Multiple Buffers**: Automatically uses Telescope when `cross_buffer.enabled = true` and multiple buffers are open
- **Optional Single Buffer Telescope**: Can be enabled for enhanced single-buffer search experience

### Configuration

```lua
require('beam').setup({
  -- Cross-buffer configuration
  cross_buffer = {
    enabled = true,                  -- Enable cross-buffer operations
    fuzzy_finder = 'telescope',      -- Currently only 'telescope' is supported
    include_hidden = false           -- Search only visible buffers by default (true = all buffers)
  },
  
  -- Optional: Use Telescope even for single buffer
  experimental = {
    telescope_single_buffer = {
      enabled = false,               -- Set to true to always use Telescope
      theme = 'dropdown',            -- 'dropdown', 'cursor', or 'ivy'
      preview = false,               -- Show preview pane
      winblend = 10                  -- Window transparency (0-100)
    }
  }
})
```

### Behavior

1. **With One Buffer Open**:
   - Uses normal `/` search (unless `telescope_single_buffer.enabled = true`)
   - Fast and lightweight

2. **With Multiple Buffers Open** (and `cross_buffer.enabled = true`):
   - Automatically uses Telescope
   - Shows all matches across all buffers
   - Properly handles buffer navigation (opens splits for change/visual operations)

3. **Smart Buffer Navigation**:
   - **Yank/Delete**: Returns cursor to original position
   - **Change/Visual**: Opens target buffer in split if needed, or switches to existing window

## Integration with Other Plugins

### Treesitter Text Objects

```lua
local beam = require('beam')
if beam then
  beam.register_text_objects({
    ['f'] = 'function (treesitter)',
    ['c'] = 'class (treesitter)',
    ['l'] = 'loop (treesitter)',
    ['a'] = 'parameter (treesitter)',
  })
end
```

### mini.ai

```lua
-- After setting up mini.ai
local beam = require('beam')
if beam then
  beam.register_text_objects({
    ['f'] = 'function (mini.ai)',
    ['a'] = 'argument (mini.ai)',
  })
end
```

## Troubleshooting

### Quick health check
Run `:checkhealth beam` to diagnose common issues.

### Mappings not working?
- Check if your prefix key is already mapped: `:verbose nmap <prefix>` (where `<prefix>` is your configured prefix, default is `,`)
- Ensure the plugin is loaded: `:lua print(vim.g.loaded_beam)`
- Verify your configuration: `:lua print(vim.inspect(require('beam').get_config()))`

### Operations not executing?
- Make sure you have the text objects installed that you're trying to use
- Check `:messages` for any error output

### Inspiration

Inspired by the power of Vim's composable operations and the desire to operate on text without losing context as well as several excellent Neovim plugins that explore innovative ways of navigating and manipulating text:

- [flash.nvim](https://github.com/folke/flash.nvim) - Jump to any location with minimal keystrokes
- [leap.nvim](https://github.com/ggandor/leap.nvim) - General-purpose motion plugin with 2-character search
- [hop.nvim](https://github.com/phaazon/hop.nvim) - Neovim motions on speed
- [vim-sneak](https://github.com/justinmk/vim-sneak) - The missing motion for Vim

While these plugins focus on cursor movement, beam.nvim takes a different approach: **operate on remote text, moving only when it makes sense** - stay in place for yank and delete, jump to location for change and visual selection.

## License

MIT 

---

<div align="center">

[Report Bug](https://github.com/Piotr1215/beam.nvim/issues) · [Request Feature](https://github.com/Piotr1215/beam.nvim/issues)

</div>
