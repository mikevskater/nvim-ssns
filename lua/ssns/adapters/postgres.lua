local BaseAdapter = require('ssns.adapters.base')

---@class PostgresAdapter : BaseAdapter
local PostgresAdapter = setmetatable({}, { __index = BaseAdapter })
PostgresAdapter.__index = PostgresAdapter

---Create a new PostgreSQL adapter instance
---@param connection_string string
---@return PostgresAdapter
function PostgresAdapter.new(connection_string)
  local self = setmetatable(BaseAdapter.new("postgres", connection_string), PostgresAdapter)

  -- PostgreSQL feature flags
  self.features = {
    schemas = true,      -- PostgreSQL supports schemas
    synonyms = false,    -- PostgreSQL doesn't support synonyms
    procedures = true,   -- Stored procedures (functions)
    functions = true,    -- User-defined functions
    sequences = true,    -- Sequences
    triggers = true,     -- Triggers
    views = true,        -- Views
    indexes = true,      -- Indexes
    constraints = true,  -- Constraints (PK, FK, CHECK, etc.)
  }

  return self
end

---Execute a query against PostgreSQL using Node.js backend
---@param connection any The database connection object or connection string
---@param query string The SQL query to execute
---@param opts table? Options (reserved for future use)
---@return table result Node.js result object { success, resultSets, metadata, error }
function PostgresAdapter:execute(connection, query, opts)
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

---Parse PostgreSQL connection string
---@return table connection_info
function PostgresAdapter:parse_connection_string()
  -- Format: postgres://[user:password@]host[:port]/database
  local info = {}

  local pattern = "^postgres(ql)?://(.+)$"
  local _, rest = self.connection_string:match(pattern)

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
      info.port = 5432 -- Default PostgreSQL port
    end
  end

  return info
end

---Test PostgreSQL connection
---@param connection any
---@return boolean success
---@return string? error_message
function PostgresAdapter:test_connection(connection)
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

---Get query to list all databases on the PostgreSQL server
---@return string query
function PostgresAdapter:get_databases_query()
  return [[
SELECT datname AS name
FROM pg_database
WHERE datistemplate = false
  AND datname NOT IN ('postgres')
ORDER BY datname;
]]
end

---Get query to list all schemas in a database
---@param database_name string
---@return string query
function PostgresAdapter:get_schemas_query(database_name)
  -- Note: PostgreSQL doesn't support USE database, connection is per-database
  return [[
SELECT schema_name AS name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND schema_name NOT LIKE 'pg_temp_%'
  AND schema_name NOT LIKE 'pg_toast_temp_%'
ORDER BY schema_name;
]]
end

---Get query to list all tables in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function PostgresAdapter:get_tables_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND table_schema = '%s'\n", schema_name)
  end

  return string.format([[
SELECT
  table_schema AS schema_name,
  table_name AS name,
  table_type AS type
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
%sORDER BY table_schema, table_name;
]], where_clause)
end

---Get query to list all views in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function PostgresAdapter:get_views_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND table_schema = '%s'\n", schema_name)
  end

  return string.format([[
SELECT
  table_schema AS schema_name,
  table_name AS name
FROM information_schema.views
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
%sORDER BY table_schema, table_name;
]], where_clause)
end

---Get query to list all stored procedures in a schema (PostgreSQL 11+)
---@param database_name string
---@param schema_name string?
---@return string query
function PostgresAdapter:get_procedures_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND n.nspname = '%s'\n", schema_name)
  end

  return string.format([[
SELECT
  n.nspname AS schema_name,
  p.proname AS name
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prokind = 'p'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
%sORDER BY n.nspname, p.proname;
]], where_clause)
end

---Get query to list all functions in a schema (excludes procedures)
---@param database_name string
---@param schema_name string?
---@return string query
function PostgresAdapter:get_functions_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND n.nspname = '%s'\n", schema_name)
  end

  -- prokind: 'f' = function, 'a' = aggregate, 'w' = window (excludes 'p' = procedure)
  return string.format([[
SELECT
  n.nspname AS schema_name,
  p.proname AS name,
  CASE p.prokind
    WHEN 'f' THEN 'FUNCTION'
    WHEN 'a' THEN 'AGGREGATE'
    WHEN 'w' THEN 'WINDOW'
    ELSE 'UNKNOWN'
  END AS type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prokind != 'p'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
%sORDER BY n.nspname, p.proname;
]], where_clause)
end

