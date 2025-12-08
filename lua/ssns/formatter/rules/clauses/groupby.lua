---@class GroupByRule
---@field name string Rule name
---GROUP BY and ORDER BY clause formatting rules.
---Handles column list formatting, expression handling, ASC/DESC positioning.
local GroupBy = {
  name = "groupby",
}

---Check if token is GROUP keyword
---@param token table
---@return boolean
function GroupBy.is_group(token)
  return token.type == "keyword" and string.upper(token.text) == "GROUP"
end

---Check if token is ORDER keyword
---@param token table
---@return boolean
function GroupBy.is_order(token)
  return token.type == "keyword" and string.upper(token.text) == "ORDER"
end

---Check if token is BY keyword
---@param token table
---@return boolean
function GroupBy.is_by(token)
  return token.type == "keyword" and string.upper(token.text) == "BY"
end

---Check if token is HAVING keyword
---@param token table
---@return boolean
function GroupBy.is_having(token)
  return token.type == "keyword" and string.upper(token.text) == "HAVING"
end

---Check if token is ASC keyword
---@param token table
---@return boolean
function GroupBy.is_asc(token)
  return token.type == "keyword" and string.upper(token.text) == "ASC"
end

---Check if token is DESC keyword
---@param token table
---@return boolean
function GroupBy.is_desc(token)
  return token.type == "keyword" and string.upper(token.text) == "DESC"
end

---Check if token is NULLS keyword
---@param token table
---@return boolean
function GroupBy.is_nulls(token)
  return token.type == "keyword" and string.upper(token.text) == "NULLS"
end

---Check if token is FIRST keyword
---@param token table
---@return boolean
function GroupBy.is_first(token)
  return token.type == "keyword" and string.upper(token.text) == "FIRST"
end

---Check if token is LAST keyword
---@param token table
---@return boolean
function GroupBy.is_last(token)
  return token.type == "keyword" and string.upper(token.text) == "LAST"
end

---Check if token ends the GROUP BY clause
---@param token table
---@return boolean
function GroupBy.is_groupby_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    HAVING = true,
    ORDER = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,
    LIMIT = true,
    OFFSET = true,
  }
  return terminators[upper] == true
end

---Check if token ends the ORDER BY clause
---@param token table
---@return boolean
function GroupBy.is_orderby_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,
    LIMIT = true,
    OFFSET = true,
  }
  return terminators[upper] == true
end

---Parse GROUP BY columns
---@param tokens table[] All tokens
---@param group_idx number Index of GROUP keyword
---@return table[] columns Array of {tokens: table[]}
function GroupBy.parse_groupby_columns(tokens, group_idx)
  local columns = {}
  local idx = group_idx

  -- Skip GROUP BY
  if GroupBy.is_group(tokens[idx]) then
    idx = idx + 1
  end
  if idx <= #tokens and GroupBy.is_by(tokens[idx]) then
    idx = idx + 1
  end

  local current = {tokens = {}}
  local paren_depth = 0

  while idx <= #tokens do
    local token = tokens[idx]

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- End of GROUP BY
    if paren_depth == 0 and (GroupBy.is_groupby_terminator(token) or token.type == "semicolon") then
      if #current.tokens > 0 then
        table.insert(columns, current)
      end
      break
    end

    -- Comma separates columns
    if paren_depth == 0 and token.type == "comma" then
      if #current.tokens > 0 then
        table.insert(columns, current)
        current = {tokens = {}}
      end
    else
      table.insert(current.tokens, token)
    end

    idx = idx + 1
  end

  -- Don't forget the last column
  if #current.tokens > 0 then
    table.insert(columns, current)
  end

  return columns
end

