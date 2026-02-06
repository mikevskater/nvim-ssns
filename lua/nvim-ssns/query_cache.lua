---@class QueryCacheEntry
---@field result table The cached query result
---@field timestamp number Unix timestamp when cached
---@field is_metadata boolean? Whether this is a metadata query (eligible for disk persistence)

---@class QueryCache
---Query result cache with TTL (Time To Live) support
---Caches query results to improve performance.
---Metadata queries (sys.*, INFORMATION_SCHEMA.*, etc.) are persisted to disk
---for instant cross-session IntelliSense completions.
local QueryCache = {}

---@type table<string, QueryCacheEntry>
QueryCache.cache = {}

---Default TTL in seconds (5 minutes)
QueryCache.default_ttl = 300

---TTL for disk-persisted metadata queries (24 hours)
QueryCache.metadata_disk_ttl = 86400

---Whether to persist metadata queries to disk
QueryCache.persist_metadata = true

---@type table<string, boolean> Tracks which connection keys have been loaded from disk
QueryCache._disk_loaded = {}

---Patterns that identify metadata queries (catalog/system views)
---@type string[]
local METADATA_PATTERNS = {
  'sys%.',           -- SQL Server catalog views (sys.tables, sys.columns, etc.)
  'information_schema%.', -- ANSI standard metadata views
  'pg_catalog%.',    -- PostgreSQL catalog
  'pg_database',     -- PostgreSQL database list
  'sqlite_master',   -- SQLite schema
  '^pragma ',        -- SQLite PRAGMA statements
}

---Normalize a query string for cache key generation
---@param query string
---@return string normalized
local function normalize_query(query)
  return vim.trim(query):lower()
end

---Generate a cache key from connection key and query
---@param connection_key string Connection key (from Connections.generate_connection_key)
---@param query string
---@return string key
local function generate_key(connection_key, query)
  return connection_key .. ":" .. normalize_query(query)
end

---Check if a cached result is still valid (not expired)
---@param cached_entry QueryCacheEntry
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return boolean valid
local function is_valid(cached_entry, ttl)
  ttl = ttl or QueryCache.default_ttl
  local current_time = os.time()
  local age = current_time - cached_entry.timestamp

  return age < ttl
end

---Check if a query is a metadata query (references system catalog views)
---@param query string The SQL query
---@return boolean is_metadata
function QueryCache.is_metadata_query(query)
  local normalized = normalize_query(query)

  -- Check for SET NOCOUNT ON + sys. (multi-statement metadata queries)
  if normalized:match('set%s+nocount%s+on') and normalized:match('sys%.') then
    return true
  end

  for _, pattern in ipairs(METADATA_PATTERNS) do
    if normalized:match(pattern) then
      return true
    end
  end

  return false
end

---Get a cached query result if it exists and is still valid
---@param connection_key string Connection key
---@param query string
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return table? result The cached result or nil if not found/expired
function QueryCache.get(connection_key, query, ttl)
  local key = generate_key(connection_key, query)
  local cached = QueryCache.cache[key]

  if cached then
    -- Use metadata TTL for metadata entries
    local effective_ttl = ttl
    if cached.is_metadata then
      effective_ttl = effective_ttl or QueryCache.metadata_disk_ttl
    else
      effective_ttl = effective_ttl or QueryCache.default_ttl
    end

    if is_valid(cached, effective_ttl) then
      return cached.result
    end

    -- Expired - remove from cache
    QueryCache.cache[key] = nil
  end

  -- Memory miss — try loading from disk for metadata queries
  if QueryCache.persist_metadata
    and QueryCache.is_metadata_query(query)
    and not QueryCache._disk_loaded[connection_key]
  then
    -- Load disk file and hydrate memory cache
    local ok, MetadataDiskCache = pcall(require, 'nvim-ssns.metadata_disk_cache')
    if ok then
      local entries = MetadataDiskCache.load(connection_key)
      QueryCache._disk_loaded[connection_key] = true

      -- Hydrate memory cache with disk entries
      for norm_query, entry in pairs(entries) do
        local disk_key = connection_key .. ":" .. norm_query
        -- Only hydrate if not already in memory
        if not QueryCache.cache[disk_key] then
          QueryCache.cache[disk_key] = {
            result = entry.result,
            timestamp = entry.timestamp,
            is_metadata = true,
          }
        end
      end

      -- Retry lookup with disk-loaded data
      cached = QueryCache.cache[key]
      if cached and is_valid(cached, QueryCache.metadata_disk_ttl) then
        return cached.result
      end
    end
  end

  return nil
end

---Store a query result in the cache
---@param connection_key string Connection key
---@param query string
---@param result table The query result to cache
function QueryCache.set(connection_key, query, result)
  local key = generate_key(connection_key, query)
  local is_metadata = QueryCache.is_metadata_query(query)

  QueryCache.cache[key] = {
    result = result,
    timestamp = os.time(),
    is_metadata = is_metadata,
  }

  -- Schedule disk write for metadata queries
  if is_metadata and QueryCache.persist_metadata then
    local ok, MetadataDiskCache = pcall(require, 'nvim-ssns.metadata_disk_cache')
    if ok then
      local metadata_entries = QueryCache._get_metadata_entries(connection_key)
      MetadataDiskCache.schedule_save(connection_key, metadata_entries)
    end
  end
end

