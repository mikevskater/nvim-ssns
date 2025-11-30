---@class UiFilters
---Filter management for UI tree groups
local UiFilters = {}

-- Global filter storage (persists per session)
-- Keyed by group's full path (e.g., "server1.db1.TABLES")
local filter_store = {}

---@class FilterState
---@field name_include string? Regex pattern to include by name
---@field name_exclude string? Regex pattern to exclude by name
---@field schema_include string? Regex pattern to include by schema
---@field schema_exclude string? Regex pattern to exclude by schema
---@field object_types table<string, boolean>? Object types to include (for SCHEMAS group)
---@field case_sensitive boolean Whether patterns are case-sensitive
---@field hide_system_schemas boolean Whether to hide system schemas (sys, INFORMATION_SCHEMA, etc.)

---Check if a group supports system schema filtering
---@param group BaseDbObject The group object
---@return boolean
local function supports_system_schema_filter(group)
  local obj_type = group.object_type
  return obj_type == "tables_group"
    or obj_type == "views_group"
    or obj_type == "procedures_group"
    or obj_type == "functions_group"
    or obj_type == "synonyms_group"
    or obj_type == "schemas_group"
    or obj_type == "schema"
    or obj_type == "schema_view"
end

---Get filter state for a group
---@param group BaseDbObject The group object
---@return FilterState
function UiFilters.get(group)
  local path = group:get_full_path()

  if not filter_store[path] then
    -- Get default from config
    local Config = require('ssns.config')
    local filter_config = Config.get_filters()
    local default_hide = filter_config and filter_config.hide_system_schemas or false

    -- Only apply system schema filter to groups that support it
    local hide_system = supports_system_schema_filter(group) and default_hide or false

    -- Initialize with defaults from config
    filter_store[path] = {
      name_include = nil,
      name_exclude = nil,
      schema_include = nil,
      schema_exclude = nil,
      object_types = nil,
      case_sensitive = false,
      hide_system_schemas = hide_system,
    }
  end

  return filter_store[path]
end

---Set filter state for a group
---@param group BaseDbObject The group object
---@param filters FilterState The filter state
function UiFilters.set(group, filters)
  local path = group:get_full_path()
  filter_store[path] = filters
end

---Clear all filters for a group (restores defaults)
---@param group BaseDbObject The group object
function UiFilters.clear(group)
  local path = group:get_full_path()

  -- Get default from config for system schema filter
  local Config = require('ssns.config')
  local filter_config = Config.get_filters()
  local default_hide = filter_config and filter_config.hide_system_schemas or false
  local hide_system = supports_system_schema_filter(group) and default_hide or false

  filter_store[path] = {
    name_include = nil,
    name_exclude = nil,
    schema_include = nil,
    schema_exclude = nil,
    object_types = nil,
    case_sensitive = false,
    hide_system_schemas = hide_system,
  }
end

---Check if a group has user-defined filters (excludes hide_system_schemas)
---@param filters FilterState Filter state
---@return boolean
local function has_user_filters(filters)
  return (filters.name_include and filters.name_include ~= "")
    or (filters.name_exclude and filters.name_exclude ~= "")
    or (filters.schema_include and filters.schema_include ~= "")
    or (filters.schema_exclude and filters.schema_exclude ~= "")
    or (filters.object_types and next(filters.object_types) ~= nil)
end

---Check if a group has any active filters (that affect display count)
---@param group BaseDbObject The group object
---@return boolean
function UiFilters.has_filters(group)
  local filters = UiFilters.get(group)
  return has_user_filters(filters) or filters.hide_system_schemas
end

---Check if a group has user-defined filters (beyond system schema filter)
---@param group BaseDbObject The group object
---@return boolean
function UiFilters.has_user_filters(group)
  local filters = UiFilters.get(group)
  return has_user_filters(filters)
end

---Test if a name matches a regex pattern
---@param name string The name to test
---@param pattern string? The regex pattern (nil = no filter)
---@param case_sensitive boolean Whether matching is case-sensitive
---@return boolean matches, string? error
local function test_pattern(name, pattern, case_sensitive)
  if not pattern or pattern == "" then
    return true, nil  -- No filter = match all
  end

  -- Apply case sensitivity
  local test_name = case_sensitive and name or name:lower()
  local test_pattern = case_sensitive and pattern or pattern:lower()

  -- Use pcall to catch invalid regex
  local success, result = pcall(function()
    return test_name:match(test_pattern) ~= nil
  end)

  if not success then
    return false, "Invalid regex: " .. tostring(result)
  end

  return result, nil