---Parse ORDER BY columns with direction
---@param tokens table[] All tokens
---@param order_idx number Index of ORDER keyword
---@return table[] columns Array of {tokens: table[], direction: string?, nulls: string?}
function GroupBy.parse_orderby_columns(tokens, order_idx)
  local columns = {}
  local idx = order_idx

  -- Skip ORDER BY
  if GroupBy.is_order(tokens[idx]) then
    idx = idx + 1
  end
  if idx <= #tokens and GroupBy.is_by(tokens[idx]) then
    idx = idx + 1
  end

  local current = {
    tokens = {},
    direction = nil,
    nulls = nil,
  }
  local paren_depth = 0

  while idx <= #tokens do
    local token = tokens[idx]

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- End of ORDER BY
    if paren_depth == 0 and (GroupBy.is_orderby_terminator(token) or token.type == "semicolon") then
      if #current.tokens > 0 or current.direction then
        table.insert(columns, current)
      end
      break
    end

    -- Handle ASC/DESC
    if paren_depth == 0 and (GroupBy.is_asc(token) or GroupBy.is_desc(token)) then
      current.direction = string.upper(token.text)
      idx = idx + 1
      -- Check for NULLS FIRST/LAST
      if idx <= #tokens and GroupBy.is_nulls(tokens[idx]) then
        idx = idx + 1
        if idx <= #tokens and (GroupBy.is_first(tokens[idx]) or GroupBy.is_last(tokens[idx])) then
          current.nulls = string.upper(tokens[idx].text)
          idx = idx + 1
        end
      end
      -- Continue without incrementing idx again
      goto continue
    end

    -- Comma separates columns
    if paren_depth == 0 and token.type == "comma" then
      if #current.tokens > 0 or current.direction then
        table.insert(columns, current)
        current = {
          tokens = {},
          direction = nil,
          nulls = nil,
        }
      end
    else
      table.insert(current.tokens, token)
    end

    idx = idx + 1
    ::continue::
  end

  -- Don't forget the last column
  if #current.tokens > 0 or current.direction then
    table.insert(columns, current)
  end

  return columns
end

---Get configuration for GROUP BY/ORDER BY formatting
---@param config FormatterConfig
---@return table groupby_config
function GroupBy.get_config(config)
  return {
    -- GROUP BY config (Phase 2)
    group_by_newline = config.group_by_newline ~= false,  -- default true
    group_by_style = config.group_by_style or "inline",   -- "inline"|"stacked"
    having_newline = config.having_newline ~= false,      -- default true

    -- ORDER BY config (Phase 2)
    order_by_newline = config.order_by_newline ~= false,  -- default true
    order_by_style = config.order_by_style or "inline",   -- "inline"|"stacked"
    order_direction_style = config.order_direction_style or "explicit", -- "always"|"explicit"|"never"

    -- Derived settings
    one_column_per_line = (config.group_by_style == "stacked") or (config.order_by_style == "stacked"),
    max_columns_inline = 5, -- Go multi-line if more columns
    indent_columns = true,
  }
end

---Check if GROUP BY/ORDER BY should be multi-line
---@param columns table[] Parsed columns
---@param max_inline number Maximum columns before going multi-line
---@return boolean
function GroupBy.should_multiline(columns, max_inline)
  max_inline = max_inline or 5
  return #columns > max_inline
end

---Apply formatting to GROUP BY/ORDER BY tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function GroupBy.apply(token, context, config)
  local groupby_config = GroupBy.get_config(config)

  -- Add formatting metadata
  local clause = context.current_clause
  if clause == "GROUP BY" or clause == "GROUP" then
    token.in_groupby_clause = true
    token.groupby_style = groupby_config.group_by_style
  elseif clause == "ORDER BY" or clause == "ORDER" then
    token.in_orderby_clause = true
    token.orderby_style = groupby_config.order_by_style
    token.order_direction_style = groupby_config.order_direction_style
  elseif clause == "HAVING" then
    token.in_having_clause = true
  end

  -- Mark GROUP keyword
  if GroupBy.is_group(token) then
    token.is_groupby_keyword = true
    token.groupby_newline = groupby_config.group_by_newline
    token.groupby_style = groupby_config.group_by_style
  end

  -- Mark ORDER keyword
  if GroupBy.is_order(token) then
    token.is_orderby_keyword = true
    token.orderby_newline = groupby_config.order_by_newline
    token.orderby_style = groupby_config.order_by_style
  end

  -- Mark HAVING keyword
  if GroupBy.is_having(token) then
    token.is_having_keyword = true
    token.having_newline = groupby_config.having_newline
  end

  -- Mark direction tokens
  if GroupBy.is_asc(token) then
    token.is_sort_direction = true
    token.order_direction_style = groupby_config.order_direction_style
  elseif GroupBy.is_desc(token) then
    token.is_sort_direction = true
    token.order_direction_style = groupby_config.order_direction_style
  end

  return token
end

return GroupBy
