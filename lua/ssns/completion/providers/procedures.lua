---Procedure and function completion provider
---Provides completions for stored procedures and functions based on SQL context
---@class ProceduresProvider
local ProceduresProvider = {}

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

---Get procedure/function completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function ProceduresProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return ProceduresProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify("[SSNS] Procedures provider error: " .. tostring(result), vim.log.levels.ERROR)
      end
      callback({})
    end
  end)
end

---Internal implementation of procedure/function completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ProceduresProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Route based on context mode
  if sql_context.mode == "exec" then
    -- EXEC | context → show procedures
    return ProceduresProvider._get_procedures(connection)

  elseif sql_context.mode == "select_function" then
    -- SELECT dbo.| context → show scalar functions
    return ProceduresProvider._get_scalar_functions(connection)

  elseif sql_context.mode == "from_function" then
    -- FROM dbo.| context → show table-valued functions
    return ProceduresProvider._get_table_functions(connection)

  else
    -- Show both procedures and functions by default
    local items = {}
    local procs = ProceduresProvider._get_procedures(connection)
    local funcs_scalar = ProceduresProvider._get_scalar_functions(connection)
    local funcs_table = ProceduresProvider._get_table_functions(connection)

    vim.list_extend(items, procs)
    vim.list_extend(items, funcs_scalar)
    vim.list_extend(items, funcs_table)

    return items
  end
end

---Get stored procedures
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_procedures(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Find the PROCEDURES group in database children
  local procedures_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "procedures_group" then
      procedures_group = child
      break
    end
  end

  if not procedures_group then
    return items
  end

  -- Lazy-load if needed
  if not procedures_group.is_loaded then
    procedures_group:load()
  end

  if not procedures_group.children then
    return items
  end

  -- Iterate through procedures in the group
  for idx, proc_obj in ipairs(procedures_group.children) do
    if proc_obj.object_type == "procedure" then
      local item = Utils.format_procedure(proc_obj, {
        show_schema = Config.ui and Config.ui.show_schema_prefix,
        priority = 1,
        with_params = true,
      })

      -- Get procedure name and schema for weight lookup
      local proc_name = proc_obj.name or proc_obj.procedure_name
      local schema = proc_obj.schema or proc_obj.schema_name

      if proc_name and schema then
        -- Build procedure path: schema.procedure
        local proc_path = string.format("%s.%s", schema, proc_name)

        -- Get weight
        local weight = get_usage_weight(connection, "procedure", proc_path)

        -- Priority calculation
        local priority
        if weight > 0 then
          priority = math.max(0, 4999 - weight)
        else
          priority = 5000 + idx
        end

        -- Update sortText with new priority
        item.sortText = string.format("%05d_%s", priority, proc_name)

        -- Store weight in data for debugging
        item.data.weight = weight
      end

      table.insert(items, item)
    end
  end

  return items
end

---Get scalar functions
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_scalar_functions(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Find the FUNCTIONS group in database children
  local functions_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "functions_group" then
      functions_group = child
      break
    end
  end

  if not functions_group then
    return items
  end

  -- Lazy-load if needed
  if not functions_group.is_loaded then
    functions_group:load()
  end

  if not functions_group.children then
    return items
  end

  -- Iterate through scalar functions in the group
  for idx, func_obj in ipairs(functions_group.children) do
    if func_obj.object_type == "function" and func_obj.function_type == "SCALAR" then
      local item = Utils.format_procedure(func_obj, {
        show_schema = Config.ui and Config.ui.show_schema_prefix,
        priority = 2,
        with_params = true,
      })

      -- Get function name and schema for weight lookup
      local func_name = func_obj.name or func_obj.function_name
      local schema = func_obj.schema or func_obj.schema_name

      if func_name and schema then
        -- Build function path: schema.function
        local func_path = string.format("%s.%s", schema, func_name)

        -- Get weight
        local weight = get_usage_weight(connection, "function", func_path)

        -- Priority calculation
        local priority
        if weight > 0 then
          priority = math.max(0, 4999 - weight)
        else
          priority = 5000 + idx
        end

        -- Update sortText with new priority
        item.sortText = string.format("%05d_%s", priority, func_name)

        -- Store weight in data for debugging
        item.data.weight = weight
      end

      table.insert(items, item)
    end
  end

  return items
end

---Get table-valued functions
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_table_functions(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Find the FUNCTIONS group in database children
  local functions_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "functions_group" then
      functions_group = child
      break
    end
  end

  if not functions_group then
    return items
  end

  -- Lazy-load if needed
  if not functions_group.is_loaded then
    functions_group:load()
  end

  if not functions_group.children then
    return items
  end

  -- Iterate through table-valued functions in the group
  for idx, func_obj in ipairs(functions_group.children) do
    if func_obj.object_type == "function" and
       (func_obj.function_type == "TABLE" or func_obj.function_type == "INLINE_TABLE") then
      local item = Utils.format_procedure(func_obj, {
        show_schema = Config.ui and Config.ui.show_schema_prefix,
        priority = 2,
        with_params = true,
      })

      -- Get function name and schema for weight lookup
      local func_name = func_obj.name or func_obj.function_name
      local schema = func_obj.schema or func_obj.schema_name

      if func_name and schema then
        -- Build function path: schema.function
        local func_path = string.format("%s.%s", schema, func_name)

        -- Get weight
        local weight = get_usage_weight(connection, "function", func_path)

        -- Priority calculation
        local priority
        if weight > 0 then
          priority = math.max(0, 4999 - weight)
        else
          priority = 5000 + idx
        end

        -- Update sortText with new priority
        item.sortText = string.format("%05d_%s", priority, func_name)

        -- Store weight in data for debugging
        item.data.weight = weight
      end

      table.insert(items, item)
    end
  end

  return items
end

return ProceduresProvider