end

---Check if an object belongs to a system schema
---@param obj BaseDbObject The object to check
---@param system_schemas string[] List of system schema names
---@return boolean is_system True if object is from a system schema
local function is_system_schema_object(obj, system_schemas)
  -- Determine which schema to check
  local schema_to_check = obj.schema_name

  -- For schema/schema_view nodes, use the node's name as the schema
  if obj.object_type == "schema" or obj.object_type == "schema_view" then
    schema_to_check = obj.name
  end

  if not schema_to_check then
    return false
  end

  local schema_lower = schema_to_check:lower()
  for _, sys_schema in ipairs(system_schemas) do
    if schema_lower == sys_schema:lower() then
      return true
    end
  end

  return false
end

---Apply filters to a list of objects
---@param objects BaseDbObject[] List of objects to filter
---@param filters FilterState Filter state
---@return BaseDbObject[] filtered, number effective_total, string? error
function UiFilters.apply(objects, filters)
  local filtered = {}
  local error_msg = nil

  -- Get system schemas list (used for both filtering and effective total calculation)
  local Config = require('ssns.config')
  local filter_config = Config.get_filters()
  local system_schemas = filter_config and filter_config.system_schemas or {}

  -- Calculate effective total (excludes system schemas if hide_system_schemas is enabled)
  local effective_total = 0
  if filters.hide_system_schemas then
    for _, obj in ipairs(objects) do
      if not is_system_schema_object(obj, system_schemas) then
        effective_total = effective_total + 1
      end
    end
  else
    effective_total = #objects
  end

  for _, obj in ipairs(objects) do
    local include = true

    -- System schema filter FIRST (hide sys, INFORMATION_SCHEMA, etc.)
    -- This determines the "effective total" baseline
    if include and filters.hide_system_schemas then
      if is_system_schema_object(obj, system_schemas) then
        include = false
      end
    end

    -- Name include filter
    if include and filters.name_include and filters.name_include ~= "" then
      local matches, err = test_pattern(obj.name, filters.name_include, filters.case_sensitive)
      if err then
        error_msg = err
        include = false
      elseif not matches then
        include = false
      end
    end

    -- Name exclude filter
    if include and filters.name_exclude and filters.name_exclude ~= "" then
      local matches, err = test_pattern(obj.name, filters.name_exclude, filters.case_sensitive)
      if err then
        error_msg = err
        include = false
      elseif matches then
        include = false  -- Exclude if it matches the exclude pattern
      end
    end

    -- Schema include filter (for objects that have schema_name)
    if include and filters.schema_include and filters.schema_include ~= "" and obj.schema_name then
      local matches, err = test_pattern(obj.schema_name, filters.schema_include, filters.case_sensitive)
      if err then
        error_msg = err
        include = false
      elseif not matches then
        include = false
      end
    end

    -- Schema exclude filter
    if include and filters.schema_exclude and filters.schema_exclude ~= "" and obj.schema_name then
      local matches, err = test_pattern(obj.schema_name, filters.schema_exclude, filters.case_sensitive)
      if err then
        error_msg = err
        include = false
      elseif matches then
        include = false  -- Exclude if it matches the exclude pattern
      end
    end

    -- Object type filter (for object references in SCHEMAS group)
    if include and filters.object_types and next(filters.object_types) ~= nil then
      -- For object_reference nodes, check the referenced object's type
      local obj_type = obj.object_type
      if obj_type == "object_reference" and obj.referenced_object then
        obj_type = obj.referenced_object.object_type
      end

      -- If object type is not in the enabled list, exclude it
      if not filters.object_types[obj_type] then
        include = false
      end
    end

    if include then
      table.insert(filtered, obj)
    end
  end

  return filtered, effective_total, error_msg
end

---Get a count string for display (e.g., "(50/337)" or "(50)")
---@param group BaseDbObject The group object
---@param filtered_count number Number of filtered objects
---@param effective_total number Effective total (after system schema filtering)
---@return string
function UiFilters.get_count_display(group, filtered_count, effective_total)
  -- If no user-defined filters (only system schema filter or no filters at all),
  -- just show the count without "x/y" format
  if not UiFilters.has_user_filters(group) then
    return string.format("(%d)", filtered_count)
  end

  -- User has additional filters - show filtered/effective_total if different
  if filtered_count == effective_total then
    return string.format("(%d)", effective_total)
  end

  return string.format("(%d/%d)", filtered_count, effective_total)
end

return UiFilters
