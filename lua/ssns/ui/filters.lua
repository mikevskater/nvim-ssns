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

---Get filter state for a group
---@param group BaseDbObject The group object
---@return FilterState
function UiFilters.get(group)
  local path = group:get_full_path()

  if not filter_store[path] then
    -- Initialize with empty filters
    filter_store[path] = {
      name_include = nil,
      name_exclude = nil,
      schema_include = nil,
      schema_exclude = nil,
      object_types = nil,
      case_sensitive = false
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

---Clear all filters for a group
---@param group BaseDbObject The group object
function UiFilters.clear(group)
  local path = group:get_full_path()
  filter_store[path] = {
    name_include = nil,
    name_exclude = nil,
    schema_include = nil,
    schema_exclude = nil,
    object_types = nil,
    case_sensitive = false
  }
end

---Check if a group has any active filters
---@param group BaseDbObject The group object
---@return boolean
function UiFilters.has_filters(group)
  local filters = UiFilters.get(group)

  return (filters.name_include and filters.name_include ~= "")
    or (filters.name_exclude and filters.name_exclude ~= "")
    or (filters.schema_include and filters.schema_include ~= "")
    or (filters.schema_exclude and filters.schema_exclude ~= "")
    or (filters.object_types and next(filters.object_types) ~= nil)
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

---Apply filters to a list of objects
---@param objects BaseDbObject[] List of objects to filter
---@param filters FilterState Filter state
---@return BaseDbObject[] filtered, number total, string? error
function UiFilters.apply(objects, filters)
  local filtered = {}
  local total = #objects
  local error_msg = nil

  for _, obj in ipairs(objects) do
    local include = true

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

  return filtered, total, error_msg
end

---Get a count string for display (e.g., "(50/337)" or "")
---@param group BaseDbObject The group object
---@param filtered_count number Number of filtered objects
---@param total_count number Total number of objects
---@return string
function UiFilters.get_count_display(group, filtered_count, total_count)
  if not UiFilters.has_filters(group) then
    return string.format("(%d)", total_count)
  end

  if filtered_count == total_count then
    return string.format("(%d)", total_count)
  end

  return string.format("(%d/%d)", filtered_count, total_count)
end

return UiFilters
