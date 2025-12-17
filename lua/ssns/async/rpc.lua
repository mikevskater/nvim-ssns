---Async RPC handler for non-blocking database queries
---Works with Node.js SSNSExecuteQueryAsync function
---@class AsyncRPC
local AsyncRPC = {}

---Pending callbacks indexed by callback ID
---@type table<string, { on_complete: function, on_error: function?, started_at: number }>
local pending_callbacks = {}

---Generate unique callback ID
---@return string
local function generate_callback_id()
  return string.format("rpc_%s_%d", os.time(), math.random(10000, 99999))
end

---Handle callback from Node.js
---This function is called by Node.js via plugin.nvim.call('luaeval', ...)
---@param callback_id string The callback ID
---@param result table? The query result
---@param err string? Error message if failed
function AsyncRPC.handle_callback(callback_id, result, err)
  local callback = pending_callbacks[callback_id]
  if not callback then
    -- Callback already handled or timed out
    return
  end

  -- Remove from pending
  pending_callbacks[callback_id] = nil

  -- Call the appropriate handler
  vim.schedule(function()
    if err and callback.on_error then
      callback.on_error(err)
    elseif callback.on_complete then
      callback.on_complete(result, err)
    end
  end)
end

---@class AsyncRPCOpts
---@field on_complete fun(result: table, error: string?)? Completion callback
---@field on_error fun(error: string)? Error callback
---@field timeout_ms number? Timeout in milliseconds (default: 60000)
---@field use_cache boolean? Use query cache (default: true)
---@field ttl number? Cache TTL

---Check if the async RPC function is available
---@return boolean available True if SSNSExecuteQueryAsync is registered
function AsyncRPC.is_available()
  return vim.fn.exists('*SSNSExecuteQueryAsync') == 1
end

---Execute a query asynchronously via RPC (non-blocking)
---The query runs in the Node.js process and calls back when complete
---@param connection_config table The connection configuration
---@param query string The SQL query
---@param opts AsyncRPCOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function AsyncRPC.execute_async(connection_config, query, opts)
  opts = opts or {}

  local callback_id = generate_callback_id()

  -- Store callback handlers
  pending_callbacks[callback_id] = {
    on_complete = opts.on_complete,
    on_error = opts.on_error,
    started_at = vim.loop.hrtime(),
  }

  -- Set up timeout if specified
  local timeout_ms = opts.timeout_ms or 60000
  if timeout_ms > 0 then
    vim.defer_fn(function()
      local callback = pending_callbacks[callback_id]
      if callback then
        -- Still pending - timed out
        pending_callbacks[callback_id] = nil
        vim.schedule(function()
          if callback.on_error then
            callback.on_error("Query timed out after " .. (timeout_ms / 1000) .. " seconds")
          elseif callback.on_complete then
            callback.on_complete(nil, "Query timed out")
          end
        end)
      end
    end, timeout_ms)
  end

  -- Serialize connection config to JSON
  local config_json = vim.fn.json_encode(connection_config)

  -- Call Node.js async function (returns immediately)
  local success, result = pcall(function()
    return vim.fn.SSNSExecuteQueryAsync({ config_json, query, callback_id })
  end)

  if not success then
    -- RPC call itself failed
    pending_callbacks[callback_id] = nil
    vim.schedule(function()
      local err_msg = "Failed to start async query: " .. tostring(result)
      if opts.on_error then
        opts.on_error(err_msg)
      elseif opts.on_complete then
        opts.on_complete(nil, err_msg)
      end
    end)
  elseif result and not result.started then
    -- Node.js returned an error
    pending_callbacks[callback_id] = nil
    vim.schedule(function()
      local err_msg = result.error or "Failed to start async query"
      if opts.on_error then
        opts.on_error(err_msg)
      elseif opts.on_complete then
        opts.on_complete(nil, err_msg)
      end
    end)
  end

  return callback_id
end

---Cancel a pending async query
---@param callback_id string The callback ID
---@return boolean cancelled True if callback was pending and cancelled
function AsyncRPC.cancel(callback_id)
  local callback = pending_callbacks[callback_id]
  if callback then
    pending_callbacks[callback_id] = nil
    -- Note: The query will still complete in Node.js, but the callback won't be invoked
    return true
  end
  return false
end

---Get number of pending callbacks
---@return number count
function AsyncRPC.get_pending_count()
  local count = 0
  for _ in pairs(pending_callbacks) do
    count = count + 1
  end
  return count
end

---Check if a callback is pending
---@param callback_id string
---@return boolean is_pending
function AsyncRPC.is_pending(callback_id)
  return pending_callbacks[callback_id] ~= nil
end

---Clear all pending callbacks (for cleanup)
function AsyncRPC.clear_all()
  pending_callbacks = {}
end

return AsyncRPC
