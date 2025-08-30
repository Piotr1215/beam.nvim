local M = {}

M.defaults = {
  prefix = ',',
  visual_feedback_duration = 150,
  clear_highlight = true,
  clear_highlight_delay = 500,
  custom_text_objects = {},
  experimental = {
    dot_repeat = false,
    count_support = false,
  },
}

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