---Get query to list all sequences in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function PostgresAdapter:get_sequences_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND sequence_schema = '%s'\n", schema_name)
  end

  return string.format([[
SELECT
  sequence_schema AS schema_name,
  sequence_name AS name,
  start_value,
  increment AS increment_by,
  last_value
FROM information_schema.sequences
WHERE sequence_schema NOT IN ('pg_catalog', 'information_schema')
%sORDER BY sequence_schema, sequence_name;
]], where_clause)
end

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function PostgresAdapter:get_columns_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND table_schema = '%s'", schema_name) or ""

  return string.format([[
SELECT
  column_name AS column_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS numeric_precision,
  numeric_scale AS numeric_scale,
  is_nullable AS is_nullable,
  column_default AS default_value,
  ordinal_position AS ordinal_position
FROM information_schema.columns
WHERE table_name = '%s'
  %s
ORDER BY ordinal_position;
]], table_name, schema_filter)
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function PostgresAdapter:get_indexes_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND n.nspname = '%s'", schema_name) or ""

  return string.format([[
SELECT
  i.relname AS index_name,
  am.amname AS index_type,
  ix.indisunique AS is_unique,
  ix.indisprimary AS is_primary,
  string_agg(a.attname, ', ' ORDER BY array_position(ix.indkey, a.attnum)) AS column_names
FROM pg_index ix
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_namespace n ON t.relnamespace = n.oid
JOIN pg_am am ON i.relam = am.oid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
WHERE t.relname = '%s'
  %s
GROUP BY i.relname, am.amname, ix.indisunique, ix.indisprimary
ORDER BY ix.indisprimary DESC, i.relname;
]], table_name, schema_filter)
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function PostgresAdapter:get_constraints_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND tc.table_schema = '%s'", schema_name) or ""

  return string.format([[
SELECT
  tc.constraint_name AS constraint_name,
  tc.constraint_type AS constraint_type,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS column_names,
  ccu.table_schema AS referenced_schema,
  ccu.table_name AS referenced_table,
  string_agg(ccu.column_name, ', ' ORDER BY kcu.ordinal_position) AS referenced_columns
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = '%s'
  %s
GROUP BY tc.constraint_name, tc.constraint_type, ccu.table_schema, ccu.table_name
ORDER BY tc.constraint_type, tc.constraint_name;
]], table_name, schema_filter)
end

---Get query to list all parameters for a function/procedure
---@param database_name string
---@param schema_name string?
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function PostgresAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  local schema_filter = schema_name and string.format("AND specific_schema = '%s'", schema_name) or ""

  return string.format([[
SELECT
  parameter_name AS parameter_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS numeric_precision,
  numeric_scale AS numeric_scale,
  parameter_mode AS mode,
  ordinal_position AS ordinal_position
FROM information_schema.parameters
WHERE specific_name = '%s'
  %s
ORDER BY ordinal_position;
]], routine_name, schema_filter)
end

---Get query to retrieve the definition of a view/function
---@param database_name string
---@param schema_name string?
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function PostgresAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  if object_type == "VIEW" then
    local schema_filter = schema_name and string.format("AND table_schema = '%s'", schema_name) or ""
    return string.format([[
SELECT view_definition AS definition
FROM information_schema.views
WHERE table_name = '%s'
  %s;
]], object_name, schema_filter)
  else
    -- For functions and procedures, use pg_proc
    local schema_filter = schema_name and string.format("AND n.nspname = '%s'", schema_name) or ""
    return string.format([[
SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = '%s'
  %s;
]], object_name, schema_filter)
  end
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function PostgresAdapter:get_table_definition_query(database_name, schema_name, table_name)
  -- PostgreSQL doesn't have a built-in SHOW CREATE TABLE
  -- We'll construct it from information_schema
  local schema_filter = schema_name or 'public'

  return string.format([[
SELECT
  'CREATE TABLE ' || table_schema || '.' || table_name || ' (' ||
  string_agg(
    column_name || ' ' || data_type ||
    COALESCE('(' || character_maximum_length || ')', '') ||
    CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
    COALESCE(' DEFAULT ' || column_default, ''),
    ', '
    ORDER BY ordinal_position
  ) || ');' AS definition
FROM information_schema.columns
WHERE table_schema = '%s'
  AND table_name = '%s'
GROUP BY table_schema, table_name;
]], schema_filter, table_name)
end

