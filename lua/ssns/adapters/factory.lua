---@class AdapterFactory
local AdapterFactory = {}

---Supported database type patterns
---@type table<string, string>
local DB_TYPE_PATTERNS = {
  ["^sqlserver://"] = "sqlserver",
  ["^mssql://"] = "sqlserver",
  ["^postgres://"] = "postgres",
  ["^postgresql://"] = "postgres",
  ["^mysql://"] = "mysql",
  ["^sqlite://"] = "sqlite",
  ["^bigquery://"] = "bigquery",
}

---Detect database type from connection string
---@param connection_string string
---@return string? db_type The detected database type or nil if unknown
local function detect_db_type(connection_string)
  for pattern, db_type in pairs(DB_TYPE_PATTERNS) do
    if connection_string:match(pattern) then
      return db_type
    end
  end
  return nil
end

---Create an adapter instance from a connection string
---Automatically detects the database type and returns the appropriate adapter
---@param connection_string string The database connection string
---@return BaseAdapter? adapter The created adapter instance or nil if type unknown
---@return string? error_message Error message if adapter creation failed
function AdapterFactory.create_adapter(connection_string)
  if not connection_string or connection_string == "" then
    return nil, "Connection string is empty"
  end

  local db_type = detect_db_type(connection_string)

  if not db_type then
    return nil, string.format("Unknown database type in connection string: %s", connection_string)
  end

  -- Load the appropriate adapter module
  local adapter_module_name = string.format("ssns.adapters.%s", db_type)
  local ok, adapter_module = pcall(require, adapter_module_name)

  if not ok then
    return nil, string.format("Failed to load adapter for %s: %s", db_type, adapter_module)
  end

  -- Create and return the adapter instance
  local adapter = adapter_module.new(connection_string)
  return adapter, nil
end

---Get list of supported database types
---@return string[] db_types Array of supported database type identifiers
function AdapterFactory.get_supported_types()
  local types = {}
  local seen = {}

  for _, db_type in pairs(DB_TYPE_PATTERNS) do
    if not seen[db_type] then
      table.insert(types, db_type)
      seen[db_type] = true
    end
  end

  table.sort(types)
  return types
end

---Check if a database type is supported
---@param db_type string
---@return boolean
function AdapterFactory.is_supported(db_type)
  for _, supported_type in pairs(DB_TYPE_PATTERNS) do
    if supported_type == db_type then
      return true
    end
  end
  return false
end

---Get the database type from a connection string without creating an adapter
---@param connection_string string
---@return string? db_type
function AdapterFactory.get_db_type(connection_string)
  return detect_db_type(connection_string)
end

---Register a custom database type pattern
---Allows users to add support for custom database types
---@param pattern string Lua pattern to match against connection strings
---@param db_type string The database type identifier
function AdapterFactory.register_type(pattern, db_type)
  DB_TYPE_PATTERNS[pattern] = db_type
end

---Validate that an adapter module exists for a database type
---@param db_type string
---@return boolean exists
function AdapterFactory.adapter_exists(db_type)
  local adapter_module_name = string.format("ssns.adapters.%s", db_type)
  local ok, _ = pcall(require, adapter_module_name)
  return ok
end

return AdapterFactory
