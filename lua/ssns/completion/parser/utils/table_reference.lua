---Table reference parser for SQL FROM/JOIN clauses
---Parses qualified table names with optional aliases and hints
---
---@module ssns.completion.parser.utils.table_reference

local Helpers = require('ssns.completion.parser.utils.helpers')
local QualifiedName = require('ssns.completion.parser.utils.qualified_name')
local AliasParser = require('ssns.completion.parser.utils.alias')

local TableReferenceParser = {}

---Parse a table reference with optional alias
---@param state ParserState
---@param scope ScopeContext? Optional scope for CTE detection
---@return TableReference?
function TableReferenceParser.parse(state, scope)
  local qualified = QualifiedName.parse(state)
  if not qualified then
    return nil
  end

  local alias = AliasParser.parse(state)

  -- Handle table hints: WITH (NOLOCK, READPAST, etc.)
  -- SQL Server allows hints between table name and alias
  if not alias and state:is_keyword("WITH") then
    state:advance()  -- consume WITH
    if state:is_type("paren_open") then
      local hint_depth = 1
      state:advance()  -- consume (
      while state:current() and hint_depth > 0 do
        if state:is_type("paren_open") then
          hint_depth = hint_depth + 1
        elseif state:is_type("paren_close") then
          hint_depth = hint_depth - 1
        end
        state:advance()
      end
    end
    -- Try to parse alias after the hint
    alias = AliasParser.parse(state)
  end

  -- Check if table name refers to a CTE (using scope if available)
  local is_cte = false
  if scope and scope.is_cte then
    is_cte = scope:is_cte(qualified.name)
  end

  return {
    server = qualified.server,
    database = qualified.database,
    schema = qualified.schema,
    name = qualified.name,
    alias = alias,
    is_temp = Helpers.is_temp_table(qualified.name),
    is_global_temp = Helpers.is_global_temp_table(qualified.name),
    is_table_variable = Helpers.is_table_variable(qualified.name),
    is_cte = is_cte,
  }
end

---Parse a table reference using legacy known_ctes table (backward compatibility)
---@param state ParserState
---@param known_ctes table<string, boolean>? Legacy CTE tracking table
---@return TableReference?
function TableReferenceParser.parse_legacy(state, known_ctes)
  local qualified = QualifiedName.parse(state)
  if not qualified then
    return nil
  end

  local alias = AliasParser.parse(state)

  -- Handle table hints: WITH (NOLOCK, READPAST, etc.)
  if not alias and state:is_keyword("WITH") then
    state:advance()  -- consume WITH
    if state:is_type("paren_open") then
      local hint_depth = 1
      state:advance()  -- consume (
      while state:current() and hint_depth > 0 do
        if state:is_type("paren_open") then
          hint_depth = hint_depth + 1
        elseif state:is_type("paren_close") then
          hint_depth = hint_depth - 1
        end
        state:advance()
      end
    end
    alias = AliasParser.parse(state)
  end

  return {
    server = qualified.server,
    database = qualified.database,
    schema = qualified.schema,
    name = qualified.name,
    alias = alias,
    is_temp = Helpers.is_temp_table(qualified.name),
    is_global_temp = Helpers.is_global_temp_table(qualified.name),
    is_table_variable = Helpers.is_table_variable(qualified.name),
    is_cte = known_ctes and known_ctes[qualified.name] == true or false,
  }
end

return TableReferenceParser
