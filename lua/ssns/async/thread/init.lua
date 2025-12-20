---Thread module for CPU-intensive operations
---Uses vim.uv.new_thread() for true parallel execution
---@class ThreadModule
local Thread = {}

local Coordinator = require('ssns.async.thread.coordinator')
local Serializer = require('ssns.async.thread.serializer')
local Channel = require('ssns.async.thread.channel')

-- Export submodules
Thread.Coordinator = Coordinator
Thread.Serializer = Serializer
Thread.Channel = Channel

---Check if threading is available on this system
---@return boolean
function Thread.is_available()
  return Coordinator.is_available()
end

---Start a threaded task
---@param opts ThreadTask Task configuration
---@return string? task_id Task ID for cancellation
---@return string? error Error message if failed
function Thread.start(opts)
  return Coordinator.start(opts)
end

---Cancel a running task
---@param task_id string Task ID
---@param reason string? Cancellation reason
---@return boolean success
function Thread.cancel(task_id, reason)
  return Coordinator.cancel(task_id, reason)
end

---Get task status
---@param task_id string Task ID
---@return ThreadHandle?
function Thread.get_task(task_id)
  return Coordinator.get_task(task_id)
end

---Clean up all tasks (for shutdown)
function Thread.cleanup_all()
  Coordinator.cleanup_all()
end

-- ============================================================================
-- Built-in Workers
-- ============================================================================

---Search worker code
---Filters objects by pattern matching
local SEARCH_WORKER = [[
local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local objects = input.objects or {}
local pattern = input.pattern or ""
local options = input.options or {}
local batch_size = options.batch_size or 50
local case_sensitive = options.case_sensitive
local use_regex = options.use_regex
local whole_word = options.whole_word
local search_names = options.search_names ~= false  -- default true
local search_definitions = options.search_definitions
local search_metadata = options.search_metadata

-- Prepare pattern for matching
local match_pattern = pattern
if not case_sensitive then
  match_pattern = pattern:lower()
end

-- Build regex pattern if whole word matching
local function check_whole_word(text, pat)
  if not whole_word then
    return text:find(pat, 1, not use_regex) ~= nil
  end
  -- Whole word matching
  local pattern_escaped = pat:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  local word_pattern = "%f[%w]" .. pattern_escaped .. "%f[%W]"
  return text:match(word_pattern) ~= nil
end

-- Match function
local function matches(obj)
  if pattern == "" then
    return true, "all"
  end

  local text_to_search = ""

  -- Build searchable text
  if search_names then
    text_to_search = text_to_search .. " " .. (obj.name or "")
    text_to_search = text_to_search .. " " .. (obj.display_name or "")
    text_to_search = text_to_search .. " " .. (obj.full_name or "")
  end

  if search_definitions and obj.definition then
    text_to_search = text_to_search .. " " .. obj.definition
  end

  if search_metadata and obj.metadata_text then
    text_to_search = text_to_search .. " " .. obj.metadata_text
  end

  if not case_sensitive then
    text_to_search = text_to_search:lower()
  end

  if check_whole_word(text_to_search, match_pattern) then
    -- Determine match type
    if search_names and obj.name and check_whole_word(
      case_sensitive and obj.name or obj.name:lower(),
      match_pattern
    ) then
      return true, "name"
    elseif search_definitions and obj.definition then
      return true, "definition"
    elseif search_metadata and obj.metadata_text then
      return true, "metadata"
    end
    return true, "name"
  end

  return false, nil
end

-- Process objects
local batch = {}
local total = #objects
local last_progress = 0

for i, obj in ipairs(objects) do
  local matched, match_type = matches(obj)

  if matched then
    table.insert(batch, {
      idx = obj.idx or i,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      match_type = match_type,
      display_name = obj.display_name,
      unique_id = obj.unique_id,
    })
  end

  -- Send batch when full
  if #batch >= batch_size then
    local progress = math.floor((i / total) * 100)
    async_handle:send(json_encode({
      type = "batch",
      items = batch,
      progress = progress,
    }))
    batch = {}
  end

  -- Send progress updates every 10%
  local current_progress = math.floor((i / total) * 10) * 10
  if current_progress > last_progress then
    last_progress = current_progress
    async_handle:send(json_encode({
      type = "progress",
      pct = current_progress,
      message = string.format("Processing %d/%d objects...", i, total),
    }))
  end
end

-- Send remaining batch
if #batch > 0 then
  async_handle:send(json_encode({
    type = "batch",
    items = batch,
    progress = 100,
  }))
end

-- Send completion
async_handle:send(json_encode({
  type = "complete",
  result = { total_processed = total },
}))
]]

