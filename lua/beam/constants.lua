---@class BeamConstants
local M = {}

-- Visual feedback
M.VISUAL_FEEDBACK_DURATION = 250
M.VISUAL_FEEDBACK_MIN = 50
M.VISUAL_FEEDBACK_MAX = 1000

-- Search behavior
M.MAX_SEARCH_ITERATIONS = 1000
M.SEARCH_TIMEOUT_MS = 5000

-- Complexity thresholds
M.COMPLEXITY_THRESHOLD = 10
M.HIGH_COMPLEXITY_THRESHOLD = 15
M.CRITICAL_COMPLEXITY_THRESHOLD = 20

-- Operator names
M.OPERATORS = {
  YANK = 'y',
  DELETE = 'd',
  CHANGE = 'c',
  VISUAL = 'v',
}

-- Mode indicators
M.MODES = {
  NORMAL = 'n',
  VISUAL = 'v',
  OPERATOR_PENDING = 'o',
  INSERT = 'i',
}

-- Text object types
M.TEXTOBJ_TYPES = {
  INNER = 'i',
  AROUND = 'a',
  TO = 't',
  FORWARD = 'f',
  BACKWARD = 'F',
  TO_BACKWARD = 'T',
}

-- Special text objects
M.SPECIAL_TEXTOBJS = {
  MARKDOWN_CODE_INNER = 'im',
  MARKDOWN_CODE_AROUND = 'am',
}

-- Buffer and window
M.INVALID_BUFFER = -1
M.INVALID_WINDOW = -1

-- Timing
M.DEBOUNCE_MS = 100
M.ANIMATION_FRAME_MS = 16

-- Registry keys
M.REGISTRY = {
  SEARCH_OPERATOR_PENDING = 'SearchOperatorPending',
  BEAM_SCOPE_ACTIVE = 'BeamScopeActive',
}

-- Error messages
M.ERRORS = {
  NO_PATTERN = 'No search pattern provided',
  NO_TEXTOBJ = 'No text object specified',
  NO_ACTION = 'No action specified',
  INVALID_BUFFER = 'Invalid buffer',
  OPERATION_FAILED = 'Operation failed',
}

return M
