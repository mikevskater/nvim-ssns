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

  self.object_type = "database"
  self.db_name = opts.name
  self.schemas = nil
  self.is_connected = false

  return self
end

---Load objects from database (vim-dadbod-ui style - no schema nodes)
---@return boolean success
function DbClass:load()
  if self.is_loaded then
    return true
  end

  local adapter = self:get_adapter()
  self:clear_children()

  -- Load all objects across ALL schemas and group by type
  -- This matches vim-dadbod-ui structure: Database -> TABLES/VIEWS/etc (no schema nodes)

  -- Load tables from all schemas
  local tables = self:load_all_tables()

  -- Load views from all schemas
  local views = self:load_all_views()

  -- Load procedures from all schemas
  local procedures = self:load_all_procedures()

  -- Load functions from all schemas
  local functions = self:load_all_functions()

  -- Load synonyms from all schemas
  local synonyms = self:load_all_synonyms()

  -- Create object type groups
  self:create_object_type_groups(tables, views, procedures, functions, synonyms)

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
  -- Invalidate query cache for this database's server connection
  local Connection = require('ssns.connection')
  local server = self:get_server()
  if server and server.connection_string then
    Connection.invalidate_cache(server.connection_string)
  end

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

---Load all synonyms from all schemas
---@return table[] Array of synonym objects
function DbClass:load_all_synonyms()
  local adapter = self:get_adapter()

  if not adapter.features.synonyms then
    return {}
  end

  -- Get synonyms query - pass nil for schema_name to get ALL synonyms
  local query = adapter:get_synonyms_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local synonym_data_list = adapter:parse_synonyms(results)

  local SynonymClass = require('ssns.classes.synonym')
  local synonyms = {}
  for _, syn_data in ipairs(synonym_data_list) do
    -- Pass nil as parent to avoid auto-adding to database.children
    local syn_obj = SynonymClass.new({
      name = syn_data.name,
      schema_name = syn_data.schema,
      base_object_name = syn_data.base_object_name,
      base_object_type = syn_data.base_object_type,
      parent = nil,  -- Don't auto-add to children
    })
    -- Set parent manually for hierarchy navigation (without adding to children)
    syn_obj.parent = self
    table.insert(synonyms, syn_obj)
  end

  return synonyms
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

---Load all tables from all schemas
---@return table[] Array of table objects
function DbClass:load_all_tables()
  local adapter = self:get_adapter()

  -- Get tables query - pass nil for schema_name to get ALL tables
  local query = adapter:get_tables_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local table_data_list = adapter:parse_tables(results)

  local tables = {}
  for _, table_data in ipairs(table_data_list) do
    -- Pass nil as parent to avoid auto-adding to database.children
    local table_obj = adapter:create_table(nil, table_data)
    -- Set parent manually for hierarchy navigation (without adding to children)
    table_obj.parent = self
    table.insert(tables, table_obj)
  end

  return tables
end

---Load all views from all schemas
---@return table[] Array of view objects
function DbClass:load_all_views()
  local adapter = self:get_adapter()

  if not adapter.features.views then
    return {}
  end

  local query = adapter:get_views_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local view_data_list = adapter:parse_views(results)

  local views = {}
  for _, view_data in ipairs(view_data_list) do
    local view_obj = adapter:create_view(nil, view_data)
    view_obj.parent = self
    table.insert(views, view_obj)
  end

  return views
end

---Load all procedures from all schemas
---@return table[] Array of procedure objects
function DbClass:load_all_procedures()
  local adapter = self:get_adapter()

  if not adapter.features.procedures then
    return {}
  end

  local query = adapter:get_procedures_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local proc_data_list = adapter:parse_procedures(results)

  local procedures = {}
  for _, proc_data in ipairs(proc_data_list) do
    local proc_obj = adapter:create_procedure(nil, proc_data)
    proc_obj.parent = self
    table.insert(procedures, proc_obj)
  end

  return procedures
end

---Load all functions from all schemas
---@return table[] Array of function objects
function DbClass:load_all_functions()
  local adapter = self:get_adapter()

  if not adapter.features.functions then
    return {}
  end

  local query = adapter:get_functions_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local func_data_list = adapter:parse_functions(results)

  local functions = {}
  for _, func_data in ipairs(func_data_list) do
    local func_obj = adapter:create_function(nil, func_data)
    func_obj.parent = self
    table.insert(functions, func_obj)
  end

  return functions
