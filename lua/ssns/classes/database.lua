local BaseDbObject = require('ssns.classes.base')

---@class DbClass : BaseDbObject
---@field db_name string The database name
---@field parent ServerClass The parent server object
---@field schemas SchemaClass[]? Array of schema objects
---@field is_connected boolean Whether this database is the active connection
local DbClass = setmetatable({}, { __index = BaseDbObject })
DbClass.__index = DbClass

---Create a new Database instance
---@param opts {name: string, parent: ServerClass}
---@return DbClass
function DbClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), DbClass)

  self.db_name = opts.name
  self.schemas = nil
  self.is_connected = false

  -- Set appropriate icon for database
  self.ui_state.icon = ""  -- Database icon

  return self
end

---Load schemas from the database
---@return boolean success
function DbClass:load()
  if self.is_loaded then
    return true
  end

  local adapter = self:get_adapter()

  -- Check if this database type supports schemas
  if not adapter.features.schemas then
    -- For databases without schemas (MySQL, SQLite), load tables directly
    return self:load_tables_directly()
  end

  -- Get schemas query from adapter
  local query = adapter:get_schemas_query(self.db_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local schemas = adapter:parse_schemas(results)

  -- Create schema objects
  self:clear_children()
  for _, schema_data in ipairs(schemas) do
    local SchemaClass = require('ssns.classes.schema')
    local schema = SchemaClass.new({
      name = schema_data.name,
      parent = self,
    })
  end

  self.is_loaded = true
  return true
end

---Load tables directly for databases without schema support
---@return boolean success
function DbClass:load_tables_directly()
  -- For databases like MySQL/SQLite that don't have schemas,
  -- create a single "default" schema to hold all objects
  self:clear_children()

  local SchemaClass = require('ssns.classes.schema')
  local default_schema = SchemaClass.new({
    name = self.db_name,  -- Use database name as schema name
    parent = self,
  })

  self.is_loaded = true
  return true
end

---Reload schemas from database
---@return boolean success
function DbClass:reload()
  self:clear_children()
  return self:load()
end

---Find a schema by name
---@param schema_name string
---@return SchemaClass?
function DbClass:find_schema(schema_name)
  return self:find_child(schema_name)
end

---Get all schemas
---@return SchemaClass[]
function DbClass:get_schemas()
  if not self.is_loaded then
    self:load()
  end
  return self.children
end

---Get the default schema for this database type
---@return string default_schema
function DbClass:get_default_schema()
  local adapter = self:get_adapter()

  if not adapter.features.schemas then
    -- No schema concept - return database name
    return self.db_name
  end

  -- Database-specific defaults
  if adapter.db_type == "sqlserver" then
    return "dbo"
  elseif adapter.db_type == "postgres" then
    return "public"
  elseif adapter.db_type == "mysql" then
    return self.db_name
  elseif adapter.db_type == "sqlite" then
    return "main"
  end

  return "dbo"  -- Fallback
end

---Load synonyms (SQL Server specific)
---@return boolean success
function DbClass:load_synonyms()
  local adapter = self:get_adapter()

  if not adapter.features.synonyms then
    return false
  end

  -- Get synonyms query from adapter
  local query = adapter:get_synonyms_query(self.db_name, nil)

  -- Execute query
  -- TODO: Implement actual execution
  local results = adapter:execute(self:get_server().connection, query)

  -- TODO: Parse and create synonym objects
  -- This will be implemented when we create SynonymClass

  return true
end

---Connect to this database (make it the active database)
function DbClass:connect()
  -- Disconnect all other databases on this server
  local server = self:get_server()
  for _, db in ipairs(server:get_databases()) do
    if db ~= self then
      db.is_connected = false
    end
  end

  self.is_connected = true
end

---Disconnect from this database
function DbClass:disconnect()
  self.is_connected = false
end

---Toggle connection to this database
function DbClass:toggle_connection()
  if self.is_connected then
    self:disconnect()
  else
    self:connect()
  end
end

---Get connection status indicator for UI
---@return string status_icon "✓" for connected, "" for disconnected
function DbClass:get_status_icon()
  return self.is_connected and "✓" or ""
end

---Get display name with connection status
---@return string
function DbClass:get_display_name()
  local status = self:get_status_icon()
  if status ~= "" then
    return string.format("%s %s", self.name, status)
  end
  return self.name
end

---Get the full database path for qualified names
---@return string
function DbClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:quote_identifier(self.db_name)
end

---Get string representation for debugging
---@return string
function DbClass:to_string()
  return string.format(
    "DbClass{name=%s, schemas=%d, connected=%s}",
    self.name,
    #self.children,
    tostring(self.is_connected)
  )
end

return DbClass
