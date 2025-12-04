--- DELETE statement handler
--- Parses DELETE statements including simple DELETE and extended DELETE with FROM
---
--- Syntax variants:
--- 1. DELETE FROM table WHERE ... (simple)
--- 2. DELETE alias FROM table alias WHERE ... (extended with alias)
--- 3. DELETE table FROM table alias WHERE ... (table name as target)
---
---@module ssns.completion.parser.statements.delete

require('ssns.completion.parser.types')
local BaseStatement = require('ssns.completion.parser.statements.base')
local FromClauseParser = require('ssns.completion.parser.clauses.from_clause')

local DeleteStatement = {}

---Parse a DELETE statement
---
---@param state ParserState Token navigation state (positioned at DELETE keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function DeleteStatement.parse(state, scope, temp_tables)
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("DELETE", start_token, state.go_batch_index)

  scope.statement_type = "DELETE"
  state:advance()  -- consume DELETE

  -- Handle DELETE TOP (n) [PERCENT] clause
  DeleteStatement._skip_top_clause(state)

  -- Build known_ctes for table reference parsing
  local known_ctes = {}
  if scope then
    for name, _ in pairs(scope.ctes) do
      known_ctes[name] = true
    end
  end

  -- Handle DELETE syntax variants
  if state:is_keyword("FROM") then
    -- Simple DELETE FROM table
    state:advance()  -- consume FROM
    local table_ref = state:parse_table_reference(known_ctes)
    if table_ref then
      table.insert(chunk.tables, table_ref)
      scope:add_table(table_ref)
    end
  elseif state:current() and (state:current().type == "identifier" or state:current().type == "bracket_id") then
    -- Extended DELETE: DELETE alias/table FROM table alias
    -- Parse the delete target (could be alias or table name)
    local delete_target = state:parse_table_reference(known_ctes)
    chunk.delete_target = delete_target
    -- The FROM clause will be parsed later in the main loop
  end

  return chunk
end

---Skip TOP (n) [PERCENT] clause if present
---@param state ParserState
function DeleteStatement._skip_top_clause(state)
  if not state:is_keyword("TOP") then
    return
  end

  state:advance()  -- consume TOP

  -- Skip the (n) or (n) PERCENT
  if state:is_type("paren_open") then
    local depth = 1
    state:advance()
    while state:current() and depth > 0 do
      if state:is_type("paren_open") then
        depth = depth + 1
      elseif state:is_type("paren_close") then
        depth = depth - 1
      end
      state:advance()
    end
  end

  -- Skip optional PERCENT keyword
  if state:is_keyword("PERCENT") then
    state:advance()
  end
end

---Parse FROM clause for extended DELETE syntax
---Called by the main loop when FROM is encountered after DELETE alias
---
---@param state ParserState Token navigation state (positioned at FROM keyword)
---@param chunk StatementChunk The DELETE chunk being built
---@param scope ScopeContext Scope context
function DeleteStatement.parse_from(state, chunk, scope)
  local from_token = state:current()
  local result = FromClauseParser.parse(state, scope, from_token)

  -- Copy tables from result (replace any existing)
  chunk.tables = result.tables

  -- Store clause positions
  if result.clause_position then
    chunk.clause_positions["from"] = result.clause_position
  end

  -- Store individual JOIN positions
  if result.join_positions then
    for i, pos in ipairs(result.join_positions) do
      chunk.clause_positions["join_" .. i] = pos
    end
  end

  -- Store individual ON positions
  if result.on_positions then
    for i, pos in ipairs(result.on_positions) do
      chunk.clause_positions["on_" .. i] = pos
    end
  end

  -- Mark that we found a FROM clause
  chunk.has_from_clause = true

  -- Add tables to scope
  for _, table_ref in ipairs(result.tables) do
    scope:add_table(table_ref)
  end
end

return DeleteStatement
