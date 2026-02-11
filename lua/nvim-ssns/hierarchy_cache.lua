---Persistent hierarchy cache for database object trees
---Saves the object hierarchy (databases -> schemas -> tables/views/procs/funcs/synonyms)
---to disk so the tree appears pre-populated instantly on reconnect.
---@class HierarchyCache
local HierarchyCache = {}

local uv = vim.loop
local FileIO = require('nvim-ssns.async.file_io')

---@type table<string, uv_timer_t> Debounce timers per connection key
HierarchyCache._timers = {}

---@type table<string, boolean> Dirty flags per connection key
HierarchyCache._dirty = {}

---@type table<string, ServerClass> Pending server refs per connection key (for debounced writes)
HierarchyCache._pending = {}

---Cache format version
HierarchyCache.VERSION = 1

---Debounce delay in milliseconds
HierarchyCache.debounce_ms = 2000

-- ============================================================================
-- File Path Helpers
-- ============================================================================

---Get the base directory for hierarchy cache files
---@return string
function HierarchyCache.get_base_dir()
  return vim.fn.stdpath('data') .. '/nvim-ssns/hierarchy_cache'
end

---Sanitize a connection key into a valid filename
---@param conn_key string Connection key
---@return string filename Sanitized filename with .json extension
function HierarchyCache.sanitize_filename(conn_key)
  local sanitized = conn_key:gsub('[:/\\%*%?%"<>|%%]', '_')
  sanitized = sanitized:gsub('_+', '_')
  sanitized = sanitized:gsub('_$', '')
  return sanitized .. '.json'
end

---Get the full file path for a connection's hierarchy cache
---@param conn_key string Connection key
---@return string path Full path to the JSON file
function HierarchyCache.get_file_path(conn_key)
  return HierarchyCache.get_base_dir() .. '/' .. HierarchyCache.sanitize_filename(conn_key)
end

-- ============================================================================
-- Serialization (save)
-- ============================================================================

---Extract serializable data from a schema object
---@param schema SchemaClass
---@return table schema_data
local function serialize_schema(schema)
  local data = {
    tables = {},
    views = {},
    procedures = {},
    functions = {},
    synonyms = {},
  }

  -- Tables
  for _, tbl in ipairs(schema.tables or {}) do
    table.insert(data.tables, {
      name = tbl.name,
      schema_name = tbl.schema_name,
      table_type = tbl.table_type,
    })
  end

  -- Views
  for _, view in ipairs(schema.views or {}) do
    table.insert(data.views, {
      name = view.name,
      schema_name = view.schema_name,
    })
  end

  -- Procedures
  for _, proc in ipairs(schema.procedures or {}) do
    table.insert(data.procedures, {
      name = proc.name,
      schema_name = proc.schema_name,
    })
  end

  -- Functions
  for _, func in ipairs(schema.functions or {}) do
    table.insert(data.functions, {
      name = func.name,
      schema_name = func.schema_name,
      function_type = func.function_type,
    })
  end

  -- Synonyms
  for _, syn in ipairs(schema.synonyms or {}) do
    table.insert(data.synonyms, {
      name = syn.name,
      schema_name = syn.schema_name,
      base_object_name = syn.base_object_name,
      base_object_type = syn.base_object_type,
    })
  end

  return data
end

---Extract serializable data from a database (non-schema server)
---@param db DbClass
---@return table db_data Objects directly on database
local function serialize_db_objects(db)
  local data = {
    tables = {},
    views = {},
    procedures = {},
    functions = {},
  }

  for _, tbl in ipairs(db.tables or {}) do
    table.insert(data.tables, {
      name = tbl.name,
      table_type = tbl.table_type,
    })
  end

  for _, view in ipairs(db.views or {}) do
    table.insert(data.views, { name = view.name })
  end

  for _, proc in ipairs(db.procedures or {}) do
    table.insert(data.procedures, { name = proc.name })
  end

  for _, func in ipairs(db.functions or {}) do
    table.insert(data.functions, {
      name = func.name,
      function_type = func.function_type,
    })
  end

  return data
end