---Parse table definition result and return normalized format
---@param result table Node.js result object
---@return string? definition The CREATE TABLE statement
function PostgresAdapter:parse_table_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      return rows[1].definition
    end
  end
  return nil
end

---Parse object definition result (for views, procedures, functions)
---@param result table Node.js result object
---@return string? definition The object definition
function PostgresAdapter:parse_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      return rows[1].definition
    end
  end
  return nil
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table databases Array of { name } objects
function PostgresAdapter:parse_databases(result)
  local databases = {}

  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.name then
        table.insert(databases, { name = row.name })
      end
    end
  end

  return databases
end

---Parse schema list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table schemas Array of { name } objects
function PostgresAdapter:parse_schemas(result)
  local schemas = {}

  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.name then
        table.insert(schemas, { name = row.name })
      end
    end
  end

  return schemas
end

---Parse table list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table tables
function PostgresAdapter:parse_tables(result)
  local tables = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(tables, {
        schema = row.schema_name,
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
function PostgresAdapter:parse_views(result)
  local views = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(views, {
        schema = row.schema_name,
        name = row.name,
      })
    end
  end
  return views
end

---Parse procedure list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table procedures
function PostgresAdapter:parse_procedures(result)
  local procedures = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(procedures, {
        schema = row.schema_name,
        name = row.name,
      })
    end
  end
  return procedures
end

---Parse function list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table functions
function PostgresAdapter:parse_functions(result)
  local funcs = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(funcs, {
        schema = row.schema_name,
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
function PostgresAdapter:parse_columns(result)
  local columns = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(columns, {
        name = row.column_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.numeric_precision,
        scale = row.numeric_scale,
        nullable = row.is_nullable == "YES",
        is_identity = row.default_value and row.default_value:match("nextval") ~= nil,
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
function PostgresAdapter:parse_indexes(result)
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
        is_unique = row.is_unique == true or row.is_unique == 't',
        is_primary = row.is_primary == true or row.is_primary == 't',
        columns = vim.split(col_names, ", ", { plain = true }),
      })
    end
  end
  return indexes
end

---Parse constraint list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table constraints
function PostgresAdapter:parse_constraints(result)
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
        ref_columns = vim.split(row.referenced_columns, ", ", { plain = true })
      end

      table.insert(constraints, {
        name = row.constraint_name,
        type = row.constraint_type,
        columns = vim.split(col_names, ", ", { plain = true }),
        referenced_table = row.referenced_table,
        referenced_schema = row.referenced_schema,
        referenced_columns = ref_columns,
      })
    end
  end
  return constraints
end

---Parse parameter list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table parameters
function PostgresAdapter:parse_parameters(result)
  local parameters = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(parameters, {
        name = row.parameter_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.numeric_precision,
        scale = row.numeric_scale,
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
function PostgresAdapter:create_table(parent, row)
  local TableClass = require('ssns.classes.table')
  return TableClass.new({
    name = row.name,
    schema_name = row.schema,
    table_type = row.type,
    parent = parent,
  })
end

---Create a view object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function PostgresAdapter:create_view(parent, row)
  local ViewClass = require('ssns.classes.view')
  return ViewClass.new({
    name = row.name,
    schema_name = row.schema,
    parent = parent,
  })
end

---Create a procedure object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function PostgresAdapter:create_procedure(parent, row)
  local ProcedureClass = require('ssns.classes.procedure')
  return ProcedureClass.new({
    name = row.name,
    schema_name = row.schema,
    parent = parent,
  })
end

---Create a function object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function PostgresAdapter:create_function(parent, row)
  local FunctionClass = require('ssns.classes.function')
  return FunctionClass.new({
    name = row.name,
    schema_name = row.schema,
    function_type = row.type,
    parent = parent,
  })
end

---Create a column object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function PostgresAdapter:create_column(parent, row)
  local ColumnClass = require('ssns.classes.column')
  return ColumnClass.new({
    name = row.name,
    data_type = row.data_type,
    nullable = row.nullable,
    is_identity = row.is_identity,
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

---Get the identifier quote character for PostgreSQL
---@return string
function PostgresAdapter:get_quote_char()
  return '"'  -- PostgreSQL uses double quotes for identifiers
end

---Get a string representation for debugging
---@return string
function PostgresAdapter:to_string()
  return string.format("PostgresAdapter{connection=%s}", self.connection_string)
end

return PostgresAdapter
