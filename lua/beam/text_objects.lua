---@class BeamTextObjects
---@field custom_objects table<string, BeamCustomTextObject> Registry of custom text objects
local M = {}

---@class BeamCustomTextObject
---@field desc string Description of the text object
---@field select fun(inclusive: boolean) Function to select the text object

---@type table<string, BeamCustomTextObject>
M.custom_objects = {}

---Register a custom text object
---@param key string Single character key for the text object
---@param opts string|BeamCustomTextObject Text object definition or description
---@return nil
function M.register_custom_text_object(key, opts)
  if type(opts) == 'string' then
    return
  end

  if type(opts) ~= 'table' then
    error("Custom text object must be a table with 'desc' and 'select' fields")
  end

  if not opts.select then
    error("Custom text object must have a 'select' function")
  end

  M.custom_objects[key] = opts

  vim.keymap.set('o', 'i' .. key, function()
    opts.select(false)
  end, { desc = opts.desc or ('inside ' .. key) })

  vim.keymap.set('o', 'a' .. key, function()
    opts.select(true)
  end, { desc = opts.desc or ('around ' .. key) })

  vim.keymap.set('x', 'i' .. key, function()
    opts.select(false)
  end, { desc = opts.desc or ('inside ' .. key) })

  vim.keymap.set('x', 'a' .. key, function()
    opts.select(true)
  end, { desc = opts.desc or ('around ' .. key) })
end

---Select markdown code block text object
---@param inclusive boolean Whether to include the delimiters (```)
---@return nil
function M.select_markdown_codeblock(inclusive)
  vim.cmd("call search('```', 'cb')")

  if inclusive then
    vim.cmd('normal! Vo')
  else
    vim.cmd('normal! j0Vo')
  end

  vim.cmd("call search('```')")

  if not inclusive then
    vim.cmd('normal! k')
  end
end

---Setup default beam text objects
---@return nil
function M.setup_defaults()
  M.register_custom_text_object('m', {
    desc = 'markdown code block',
    select = M.select_markdown_codeblock,
  })
end

return M
