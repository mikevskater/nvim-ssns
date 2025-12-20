---Thread lifecycle coordinator
---Manages worker thread creation, execution, cancellation, and cleanup
---@class ThreadCoordinatorModule
local Coordinator = {}

local Channel = require('ssns.async.thread.channel')
local Serializer = require('ssns.async.thread.serializer')

---@class ThreadHandle
---@field id string Unique task identifier
---@field thread userdata? The libuv thread handle
---@field channel ThreadChannel Communication channel
---@field status "pending"|"running"|"completed"|"cancelled"|"error" Task status
---@field start_time number Start time (vim.loop.hrtime)
---@field timeout_timer userdata? Timeout timer handle
---@field cancel_token table? Cancellation token reference
---@field on_batch fun(batch: table)? Batch callback
---@field on_progress fun(pct: number, message: string?)? Progress callback
---@field on_complete fun(result: table?, error: string?)? Completion callback

---@class ThreadTask
---@field worker string Worker name (e.g., "search", "sort")
---@field input table Input data (will be serialized)
---@field on_batch fun(batch: table)? Called for each result batch
---@field on_progress fun(pct: number, message: string?)? Called for progress updates
---@field on_complete fun(result: table?, error: string?)? Called on completion/error
---@field cancel_token table? Cancellation token
---@field timeout_ms number? Timeout in milliseconds (default: 30000)

---Active thread handles indexed by task ID
---@type table<string, ThreadHandle>
local active_threads = {}

---Worker code registry
---@type table<string, string>
local worker_registry = {}

---Maximum concurrent threads
local MAX_THREADS = 4

---Default timeout
local DEFAULT_TIMEOUT_MS = 30000

---Generate unique task ID
---@return string
local function generate_task_id()
  return string.format("task_%s_%d", os.time(), math.random(10000, 99999))
end

---Get base worker code template
---Includes JSON encoder/decoder for pure Lua environment
---@return string
local function get_worker_base()
  local json_encoder = Serializer.get_worker_json_encoder()
  local json_decoder = Serializer.get_worker_json_decoder()

  return json_encoder .. "\n" .. json_decoder .. "\n"
end

---Register a worker with its code
---@param name string Worker name
---@param code string Pure Lua code to execute
function Coordinator.register_worker(name, code)
  -- Prepend base code (JSON utilities)
  worker_registry[name] = get_worker_base() .. code
end

---Check if threading is available
---@return boolean
function Coordinator.is_available()
  -- Check if vim.uv.new_thread exists and works
  local ok = pcall(function()
    local test_thread = vim.uv.new_thread(function() end)
    if test_thread then
      test_thread:join()
    end
  end)
  return ok
end

---Get count of active threads
---@return number
function Coordinator.get_active_count()
  local count = 0
  for _, handle in pairs(active_threads) do
    if handle.status == "running" then
      count = count + 1
    end
  end
  return count
end

