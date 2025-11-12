---@class Connection
---Database connection management using vim-dadbod
local Connection = {}

---Check if vim-dadbod is available
---@return boolean available
function Connection.is_dadbod_available()
  return vim.fn.exists("*db#query") == 1
end

---Parse connection string into components
---@param connection_string string
---@return table parsed {url: string, database: string?, scheme: string?}
function Connection.parse(connection_string)
  local parsed = {
    url = connection_string,
    database = nil,
    scheme = nil,
  }

  -- Extract scheme (database type)
  local scheme = connection_string:match("^([^:]+)://")
  if scheme then
    parsed.scheme = scheme
  end

  -- Extract database name (last part after /)
  local database = connection_string:match("/([^/]+)$")
  if database then
    parsed.database = database
  end

  return parsed
end

---Test a connection without maintaining state
---@param connection_string string
---@return boolean success
---@return string? error_message
function Connection.test(connection_string)
  if not Connection.is_dadbod_available() then
    return false, "vim-dadbod not available"
  end

  -- Try a simple query to test connection
  local test_query = "SELECT 1"

  local success, result = pcall(function()
    return vim.fn["db#query"](connection_string, test_query)
  end)

  if not success then
    return false, tostring(result)
  end

  -- Check if result indicates an error
  if type(result) == "string" and result:match("Error") then
    return false, result
  end

  return true, nil
end

---Execute a synchronous query using vim-dadbod
---@param connection_string string The connection string or connection object
---@param query string The SQL query to execute
---@return table results Array of result rows
---@return string? error_message Error message if query failed
function Connection.execute_sync(connection_string, query)
  if not Connection.is_dadbod_available() then
    return {}, "vim-dadbod not available"
  end

  -- Execute query using vim-dadbod
  local success, result = pcall(function()
    return vim.fn["db#query"](connection_string, query)
  end)

  if not success then
    return {}, tostring(result)
  end

  -- Check if result is an error string
  if type(result) == "string" then
    -- Check if it's an error message
    if result:match("Error") or result:match("error") then
      return {}, result
    end

    -- Empty result or success message
    return {}, nil
  end

  -- Parse result based on format
  local parsed_results = Connection.parse_result(result)
  return parsed_results, nil
end

---Parse vim-dadbod result into table format
---@param result any Raw result from vim-dadbod
---@return table parsed Array of row tables
function Connection.parse_result(result)
  -- If result is already a table, return it
  if type(result) == "table" then
    return result
  end

  -- If result is a string, try to parse it
  if type(result) == "string" then
    -- Split by lines
    local lines = vim.split(result, "\n", { plain = true })

    if #lines == 0 then
      return {}
    end

    -- Try to parse as table format
    -- First line is often headers
    local headers = {}
    local data_start = 1

    -- Look for header line (usually has | separators)
    if lines[1]:match("|") then
      -- Parse headers
      for header in lines[1]:gmatch("([^|]+)") do
        local trimmed = vim.trim(header)
        if trimmed ~= "" then
          table.insert(headers, trimmed)
        end
      end
      data_start = 2

      -- Skip separator line if present (usually all dashes)
      if lines[2] and lines[2]:match("^[+-|]+$") then
        data_start = 3
      end
    end

    -- Parse data rows
    local rows = {}
    for i = data_start, #lines do
      local line = lines[i]
      if line and line ~= "" and line:match("|") then
        local row = {}
        local col_idx = 1

        for value in line:gmatch("([^|]+)") do
          local trimmed = vim.trim(value)
          if trimmed ~= "" then
            local key = headers[col_idx] or col_idx
            row[key] = trimmed
            col_idx = col_idx + 1
          end
        end

        if vim.tbl_count(row) > 0 then
          table.insert(rows, row)
        end
      end
    end

    return rows
  end

  -- Unknown format, return empty
  return {}
end

---Execute an asynchronous query using vim-dadbod
---@param connection_string string The connection string
---@param query string The SQL query to execute
---@param callback function Callback function(results, error)
function Connection.execute_async(connection_string, query, callback)
  if not Connection.is_dadbod_available() then
    callback({}, "vim-dadbod not available")
    return
  end

  -- Use vim.schedule to run in background
  vim.schedule(function()
    local results, err = Connection.execute_sync(connection_string, query)
    callback(results, err)
  end)
