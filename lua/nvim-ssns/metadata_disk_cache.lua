---Persistent disk cache for metadata query results
---Stores metadata (sys.*, INFORMATION_SCHEMA.*, etc.) to disk with 24h TTL
---so IntelliSense completions are instant across Neovim sessions.
---@class MetadataDiskCache
local MetadataDiskCache = {}

local uv = vim.loop
local FileIO = require('nvim-ssns.async.file_io')

---@type table<string, uv_timer_t> Debounce timers per connection key
MetadataDiskCache._timers = {}

---@type table<string, boolean> Dirty flags per connection key
MetadataDiskCache._dirty = {}

---@type table<string, table> Pending entries per connection key (for debounced writes)
MetadataDiskCache._pending = {}

---Debounce delay in milliseconds
MetadataDiskCache.debounce_ms = 2000

---Get the base directory for metadata cache files
---@return string
function MetadataDiskCache.get_base_dir()
  return vim.fn.stdpath('data') .. '/nvim-ssns/metadata_cache'
end

---Sanitize a connection key into a valid filename
---@param conn_key string Connection key (e.g. "sqlserver:localhost:SQLEXPRESS:vim_dadbod_test:windows:")
---@return string filename Sanitized filename with .json extension
function MetadataDiskCache.sanitize_filename(conn_key)
  -- Replace characters invalid in filenames with underscores
  local sanitized = conn_key:gsub('[:/\\%*%?%"<>|%%]', '_')
  -- Collapse multiple underscores
  sanitized = sanitized:gsub('_+', '_')
  -- Remove trailing underscores
  sanitized = sanitized:gsub('_$', '')
  return sanitized .. '.json'
end

---Get the full file path for a connection's disk cache
---@param conn_key string Connection key
---@return string path Full path to the JSON file
function MetadataDiskCache.get_file_path(conn_key)
  return MetadataDiskCache.get_base_dir() .. '/' .. MetadataDiskCache.sanitize_filename(conn_key)
end

---Load metadata entries from disk for a connection (synchronous)
---Called on first cache miss to hydrate in-memory cache.
---@param conn_key string Connection key
---@return table<string, {result: table, timestamp: number}> entries Map of normalized_query -> {result, timestamp}
function MetadataDiskCache.load(conn_key)
  local path = MetadataDiskCache.get_file_path(conn_key)

  local f = io.open(path, 'r')
  if not f then
    return {}
  end

  local content = f:read('*a')
  f:close()

  if not content or content == '' then
    return {}
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify('SSNS: Corrupt metadata cache file, removing: ' .. path, vim.log.levels.WARN)
    os.remove(path)
    return {}
  end

  -- Validate version
  if data.version ~= 1 then
    vim.notify('SSNS: Unsupported metadata cache version, removing: ' .. path, vim.log.levels.WARN)
    os.remove(path)
    return {}
  end

  -- Convert entries to internal format
  local entries = {}
  if data.entries then
    for query, entry in pairs(data.entries) do
      if entry.result and entry.timestamp then
        entries[query] = {
          result = entry.result,
          timestamp = entry.timestamp,
        }
      end
    end
  end

  return entries
end

---Save metadata entries to disk asynchronously with atomic write
---@param conn_key string Connection key
---@param entries table<string, {result: table, timestamp: number}> Entries to save
function MetadataDiskCache.save_async(conn_key, entries)
  local base_dir = MetadataDiskCache.get_base_dir()
  local path = MetadataDiskCache.get_file_path(conn_key)
  local temp_path = path .. '.tmp'

  -- Build disk format
  local data = {
    version = 1,
    connection_key = conn_key,
    saved_at = os.time(),
    entries = {},
  }

  for query, entry in pairs(entries) do
    data.entries[query] = {
      result = entry.result,
      timestamp = entry.timestamp,
    }
  end

  -- Encode JSON
  local ok_encode, json = pcall(vim.fn.json_encode, data)
  if not ok_encode then
    vim.schedule(function()
      vim.notify('SSNS: Failed to encode metadata cache: ' .. tostring(json), vim.log.levels.WARN)
    end)
    return
  end

  -- Ensure directory exists, then write
  FileIO.mkdir_async(base_dir, function(mkdir_ok, mkdir_err)
    if not mkdir_ok then
      vim.notify('SSNS: Failed to create metadata cache dir: ' .. tostring(mkdir_err), vim.log.levels.WARN)
      return
    end

    -- Write to temp file
    FileIO.write_async(temp_path, json, function(write_result)
      if not write_result.success then
        vim.notify('SSNS: Failed to write metadata cache: ' .. tostring(write_result.error), vim.log.levels.WARN)
        return
      end

      -- Atomic rename (Windows: remove target first)
      os.remove(path)
      FileIO.rename_async(temp_path, path, function(rename_ok, rename_err)
        if not rename_ok then
          -- Fallback: try sync rename
          local sync_ok = os.rename(temp_path, path)
          if not sync_ok then
            vim.notify('SSNS: Failed to rename metadata cache: ' .. tostring(rename_err), vim.log.levels.WARN)
            os.remove(temp_path)
          end
        end

        -- Clear dirty flag
        MetadataDiskCache._dirty[conn_key] = nil
      end)
    end)
  end)
