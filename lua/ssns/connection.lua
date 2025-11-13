---@class Connection
---Database connection management using vim-dadbod
local Connection = {}

---Check if vim-dadbod is available
---@return boolean available
function Connection.is_dadbod_available()
  -- Check if we can find the autoload file
  local db_path = vim.fn.globpath(vim.o.runtimepath, "autoload/db.vim")
  return db_path ~= ""
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

  local results, err = Connection.execute_sync(connection_string, test_query)

  if err then
    return false, err
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

  -- Get the connection URL
  local conn_str = type(connection_string) == "string" and connection_string or connection_string.connection_string

  -- Get the command array using db#adapter#dispatch
  local success, cmd = pcall(function()
    return vim.fn["db#adapter#dispatch"](conn_str, "interactive")
  end)

  if not success then
    return {}, "Failed to get database adapter: " .. tostring(cmd)
  end

  -- Add sqlcmd flags for cleaner output
  -- -h-1: Remove headers
  -- -W: Remove trailing spaces
  -- -s",": Use comma as column separator (easier to parse)
  table.insert(cmd, "-h-1")
  table.insert(cmd, "-W")
  table.insert(cmd, "-s,")

  -- Prepend SET NOCOUNT ON to prevent row count messages
  local clean_query = "SET NOCOUNT ON;\n" .. query

  -- Execute query using db#systemlist
  local results_raw
  success, results_raw = pcall(function()
    return vim.fn["db#systemlist"](cmd, clean_query)
  end)

  if not success then
    return {}, "Query execution failed: " .. tostring(results_raw)
  end

  -- Check if results indicate an error
  if type(results_raw) == "table" and #results_raw > 0 then
    local first_line = results_raw[1] or ""
    if first_line:match("^Msg %d+") or first_line:match("^Error") then
      return {}, table.concat(results_raw, "\n")
    end
  end

  -- Parse the results
  local parsed_results = Connection.parse_result(results_raw)
  return parsed_results, nil
end

---Parse vim-dadbod result into table format
---@param result any Raw result from vim-dadbod (array of lines or string)
---@return table parsed Array of row tables
function Connection.parse_result(result)
  local lines = {}

  -- Convert result to lines array
  if type(result) == "table" then
    -- Already an array of lines from db#systemlist
    lines = result
  elseif type(result) == "string" then
    -- Split string into lines
    lines = vim.split(result, "\n", { plain = true })
  else
    return {}
  end

  if #lines == 0 then
    return {}
  end

  -- With -h-1 and -s"," flags, sqlcmd output is:
  -- - No headers (we use column names from query)
  -- - Comma-separated values
  -- - One row per line
  -- - SET NOCOUNT ON prevents row count messages

  local rows = {}
  for _, line in ipairs(lines) do
    -- Skip empty lines and any remaining noise
    if line and line ~= "" and not line:match("^%s*$") then
      -- Skip lines that look like messages or errors
      if not line:match("^Changed database context") and
         not line:match("^Msg %d+") and
         not line:match("^%(") and  -- Skip "(X rows affected)" if any slip through
         not line:match("^Changed language setting") then

        -- Parse comma-separated values
        local values = {}
        for value in line:gmatch("([^,]+)") do
          local trimmed = vim.trim(value)
          table.insert(values, trimmed)
        end

        -- Create row object
        -- Since we use -h-1, we don't have headers from sqlcmd
        -- We rely on the adapter's parse methods to handle this
        if #values > 0 then
          local row = {}
          for idx, value in ipairs(values) do
            row[idx] = value  -- Store by numeric index
            -- For single-column results, also store as 'name' for compatibility
            if #values == 1 then
              row.name = value
            end
          end
          table.insert(rows, row)
        end
      end
    end
  end

  return rows
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
