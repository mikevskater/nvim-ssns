local BaseAdapter = require('ssns.adapters.base')

---@class MySQLAdapter : BaseAdapter
local MySQLAdapter = setmetatable({}, { __index = BaseAdapter })
MySQLAdapter.__index = MySQLAdapter

---Create a new MySQL adapter instance
---@param connection_string string
---@return MySQLAdapter
function MySQLAdapter.new(connection_string)
  local self = setmetatable(BaseAdapter.new("mysql", connection_string), MySQLAdapter)

  -- MySQL feature flags
  self.features = {
    schemas = false,     -- MySQL uses databases, not schemas (schema = database)
    synonyms = false,    -- MySQL doesn't support synonyms
    procedures = true,   -- Stored procedures
    functions = true,    -- User-defined functions
    sequences = false,   -- MySQL doesn't have sequences (uses AUTO_INCREMENT)
    triggers = true,     -- Triggers
    views = true,        -- Views
    indexes = true,      -- Indexes
    constraints = true,  -- Constraints (PK, FK, CHECK, etc.)
  }

  return self
end

---Execute a query against MySQL using Node.js backend
---@param connection any The database connection object or connection string
---@param query string The SQL query to execute
---@param opts table? Options (reserved for future use)
---@return table result Node.js result object { success, resultSets, metadata, error }
function MySQLAdapter:execute(connection, query, opts)
  opts = opts or {}
  local ConnectionModule = require('ssns.connection')

  -- Handle both connection object and connection string
  local conn_str
  if type(connection) == "string" then
    conn_str = connection
  elseif type(connection) == "table" and connection.connection_string then
    conn_str = connection.connection_string
  else
    -- Fallback to adapter's connection string
    conn_str = self.connection_string
  end

  -- Execute via Node.js backend
  return ConnectionModule.execute(conn_str, query, opts)
end

---Parse MySQL connection string
---@return table connection_info
function MySQLAdapter:parse_connection_string()
  -- Format: mysql://[user:password@]host[:port]/database
  local info = {}

  local pattern = "^mysql://(.+)$"
  local rest = self.connection_string:match(pattern)

  if not rest then
    return info
  end

  -- Extract user:password if present
  local auth, host_db = rest:match("^([^@]+)@(.+)$")
  if auth then
    info.user, info.password = auth:match("^([^:]+):(.+)$")
    rest = host_db
  else
    rest = rest
  end

  -- Extract host:port and database
  local host_part, database = rest:match("^([^/]+)/(.+)$")
  if host_part then
    info.database = database

    -- Check for port
    local host, port = host_part:match("^([^:]+):(.+)$")
    if host then
      info.host = host
      info.port = tonumber(port)
    else
      info.host = host_part
      info.port = 3306 -- Default MySQL port
    end
  end

  return info
end

---Test MySQL connection
---@param connection any
---@return boolean success
---@return string? error_message
function MySQLAdapter:test_connection(connection)
  local ConnectionModule = require('ssns.connection')

  -- Handle both connection object and connection string
  local conn_str
  if type(connection) == "string" then
    conn_str = connection
  elseif type(connection) == "table" and connection.connection_string then
    conn_str = connection.connection_string
  else
    conn_str = self.connection_string
  end

  return ConnectionModule.test(conn_str)
end

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list all databases on the MySQL server
---@return string query
function MySQLAdapter:get_databases_query()
  return [[
SELECT schema_name AS name
FROM information_schema.schemata
WHERE schema_name NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY schema_name;
]]
end

---Get query to list all tables in a database
---@param database_name string
---@param schema_name string? Not used in MySQL (schema = database)
---@return string query
function MySQLAdapter:get_tables_query(database_name, schema_name)
  return string.format([[
SELECT
  table_name AS name,
  table_type AS type
FROM information_schema.tables
WHERE table_schema = '%s'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
]], database_name)
end

