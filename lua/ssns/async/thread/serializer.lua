---Thread-safe serialization utilities
---Handles conversion of complex objects to JSON for thread communication
---@class ThreadSerializerModule
local Serializer = {}

---Serialize a value to JSON, handling special cases
---@param value any Value to serialize
---@return string json
function Serializer.encode(value)
  local ok, json = pcall(vim.fn.json_encode, value)
  if ok then
    return json
  end
  -- Fallback for problematic values
  return "{}"
end

---Deserialize JSON to Lua value
---@param json string JSON string
---@return any? value
---@return string? error
function Serializer.decode(json)
  if not json or json == "" then
    return nil, "Empty JSON string"
  end

  local ok, value = pcall(vim.fn.json_decode, json)
  if ok then
    return value, nil
  end
  return nil, tostring(value)
end

---Serialize searchable objects for object search threading
---Strips non-serializable data (functions, metatables, circular refs)
---@param objects table[] Array of searchable objects
---@return string json
function Serializer.serialize_searchables(objects)
  local simplified = {}

  for i, obj in ipairs(objects) do
    -- Extract only serializable fields needed for search
    simplified[i] = {
      idx = i,  -- Original index for reconstruction
      unique_id = obj.unique_id,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      -- Only include already-loaded data (no lazy loading in thread)
      definition = obj.definition_loaded and obj.definition or nil,
      metadata_text = obj.metadata_loaded and obj.metadata_text or nil,
      -- Include display info
      display_name = obj.display_name,
      full_name = obj.full_name,
    }
  end

  return Serializer.encode(simplified)
end

---Serialize tree nodes for rendering
---@param nodes table[] Array of tree nodes
---@return string json
function Serializer.serialize_tree_nodes(nodes)
  local simplified = {}

  local function serialize_node(node, depth)
    if depth > 10 then return nil end  -- Prevent infinite recursion

    local data = {
      name = node.name,
      object_type = node.object_type,
      db_name = node.db_name,
      schema_name = node.schema_name,
      is_loaded = node.is_loaded,
      is_expanded = node.ui_state and node.ui_state.expanded,
    }

    -- Serialize children if present
    if node.schemas then
      data.schemas = {}
      for _, schema in ipairs(node.schemas) do
        table.insert(data.schemas, serialize_node(schema, depth + 1))
      end
    end

    if node.tables then
      data.tables = {}
      for _, tbl in ipairs(node.tables) do
        table.insert(data.tables, { name = tbl.name, object_type = "table" })
      end
    end

    if node.views then
      data.views = {}
      for _, view in ipairs(node.views) do
        table.insert(data.views, { name = view.name, object_type = "view" })
      end
    end

    if node.procedures then
      data.procedures = {}
      for _, proc in ipairs(node.procedures) do
        table.insert(data.procedures, { name = proc.name, object_type = "procedure" })
      end
    end

    if node.functions then
      data.functions = {}
      for _, func in ipairs(node.functions) do
        table.insert(data.functions, { name = func.name, object_type = "function" })
      end
    end

    if node.synonyms then
      data.synonyms = {}
      for _, syn in ipairs(node.synonyms) do
        table.insert(data.synonyms, { name = syn.name, object_type = "synonym" })
      end
    end

    return data
  end

  for _, node in ipairs(nodes) do
    table.insert(simplified, serialize_node(node, 0))
  end

  return Serializer.encode(simplified)
end

---Serialize columns for completion threading
---@param columns table[] Array of column objects
---@return string json
function Serializer.serialize_columns(columns)
  local simplified = {}

  for i, col in ipairs(columns) do
    simplified[i] = {
      idx = i,
      name = col.name or col.column_name,
      data_type = col.data_type,
      nullable = col.nullable,
      is_primary_key = col.is_primary_key,
      is_foreign_key = col.is_foreign_key,
      is_identity = col.is_identity,
      is_computed = col.is_computed,
      table_name = col.table_name,
      schema_name = col.schema_name,
      max_length = col.max_length,
      precision = col.precision,
      scale = col.scale,
    }
  end

  return Serializer.encode(simplified)
end

---Serialize FK graph for BFS threading
---@param graph table FK constraint graph
---@return string json
function Serializer.serialize_fk_graph(graph)
  local simplified = {}

  for key, node in pairs(graph) do
    simplified[key] = {
      table_name = node.table_name,
      schema_name = node.schema_name,
      constraints = {},
    }

    if node.constraints then
      for _, constraint in ipairs(node.constraints) do
        table.insert(simplified[key].constraints, {
          name = constraint.name,
          column_name = constraint.column_name,
          referenced_table = constraint.referenced_table,
          referenced_schema = constraint.referenced_schema,
          referenced_column = constraint.referenced_column,
        })
      end
    end
  end

  return Serializer.encode(simplified)
end

---Serialize items for sorting
---@param items table[] Array of items to sort
---@param key_field string Field name to sort by
---@return string json
function Serializer.serialize_for_sort(items, key_field)
  local simplified = {}

  for i, item in ipairs(items) do
    simplified[i] = {
      idx = i,
      sort_key = item[key_field] or item.name or "",
      name = item.name,
      object_type = item.object_type,
    }
  end

  return Serializer.encode({
    items = simplified,
    key_field = key_field,
  })
