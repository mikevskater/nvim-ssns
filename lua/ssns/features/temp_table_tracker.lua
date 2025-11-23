---Temp table tracker for SSNS
---Handles SELECT * INTO #temp and CREATE TABLE #temp (...) statements
---Integrates with asterisk expansion module for column metadata
---@class TempTableTracker
local TempTableTracker = {}

local Cache = require('ssns.cache')
local ExpandAsterisk = require('ssns.features.expand_asterisk')
local ScopeTracker = require('ssns.completion.metadata.scope_tracker')
local Debug = require('ssns.debug')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[TEMP_TABLE_TRACKER] " .. message)
  end
end

---Find all temp table creation statements in buffer
---Returns array of temp table statements with line numbers and types
---@param buffer_lines string[] Array of buffer lines
---@return table[] statements Array of {type, line, statement, statement_end_line}
function TempTableTracker.find_temp_table_statements(buffer_lines)
  debug_log("find_temp_table_statements: scanning " .. #buffer_lines .. " lines")

  local statements = {}
  local i = 1

  while i <= #buffer_lines do
    local line = buffer_lines[i]
    local line_upper = line:upper()

    -- Check for SELECT statement (may be SELECT INTO on single or multiple lines)
    if line_upper:match("^%s*SELECT%s+") then
      -- Collect the full statement across multiple lines
      local statement_lines = {line}
      local statement_end_line = i
      local j = i + 1

      while j <= #buffer_lines do
        local next_line = buffer_lines[j]
        local next_line_upper = next_line:upper()

        -- Stop at GO, semicolon on own line, or next SELECT/CREATE/ALTER/DROP
        if next_line_upper:match("^%s*GO%s*$") or
           next_line_upper:match("^%s*;%s*$") or
           next_line_upper:match("^%s*SELECT%s+") or
           next_line_upper:match("^%s*CREATE%s+") or
           next_line_upper:match("^%s*ALTER%s+") or
           next_line_upper:match("^%s*DROP%s+") then
          break
        end

        table.insert(statement_lines, next_line)
        statement_end_line = j

        -- Stop if line ends with semicolon
        if next_line:match(";%s*$") then
          break
        end

        j = j + 1
      end

      local full_statement = table.concat(statement_lines, "\n")
      local full_statement_upper = full_statement:upper()

      -- Check if this is a SELECT INTO statement (with or without brackets around table name)
      -- Pattern: SELECT ... INTO [#]{1,2}[identifier] FROM ...
      if full_statement_upper:match("SELECT.+INTO%s+%[?##?[%w_]+%]?") then
        debug_log(string.format("Found SELECT INTO at line %d", i))

        table.insert(statements, {
          type = "select_into",
          line = i,
          statement = full_statement,
          statement_end_line = statement_end_line,
        })
      end

      -- Skip to end of this statement
      i = statement_end_line + 1

    -- Check for CREATE TABLE pattern
    -- Pattern: CREATE TABLE [#]{1,2}[identifier] (...)
    elseif line_upper:match("CREATE%s+TABLE%s+##?[%w_]+") then
      debug_log(string.format("Found CREATE TABLE at line %d", i))

      -- Extract the full statement (continue until closing parenthesis)
      local statement_lines = {line}
      local statement_end_line = i
      local paren_count = 0

      -- Count parentheses in first line
      for c in line:gmatch(".") do
        if c == "(" then
          paren_count = paren_count + 1
        elseif c == ")" then
          paren_count = paren_count - 1
        end
      end

      -- If parentheses not balanced, continue to next lines
      local j = i + 1
      while j <= #buffer_lines and paren_count > 0 do
        local next_line = buffer_lines[j]
        table.insert(statement_lines, next_line)
        statement_end_line = j

        -- Count parentheses
        for c in next_line:gmatch(".") do
          if c == "(" then
            paren_count = paren_count + 1
          elseif c == ")" then
            paren_count = paren_count - 1
          end
        end

        j = j + 1
      end

      local full_statement = table.concat(statement_lines, "\n")

      table.insert(statements, {
        type = "create_table",
        line = i,
        statement = full_statement,
        statement_end_line = statement_end_line,
      })

      -- Skip to end of this statement
      i = statement_end_line + 1
    else
      i = i + 1
    end
  end

  debug_log(string.format("Found %d temp table statements", #statements))
  return statements
end

---Extract temp table name and type from statement
---@param statement string SQL statement
---@return string? temp_table_name Name of temp table (#temp or ##temp)
---@return string? temp_table_type Type: "local" (#) or "global" (##)
function TempTableTracker.extract_temp_table_name(statement)
  -- Pattern: INTO [#name] or INTO #name or CREATE TABLE [#name] or CREATE TABLE #name
  -- First try to match with brackets
  local name_match = statement:match("INTO%s+%[?(##?[%w_]+)%]?") or
                     statement:match("CREATE%s+TABLE%s+%[?(##?[%w_]+)%]?")

  if not name_match then
    return nil, nil
  end

  -- Clean up brackets if present (they might be part of the match)
  name_match = name_match:gsub("%[", ""):gsub("%]", "")

  -- Determine type: local (#) or global (##)
  local temp_type = name_match:match("^##") and "global" or "local"

  debug_log(string.format("Extracted temp table: %s (type: %s)", name_match, temp_type))
  return name_match, temp_type
end

---Parse SELECT column list (when not using asterisk)
---@param select_clause string The SELECT portion (e.g., "col1, col2 AS alias, col3")
---@return table[] columns Array of {name, data_type, ordinal_position}
function TempTableTracker.parse_select_columns(select_clause)
  debug_log("parse_select_columns: " .. select_clause:sub(1, 100))

  local columns = {}
  local ordinal = 1

  -- Split by comma (handle nested parentheses)
  local parts = {}
  local current_part = ""
  local paren_depth = 0

  for i = 1, #select_clause do
    local char = select_clause:sub(i, i)

    if char == "(" then
      paren_depth = paren_depth + 1
      current_part = current_part .. char
    elseif char == ")" then
      paren_depth = paren_depth - 1
      current_part = current_part .. char
    elseif char == "," and paren_depth == 0 then
      table.insert(parts, current_part)
      current_part = ""
    else
      current_part = current_part .. char
    end
  end

  -- Add last part
  if #current_part > 0 then
    table.insert(parts, current_part)
  end

  -- Parse each column expression
  for _, part in ipairs(parts) do
    local trimmed = part:match("^%s*(.-)%s*$")

    -- Check for AS alias
    local alias = trimmed:match("%s+[Aa][Ss]%s+([%w_]+)%s*$")

    local col_name
    if alias then
      -- Use alias as column name
      col_name = alias
    else
      -- Extract column identifier (handle table.column syntax)
      local identifier = trimmed:match("([%w_]+)%s*$")
      if identifier then
        col_name = identifier
      else
        -- Complex expression, use placeholder
        col_name = "expr" .. ordinal
      end
    end

    table.insert(columns, {
      name = col_name,
      data_type = "unknown",  -- Would need execution to infer
      ordinal_position = ordinal,
    })

    ordinal = ordinal + 1
  end

  debug_log(string.format("Parsed %d columns from SELECT clause", #columns))
  return columns
end

---Extract columns from SELECT * INTO statement using asterisk expansion
---@param statement string SQL statement
---@param bufnr number Buffer number
---@param connection table Connection context
---@return table result {success, temp_table_name, temp_table_type, columns, error}
function TempTableTracker.extract_columns_from_select_into(statement, bufnr, connection)
  debug_log("extract_columns_from_select_into")

  local result = {
    success = false,
    temp_table_name = nil,
    temp_table_type = nil,
    columns = {},
    error = nil,
  }

  -- Extract temp table name
  local temp_name, temp_type = TempTableTracker.extract_temp_table_name(statement)
  if not temp_name then
    result.error = "Could not extract temp table name from statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  result.temp_table_name = temp_name
  result.temp_table_type = temp_type

  -- Check if SELECT uses asterisk
  local select_clause = statement:match("SELECT%s+(.-)%s+INTO")
  if not select_clause then
    result.error = "Could not extract SELECT clause from statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  -- Check if asterisk is present
  local has_asterisk = select_clause:match("%*")

  if has_asterisk then
    debug_log("SELECT uses asterisk, using ExpandAsterisk module")

    -- Use ExpandAsterisk to get columns
    -- First, build scope tree
    local success, scope_tree = pcall(function()
      return ScopeTracker.build_scope_tree(statement, bufnr)
    end)

    if not success or not scope_tree then
      result.error = "Failed to parse query structure for asterisk expansion"
      debug_log("ERROR: " .. result.error)
      return result
    end

    -- Find asterisk position in statement
    -- (We need line and column for ExpandAsterisk)
    local lines = vim.split(statement, "\n")
    local asterisk_pos = nil

    for line_idx, line in ipairs(lines) do
      local col = line:find("%*", 1, true)
      if col then
        asterisk_pos = {line_idx, col - 1}  -- 1-indexed row, 0-indexed col
        break
      end
    end

    if not asterisk_pos then
      result.error = "Could not locate asterisk in SELECT clause"
      debug_log("ERROR: " .. result.error)
      return result
    end

    -- Expand asterisk
    local expand_result = ExpandAsterisk.expand_asterisk_in_context(
      bufnr,
      connection,
      asterisk_pos,
      statement,
      scope_tree
    )

    if not expand_result.success then
      result.error = "Asterisk expansion failed: " .. (expand_result.error or "unknown error")
      debug_log("ERROR: " .. result.error)
      return result
    end

    -- Convert ExpandAsterisk columns to temp table columns
    for i, col in ipairs(expand_result.columns) do
      table.insert(result.columns, {
        name = col.name,
        data_type = col.data_type or "unknown",
        ordinal_position = i,
      })
    end

    debug_log(string.format("Extracted %d columns from asterisk expansion", #result.columns))
  else
    debug_log("SELECT uses explicit columns, parsing manually")

    -- Parse explicit column list
    result.columns = TempTableTracker.parse_select_columns(select_clause)
  end

  result.success = true
  return result
end

---Extract columns from CREATE TABLE #temp (...) statement
---@param statement string CREATE TABLE statement
---@return table result {success, temp_table_name, temp_table_type, columns, error}
function TempTableTracker.extract_columns_from_create_table(statement)
  debug_log("extract_columns_from_create_table")

  local result = {
    success = false,
    temp_table_name = nil,
    temp_table_type = nil,
    columns = {},
    error = nil,
  }

  -- Extract temp table name
  local temp_name, temp_type = TempTableTracker.extract_temp_table_name(statement)
  if not temp_name then
    result.error = "Could not extract temp table name from statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  result.temp_table_name = temp_name
  result.temp_table_type = temp_type

  -- Extract column definitions from (...) - need to match balanced parentheses
  -- Find the opening parenthesis after the table name
  local after_table_name = statement:match("CREATE%s+TABLE%s+%[?##?[%w_]+%]?%s*(.*)$")
  if not after_table_name then
    result.error = "Could not find column definitions in CREATE TABLE statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  -- Find matching parentheses
  local paren_start = after_table_name:find("%(")
  if not paren_start then
    result.error = "Could not find opening parenthesis in CREATE TABLE statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  -- Extract content between balanced parentheses
  local column_defs = ""
  local paren_depth = 0
  local in_column_list = false

  for i = paren_start, #after_table_name do
    local char = after_table_name:sub(i, i)

    if char == "(" then
      paren_depth = paren_depth + 1
      if paren_depth == 1 then
        in_column_list = true
      else
        column_defs = column_defs .. char
      end
    elseif char == ")" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        break
      else
        column_defs = column_defs .. char
      end
    elseif in_column_list then
      column_defs = column_defs .. char
    end
  end

  if not column_defs or #column_defs == 0 then
    result.error = "Could not extract column definitions from CREATE TABLE statement"
    debug_log("ERROR: " .. result.error)
    return result
  end

  debug_log("Column definitions: " .. column_defs:sub(1, 100))

  -- Split by comma (handle nested parentheses for constraints)
  local parts = {}
  local current_part = ""
  local paren_depth = 0

  for i = 1, #column_defs do
    local char = column_defs:sub(i, i)

    if char == "(" then
      paren_depth = paren_depth + 1
      current_part = current_part .. char
    elseif char == ")" then
      paren_depth = paren_depth - 1
      current_part = current_part .. char
    elseif char == "," and paren_depth == 0 then
      table.insert(parts, current_part)
      current_part = ""
    else
      current_part = current_part .. char
    end
  end

  -- Add last part
  if #current_part > 0 then
    table.insert(parts, current_part)
  end

  -- Parse each column definition
  local ordinal = 1
  for _, part in ipairs(parts) do
    local trimmed = part:match("^%s*(.-)%s*$")

    -- Skip table-level constraints (PRIMARY KEY, FOREIGN KEY, CHECK, etc.)
    if trimmed:upper():match("^PRIMARY%s+KEY") or
       trimmed:upper():match("^FOREIGN%s+KEY") or
       trimmed:upper():match("^UNIQUE%s*%(") or
       trimmed:upper():match("^CHECK%s*%(") or
       trimmed:upper():match("^CONSTRAINT%s+") then
      debug_log("Skipping table-level constraint: " .. trimmed:sub(1, 50))
      goto continue
    end

    -- Pattern: column_name data_type [constraints...]
    -- Extract column name (may be bracketed, no spaces allowed in identifier)
    local col_name_with_brackets = trimmed:match("^(%[?[%w_]+%]?)")
    if not col_name_with_brackets then
      debug_log("Could not parse column name from: " .. trimmed:sub(1, 50))
      goto continue
    end

    -- Clean up the column name (remove brackets and trim)
    local col_name = col_name_with_brackets:gsub("%[", ""):gsub("%]", ""):match("^%s*(.-)%s*$")

    -- Extract data type (everything after column name + brackets until constraint keywords)
    local after_name = trimmed:sub(#col_name_with_brackets + 1)

    -- Match data type patterns:
    -- 1. TYPE(params) - handle nested commas like DECIMAL(10,2)
    -- 2. TYPE
    local data_type = nil

    -- Try to match TYPE(params) with proper parenthesis matching
    local type_start = after_name:match("^%s*([%w_]+)%s*%(")
    if type_start then
      -- Find the matching closing parenthesis
      local paren_count = 1
      local params_start = after_name:find("%(") + 1
      local params_end = params_start

      for i = params_start, #after_name do
        local c = after_name:sub(i, i)
        if c == "(" then
          paren_count = paren_count + 1
        elseif c == ")" then
          paren_count = paren_count - 1
          if paren_count == 0 then
            params_end = i - 1
            break
          end
        end
      end

      local params = after_name:sub(params_start, params_end)
      data_type = type_start .. "(" .. params .. ")"
    else
      -- Simple type without parameters
      data_type = after_name:match("^%s*([%w_]+)")
    end

    if not data_type then
      debug_log("Could not parse data type from: " .. trimmed:sub(1, 50))
      goto continue
    end

    -- Clean up data type (remove trailing constraint keywords)
    data_type = data_type:match("^%s*(.-)%s*$")

    table.insert(result.columns, {
      name = col_name,
      data_type = data_type,
      ordinal_position = ordinal,
    })

    ordinal = ordinal + 1

    ::continue::
  end

  debug_log(string.format("Extracted %d columns from CREATE TABLE", #result.columns))
  result.success = true
  return result
end

---Update buffer cache with temp table info
---@param bufnr number Buffer number
---@param temp_table_info table Object from extract_columns_* functions
---@param chunk_index number GO chunk index (0-based)
function TempTableTracker.update_buffer_cache_with_temp_table(bufnr, temp_table_info, chunk_index)
  debug_log(string.format("update_buffer_cache_with_temp_table: %s (chunk %d)",
    temp_table_info.temp_table_name, chunk_index))

  -- Create TempTableClass-like object
  local temp_table = {
    name = temp_table_info.temp_table_name,
    type = temp_table_info.temp_table_type,  -- "local" or "global"
    columns = temp_table_info.columns,
    created_at_line = temp_table_info.line or 0,
    chunk_index = chunk_index,
  }

  -- Add to buffer cache
  Cache.add_buffer_temp_table(bufnr, temp_table, chunk_index)

  debug_log(string.format("Added temp table %s to buffer cache (%d columns)",
    temp_table.name, #temp_table.columns))
end

---Scan buffer for temp table definitions and update cache
---@param bufnr number Buffer number
---@param connection table Connection context {server, database, connection_string}
---@return table result {success, temp_tables_found, errors}
function TempTableTracker.scan_buffer_for_temp_tables(bufnr, connection)
  debug_log(string.format("scan_buffer_for_temp_tables: bufnr=%d", bufnr))

  local result = {
    success = true,
    temp_tables_found = 0,
    errors = {},
  }

  -- Get buffer lines
  local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find all temp table statements
  local statements = TempTableTracker.find_temp_table_statements(buffer_lines)

  if #statements == 0 then
    debug_log("No temp table statements found in buffer")
    return result
  end

  -- Track GO chunks for proper scoping
  local chunk_index = 0
  local last_go_line = 0

  -- Process each statement
  for _, stmt_info in ipairs(statements) do
    -- Check if we crossed a GO boundary
    for i = last_go_line + 1, stmt_info.line do
      local line_upper = buffer_lines[i]:upper()
      if line_upper:match("^%s*GO%s*$") then
        chunk_index = chunk_index + 1
        last_go_line = i

        -- Clear local temp tables at GO boundary
        Cache.clear_local_temps_at_go(bufnr, i)
        debug_log(string.format("GO boundary at line %d, chunk_index now %d", i, chunk_index))
      end
    end

    debug_log(string.format("Processing %s statement at line %d (chunk %d)",
      stmt_info.type, stmt_info.line, chunk_index))

    -- Extract columns based on statement type
    local extract_result

    if stmt_info.type == "select_into" then
      local success, res = pcall(function()
        return TempTableTracker.extract_columns_from_select_into(
          stmt_info.statement,
          bufnr,
          connection
        )
      end)

      if success then
        extract_result = res
      else
        extract_result = {
          success = false,
          error = "Exception: " .. tostring(res)
        }
      end
    elseif stmt_info.type == "create_table" then
      local success, res = pcall(function()
        return TempTableTracker.extract_columns_from_create_table(stmt_info.statement)
      end)

      if success then
        extract_result = res
      else
        extract_result = {
          success = false,
          error = "Exception: " .. tostring(res)
        }
      end
    else
      extract_result = {
        success = false,
        error = "Unknown statement type: " .. stmt_info.type
      }
    end

    -- Update cache if extraction succeeded
    if extract_result.success then
      extract_result.line = stmt_info.line  -- Add line number for cache
      TempTableTracker.update_buffer_cache_with_temp_table(bufnr, extract_result, chunk_index)
      result.temp_tables_found = result.temp_tables_found + 1
    else
      local error_msg = string.format("Line %d: %s", stmt_info.line, extract_result.error or "unknown error")
      table.insert(result.errors, error_msg)
      debug_log("ERROR: " .. error_msg)
    end
  end

  if #result.errors > 0 then
    result.success = false
  end

  debug_log(string.format("Scan complete: %d temp tables found, %d errors",
    result.temp_tables_found, #result.errors))

  return result
end

---Setup auto-scan for temp tables in buffer
---Scans on buffer save or manual trigger
---@param bufnr number Buffer number
function TempTableTracker.setup_auto_scan(bufnr)
  debug_log(string.format("setup_auto_scan: bufnr=%d", bufnr))

  -- Auto-scan on buffer save
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    callback = function()
      debug_log("BufWritePost triggered, scanning for temp tables")

      -- Get connection context (would need to be implemented in buffer management)
      -- For now, skip auto-scan if no connection available
      local Cache = require('ssns.cache')
      local connection = Cache.get_active_database()

      if not connection then
        debug_log("No active database connection, skipping auto-scan")
        return
      end

      -- Build connection context
      local conn_context = {
        server = connection.parent,
        database = connection,
        connection_string = connection.parent.connection_string .. "/" .. connection.name,
      }

      -- Scan buffer
      TempTableTracker.scan_buffer_for_temp_tables(bufnr, conn_context)
    end,
  })

  debug_log("Auto-scan autocmd registered")
end

---Manual scan command (for testing/debugging)
---@param bufnr number? Buffer number (defaults to current buffer)
function TempTableTracker.scan_current_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  debug_log("Manual scan triggered for bufnr=" .. bufnr)

  -- Get active database connection
  local Cache = require('ssns.cache')
  local connection = Cache.get_active_database()

  if not connection then
    vim.notify("No active database connection. Connect to a database first.", vim.log.levels.WARN)
    return
  end

  -- Build connection context
  local conn_context = {
    server = connection.parent,
    database = connection,
    connection_string = connection.parent.connection_string .. "/" .. connection.name,
  }

  -- Scan buffer
  local result = TempTableTracker.scan_buffer_for_temp_tables(bufnr, conn_context)

  -- Show results to user
  if result.success then
    vim.notify(string.format("Found %d temp tables in buffer", result.temp_tables_found), vim.log.levels.INFO)
  else
    local error_msg = string.format("Found %d temp tables with %d errors:\n%s",
      result.temp_tables_found,
      #result.errors,
      table.concat(result.errors, "\n"))
    vim.notify(error_msg, vim.log.levels.WARN)
  end

  return result
end

return TempTableTracker
