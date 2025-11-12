---@class Factory
---Factory for creating database objects
---Centralizes object creation logic and provides consistent instantiation
local Factory = {}

---Create a Server instance from connection configuration
---@param name string Display name for the server
---@param connection_string string Database connection string
---@return ServerClass server The created server instance
---@return string? error_message Error message if creation failed
function Factory.create_server(name, connection_string)
  local ServerClass = require('ssns.classes.server')

  local server = ServerClass.new({
    name = name,
    connection_string = connection_string,
  })

  if server.connection_state == ServerClass.ConnectionState.ERROR then
    return server, server.error_message
  end

  return server, nil
end

---Create a Database instance
---@param name string Database name
---@param parent ServerClass Parent server object
---@return DbClass database The created database instance
function Factory.create_database(name, parent)
  local DbClass = require('ssns.classes.database')

  return DbClass.new({
    name = name,
    parent = parent,
  })
end

---Create a Schema instance
---@param name string Schema name
---@param parent DbClass Parent database object
---@return SchemaClass schema The created schema instance
function Factory.create_schema(name, parent)
  local SchemaClass = require('ssns.classes.schema')

  return SchemaClass.new({
    name = name,
    parent = parent,
  })
end

---Create a Table instance
---@param name string Table name
---@param schema_name string Schema name
---@param table_type string? Table type
---@param parent SchemaClass Parent schema object
---@return TableClass table The created table instance
function Factory.create_table(name, schema_name, table_type, parent)
  local TableClass = require('ssns.classes.table')

  return TableClass.new({
    name = name,
    schema_name = schema_name,
    table_type = table_type,
    parent = parent,
  })
end

---Create a View instance
---@param name string View name
---@param schema_name string Schema name
---@param parent SchemaClass Parent schema object
---@return ViewClass view The created view instance
function Factory.create_view(name, schema_name, parent)
  local ViewClass = require('ssns.classes.view')

  return ViewClass.new({
    name = name,
    schema_name = schema_name,
    parent = parent,
  })
end

---Create a Procedure instance
---@param name string Procedure name
---@param schema_name string Schema name
---@param parent SchemaClass Parent schema object
---@return ProcedureClass procedure The created procedure instance
function Factory.create_procedure(name, schema_name, parent)
  local ProcedureClass = require('ssns.classes.procedure')

  return ProcedureClass.new({
    name = name,
    schema_name = schema_name,
    parent = parent,
  })
end

---Create a Function instance
---@param name string Function name
---@param schema_name string Schema name
---@param function_type string? Function type
---@param parent SchemaClass Parent schema object
---@return FunctionClass function The created function instance
function Factory.create_function(name, schema_name, function_type, parent)
  local FunctionClass = require('ssns.classes.function')

  return FunctionClass.new({
    name = name,
    schema_name = schema_name,
    function_type = function_type,
    parent = parent,
  })
end

---Create a Column instance
---@param name string Column name
---@param data_type string Data type
---@param nullable boolean Whether NULL is allowed
---@param parent TableClass|ViewClass Parent table or view object
---@param opts table? Additional options (is_identity, default, max_length, precision, scale)
---@return ColumnClass column The created column instance
function Factory.create_column(name, data_type, nullable, parent, opts)
  local ColumnClass = require('ssns.classes.column')

  opts = opts or {}

  return ColumnClass.new({
    name = name,
    data_type = data_type,
    nullable = nullable,
    is_identity = opts.is_identity,
    default = opts.default,
    max_length = opts.max_length,
    precision = opts.precision,
    scale = opts.scale,
    ordinal_position = opts.ordinal_position,
    parent = parent,
  })
end

---Create an Index instance
---@param name string Index name
---@param columns string[] Column names in the index
---@param parent TableClass Parent table object
---@param opts table? Additional options (index_type, is_unique, is_primary)
---@return IndexClass index The created index instance
function Factory.create_index(name, columns, parent, opts)
  local IndexClass = require('ssns.classes.index')

  opts = opts or {}

  return IndexClass.new({
    name = name,
    columns = columns,
    index_type = opts.index_type,
    is_unique = opts.is_unique or false,
    is_primary = opts.is_primary or false,
    parent = parent,
  })
