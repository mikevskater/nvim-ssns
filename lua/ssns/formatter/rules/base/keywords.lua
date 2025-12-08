---@class KeywordsRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Keyword and casing rules for SQL formatting.
---Handles keyword_case, function_case, datatype_case, identifier_case, alias_case.
---Uses the tokenizer's keyword categories as the single source of truth.
local Keywords = {
  name = "keywords",
}

---Apply keyword case transformation
---@param text string Keyword text
---@param case_style string "upper"|"lower"|"preserve"
---@return string
function Keywords.apply_case(text, case_style)
  if case_style == "upper" then
    return string.upper(text)
  elseif case_style == "lower" then
    return string.lower(text)
  else
    return text
  end
end

---Check if token is a built-in function
---Uses keyword_category from tokenizer (single source of truth)
---@param token Token
---@return boolean
function Keywords.is_function(token)
  -- The tokenizer already categorizes functions via keyword_category
  return token.keyword_category == "function"
end

---Check if token is a data type
---Uses keyword_category from tokenizer (single source of truth)
---@param token Token
---@return boolean
function Keywords.is_datatype(token)
  -- The tokenizer already categorizes datatypes via keyword_category
  return token.keyword_category == "datatype"
end

---Check if a token is a keyword that should have casing applied
---@param token Token
---@return boolean
function Keywords.should_transform(token)
  local keyword_types = {
    keyword = true,
    go = true,
  }
  return keyword_types[token.type] == true
end

---Get casing configuration
---@param config FormatterConfig
---@return table casing_config
function Keywords.get_config(config)
  return {
    keyword_case = config.keyword_case or "upper",
    function_case = config.function_case or "upper",
    datatype_case = config.datatype_case or "upper",
    identifier_case = config.identifier_case or "preserve",
    alias_case = config.alias_case or "preserve",
  }
end

---Apply keyword casing rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Keywords.apply(token, context, config)
  local casing = Keywords.get_config(config)

  -- Check for data type (highest priority for type keywords)
  if Keywords.is_datatype(token) then
    token.text = Keywords.apply_case(token.text, casing.datatype_case)
    token.is_datatype = true
    return token
  end

  -- Check for built-in function
  if Keywords.is_function(token) then
    token.text = Keywords.apply_case(token.text, casing.function_case)
    token.is_function = true
    return token
  end

  -- Regular keyword
  if Keywords.should_transform(token) then
    token.text = Keywords.apply_case(token.text, casing.keyword_case)
    return token
  end

  -- Identifier casing (table/column names)
  if token.type == "identifier" then
    token.text = Keywords.apply_case(token.text, casing.identifier_case)
    return token
  end

  -- Alias casing (marked by context)
  if token.is_alias then
    token.text = Keywords.apply_case(token.text, casing.alias_case)
    return token
  end

  return token
end

return Keywords
