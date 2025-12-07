---@class DmlRule
---@field name string Rule name
---INSERT, UPDATE, DELETE statement formatting rules.
---Handles column lists, VALUES formatting, SET clause formatting.
local Dml = {
  name = "dml",
}

-- =============================================================================
-- INSERT Statement Helpers
-- =============================================================================

---Check if token is INSERT keyword
---@param token table
---@return boolean
function Dml.is_insert(token)
  return token.type == "keyword" and string.upper(token.text) == "INSERT"
end

---Check if token is INTO keyword
---@param token table
---@return boolean
function Dml.is_into(token)
  return token.type == "keyword" and string.upper(token.text) == "INTO"
end

---Check if token is VALUES keyword
---@param token table
---@return boolean
function Dml.is_values(token)
  return token.type == "keyword" and string.upper(token.text) == "VALUES"
end

---Check if token is DEFAULT keyword
---@param token table
---@return boolean
function Dml.is_default(token)
  return token.type == "keyword" and string.upper(token.text) == "DEFAULT"
end

---Check if token is OUTPUT keyword
---@param token table
---@return boolean
function Dml.is_output(token)
  return token.type == "keyword" and string.upper(token.text) == "OUTPUT"
end

---Parse INSERT column list
---@param tokens table[] All tokens
---@param insert_idx number Index of INSERT keyword
---@return table|nil column_list {start_idx: number, end_idx: number, columns: string[]}
function Dml.parse_insert_columns(tokens, insert_idx)
  local idx = insert_idx + 1

  -- Skip INTO
  if idx <= #tokens and Dml.is_into(tokens[idx]) then
    idx = idx + 1
  end

  -- Skip table name (may be schema.table)
  while idx <= #tokens do
    local token = tokens[idx]
    if token.type == "identifier" or token.type == "bracket_id" or token.type == "dot" then
      idx = idx + 1
    else
      break
    end
  end

  -- Look for opening paren (column list)
  if idx > #tokens or tokens[idx].type ~= "paren_open" then
    return nil -- No column list
  end

  local start_idx = idx
  local paren_depth = 1
  idx = idx + 1

  local columns = {}
  local current_col = ""

  while idx <= #tokens and paren_depth > 0 do
    local token = tokens[idx]

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        if current_col ~= "" then
          table.insert(columns, current_col)
        end
        return {
          start_idx = start_idx,
          end_idx = idx,
          columns = columns,
        }
      end
    elseif token.type == "comma" and paren_depth == 1 then
      if current_col ~= "" then
        table.insert(columns, current_col)
        current_col = ""
      end
    else
      current_col = current_col .. token.text
    end

    idx = idx + 1
  end

  return nil
end

---Parse VALUES clause
---@param tokens table[] All tokens
---@param values_idx number Index of VALUES keyword
---@return table[] value_rows Array of {start_idx: number, end_idx: number, values: table[]}
function Dml.parse_values(tokens, values_idx)
  local rows = {}
  local idx = values_idx + 1

  while idx <= #tokens do
    -- Look for opening paren (value row)
    while idx <= #tokens and tokens[idx].type ~= "paren_open" do
      if tokens[idx].type == "semicolon" then
        return rows
      end
      idx = idx + 1
    end

    if idx > #tokens then
      break
    end

    local row = {
      start_idx = idx,
      end_idx = nil,
      values = {},
    }

    local paren_depth = 1
    idx = idx + 1
    local current_value = {}

    while idx <= #tokens and paren_depth > 0 do
      local token = tokens[idx]

      if token.type == "paren_open" then
        paren_depth = paren_depth + 1
        table.insert(current_value, token)
      elseif token.type == "paren_close" then
        paren_depth = paren_depth - 1
        if paren_depth == 0 then
          if #current_value > 0 then
            table.insert(row.values, current_value)
          end
          row.end_idx = idx
        else
          table.insert(current_value, token)
        end
      elseif token.type == "comma" and paren_depth == 1 then
        if #current_value > 0 then
          table.insert(row.values, current_value)
          current_value = {}
        end
      else
        table.insert(current_value, token)
      end

      idx = idx + 1
    end

    if row.end_idx then
      table.insert(rows, row)
    end

    -- Check for comma (more rows) or end
    if idx <= #tokens and tokens[idx].type == "comma" then
      idx = idx + 1
    else
      break
    end
  end

  return rows
end

-- =============================================================================
-- UPDATE Statement Helpers
-- =============================================================================

---Check if token is UPDATE keyword
---@param token table
---@return boolean
function Dml.is_update(token)
  return token.type == "keyword" and string.upper(token.text) == "UPDATE"
end

---Check if token is SET keyword
---@param token table
---@return boolean
function Dml.is_set(token)
  return token.type == "keyword" and string.upper(token.text) == "SET"
end