---Start a threaded task
---@param task ThreadTask Task configuration
---@return string? task_id Task ID for cancellation, or nil if failed
---@return string? error Error message if failed
function Coordinator.start(task)
  -- Validate worker exists
  local worker_code = worker_registry[task.worker]
  if not worker_code then
    return nil, string.format("Unknown worker: %s", task.worker)
  end

  -- Check thread limit
  if Coordinator.get_active_count() >= MAX_THREADS then
    return nil, "Thread limit reached"
  end

  -- Check if threading is available
  if not Coordinator.is_available() then
    return nil, "Threading not available"
  end

  local task_id = generate_task_id()

  -- Create communication channel
  local channel = Channel.create(Channel.create_router({
    on_batch = function(items, progress)
      local handle = active_threads[task_id]
      if handle and handle.on_batch then
        handle.on_batch({ items = items, progress = progress })
      end
    end,
    on_progress = function(pct, message)
      local handle = active_threads[task_id]
      if handle and handle.on_progress then
        handle.on_progress(pct, message)
      end
    end,
    on_complete = function(result)
      local handle = active_threads[task_id]
      if handle then
        handle.status = "completed"
        if handle.on_complete then
          handle.on_complete(result, nil)
        end
        Coordinator.cleanup(task_id)
      end
    end,
    on_error = function(error_msg)
      local handle = active_threads[task_id]
      if handle then
        handle.status = "error"
        if handle.on_complete then
          handle.on_complete(nil, error_msg)
        end
        Coordinator.cleanup(task_id)
      end
    end,
    on_cancelled = function(processed)
      local handle = active_threads[task_id]
      if handle then
        handle.status = "cancelled"
        if handle.on_complete then
          handle.on_complete({ cancelled = true, processed = processed }, nil)
        end
        Coordinator.cleanup(task_id)
      end
    end,
  }))

  -- Serialize input data
  local input_json = Serializer.encode(task.input)

  -- Create thread handle
  ---@type ThreadHandle
  local handle = {
    id = task_id,
    thread = nil,
    channel = channel,
    status = "pending",
    start_time = vim.loop.hrtime(),
    timeout_timer = nil,
    cancel_token = task.cancel_token,
    on_batch = task.on_batch,
    on_progress = task.on_progress,
    on_complete = task.on_complete,
  }

  active_threads[task_id] = handle

  -- Setup timeout timer
  local timeout_ms = task.timeout_ms or DEFAULT_TIMEOUT_MS
  handle.timeout_timer = vim.uv.new_timer()
  handle.timeout_timer:start(timeout_ms, 0, vim.schedule_wrap(function()
    if active_threads[task_id] and active_threads[task_id].status == "running" then
      Coordinator.cancel(task_id, "Timeout")
    end
  end))

  -- Setup cancellation token listener
  if task.cancel_token then
    task.cancel_token:on_cancel(function(reason)
      Coordinator.cancel(task_id, reason or "Cancelled")
    end)
  end

  -- Start worker thread
  local thread_ok, thread_or_err = pcall(function()
    return vim.uv.new_thread(worker_code, channel:get_async_handle(), input_json)
  end)

  if not thread_ok then
    handle.status = "error"
    Coordinator.cleanup(task_id)
    return nil, "Failed to create thread: " .. tostring(thread_or_err)
  end

  handle.thread = thread_or_err
  handle.status = "running"

  return task_id, nil
end

---Cancel a running task
---@param task_id string Task ID
---@param reason string? Cancellation reason
---@return boolean success
function Coordinator.cancel(task_id, reason)
  local handle = active_threads[task_id]
  if not handle then
    return false
  end

  if handle.status ~= "running" and handle.status ~= "pending" then
    return false
  end

  handle.status = "cancelled"

  -- Note: We cannot force-kill a thread in Lua/libuv
  -- The worker must check for cancellation cooperatively
  -- We mark it cancelled and let cleanup happen

  if handle.on_complete then
    vim.schedule(function()
      handle.on_complete({ cancelled = true, reason = reason }, nil)
    end)
  end

  Coordinator.cleanup(task_id)
  return true
end

---Clean up a completed/cancelled/error task
---@param task_id string Task ID
function Coordinator.cleanup(task_id)
  local handle = active_threads[task_id]
  if not handle then return end

  -- Stop timeout timer
  if handle.timeout_timer then
    if not handle.timeout_timer:is_closing() then
      handle.timeout_timer:stop()
      handle.timeout_timer:close()
    end
    handle.timeout_timer = nil
  end

  -- Close channel
  if handle.channel then
    handle.channel:close()
  end

  -- Wait for thread to finish (non-blocking check)
  -- We use a deferred cleanup to allow thread to complete
  vim.defer_fn(function()
    if handle.thread then
      -- Thread should have completed by now
      -- If not, there's not much we can do in Lua
      handle.thread = nil
    end
    active_threads[task_id] = nil
  end, 100)
end

---Get task status
---@param task_id string Task ID
---@return ThreadHandle?
function Coordinator.get_task(task_id)
  return active_threads[task_id]
end

---Get all active tasks
---@return table<string, ThreadHandle>
function Coordinator.get_all_tasks()
  return active_threads
end

---Clean up all tasks (for shutdown)
function Coordinator.cleanup_all()
  for task_id, _ in pairs(active_threads) do
    Coordinator.cancel(task_id, "Shutdown")
  end
end

return Coordinator