---Walk server hierarchy and extract serializable data
---Only caches loaded branches (what the user has expanded)
---@param server ServerClass
---@return table data Serializable hierarchy data
function HierarchyCache.serialize(server)
  local Connections = require('nvim-ssns.connections')
  local conn_key = Connections.generate_connection_key(server.connection_config)

  local data = {
    version = HierarchyCache.VERSION,
    connection_key = conn_key,
    saved_at = os.time(),
    db_type = server:get_db_type(),
    databases = {},
  }

  for _, db in ipairs(server.databases or {}) do
    if db.is_loaded then
      local db_entry = {}

      if db.schemas then
        -- Schema-based server (SQL Server, PostgreSQL)
        db_entry.schemas = {}
        for _, schema in ipairs(db.schemas) do
          -- Always cache schema names; only cache objects if loaded
          if schema.tables or schema.views or schema.procedures
              or schema.functions or schema.synonyms then
            db_entry.schemas[schema.name] = serialize_schema(schema)
          else
            -- Schema exists but objects not loaded yet — store empty placeholder
            db_entry.schemas[schema.name] = {}
          end
        end
      else
        -- Non-schema server (MySQL, SQLite)
        db_entry.objects = serialize_db_objects(db)
      end

      data.databases[db.name] = db_entry
    end
  end

  return data
end

-- ============================================================================
-- Disk I/O
-- ============================================================================

---Save hierarchy data to disk asynchronously with atomic write
---@param server ServerClass
function HierarchyCache.save(server)
  local Connections = require('nvim-ssns.connections')
  local conn_key = Connections.generate_connection_key(server.connection_config)
  local base_dir = HierarchyCache.get_base_dir()
  local path = HierarchyCache.get_file_path(conn_key)
  local temp_path = path .. '.tmp'

  local data = HierarchyCache.serialize(server)

  local ok_encode, json = pcall(vim.fn.json_encode, data)
  if not ok_encode then
    vim.schedule(function()
      vim.notify('SSNS: Failed to encode hierarchy cache: ' .. tostring(json), vim.log.levels.WARN)
    end)
    return
  end

  FileIO.mkdir_async(base_dir, function(mkdir_ok, mkdir_err)
    if not mkdir_ok then
      vim.schedule(function()
        vim.notify('SSNS: Failed to create hierarchy cache dir: ' .. tostring(mkdir_err), vim.log.levels.WARN)
      end)
      return
    end

    FileIO.write_async(temp_path, json, function(write_result)
      if not write_result.success then
        vim.schedule(function()
          vim.notify('SSNS: Failed to write hierarchy cache: ' .. tostring(write_result.error), vim.log.levels.WARN)
        end)
        return
      end

      -- Atomic rename (Windows: remove target first)
      os.remove(path)
      FileIO.rename_async(temp_path, path, function(rename_ok, rename_err)
        if not rename_ok then
          local sync_ok = os.rename(temp_path, path)
          if not sync_ok then
            vim.schedule(function()
              vim.notify('SSNS: Failed to rename hierarchy cache: ' .. tostring(rename_err), vim.log.levels.WARN)
            end)
            os.remove(temp_path)
          end
        end

        -- Clear dirty flag
        HierarchyCache._dirty[conn_key] = nil
      end)
    end)
  end)
end

---Schedule a debounced save for a server
---@param server ServerClass
function HierarchyCache.schedule_save(server)
  if not server or not server.connection_config then
    return
  end

  -- Check if hierarchy persistence is enabled
  local Config = require('nvim-ssns.config')
  local cache_config = Config.get().cache or {}
  if cache_config.persist_hierarchy == false then
    return
  end

  local Connections = require('nvim-ssns.connections')
  local conn_key = Connections.generate_connection_key(server.connection_config)

  -- Store pending server ref and mark dirty
  HierarchyCache._pending[conn_key] = server
  HierarchyCache._dirty[conn_key] = true

  -- Cancel existing timer
  if HierarchyCache._timers[conn_key] then
    HierarchyCache._timers[conn_key]:stop()
    HierarchyCache._timers[conn_key]:close()
    HierarchyCache._timers[conn_key] = nil
  end

  -- Create new debounce timer
  local timer = uv.new_timer()
  HierarchyCache._timers[conn_key] = timer

  timer:start(HierarchyCache.debounce_ms, 0, vim.schedule_wrap(function()
    if HierarchyCache._timers[conn_key] == timer then
      HierarchyCache._timers[conn_key] = nil
    end
    timer:stop()
    timer:close()

    local pending_server = HierarchyCache._pending[conn_key]
    if pending_server then
      HierarchyCache._pending[conn_key] = nil
      HierarchyCache.save(pending_server)
    end
  end))
end