end

---Schedule a debounced save for a connection
---@param conn_key string Connection key
---@param entries table<string, {result: table, timestamp: number}> Entries to save
function MetadataDiskCache.schedule_save(conn_key, entries)
  -- Store pending entries
  MetadataDiskCache._pending[conn_key] = entries
  MetadataDiskCache._dirty[conn_key] = true

  -- Cancel existing timer
  if MetadataDiskCache._timers[conn_key] then
    MetadataDiskCache._timers[conn_key]:stop()
    MetadataDiskCache._timers[conn_key]:close()
    MetadataDiskCache._timers[conn_key] = nil
  end

  -- Create new debounce timer
  local timer = uv.new_timer()
  MetadataDiskCache._timers[conn_key] = timer

  timer:start(MetadataDiskCache.debounce_ms, 0, vim.schedule_wrap(function()
    -- Clean up timer
    if MetadataDiskCache._timers[conn_key] == timer then
      MetadataDiskCache._timers[conn_key] = nil
    end
    timer:stop()
    timer:close()

    -- Save pending entries
    local pending = MetadataDiskCache._pending[conn_key]
    if pending then
      MetadataDiskCache._pending[conn_key] = nil
      MetadataDiskCache.save_async(conn_key, pending)
    end
  end))
end

---Synchronously flush all dirty connections to disk (for VimLeavePre)
function MetadataDiskCache.save_all_dirty_sync()
  local base_dir = MetadataDiskCache.get_base_dir()

  -- Ensure directory exists (sync)
  vim.fn.mkdir(base_dir, 'p')

  for conn_key, is_dirty in pairs(MetadataDiskCache._dirty) do
    if is_dirty then
      local entries = MetadataDiskCache._pending[conn_key]
      if entries then
        local path = MetadataDiskCache.get_file_path(conn_key)
        local temp_path = path .. '.tmp'

        local data = {
          version = 1,
          connection_key = conn_key,
          saved_at = os.time(),
          entries = {},
        }

        for query, entry in pairs(entries) do
          data.entries[query] = {
            result = entry.result,
            timestamp = entry.timestamp,
          }
        end

        local ok_encode, json = pcall(vim.fn.json_encode, data)
        if ok_encode then
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

  -- Clear state
  MetadataDiskCache._dirty = {}
  MetadataDiskCache._pending = {}
end

---Clear disk cache for a specific connection
---@param conn_key string Connection key
function MetadataDiskCache.clear(conn_key)
  -- Cancel pending timer
  if MetadataDiskCache._timers[conn_key] then
    MetadataDiskCache._timers[conn_key]:stop()
    MetadataDiskCache._timers[conn_key]:close()
    MetadataDiskCache._timers[conn_key] = nil
  end

  -- Clear pending state
  MetadataDiskCache._dirty[conn_key] = nil
  MetadataDiskCache._pending[conn_key] = nil

  -- Delete disk file
  local path = MetadataDiskCache.get_file_path(conn_key)
  os.remove(path)
end

---Clear all disk cache files
function MetadataDiskCache.clear_all()
  -- Cancel all timers
  for conn_key, timer in pairs(MetadataDiskCache._timers) do
    timer:stop()
    timer:close()
    MetadataDiskCache._timers[conn_key] = nil
  end

  -- Clear all pending state
  MetadataDiskCache._dirty = {}
  MetadataDiskCache._pending = {}

  -- Delete all .json files in cache dir
  local base_dir = MetadataDiskCache.get_base_dir()
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

---Setup VimLeavePre autocmd to flush dirty caches
function MetadataDiskCache.setup()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('ssns_metadata_disk_cache', { clear = true }),
    callback = function()
      MetadataDiskCache.save_all_dirty_sync()
    end,
  })
end

return MetadataDiskCache
