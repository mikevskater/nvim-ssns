---@class SpacingRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Whitespace and spacing rules for SQL formatting.
---Handles operator_spacing, parenthesis_spacing, comma_spacing, semicolon_spacing,
---bracket_spacing, equals_spacing, concatenation_spacing, comparison_spacing.
local Spacing = {
  name = "spacing",
}

-- Comparison operators
local COMPARISON_OPERATORS = {
  ["<>"] = true,
  ["!="] = true,
  [">="] = true,
  ["<="] = true,
  [">"] = true,
  ["<"] = true,
  ["!<"] = true,
  ["!>"] = true,
}

-- Assignment/equality operators
local EQUALS_OPERATORS = {
  ["="] = true,
}

-- Concatenation operators
local CONCAT_OPERATORS = {
  ["+"] = true,  -- SQL Server string concat
  ["||"] = true, -- ANSI SQL string concat
}

-- Arithmetic operators
local ARITHMETIC_OPERATORS = {
  ["+"] = true,
  ["-"] = true,
  ["*"] = true,
  ["/"] = true,
  ["%"] = true,
}

---Get spacing configuration
---@param config FormatterConfig
---@return table spacing_config
function Spacing.get_config(config)
  return {
    operator_spacing = config.operator_spacing ~= false,      -- default true
    parenthesis_spacing = config.parenthesis_spacing or false,
    comma_spacing = config.comma_spacing or "after",          -- "before"|"after"|"both"|"none"
    semicolon_spacing = config.semicolon_spacing or false,
    bracket_spacing = config.bracket_spacing or false,
    equals_spacing = config.equals_spacing ~= false,          -- default true
    concatenation_spacing = config.concatenation_spacing ~= false, -- default true
    comparison_spacing = config.comparison_spacing ~= false,  -- default true
  }
end

---Check if a token is a comparison operator
---@param token Token
---@return boolean
function Spacing.is_comparison_operator(token)
  if token.type ~= "operator" then
    return false
  end
  return COMPARISON_OPERATORS[token.text] == true
end

---Check if a token is an equals operator
---@param token Token
---@return boolean
function Spacing.is_equals_operator(token)
  if token.type ~= "operator" then
    return false
  end
  return EQUALS_OPERATORS[token.text] == true
end

---Check if a token is a concatenation operator
---@param token Token
---@return boolean
function Spacing.is_concat_operator(token)
  if token.type ~= "operator" then
    return false
  end
  return CONCAT_OPERATORS[token.text] == true
end

---Check if a token is an arithmetic operator
---@param token Token
---@return boolean
function Spacing.is_arithmetic_operator(token)
  if token.type ~= "operator" then
    return false
  end
  return ARITHMETIC_OPERATORS[token.text] == true
end

---Check if a token is any spaced operator based on config
---@param token Token
---@param spacing_config table
---@return boolean
function Spacing.should_space_operator(token, spacing_config)
  if token.type ~= "operator" then
    return false
  end

  -- Check specific operator types
  if Spacing.is_equals_operator(token) and spacing_config.equals_spacing then
    return true
  end

  if Spacing.is_comparison_operator(token) and spacing_config.comparison_spacing then
    return true
  end

  if Spacing.is_concat_operator(token) and spacing_config.concatenation_spacing then
    return true
  end

  -- Arithmetic operators follow general operator_spacing
  if Spacing.is_arithmetic_operator(token) and spacing_config.operator_spacing then
    return true
  end

  return false
end

---Determine required whitespace before a token
---@param prev Token|nil Previous token
---@param curr Token Current token
---@param config FormatterConfig
---@return string whitespace
function Spacing.get_before(prev, curr, config)
  if not prev then
    return ""
  end

  local spacing_config = Spacing.get_config(config)

  -- No space after opening paren (unless configured)
  if prev.type == "paren_open" then
    if spacing_config.parenthesis_spacing then
      return " "
    end
    return ""
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    if spacing_config.parenthesis_spacing then
      return " "
    end
    return ""
  end

  -- Bracket spacing (inside [] for identifiers)
  if prev.type == "bracket_open" then
    if spacing_config.bracket_spacing then
      return " "
    end
    return ""
  end

  if curr.type == "bracket_close" then
    if spacing_config.bracket_spacing then
      return " "
    end
    return ""
  end

  -- No space around dots (qualified names)
  if prev.type == "dot" or curr.type == "dot" then
    return ""
  end

  -- Comma spacing based on config
  if curr.type == "comma" then
    local comma_mode = spacing_config.comma_spacing
    if comma_mode == "before" or comma_mode == "both" then
      return " "
    end
    return ""
  end

  if prev.type == "comma" then
    local comma_mode = spacing_config.comma_spacing
    if comma_mode == "after" or comma_mode == "both" then
      return " "
    end
    if comma_mode == "none" then
      return ""
    end
    return " " -- default to space after comma
  end

  -- Semicolon spacing
  if curr.type == "semicolon" then
    if spacing_config.semicolon_spacing then
      return " "
    end
    return ""
  end

  -- Space around operators based on specific config
  if Spacing.should_space_operator(prev, spacing_config) or
     Spacing.should_space_operator(curr, spacing_config) then
    return " "
  end

  -- No space after @
  if prev.type == "at" then
    return ""
  end

  -- Space between word tokens
  local word_types = {
    keyword = true,
    identifier = true,
    bracket_id = true,
    number = true,
    string = true,
    global_variable = true,
    system_procedure = true,
    temp_table = true,
  }

  if word_types[prev.type] and (word_types[curr.type] or curr.type == "star") then
    return " "
  end

  -- Space after star if followed by keyword/identifier
  if prev.type == "star" and word_types[curr.type] then
    return " "
  end

  return ""
end

---Apply spacing rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Spacing.apply(token, context, config)
  local spacing_config = Spacing.get_config(config)

  -- Add spacing metadata to token
  if token.type == "comma" then
    token.comma_spacing = spacing_config.comma_spacing
  end

  if token.type == "semicolon" then
    token.semicolon_spacing = spacing_config.semicolon_spacing
  end

  if token.type == "operator" then
    token.operator_spacing = spacing_config.operator_spacing
    token.equals_spacing = spacing_config.equals_spacing
    token.comparison_spacing = spacing_config.comparison_spacing
    token.concatenation_spacing = spacing_config.concatenation_spacing
  end

  return token
end

return Spacing
