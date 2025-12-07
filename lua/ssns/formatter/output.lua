---@class FormatterOutput
---Token stream to text reconstruction module.
---Handles whitespace insertion, indentation, and line ending normalization.
local Output = {}

---Get the indent string based on configuration
---@param config FormatterConfig
---@param level number Indentation level
---@return string
local function get_indent(config, level)
  if config.indent_style == "tab" then
    return string.rep("\t", level)
  else
    return string.rep(" ", config.indent_size * level)
  end
end

---Check if a keyword is a major clause that should start on a new line
---@param text string
---@return boolean
local function is_major_clause(text)
  local upper = string.upper(text)
  local major_clauses = {
    SELECT = true,
    FROM = true,
    WHERE = true,
    ["GROUP BY"] = true,
    ["ORDER BY"] = true,
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    INSERT = true,
    UPDATE = true,
    DELETE = true,
    SET = true,
    VALUES = true,
  }
  return major_clauses[upper] == true
end

---Check if keyword starts a JOIN
---@param text string
---@return boolean
local function is_join_start(text)
  local upper = string.upper(text)
  return upper == "JOIN" or upper == "INNER" or upper == "LEFT" or
         upper == "RIGHT" or upper == "FULL" or upper == "CROSS" or
         upper == "NATURAL"
end

---Check if token is AND or OR
---@param token table
---@return boolean
local function is_and_or(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

---Check if token is ON keyword
---@param token table
---@return boolean
local function is_on_keyword(token)
  return token.type == "keyword" and string.upper(token.text) == "ON"
end

---Determine if space should be added before a token
---@param prev table|nil Previous token
---@param curr table Current token
---@param config FormatterConfig
---@return boolean
local function needs_space_before(prev, curr, config)
  if not prev then
    return false
  end

  -- No space after opening paren (unless configured)
  if prev.type == "paren_open" then
    return config.parenthesis_spacing
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    return config.parenthesis_spacing
  end

  -- No space after dot (for qualified names)
  if prev.type == "dot" then
    return false
  end

  -- No space before dot
  if curr.type == "dot" then
    return false
  end

  -- No space before comma
  if curr.type == "comma" then
    return false
  end

  -- Space after comma
  if prev.type == "comma" then
    return true
  end

  -- No space before semicolon
  if curr.type == "semicolon" then
    return false
  end

  -- Space around operators (if configured)
  if (prev.type == "operator" or curr.type == "operator") and config.operator_spacing then
    return true
  end

  -- No space between @ and identifier for variables
  if prev.type == "at" then
    return false
  end

  -- Space between keywords/identifiers
  if prev.type == "keyword" or prev.type == "identifier" or prev.type == "bracket_id" or
     prev.type == "number" or prev.type == "string" then
    if curr.type == "keyword" or curr.type == "identifier" or curr.type == "bracket_id" or
       curr.type == "number" or curr.type == "string" or curr.type == "star" then
      return true
    end
  end

  -- Space after star if followed by keyword/identifier
  if prev.type == "star" then
    if curr.type == "keyword" or curr.type == "identifier" then
      return true
    end
  end

  return false
end

---Generate formatted output from processed tokens
---@param tokens table[] Processed tokens with formatting metadata
---@param config FormatterConfig Formatter configuration
---@return string
function Output.generate(tokens, config)
  if not tokens or #tokens == 0 then
    return ""
  end

  local result = {}
  local current_line = {}
  local current_indent = 0
  local in_select_list = false
  local in_where_clause = false
  local prev_token = nil
  local join_context = false -- Track if we're processing a JOIN clause

  for i, token in ipairs(tokens) do
    local text = token.text
    local needs_newline = false
    local extra_indent = 0

    -- Track SELECT list context
    if token.type == "keyword" and string.upper(token.text) == "SELECT" then
      in_select_list = true
      in_where_clause = false
      join_context = false
    elseif token.type == "keyword" and string.upper(token.text) == "FROM" then
      in_select_list = false
      in_where_clause = false
    elseif token.type == "keyword" and string.upper(token.text) == "WHERE" then
      in_select_list = false
      in_where_clause = true
      join_context = false
    elseif token.type == "keyword" and is_join_start(token.text) then
      join_context = true
      in_where_clause = false
    end

    -- Handle newlines before major clauses
    if config.newline_before_clause and token.type == "keyword" then
      if is_major_clause(token.text) then
        needs_newline = true
        current_indent = 0
      elseif is_join_start(token.text) then
        needs_newline = true
        current_indent = 0
      end
    end

    -- Handle ON clause positioning
    if is_on_keyword(token) and not config.join_on_same_line then
      needs_newline = true
      extra_indent = 1
    end

    -- Handle AND/OR positioning in WHERE clause
    if in_where_clause and is_and_or(token) then
      if config.and_or_position == "leading" then
        needs_newline = true
        extra_indent = 1
      end
    end

    -- Handle comma for column lists
    if token.type == "comma" and in_select_list then
      if config.comma_position == "trailing" then
        -- Comma stays at end of line, newline after
        -- This is default behavior, handled after adding token
      elseif config.comma_position == "leading" then
        -- Comma starts new line
        needs_newline = true
        extra_indent = 1
      end
    end

    -- Apply newline if needed
    if needs_newline and #current_line > 0 then
      -- Finish current line
      local line_text = table.concat(current_line, "")
      -- Only add if not just whitespace
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}

      -- Start new line with indent
      local indent = get_indent(config, current_indent + extra_indent)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    else
      -- Add space between tokens if needed
      if needs_space_before(prev_token, token, config) then
        table.insert(current_line, " ")
      end
    end

    -- Add the token text
    table.insert(current_line, text)

    -- Handle trailing comma newline in SELECT list
    if token.type == "comma" and in_select_list and config.comma_position == "trailing" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent continuation
      local indent = get_indent(config, 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Handle semicolon - end of statement
    if token.type == "semicolon" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      current_indent = 0
      in_select_list = false
      in_where_clause = false
      join_context = false
    end

    prev_token = token
  end

  -- Don't forget remaining tokens
  if #current_line > 0 then
    local line_text = table.concat(current_line, "")
    if line_text:match("%S") then
      table.insert(result, line_text)
    end
  end

  return table.concat(result, "\n")
end

return Output