---Extract all metadata entries for a connection (for disk serialization)
---@param connection_key string Connection key
---@return table<string, {result: table, timestamp: number}> entries
function QueryCache._get_metadata_entries(connection_key)
  local entries = {}
  local prefix = connection_key .. ":"

  for key, cached in pairs(QueryCache.cache) do
    if cached.is_metadata and key:sub(1, #prefix) == prefix then
      -- Extract the normalized query from the key
      local norm_query = key:sub(#prefix + 1)
      entries[norm_query] = {
        result = cached.result,
        timestamp = cached.timestamp,
      }
    end
  end

  return entries
end

---Invalidate (remove) a specific cached query
---@param connection_key string Connection key
---@param query string
---@return boolean removed True if entry was removed
function QueryCache.invalidate(connection_key, query)
  local key = generate_key(connection_key, query)
  local existed = QueryCache.cache[key] ~= nil
  QueryCache.cache[key] = nil
  return existed
end

---Invalidate all cached results for a specific connection
---@param connection_key string Connection key
---@return number count Number of entries removed
function QueryCache.invalidate_connection(connection_key)
  local count = 0
  local prefix = connection_key .. ":"

  for key, _ in pairs(QueryCache.cache) do
    if key:sub(1, #prefix) == prefix then
      QueryCache.cache[key] = nil
      count = count + 1
    end
  end

  -- Also clear disk cache and reset disk loaded flag
  QueryCache._disk_loaded[connection_key] = nil
  local ok, MetadataDiskCache = pcall(require, 'nvim-ssns.metadata_disk_cache')
  if ok then
    MetadataDiskCache.clear(connection_key)
  end

  return count
end

---Clear all cached query results
function QueryCache.clear_all()
  QueryCache.cache = {}
  QueryCache._disk_loaded = {}

  -- Also clear all disk caches
  local ok, MetadataDiskCache = pcall(require, 'nvim-ssns.metadata_disk_cache')
  if ok then
    MetadataDiskCache.clear_all()
  end
end

---Remove all expired entries from the cache
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return number count Number of expired entries removed
function QueryCache.cleanup_expired(ttl)
  ttl = ttl or QueryCache.default_ttl
  local count = 0

  for key, cached in pairs(QueryCache.cache) do
    local effective_ttl = cached.is_metadata and QueryCache.metadata_disk_ttl or ttl
    if not is_valid(cached, effective_ttl) then
      QueryCache.cache[key] = nil
      count = count + 1
    end
  end

  return count
end

---Get cache statistics
---@return table stats
function QueryCache.get_stats()
  local stats = {
    total_entries = 0,
    valid_entries = 0,
    expired_entries = 0,
    metadata_entries = 0,
    disk_loaded_connections = 0,
    oldest_entry = nil,
    newest_entry = nil,
  }

  local current_time = os.time()

  for _, cached in pairs(QueryCache.cache) do
    stats.total_entries = stats.total_entries + 1

    if cached.is_metadata then
      stats.metadata_entries = stats.metadata_entries + 1
    end

    local effective_ttl = cached.is_metadata and QueryCache.metadata_disk_ttl or QueryCache.default_ttl
    if is_valid(cached, effective_ttl) then
      stats.valid_entries = stats.valid_entries + 1
    else
      stats.expired_entries = stats.expired_entries + 1
    end

    if not stats.oldest_entry or cached.timestamp < stats.oldest_entry then
      stats.oldest_entry = cached.timestamp
    end

    if not stats.newest_entry or cached.timestamp > stats.newest_entry then
      stats.newest_entry = cached.timestamp
    end
  end

  -- Count disk-loaded connections
  for _ in pairs(QueryCache._disk_loaded) do
    stats.disk_loaded_connections = stats.disk_loaded_connections + 1
  end

  -- Convert timestamps to age in seconds
  if stats.oldest_entry then
    stats.oldest_age = current_time - stats.oldest_entry
  end
  if stats.newest_entry then
    stats.newest_age = current_time - stats.newest_entry
  end

  return stats
end

---Debug: Print cache contents
function QueryCache.debug_print()
  print("=== SSNS Query Cache ===")
  local stats = QueryCache.get_stats()
  print(string.format("Total entries: %d", stats.total_entries))
  print(string.format("Valid entries: %d", stats.valid_entries))
  print(string.format("Expired entries: %d", stats.expired_entries))
  print(string.format("Metadata entries: %d (disk TTL: %ds)", stats.metadata_entries, QueryCache.metadata_disk_ttl))
  print(string.format("Disk-loaded connections: %d", stats.disk_loaded_connections))
  print(string.format("Persist metadata: %s", tostring(QueryCache.persist_metadata)))

  if stats.oldest_age then
    print(string.format("Oldest entry age: %d seconds", stats.oldest_age))
  end
  if stats.newest_age then
    print(string.format("Newest entry age: %d seconds", stats.newest_age))
  end

  print("========================")
end

---Setup QueryCache from config and initialize disk cache
---@param config SsnsConfig Plugin configuration
function QueryCache.setup(config)
  if config.cache then
    if config.cache.ttl then
      QueryCache.default_ttl = config.cache.ttl
    end
    if config.cache.persist_metadata ~= nil then
      QueryCache.persist_metadata = config.cache.persist_metadata
    end
    if config.cache.metadata_disk_ttl then
      QueryCache.metadata_disk_ttl = config.cache.metadata_disk_ttl
    end
  end

  -- Initialize disk cache (registers VimLeavePre)
  if QueryCache.persist_metadata then
    local ok, MetadataDiskCache = pcall(require, 'nvim-ssns.metadata_disk_cache')
    if ok then
      MetadataDiskCache.setup()
    end
  end
end

return QueryCache