end

---Execute multiple queries in sequence
---@param connection_string string The connection string
---@param queries string[] Array of queries to execute
---@return table[] results Array of result sets (one per query)
---@return string? error_message Error message if any query failed
function Connection.execute_batch(connection_string, queries)
  local all_results = {}

  for i, query in ipairs(queries) do
    local results, err = Connection.execute_sync(connection_string, query)

    if err then
      return all_results, string.format("Query %d failed: %s", i, err)
    end

    table.insert(all_results, results)
  end

  return all_results, nil
end

---Switch database context (USE statement for SQL Server)
---@param connection_string string The connection string
---@param database_name string Database name to switch to
---@return boolean success
---@return string? error_message
function Connection.use_database(connection_string, database_name)
  -- For SQL Server, we need to send a USE statement
  local query = string.format("USE [%s];", database_name)

  local _, err = Connection.execute_sync(connection_string, query)

  if err then
    return false, err
  end

  return true, nil
end

---Get the current database name from connection
---@param connection_string string
---@return string? database_name
function Connection.get_current_database(connection_string)
  local query = "SELECT DB_NAME() AS current_database;"

  local results, err = Connection.execute_sync(connection_string, query)

  if err or #results == 0 then
    return nil
  end

  return results[1].current_database or results[1][1]
end

---Create a new connection object with state
---@param connection_string string
---@return table connection Connection object with methods
function Connection.new(connection_string)
  local conn = {
    connection_string = connection_string,
    current_database = nil,
  }

  ---Execute query on this connection
  ---@param query string
  ---@return table results
  ---@return string? error
  function conn:execute(query)
    return Connection.execute_sync(self.connection_string, query)
  end

  ---Execute async query on this connection
  ---@param query string
  ---@param callback function
  function conn:execute_async(query, callback)
    Connection.execute_async(self.connection_string, query, callback)
  end

  ---Switch database context
  ---@param database_name string
  ---@return boolean success
  ---@return string? error
  function conn:use_database(database_name)
    local success, err = Connection.use_database(self.connection_string, database_name)
    if success then
      self.current_database = database_name
    end
    return success, err
  end

  ---Get current database
  ---@return string? database_name
  function conn:get_current_database()
    if self.current_database then
      return self.current_database
    end

    self.current_database = Connection.get_current_database(self.connection_string)
    return self.current_database
  end

  ---Test this connection
  ---@return boolean success
  ---@return string? error
  function conn:test()
    return Connection.test(self.connection_string)
  end

  return conn
end

---Connection pool for reusing connections
---@type table<string, table>
Connection.pool = {}

---Get or create a connection from the pool
---@param connection_string string
---@return table connection Connection object
function Connection.get_or_create(connection_string)
  if not Connection.pool[connection_string] then
    Connection.pool[connection_string] = Connection.new(connection_string)
  end
  return Connection.pool[connection_string]
end

---Close and remove a connection from the pool
---@param connection_string string
function Connection.close(connection_string)
  Connection.pool[connection_string] = nil
end

---Close all connections in the pool
function Connection.close_all()
  Connection.pool = {}
end

---Get statistics about connection pool
---@return table stats {active_connections: number, connections: string[]}
function Connection.get_pool_stats()
  local stats = {
    active_connections = 0,
    connections = {},
  }

  for conn_str, _ in pairs(Connection.pool) do
    stats.active_connections = stats.active_connections + 1
    table.insert(stats.connections, conn_str)
  end

  return stats
end

---Format query with proper line endings
---@param query string
---@return string formatted
function Connection.format_query(query)
  -- Ensure proper line endings
  query = query:gsub("\r\n", "\n")
  query = query:gsub("\r", "\n")

  -- Trim leading/trailing whitespace
  query = vim.trim(query)

  return query
end

---Escape special characters in strings for SQL
---@param str string
---@return string escaped
function Connection.escape_string(str)
  -- Replace single quotes with double single quotes (SQL standard)
  return str:gsub("'", "''")
end

return Connection