---Load hierarchy data from disk (synchronous — used at connect time)
---@param conn_key string Connection key
---@return table? data Parsed hierarchy data, or nil if not found/corrupt
function HierarchyCache.load_sync(conn_key)
  local path = HierarchyCache.get_file_path(conn_key)

  local f = io.open(path, 'r')
  if not f then
    return nil
  end

  local content = f:read('*a')
  f:close()

  if not content or content == '' then
    return nil
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify('SSNS: Corrupt hierarchy cache file, removing: ' .. path, vim.log.levels.WARN)
    os.remove(path)
    return nil
  end

  if data.version ~= HierarchyCache.VERSION then
    vim.notify('SSNS: Unsupported hierarchy cache version, removing: ' .. path, vim.log.levels.WARN)
    os.remove(path)
    return nil
  end

  return data
end

-- ============================================================================
-- Staleness Check
-- ============================================================================

---Check if cached data is stale based on config TTL
---@param data table Parsed hierarchy data with saved_at field
---@return boolean is_stale True if cache has expired
function HierarchyCache.is_stale(data)
  if not data or not data.saved_at then
    return true
  end

  local Config = require('nvim-ssns.config')
  local cache_config = Config.get().cache or {}
  local ttl = cache_config.hierarchy_ttl or 86400

  return (os.time() - data.saved_at) > ttl
end

-- ============================================================================
-- Hydration (load cached hierarchy into live objects)
-- ============================================================================

---Reconstruct the object hierarchy from cached data
---@param server ServerClass The server to hydrate
---@param data table Parsed hierarchy cache data
function HierarchyCache.hydrate(server, data)
  if not data or not data.databases then
    return
  end

  local DbClass = require('nvim-ssns.classes.database')
  local SchemaClass = require('nvim-ssns.classes.schema')
  local adapter = server:get_adapter()

  if not adapter then
    return
  end

  server.databases = {}

  for db_name, db_entry in pairs(data.databases) do
    local db = DbClass.new({
      name = db_name,
      parent = server,
    })

    if db_entry.schemas then
      -- Schema-based server
      db.schemas = {}
      for schema_name, schema_data in pairs(db_entry.schemas) do
        local schema = SchemaClass.new({
          name = schema_name,
          parent = db,
        })

        -- Hydrate objects if cached
        if schema_data.tables and #schema_data.tables > 0 then
          schema.tables = {}
          for _, tbl_data in ipairs(schema_data.tables) do
            local tbl = adapter:create_table(schema, {
              name = tbl_data.name,
              schema = tbl_data.schema_name,
              type = tbl_data.table_type,
            })
            tbl.ui_state = tbl.ui_state or {}
            tbl.ui_state.from_cache = true
            table.insert(schema.tables, tbl)
          end
        end

        if schema_data.views and #schema_data.views > 0 then
          schema.views = {}
          for _, view_data in ipairs(schema_data.views) do
            local view = adapter:create_view(schema, {
              name = view_data.name,
              schema = view_data.schema_name,
            })
            view.ui_state = view.ui_state or {}
            view.ui_state.from_cache = true
            table.insert(schema.views, view)
          end
        end

        if schema_data.procedures and #schema_data.procedures > 0 then
          local ProcedureClass = require('nvim-ssns.classes.procedure')
          schema.procedures = {}
          for _, proc_data in ipairs(schema_data.procedures) do
            local proc = ProcedureClass.new({
              name = proc_data.name,
              schema_name = proc_data.schema_name,
              parent = schema,
            })
            proc.ui_state = proc.ui_state or {}
            proc.ui_state.from_cache = true
            table.insert(schema.procedures, proc)
          end
        end

        if schema_data.functions and #schema_data.functions > 0 then
          local FunctionClass = require('nvim-ssns.classes.function')
          schema.functions = {}
          for _, func_data in ipairs(schema_data.functions) do
            local func = FunctionClass.new({
              name = func_data.name,
              schema_name = func_data.schema_name,
              function_type = func_data.function_type,
              parent = schema,
            })
            func.ui_state = func.ui_state or {}
            func.ui_state.from_cache = true
            table.insert(schema.functions, func)
          end
        end

        if schema_data.synonyms and #schema_data.synonyms > 0 then
          local SynonymClass = require('nvim-ssns.classes.synonym')
          schema.synonyms = {}
          for _, syn_data in ipairs(schema_data.synonyms) do
            local syn = SynonymClass.new({
              name = syn_data.name,
              schema_name = syn_data.schema_name,
              base_object_name = syn_data.base_object_name,
              base_object_type = syn_data.base_object_type,
              parent = schema,
            })
            syn.ui_state = syn.ui_state or {}
            syn.ui_state.from_cache = true
            table.insert(schema.synonyms, syn)
          end
        end

        -- Mark schema as loaded if it had any objects cached
        if schema.tables or schema.views or schema.procedures
            or schema.functions or schema.synonyms then
          schema.is_loaded = true
        end

        table.insert(db.schemas, schema)
      end
    elseif db_entry.objects then
      -- Non-schema server
      local objects = db_entry.objects

      if objects.tables and #objects.tables > 0 then
        db.tables = {}
        for _, tbl_data in ipairs(objects.tables) do
          local tbl = adapter:create_table(db, {
            name = tbl_data.name,
            type = tbl_data.table_type,
          })
          tbl.ui_state = tbl.ui_state or {}
          tbl.ui_state.from_cache = true
          table.insert(db.tables, tbl)
        end
      end

      if objects.views and #objects.views > 0 then
        db.views = {}
        for _, view_data in ipairs(objects.views) do
          local view = adapter:create_view(db, {
            name = view_data.name,
          })
          view.ui_state = view.ui_state or {}
          view.ui_state.from_cache = true
          table.insert(db.views, view)
        end
      end

      if objects.procedures and #objects.procedures > 0 then
        local ProcedureClass = require('nvim-ssns.classes.procedure')
        db.procedures = {}
        for _, proc_data in ipairs(objects.procedures) do
          local proc = ProcedureClass.new({
            name = proc_data.name,
            parent = db,
          })
          proc.ui_state = proc.ui_state or {}
          proc.ui_state.from_cache = true
          table.insert(db.procedures, proc)
        end
      end

      if objects.functions and #objects.functions > 0 then
        local FunctionClass = require('nvim-ssns.classes.function')
        db.functions = {}
        for _, func_data in ipairs(objects.functions) do
          local func = FunctionClass.new({
            name = func_data.name,
            function_type = func_data.function_type,
            parent = db,
          })
          func.ui_state = func.ui_state or {}
          func.ui_state.from_cache = true
          table.insert(db.functions, func)
        end
      end
    end

    db.is_loaded = true
    db.ui_state = db.ui_state or {}
    db.ui_state.from_cache = true
    table.insert(server.databases, db)
  end

  server.is_loaded = true