---Get query to list all views in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_views_query(database_name, schema_name)
  return string.format([[
SELECT
  table_name AS name
FROM information_schema.views
WHERE table_schema = '%s'
ORDER BY table_name;
]], database_name)
end

---Get query to list all stored procedures in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_procedures_query(database_name, schema_name)
  return string.format([[
SELECT
  routine_name AS name
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_type = 'PROCEDURE'
ORDER BY routine_name;
]], database_name)
end

---Get query to list all functions in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_functions_query(database_name, schema_name)
  return string.format([[
SELECT
  routine_name AS name,
  routine_type AS type
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;
]], database_name)
end

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_columns_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  column_name AS column_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS `precision`,
  numeric_scale AS `scale`,
  is_nullable AS is_nullable,
  column_default AS default_value,
  extra AS extra,
  ordinal_position AS ordinal_position
FROM information_schema.columns
WHERE table_schema = '%s'
  AND table_name = '%s'
ORDER BY ordinal_position;
]], database_name, table_name)
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_indexes_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  index_name AS index_name,
  index_type AS index_type,
  non_unique AS non_unique,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS column_names
FROM information_schema.statistics
WHERE table_schema = '%s'
  AND table_name = '%s'
GROUP BY index_name, index_type, non_unique
ORDER BY index_name;
]], database_name, table_name)
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_constraints_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  tc.constraint_name AS constraint_name,
  tc.constraint_type AS constraint_type,
  GROUP_CONCAT(kcu.column_name ORDER BY kcu.ordinal_position) AS column_names,
  kcu.referenced_table_schema AS referenced_table_schema,
  kcu.referenced_table_name AS referenced_table_name,
  GROUP_CONCAT(kcu.referenced_column_name ORDER BY kcu.ordinal_position) AS referenced_columns
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
  AND tc.table_name = kcu.table_name
WHERE tc.table_schema = '%s'
  AND tc.table_name = '%s'
GROUP BY tc.constraint_name, tc.constraint_type, kcu.referenced_table_schema, kcu.referenced_table_name
ORDER BY tc.constraint_type, tc.constraint_name;
]], database_name, table_name)
end

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function MySQLAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  return string.format([[
SELECT
  parameter_name AS parameter_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS `precision`,
  numeric_scale AS `scale`,
  parameter_mode AS mode,
  ordinal_position AS ordinal_position
FROM information_schema.parameters
WHERE specific_schema = '%s'
  AND specific_name = '%s'
  AND routine_type = '%s'
ORDER BY ordinal_position;
]], database_name, routine_name, routine_type)
end

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function MySQLAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  if object_type == "VIEW" then
    return string.format([[
SELECT view_definition AS definition
FROM information_schema.views
WHERE table_schema = '%s'
  AND table_name = '%s';
]], database_name, object_name)
  else
    -- For procedures and functions
    return string.format([[
SELECT routine_definition AS definition
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_name = '%s';
]], database_name, object_name)
  end
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_table_definition_query(database_name, schema_name, table_name)
  return string.format([[
SHOW CREATE TABLE `%s`.`%s`;
]], database_name, table_name)
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table databases Array of { name } objects
function MySQLAdapter:parse_databases(result)
  local databases = {}

  -- Extract rows from first result set
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Extract 'name' column value
      if row.name then
        table.insert(databases, { name = row.name })
      end
    end
  end

  return databases
end

---Parse table list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table tables
function MySQLAdapter:parse_tables(result)
  local tables = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(tables, {
        name = row.name,
        type = row.type,
      })
    end
  end
  return tables
end

---Parse view list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table views
function MySQLAdapter:parse_views(result)
  local views = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(views, {
        name = row.name,
      })
    end
  end
  return views
end

---Parse procedure list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table procedures
function MySQLAdapter:parse_procedures(result)
  local procedures = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(procedures, {
        name = row.name,
      })
    end
  end
  return procedures
end

---Parse function list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table functions
function MySQLAdapter:parse_functions(result)
  local funcs = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(funcs, {
        name = row.name,
        type = row.type,
      })
    end
  end
  return funcs
