---Database completion provider for SSNS IntelliSense
---Provides completion for database names (e.g., after USE keyword)
---@class DatabasesProvider
local DatabasesProvider = {}

local UsageTracker = require('ssns.completion.usage_tracker')
local Config = require('ssns.config')

---Get usage weight for an item
---@param connection table Connection context
---@param item_type string Type ("table", "column", etc.)
---@param item_path string Full path to item
---@return number weight Usage weight (0 if not found or tracking disabled)
local function get_usage_weight(connection, item_type, item_path)
  local config = Config.get()

  -- If tracking disabled, return 0 (no weight)
  if not config.completion or not config.completion.track_usage then
    return 0
  end

  -- Get weight from UsageTracker
  local success, weight = pcall(function()
    return UsageTracker.get_weight(connection, item_type, item_path)
  end)

  if success then
    return weight or 0
  else
    return 0
  end
end

---Get database completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function DatabasesProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return DatabasesProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify(
          string.format("[SSNS Completion] Databases provider error: %s", tostring(result)),
          vim.log.levels.ERROR
        )
      end
      callback({})
    end
  end)
end

---Internal implementation of database completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function DatabasesProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
  local connection = ctx.connection

  if not connection or not connection.server then
    return {}
  end

  local server = connection.server

  -- Verify we have a valid, connected server
  if not server:is_connected() then
    return {}
  end

  local items = {}

  -- Get all databases from server
  local databases = server:get_databases()

  if not databases then
    return {}
  end

  -- Format each database as CompletionItem
  for idx, db in ipairs(databases) do
    local item = Utils.format_database(db, {})

    -- Get database name for weight lookup
    local db_name = db.name or db.db_name or db.database_name

    if db_name then
      -- Get weight for database
      local weight = get_usage_weight(connection, "database", db_name)

      -- Priority: 0-4999 (weighted), 5000+ (alphabetical)
      local priority
      if weight > 0 then
        priority = math.max(0, 4999 - weight)
      else
        priority = 5000 + idx  -- idx from iteration
      end

      -- Update sortText with new priority
      item.sortText = string.format("%05d_%s", priority, db_name)

      -- Store weight in data for debugging
      item.data.weight = weight
    end

    table.insert(items, item)
  end

  return items
end

return DatabasesProvider
