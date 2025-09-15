-- vim: ft=lua tw=80

stds.nvim = {
  globals = {
    vim = { fields = { "g", "b", "w", "o", "bo", "wo", "go", "v", "fn", "api", "opt", "loop", "cmd", "ui", "fs", "keymap", "lsp", "diagnostic", "treesitter", "health", "inspect", "schedule", "defer_fn", "notify", "validate", "deprecate" }},
    "describe",
    "it",
    "before_each",
    "after_each",
    "pending",
    "assert",
  },
}

std = "lua51+nvim"

-- Ignore W211 (unused variable) for test files
files["test/**/*_spec.lua"].ignore = { "211" }

-- Ignore max cyclomatic complexity warnings (we've already addressed these)
ignore = {
  "561", -- max cyclomatic complexity
  "631", -- line too long
}

-- Don't report globals from beam modules
read_globals = {
  "BeamSearchOperatorPending",
  "BeamSearchOperatorWrapper",
  "SearchOperatorPending",
  "BeamScopeActive",
}

cache = true