end

---Parse column list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table columns
function MySQLAdapter:parse_columns(result)
  local columns = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- All column names aliased to lowercase in query for consistency
      table.insert(columns, {
        name = row.column_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.precision,
        scale = row.scale,
        nullable = row.is_nullable == "YES",
        is_identity = row.extra and row.extra:lower():find("auto_increment") ~= nil,
        is_computed = row.extra and (row.extra:lower():find("generated") ~= nil or row.extra:lower():find("virtual") ~= nil),
        default = row.default_value,
        ordinal_position = row.ordinal_position,
      })
    end
  end
  return columns
end

---Parse index list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table indexes
function MySQLAdapter:parse_indexes(result)
  local indexes = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Handle vim.NIL for column_names
      local col_names = row.column_names
      if col_names == vim.NIL or col_names == nil then
        col_names = ""
      end

      table.insert(indexes, {
        name = row.index_name,
        type = row.index_type,
        is_unique = row.non_unique == 0,
        is_primary = row.index_name == "PRIMARY",
        columns = vim.split(col_names, ",", { plain = true }),
      })
    end
  end
  return indexes
end

---Parse constraint list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table constraints
function MySQLAdapter:parse_constraints(result)
  local constraints = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Handle vim.NIL for column_names
      local col_names = row.column_names
      if col_names == vim.NIL or col_names == nil then
        col_names = ""
      end

      -- Handle vim.NIL for referenced_columns
      local ref_columns = nil
      if row.referenced_columns and row.referenced_columns ~= vim.NIL then
        ref_columns = vim.split(row.referenced_columns, ",", { plain = true })
      end

      table.insert(constraints, {
        name = row.constraint_name,
        type = row.constraint_type,
        columns = vim.split(col_names, ",", { plain = true }),
        referenced_table = row.referenced_table_name,
        referenced_schema = row.referenced_table_schema,
        referenced_columns = ref_columns,
      })
    end
  end
  return constraints
end

---Parse parameter list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table parameters
function MySQLAdapter:parse_parameters(result)
  local parameters = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(parameters, {
        name = row.parameter_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.precision,
        scale = row.scale,
        mode = row.mode or "IN",
        ordinal_position = row.ordinal_position,
      })
    end
  end
  return parameters
end

-- ============================================================================
-- Object Creation Helpers
-- ============================================================================

---Create a table object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_table(parent, row)
  local TableClass = require('ssns.classes.table')
  return TableClass.new({
    name = row.name,
    table_type = row.type,
    parent = parent,
  })
end

---Create a view object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_view(parent, row)
  local ViewClass = require('ssns.classes.view')
  return ViewClass.new({
    name = row.name,
    parent = parent,
  })
end

---Create a procedure object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_procedure(parent, row)
  local ProcedureClass = require('ssns.classes.procedure')
  return ProcedureClass.new({
    name = row.name,
    parent = parent,
  })
end

---Create a function object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_function(parent, row)
  local FunctionClass = require('ssns.classes.function')
  return FunctionClass.new({
    name = row.name,
    function_type = row.type,
    parent = parent,
  })
end

---Create a column object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_column(parent, row)
  local ColumnClass = require('ssns.classes.column')
  return ColumnClass.new({
    name = row.name,
    data_type = row.data_type,
    nullable = row.nullable,
    is_identity = row.is_identity,
    is_computed = row.is_computed,
    default = row.default,
    max_length = row.max_length,
    precision = row.precision,
    scale = row.scale,
    parent = parent,
  })
end

-- ============================================================================
-- Utility Methods
-- ============================================================================

---Get the identifier quote character for MySQL
---@return string
function MySQLAdapter:get_quote_char()
  return "`"  -- MySQL uses backticks
end

---Get a string representation for debugging
---@return string
function MySQLAdapter:to_string()
  return string.format("MySQLAdapter{connection=%s}", self.connection_string)
end

return MySQLAdapter