end

-- ============================================================================
-- Background Refresh
-- ============================================================================

---Clear from_cache flags on all objects under a server
---@param server ServerClass
local function clear_cache_flags(server)
  for _, db in ipairs(server.databases or {}) do
    if db.ui_state then db.ui_state.from_cache = nil end

    if db.schemas then
      for _, schema in ipairs(db.schemas) do
        for _, tbl in ipairs(schema.tables or {}) do
          if tbl.ui_state then tbl.ui_state.from_cache = nil end
        end
        for _, view in ipairs(schema.views or {}) do
          if view.ui_state then view.ui_state.from_cache = nil end
        end
        for _, proc in ipairs(schema.procedures or {}) do
          if proc.ui_state then proc.ui_state.from_cache = nil end
        end
        for _, func in ipairs(schema.functions or {}) do
          if func.ui_state then func.ui_state.from_cache = nil end
        end
        for _, syn in ipairs(schema.synonyms or {}) do
          if syn.ui_state then syn.ui_state.from_cache = nil end
        end
      end
    else
      for _, tbl in ipairs(db.tables or {}) do
        if tbl.ui_state then tbl.ui_state.from_cache = nil end
      end
      for _, view in ipairs(db.views or {}) do
        if view.ui_state then view.ui_state.from_cache = nil end
      end
      for _, proc in ipairs(db.procedures or {}) do
        if proc.ui_state then proc.ui_state.from_cache = nil end
      end
      for _, func in ipairs(db.functions or {}) do
        if func.ui_state then func.ui_state.from_cache = nil end
      end
    end
  end
end