---Parse SET clause assignments
---@param tokens table[] All tokens
---@param set_idx number Index of SET keyword
---@return table[] assignments Array of {column: string, tokens: table[]}
function Dml.parse_set_assignments(tokens, set_idx)
  local assignments = {}
  local idx = set_idx + 1

  local current = {
    column = nil,
    tokens = {},
  }
  local paren_depth = 0
  local case_depth = 0
  local past_equals = false

  while idx <= #tokens do
    local token = tokens[idx]

    -- Track nesting
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    elseif token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "CASE" then
        case_depth = case_depth + 1
      elseif upper == "END" then
        case_depth = math.max(0, case_depth - 1)
      end
    end

    -- End of SET clause
    if paren_depth == 0 and case_depth == 0 then
      if token.type == "keyword" then
        local upper = string.upper(token.text)
        if upper == "FROM" or upper == "WHERE" or upper == "OUTPUT" then
          if #current.tokens > 0 or current.column then
            table.insert(assignments, current)
          end
          break
        end
      end
      if token.type == "semicolon" then
        if #current.tokens > 0 or current.column then
          table.insert(assignments, current)
        end
        break
      end
    end

    -- Comma at depth 0 separates assignments
    if paren_depth == 0 and case_depth == 0 and token.type == "comma" then
      if #current.tokens > 0 or current.column then
        table.insert(assignments, current)
        current = {
          column = nil,
          tokens = {},
        }
        past_equals = false
      end
      idx = idx + 1
      goto continue
    end

    -- Track column name (before =)
    if not past_equals then
      if token.type == "operator" and token.text == "=" then
        past_equals = true
      elseif token.type == "identifier" or token.type == "bracket_id" then
        current.column = token.text
      elseif token.type == "dot" then
        -- Handle schema.column
        current.column = (current.column or "") .. "."
      end
    else
      table.insert(current.tokens, token)
    end

    idx = idx + 1
    ::continue::
  end

  -- Don't forget the last assignment
  if #current.tokens > 0 or current.column then
    table.insert(assignments, current)
  end

  return assignments
end

-- =============================================================================
-- DELETE Statement Helpers
-- =============================================================================

---Check if token is DELETE keyword
---@param token table
---@return boolean
function Dml.is_delete(token)
  return token.type == "keyword" and string.upper(token.text) == "DELETE"
end

---Check if token is TRUNCATE keyword
---@param token table
---@return boolean
function Dml.is_truncate(token)
  return token.type == "keyword" and string.upper(token.text) == "TRUNCATE"
end

-- =============================================================================
-- MERGE Statement Helpers
-- =============================================================================

---Check if token is MERGE keyword
---@param token table
---@return boolean
function Dml.is_merge(token)
  return token.type == "keyword" and string.upper(token.text) == "MERGE"
end

---Check if token is USING keyword
---@param token table
---@return boolean
function Dml.is_using(token)
  return token.type == "keyword" and string.upper(token.text) == "USING"
end

---Check if token is MATCHED keyword
---@param token table
---@return boolean
function Dml.is_matched(token)
  return token.type == "keyword" and string.upper(token.text) == "MATCHED"
end

---Check if token is WHEN keyword
---@param token table
---@return boolean
function Dml.is_when(token)
  return token.type == "keyword" and string.upper(token.text) == "WHEN"
end

---Check if token is THEN keyword
---@param token table
---@return boolean
function Dml.is_then(token)
  return token.type == "keyword" and string.upper(token.text) == "THEN"
end

-- =============================================================================
-- Configuration and Application
-- =============================================================================

---Get configuration for DML formatting
---@param config FormatterConfig
---@return table dml_config
function Dml.get_config(config)
  return {
    values_per_line = true, -- Each value row on its own line
    set_per_line = true, -- Each SET assignment on its own line
    indent_values = true,
    indent_set = true,
    max_inline_values = 3, -- Go multi-line if more values per row
  }
end

---Check if VALUES clause should be multi-line
---@param value_rows table[] Parsed value rows
---@param max_inline number Maximum values per row before going multi-line
---@return boolean
function Dml.should_multiline_values(value_rows, max_inline)
  max_inline = max_inline or 3

  -- Multiple rows always multi-line
  if #value_rows > 1 then
    return true
  end

  -- Check single row
  if #value_rows == 1 and #value_rows[1].values > max_inline then
    return true
  end

  return false
end

---Apply formatting to DML tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Dml.apply(token, context, config)
  local clause = context.current_clause

  -- Mark INSERT-related tokens
  if Dml.is_insert(token) then
    token.is_insert_keyword = true
  elseif Dml.is_values(token) then
    token.is_values_keyword = true
  end

  -- Mark UPDATE-related tokens
  if Dml.is_update(token) then
    token.is_update_keyword = true
  elseif Dml.is_set(token) then
    token.is_set_keyword = true
  end

  -- Mark DELETE-related tokens
  if Dml.is_delete(token) then
    token.is_delete_keyword = true
  end

  -- Mark MERGE-related tokens
  if Dml.is_merge(token) then
    token.is_merge_keyword = true
  end

  -- Track clause context
  if clause == "INSERT" then
    token.in_insert_statement = true
  elseif clause == "UPDATE" then
    token.in_update_statement = true
  elseif clause == "DELETE" then
    token.in_delete_statement = true
  elseif clause == "SET" then
    token.in_set_clause = true
  elseif clause == "VALUES" then
    token.in_values_clause = true
  end

  return token
end

return Dml
