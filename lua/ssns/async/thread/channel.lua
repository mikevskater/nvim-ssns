---Thread communication channel using vim.uv.new_async()
---Provides bidirectional communication between main thread and worker threads
---@class ThreadChannelModule
local Channel = {}

---@class ThreadChannel
---@field id string Unique channel identifier
---@field async_handle userdata? The libuv async handle
---@field message_queue string[] Queue of pending messages (JSON strings)
---@field on_message fun(message: table) Message handler (runs on main thread)
---@field is_closed boolean Whether the channel has been closed
local ThreadChannel = {}
ThreadChannel.__index = ThreadChannel

---Generate unique channel ID
---@return string
local function generate_id()
  return string.format("channel_%s_%d", os.time(), math.random(10000, 99999))
end

---Create a new thread communication channel
---@param on_message fun(message: table) Message handler called on main thread
---@return ThreadChannel
function Channel.create(on_message)
  local channel = setmetatable({
    id = generate_id(),
    message_queue = {},
    on_message = on_message,
    is_closed = false,
    async_handle = nil,
  }, ThreadChannel)

  -- Create async handle that triggers callback on main thread
  -- The async handle is what allows worker threads to signal the main thread
  channel.async_handle = vim.uv.new_async(vim.schedule_wrap(function()
    channel:_process_queue()
  end))

  return channel
end

---Process all queued messages
---Called on main thread when async handle is triggered
function ThreadChannel:_process_queue()
  if self.is_closed then return end

  -- Process all pending messages
  while #self.message_queue > 0 do
    local message_json = table.remove(self.message_queue, 1)

    -- Decode JSON message
    local ok, message = pcall(vim.fn.json_decode, message_json)
    if ok and message then
      -- Invoke handler in protected call
      local handler_ok, handler_err = pcall(self.on_message, message)
      if not handler_ok then
        vim.schedule(function()
          vim.notify(
            string.format("SSNS Thread: Message handler error: %s", tostring(handler_err)),
            vim.log.levels.ERROR
          )
        end)
      end
    else
      vim.schedule(function()
        vim.notify(
          string.format("SSNS Thread: Failed to decode message: %s", message_json:sub(1, 100)),
          vim.log.levels.WARN
        )
      end)
    end
  end
end

---Queue a message from worker thread and trigger async handle
---This is called from the worker thread context
---@param message_json string JSON-encoded message
function ThreadChannel:send(message_json)
  if self.is_closed then return end

  table.insert(self.message_queue, message_json)

  -- Trigger async handle to process on main thread
  if self.async_handle then
    self.async_handle:send()
  end
end

---Get the async handle for passing to worker thread
---@return userdata? async_handle
function ThreadChannel:get_async_handle()
  return self.async_handle
end

---Close the channel and clean up resources
function ThreadChannel:close()
  if self.is_closed then return end

  self.is_closed = true

  if self.async_handle then
    -- Close the async handle
    if not self.async_handle:is_closing() then
      self.async_handle:close()
    end
    self.async_handle = nil
  end

  -- Clear message queue
  self.message_queue = {}
end

---Check if channel is still open
---@return boolean
function ThreadChannel:is_open()
  return not self.is_closed and self.async_handle ~= nil
end

---@class ChannelMessage
---@field type "batch"|"progress"|"complete"|"error"|"cancelled" Message type
---@field items table[]? Batch items (for type="batch")
---@field pct number? Progress percentage (for type="progress")
---@field message string? Progress/error message
---@field result table? Final result (for type="complete")
---@field error string? Error message (for type="error")
---@field processed number? Items processed before cancellation

---Create a message handler that routes to typed callbacks
---@param opts {on_batch: fun(items: table[], progress: number?)?, on_progress: fun(pct: number, message: string?)?, on_complete: fun(result: table?)?, on_error: fun(error: string)?, on_cancelled: fun(processed: number?)?}
---@return fun(message: ChannelMessage)
function Channel.create_router(opts)
  return function(message)
    local msg_type = message.type

    if msg_type == "batch" and opts.on_batch then
      opts.on_batch(message.items or {}, message.progress)
    elseif msg_type == "progress" and opts.on_progress then
      opts.on_progress(message.pct or 0, message.message)
    elseif msg_type == "complete" and opts.on_complete then
      opts.on_complete(message.result)
    elseif msg_type == "error" and opts.on_error then
      opts.on_error(message.error or "Unknown error")
    elseif msg_type == "cancelled" and opts.on_cancelled then
      opts.on_cancelled(message.processed)
    end
  end
end

return Channel