---Schedule a silent background refresh after hydrating from cache
---Re-queries metadata in background; if different from cached data, re-renders tree
---@param server ServerClass
function HierarchyCache.schedule_background_refresh(server)
  local Config = require('nvim-ssns.config')
  local cache_config = Config.get().cache or {}

  if cache_config.hierarchy_background_refresh == false then
    -- Just clear cache flags without refreshing
    clear_cache_flags(server)
    return
  end

  vim.defer_fn(function()
    if not server:is_connected() then
      return
    end

    -- Capture pre-refresh counts for comparison
    local old_db_count = server.databases and #server.databases or 0

    -- Reset is_loaded so load_async actually re-queries
    -- (load_async returns "already_loaded" if is_loaded is true)
    server.is_loaded = false

    -- Use existing load_async to re-query databases
    server:load_async({
      on_complete = function(success)
        if not success then
          -- Refresh failed — restore is_loaded, keep cached data, clear flags
          server.is_loaded = true
          clear_cache_flags(server)
          return
        end

        -- Compare: if database count changed, tree needs re-render
        local new_db_count = server.databases and #server.databases or 0
        if new_db_count ~= old_db_count then
          -- Save updated hierarchy
          HierarchyCache.schedule_save(server)
        end

        -- Clear from_cache flags
        clear_cache_flags(server)
      end,
    })
  end, 3000) -- 3 second delay after connect
end

-- ============================================================================
-- Invalidation
-- ============================================================================

---Delete cache file for a specific connection
---@param conn_key string Connection key
function HierarchyCache.invalidate(conn_key)
  -- Cancel pending timer
  if HierarchyCache._timers[conn_key] then
    HierarchyCache._timers[conn_key]:stop()
    HierarchyCache._timers[conn_key]:close()
    HierarchyCache._timers[conn_key] = nil
  end

  -- Clear pending state
  HierarchyCache._dirty[conn_key] = nil
  HierarchyCache._pending[conn_key] = nil

  -- Delete disk file
  local path = HierarchyCache.get_file_path(conn_key)
  os.remove(path)
end

---Delete all hierarchy cache files
function HierarchyCache.clear_all()
  -- Cancel all timers
  for conn_key, timer in pairs(HierarchyCache._timers) do
    timer:stop()
    timer:close()
    HierarchyCache._timers[conn_key] = nil
  end

  HierarchyCache._dirty = {}
  HierarchyCache._pending = {}

  -- Delete all .json files in cache dir
  local base_dir = HierarchyCache.get_base_dir()
  local handle = uv.fs_scandir(base_dir)
  if handle then
    while true do
      local name, typ = uv.fs_scandir_next(handle)
      if not name then break end
      if (typ == 'file' or not typ) and name:match('%.json$') then
        os.remove(base_dir .. '/' .. name)
      end
    end
  end
end

-- ============================================================================
-- Stats
-- ============================================================================

---Get cache statistics
---@return { file_count: number, total_size_bytes: number, connections: string[] }
function HierarchyCache.get_stats()
  local stats = {
    file_count = 0,
    total_size_bytes = 0,
    connections = {},
  }

  local base_dir = HierarchyCache.get_base_dir()
  local handle = uv.fs_scandir(base_dir)
  if not handle then
    return stats
  end

  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then break end
    if (typ == 'file' or not typ) and name:match('%.json$') then
      stats.file_count = stats.file_count + 1
      local stat = uv.fs_stat(base_dir .. '/' .. name)
      if stat then
        stats.total_size_bytes = stats.total_size_bytes + stat.size
      end
      table.insert(stats.connections, name:gsub('%.json$', ''))
    end
  end

  return stats
end

-- ============================================================================
-- VimLeavePre Flush
-- ============================================================================

---Synchronously flush all dirty hierarchies to disk (for VimLeavePre)
function HierarchyCache.save_all_dirty_sync()
  local base_dir = HierarchyCache.get_base_dir()
  vim.fn.mkdir(base_dir, 'p')

  for conn_key, is_dirty in pairs(HierarchyCache._dirty) do
    if is_dirty then
      local server = HierarchyCache._pending[conn_key]
      if server then
        local data = HierarchyCache.serialize(server)
        local ok_encode, json = pcall(vim.fn.json_encode, data)
        if ok_encode then
          local path = HierarchyCache.get_file_path(conn_key)
          local temp_path = path .. '.tmp'
          local f = io.open(temp_path, 'w')
          if f then
            f:write(json)
            f:close()
            os.remove(path)
            os.rename(temp_path, path)
          end
        end
      end
    end
  end

  HierarchyCache._dirty = {}
  HierarchyCache._pending = {}
end

---Register VimLeavePre autocmd to flush dirty caches
function HierarchyCache.setup()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('ssns_hierarchy_cache', { clear = true }),
    callback = function()
      HierarchyCache.save_all_dirty_sync()
    end,
  })
end

return HierarchyCache