end

---Create a Constraint instance
---@param name string Constraint name
---@param constraint_type string Constraint type
---@param columns string[] Column names
---@param parent TableClass Parent table object
---@param opts table? Additional options (referenced_table, referenced_schema, referenced_columns, check_clause)
---@return ConstraintClass constraint The created constraint instance
function Factory.create_constraint(name, constraint_type, columns, parent, opts)
  local ConstraintClass = require('ssns.classes.constraint')

  opts = opts or {}

  return ConstraintClass.new({
    name = name,
    constraint_type = constraint_type,
    columns = columns,
    referenced_table = opts.referenced_table,
    referenced_schema = opts.referenced_schema,
    referenced_columns = opts.referenced_columns,
    check_clause = opts.check_clause,
    parent = parent,
  })
end

---Create a Parameter instance
---@param name string Parameter name
---@param data_type string Data type
---@param mode string Parameter mode (IN/OUT/INOUT)
---@param parent ProcedureClass|FunctionClass Parent procedure or function object
---@param opts table? Additional options (has_default, max_length, precision, scale)
---@return ParameterClass parameter The created parameter instance
function Factory.create_parameter(name, data_type, mode, parent, opts)
  local ParameterClass = require('ssns.classes.parameter')

  opts = opts or {}

  return ParameterClass.new({
    name = name,
    data_type = data_type,
    mode = mode,
    has_default = opts.has_default or false,
    max_length = opts.max_length,
    precision = opts.precision,
    scale = opts.scale,
    ordinal_position = opts.ordinal_position,
    parent = parent,
  })
end

---Create a server from user configuration
---@param config_name string The configuration name (key in config.connections)
---@param connection_string string The connection string
---@return ServerClass? server The created server or nil if failed
---@return string? error_message Error message if creation failed
function Factory.create_server_from_config(config_name, connection_string)
  -- Validate connection string
  if not connection_string or connection_string == "" then
    return nil, "Connection string is empty"
  end

  -- Create server with config name as display name
  local server, err = Factory.create_server(config_name, connection_string)

  if err then
    return nil, err
  end

  return server, nil
end

---Clone a server configuration with a new connection
---Useful for creating multiple connections to the same server
---@param source_server ServerClass The source server to clone
---@param new_name string New display name
---@return ServerClass cloned_server The cloned server instance
function Factory.clone_server(source_server, new_name)
  local ServerClass = require('ssns.classes.server')

  local cloned = ServerClass.new({
    name = new_name,
    connection_string = source_server.connection_string,
  })

  return cloned
end

---Create multiple servers from configuration table
---@param connections table<string, string> Map of connection names to connection strings
---@return ServerClass[] servers Array of created server instances
---@return table<string, string> errors Map of connection names to error messages (for failed connections)
function Factory.create_servers_from_config(connections)
  local servers = {}
  local errors = {}

  for name, connection_string in pairs(connections) do
    local server, err = Factory.create_server_from_config(name, connection_string)

    if server then
      table.insert(servers, server)
    else
      errors[name] = err or "Unknown error"
    end
  end

  return servers, errors
end

---Validate a connection string format
---@param connection_string string
---@return boolean valid
---@return string? error_message
function Factory.validate_connection_string(connection_string)
  if not connection_string or connection_string == "" then
    return false, "Connection string is empty"
  end

  -- Check if it matches a known database type pattern
  local AdapterFactory = require('ssns.adapters.factory')
  local db_type = AdapterFactory.get_db_type(connection_string)

  if not db_type then
    return false, "Unknown database type in connection string"
  end

  -- Check if adapter exists for this database type
  if not AdapterFactory.adapter_exists(db_type) then
    return false, string.format("No adapter available for database type: %s", db_type)
  end

  return true, nil
end

---Create a test server (for development/testing)
---@return ServerClass server Test server instance
function Factory.create_test_server()
  local test_connection = "sqlserver://localhost/vim_dadbod_test"

  local server = Factory.create_server("Test Server", test_connection)
  return server
end

return Factory