---Sort worker code
---Sorts items by a key field
local SORT_WORKER = [[
local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local items = input.items or {}
local key_field = input.key_field or "name"
local descending = input.descending or false

-- Sort items
table.sort(items, function(a, b)
  local a_key = a[key_field] or a.sort_key or a.name or ""
  local b_key = b[key_field] or b.sort_key or b.name or ""

  -- Case-insensitive string comparison
  if type(a_key) == "string" and type(b_key) == "string" then
    a_key = a_key:lower()
    b_key = b_key:lower()
  end

  if descending then
    return a_key > b_key
  else
    return a_key < b_key
  end
end)

-- Send sorted result
async_handle:send(json_encode({
  type = "complete",
  result = { items = items },
}))
]]

---Deduplication and sort worker for columns
local DEDUPE_SORT_WORKER = [[
local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local columns = input.columns or {}

-- Deduplicate by name
local seen = {}
local unique = {}

for _, col in ipairs(columns) do
  local name = col.name or ""
  local key = name:lower()

  if not seen[key] then
    seen[key] = true
    table.insert(unique, col)
  end
end

-- Sort by name
table.sort(unique, function(a, b)
  local a_name = (a.name or ""):lower()
  local b_name = (b.name or ""):lower()
  return a_name < b_name
end)

-- Add sort text for completion
for i, col in ipairs(unique) do
  col.sortText = string.format("%05d_%s", i, col.name or "")
end

-- Send result
async_handle:send(json_encode({
  type = "complete",
  result = { columns = unique },
}))
]]

---FK Graph BFS worker
local FK_GRAPH_WORKER = [[
local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local graph = input.graph or {}
local source_keys = input.source_keys or {}
local max_depth = input.max_depth or 2
local batch_size = input.batch_size or 10

-- BFS traversal
local queue = {}
local visited = {}
local chains = {}
local batch = {}

-- Initialize queue with source tables
for _, key in ipairs(source_keys) do
  if graph[key] then
    table.insert(queue, {
      key = key,
      path = { key },
      depth = 0,
    })
  end
end

while #queue > 0 do
  local current = table.remove(queue, 1)

  if current.depth >= max_depth then
    goto continue
  end

  local node = graph[current.key]
  if not node then
    goto continue
  end

  -- Process constraints
  for _, constraint in ipairs(node.constraints or {}) do
    local target_key = constraint.referenced_schema .. "." .. constraint.referenced_table

    if not visited[current.key .. "->" .. target_key] then
      visited[current.key .. "->" .. target_key] = true

      -- Build chain
      local chain = {
        source_table = node.table_name,
        source_schema = node.schema_name,
        source_column = constraint.column_name,
        target_table = constraint.referenced_table,
        target_schema = constraint.referenced_schema,
        target_column = constraint.referenced_column,
        constraint_name = constraint.name,
        depth = current.depth + 1,
        path = current.path,
      }

      table.insert(batch, chain)
      table.insert(chains, chain)

      -- Send batch
      if #batch >= batch_size then
        async_handle:send(json_encode({
          type = "batch",
          items = batch,
        }))
        batch = {}
      end

      -- Continue BFS if target exists in graph
      if graph[target_key] then
        local new_path = {}
        for _, p in ipairs(current.path) do
          table.insert(new_path, p)
        end
        table.insert(new_path, target_key)

        table.insert(queue, {
          key = target_key,
          path = new_path,
          depth = current.depth + 1,
        })
      end
    end
  end

  ::continue::
end

-- Send remaining batch
if #batch > 0 then
  async_handle:send(json_encode({
    type = "batch",
    items = batch,
  }))
end

-- Send completion
async_handle:send(json_encode({
  type = "complete",
  result = { chains = chains, total = #chains },
}))
]]

-- Register built-in workers
Coordinator.register_worker("search", SEARCH_WORKER)
Coordinator.register_worker("sort", SORT_WORKER)
Coordinator.register_worker("dedupe_sort", DEDUPE_SORT_WORKER)
Coordinator.register_worker("fk_graph", FK_GRAPH_WORKER)

---Register a custom worker
---@param name string Worker name
---@param code string Pure Lua code (no vim.* APIs)
function Thread.register_worker(name, code)
  Coordinator.register_worker(name, code)
end

return Thread