end

---Create a pure Lua JSON encoder for use in worker threads
---Worker threads cannot use vim.fn.json_encode, so we need a pure Lua version
---@return string lua_code Lua code string for JSON encoding
function Serializer.get_worker_json_encoder()
  -- Simple JSON encoder that works in pure Lua (no vim.* dependencies)
  return [[
local function json_encode(value)
  local t = type(value)

  if value == nil then
    return "null"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    if value ~= value then return "null" end  -- NaN
    if value >= math.huge then return "null" end  -- Infinity
    if value <= -math.huge then return "null" end  -- -Infinity
    return tostring(value)
  elseif t == "string" then
    -- Escape special characters
    local escaped = value:gsub('[\\"\b\f\n\r\t]', {
      ['\\'] = '\\\\',
      ['"'] = '\\"',
      ['\b'] = '\\b',
      ['\f'] = '\\f',
      ['\n'] = '\\n',
      ['\r'] = '\\r',
      ['\t'] = '\\t',
    })
    return '"' .. escaped .. '"'
  elseif t == "table" then
    -- Check if array or object
    local is_array = true
    local max_idx = 0
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        is_array = false
        break
      end
      if k > max_idx then max_idx = k end
    end

    if is_array and max_idx == #value then
      -- Encode as array
      local parts = {}
      for i = 1, #value do
        parts[i] = json_encode(value[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Encode as object
      local parts = {}
      for k, v in pairs(value) do
        if type(k) == "string" then
          table.insert(parts, json_encode(k) .. ":" .. json_encode(v))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    return "null"  -- Functions, userdata, etc.
  end
end
]]
end

---Create a pure Lua JSON decoder for use in worker threads
---@return string lua_code Lua code string for JSON decoding
function Serializer.get_worker_json_decoder()
  -- Simple JSON decoder for pure Lua
  return [[
local function json_decode(str)
  if not str or str == "" then return nil end

  local pos = 1
  local function skip_whitespace()
    while pos <= #str and str:sub(pos, pos):match("%s") do
      pos = pos + 1
    end
  end

  local function parse_string()
    pos = pos + 1  -- Skip opening quote
    local start = pos
    local result = ""
    while pos <= #str do
      local c = str:sub(pos, pos)
      if c == '"' then
        pos = pos + 1
        return result .. str:sub(start, pos - 2)
      elseif c == '\\' then
        result = result .. str:sub(start, pos - 1)
        pos = pos + 1
        local escaped = str:sub(pos, pos)
        if escaped == 'n' then result = result .. '\n'
        elseif escaped == 't' then result = result .. '\t'
        elseif escaped == 'r' then result = result .. '\r'
        elseif escaped == '"' then result = result .. '"'
        elseif escaped == '\\' then result = result .. '\\'
        else result = result .. escaped
        end
        pos = pos + 1
        start = pos
      else
        pos = pos + 1
      end
    end
    return result
  end

  local function parse_number()
    local start = pos
    if str:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
    if str:sub(pos, pos) == '.' then
      pos = pos + 1
      while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
    end
    if str:sub(pos, pos):match("[eE]") then
      pos = pos + 1
      if str:sub(pos, pos):match("[+-]") then pos = pos + 1 end
      while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
    end
    return tonumber(str:sub(start, pos - 1))
  end

  local parse_value  -- Forward declaration

  local function parse_array()
    pos = pos + 1  -- Skip [
    local arr = {}
    skip_whitespace()
    if str:sub(pos, pos) == ']' then
      pos = pos + 1
      return arr
    end
    while true do
      table.insert(arr, parse_value())
      skip_whitespace()
      if str:sub(pos, pos) == ']' then
        pos = pos + 1
        return arr
      elseif str:sub(pos, pos) == ',' then
        pos = pos + 1
        skip_whitespace()
      end
    end
  end

  local function parse_object()
    pos = pos + 1  -- Skip {
    local obj = {}
    skip_whitespace()
    if str:sub(pos, pos) == '}' then
      pos = pos + 1
      return obj
    end
    while true do
      skip_whitespace()
      local key = parse_string()
      skip_whitespace()
      pos = pos + 1  -- Skip :
      skip_whitespace()
      obj[key] = parse_value()
      skip_whitespace()
      if str:sub(pos, pos) == '}' then
        pos = pos + 1
        return obj
      elseif str:sub(pos, pos) == ',' then
        pos = pos + 1
      end
    end
  end

  parse_value = function()
    skip_whitespace()
    local c = str:sub(pos, pos)
    if c == '"' then return parse_string()
    elseif c == '[' then return parse_array()
    elseif c == '{' then return parse_object()
    elseif c == 't' then pos = pos + 4; return true
    elseif c == 'f' then pos = pos + 5; return false
    elseif c == 'n' then pos = pos + 4; return nil
    elseif c:match("[0-9-]") then return parse_number()
    end
    return nil
  end

  return parse_value()
end
]]
end

return Serializer