end

---Create object type groups (TABLES, VIEWS, PROCEDURES, FUNCTIONS, SYNONYMS)
---@param tables table[]
---@param views table[]
---@param procedures table[]
---@param functions table[]
---@param synonyms table[]
function DbClass:create_object_type_groups(tables, views, procedures, functions, synonyms)
  -- Always create TABLES group (even if empty)
  local tables_group = BaseDbObject.new({
    name = string.format("TABLES (%d)", #tables),
    parent = self,
  })
  tables_group.object_type = "tables_group"

  -- Add tables to group (but keep their parent as database for hierarchy)
  for _, table_obj in ipairs(tables) do
    table.insert(tables_group.children, table_obj)
  end

  tables_group.is_loaded = true

  -- Always create VIEWS group (even if empty)
  local views_group = BaseDbObject.new({
    name = string.format("VIEWS (%d)", #views),
    parent = self,
  })
  views_group.object_type = "views_group"

  for _, view_obj in ipairs(views) do
    table.insert(views_group.children, view_obj)
  end

  views_group.is_loaded = true

  -- Always create PROCEDURES group (even if empty)
  local procs_group = BaseDbObject.new({
    name = string.format("PROCEDURES (%d)", #procedures),
    parent = self,
  })
  procs_group.object_type = "procedures_group"

  for _, proc_obj in ipairs(procedures) do
    table.insert(procs_group.children, proc_obj)
  end

  procs_group.is_loaded = true

  -- Always create FUNCTIONS group (even if empty)
  local funcs_group = BaseDbObject.new({
    name = string.format("FUNCTIONS (%d)", #functions),
    parent = self,
  })
  funcs_group.object_type = "functions_group"

  for _, func_obj in ipairs(functions) do
    table.insert(funcs_group.children, func_obj)
  end

  funcs_group.is_loaded = true

  -- Create SYNONYMS group if adapter supports synonyms
  local adapter = self:get_adapter()
  if adapter.features.synonyms then
    local synonyms_group = BaseDbObject.new({
      name = string.format("SYNONYMS (%d)", #synonyms),
      parent = self,
    })
    synonyms_group.object_type = "synonyms_group"

    for _, syn_obj in ipairs(synonyms) do
      table.insert(synonyms_group.children, syn_obj)
    end

    synonyms_group.is_loaded = true
  end

  -- Create SCHEMAS group (alternate schema-based view)
  self:create_schemas_group(tables, views, procedures, functions, synonyms)
end

---Create SCHEMAS group with schema-based organization
---@param tables table[]
---@param views table[]
---@param procedures table[]
---@param functions table[]
---@param synonyms table[]
function DbClass:create_schemas_group(tables, views, procedures, functions, synonyms)
  local BaseDbObject = require('ssns.classes.base')

  -- Collect unique schemas
  local schemas_map = {}

  for _, table_obj in ipairs(tables) do
    if table_obj.schema_name then
      schemas_map[table_obj.schema_name] = true
    end
  end
  for _, view_obj in ipairs(views) do
    if view_obj.schema_name then
      schemas_map[view_obj.schema_name] = true
    end
  end
  for _, proc_obj in ipairs(procedures) do
    if proc_obj.schema_name then
      schemas_map[proc_obj.schema_name] = true
    end
  end
  for _, func_obj in ipairs(functions) do
    if func_obj.schema_name then
      schemas_map[func_obj.schema_name] = true
    end
  end
  for _, syn_obj in ipairs(synonyms) do
    if syn_obj.schema_name then
      schemas_map[syn_obj.schema_name] = true
    end
  end

  local schema_names = {}
  for schema_name in pairs(schemas_map) do
    table.insert(schema_names, schema_name)
  end
  table.sort(schema_names)

  -- Create SCHEMAS group
  local schemas_group = BaseDbObject.new({
    name = string.format("SCHEMAS (%d)", #schema_names),
    parent = self,
  })
  schemas_group.object_type = "schemas_group"

  -- Create schema nodes with lazy loading
  for _, schema_name in ipairs(schema_names) do
    local schema_node = BaseDbObject.new({
      name = schema_name,
      parent = schemas_group,
    })
    schema_node.object_type = "schema_view"
    schema_node.schema_name = schema_name

    -- Lazy load function for schema node
    schema_node.load = function(self_node)
      if self_node.is_loaded then
        return true
      end

      self_node:clear_children()

      -- Collect all objects in this schema
      local schema_objects = {}

      for _, table_obj in ipairs(tables) do
        if table_obj.schema_name == schema_name then
          table.insert(schema_objects, {
            obj = table_obj,
            name = string.format("[%s].[%s]", table_obj.schema_name, table_obj.table_name),
            type = "table"
          })
        end
      end
      for _, view_obj in ipairs(views) do
        if view_obj.schema_name == schema_name then
          table.insert(schema_objects, {
            obj = view_obj,
            name = string.format("[%s].[%s]", view_obj.schema_name, view_obj.view_name),
            type = "view"
          })
        end
      end
      for _, proc_obj in ipairs(procedures) do
        if proc_obj.schema_name == schema_name then
          table.insert(schema_objects, {
            obj = proc_obj,
            name = string.format("[%s].[%s]", proc_obj.schema_name, proc_obj.procedure_name),
            type = "procedure"
          })
        end
      end
      for _, func_obj in ipairs(functions) do
        if func_obj.schema_name == schema_name then
          table.insert(schema_objects, {
            obj = func_obj,
            name = string.format("[%s].[%s]", func_obj.schema_name, func_obj.function_name),
            type = "function"
          })
        end
      end
      for _, syn_obj in ipairs(synonyms) do
        if syn_obj.schema_name == schema_name then
          table.insert(schema_objects, {
            obj = syn_obj,
            name = string.format("[%s].[%s]", syn_obj.schema_name, syn_obj.synonym_name),
            type = "synonym"
          })
        end
      end

      -- Sort objects by name
      table.sort(schema_objects, function(a, b)
        return a.name < b.name
      end)

      -- Add reference nodes that point to the actual objects
      for _, item in ipairs(schema_objects) do
        local ref_node = BaseDbObject.new({
          name = item.name,
          parent = self_node,
        })
        ref_node.object_type = "object_reference"
        ref_node.referenced_object = item.obj

        -- Proxy methods to the referenced object for full functionality
        ref_node.has_children = function(self_ref)
          return self_ref.referenced_object:has_children()
        end

        ref_node.get_children = function(self_ref)
          return self_ref.referenced_object:get_children()
        end

        ref_node.load = function(self_ref)
          -- Load the referenced object
          if self_ref.referenced_object.load then
            return self_ref.referenced_object:load()
          end
          return true
        end

        -- Proxy all query generation methods for actions
        ref_node.generate_select = function(self_ref, limit)
          if self_ref.referenced_object.generate_select then
            return self_ref.referenced_object:generate_select(limit)
          end
        end

        ref_node.generate_exec = function(self_ref)
          if self_ref.referenced_object.generate_exec then
            return self_ref.referenced_object:generate_exec()
          end
        end

        ref_node.generate_count = function(self_ref)
          if self_ref.referenced_object.generate_count then
            return self_ref.referenced_object:generate_count()
          end
        end

        ref_node.generate_describe = function(self_ref)
          if self_ref.referenced_object.generate_describe then
            return self_ref.referenced_object:generate_describe()
          end
        end

        ref_node.generate_insert = function(self_ref)
          if self_ref.referenced_object.generate_insert then
            return self_ref.referenced_object:generate_insert()
          end
        end

        ref_node.generate_update = function(self_ref)
          if self_ref.referenced_object.generate_update then
            return self_ref.referenced_object:generate_update()
          end
        end

        ref_node.generate_delete = function(self_ref)
          if self_ref.referenced_object.generate_delete then
            return self_ref.referenced_object:generate_delete()
          end
        end

        ref_node.get_definition = function(self_ref)
          if self_ref.referenced_object.get_definition then
            return self_ref.referenced_object:get_definition()
          end
        end

        -- Proxy methods for getting server/database/adapter
        ref_node.get_server = function(self_ref)
          return self_ref.referenced_object:get_server()
        end

        ref_node.get_database = function(self_ref)
          return self_ref.referenced_object:get_database()
        end

        ref_node.get_adapter = function(self_ref)
          return self_ref.referenced_object:get_adapter()
        end

        -- Proxy synonym resolve method for GO-TO action
        ref_node.resolve = function(self_ref)
          if self_ref.referenced_object.resolve then
            return self_ref.referenced_object:resolve()
          end
        end

        ref_node.is_loaded = false  -- Will be loaded on demand
      end

      self_node.is_loaded = true
      return true
    end
  end

  schemas_group.is_loaded = true
end

return DbClass
