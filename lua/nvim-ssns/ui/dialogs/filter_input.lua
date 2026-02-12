---@class UiFilterInput
---Filter input UI for database object filtering
local UiFilterInput = {}

local UiFloat = require('nvim-float.window')
local ContentBuilder = require('nvim-float.content')

---@type FloatWindow? Current float window
local current_float = nil

---Object type options for schema filtering
---Keys must match actual object_type values from the class definitions
local OBJECT_TYPES = {
  { key = "table", label = "Tables" },
  { key = "view", label = "Views" },
  { key = "procedure", label = "Procedures" },
  { key = "function", label = "Functions" },
  { key = "synonym", label = "Synonyms" },
  { key = "sequence", label = "Sequences" },
}

---Show filter input form
---@param group BaseDbObject The group to filter
---@param current_filters table? Current filter state
---@param callback function Callback function(filters: table)
---@param on_cancel function? Optional callback when form is cancelled
function UiFilterInput.show_input(group, current_filters, callback, on_cancel)
  current_filters = current_filters or {}

  -- Close existing if open
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  -- Determine if this is a schema node (needs object type filters)
  local is_schema_node = group.object_type == "schema" or group.object_type == "schema_view"

  -- Check if this group supports system schema filtering
  local supports_sys_schema_filter = group.object_type == "tables_group"
    or group.object_type == "views_group"
    or group.object_type == "procedures_group"
    or group.object_type == "functions_group"
    or group.object_type == "scalar_functions_group"
    or group.object_type == "table_functions_group"
    or group.object_type == "synonyms_group"
    or group.object_type == "schemas_group"
    or group.object_type == "system_databases_group"
    or group.object_type == "system_schemas_group"
    or group.object_type == "schema"
    or group.object_type == "schema_view"

  -- Get default for hide_system_schemas from config
  local Config = require('nvim-ssns.config')
  local filter_config = Config.get_filters()
  local default_hide_system = filter_config and filter_config.hide_system_schemas or false

  -- Build content with embedded containers
  local cb = ContentBuilder.new()

  cb:blank()
  cb:styled(string.format("  Filter: %s (%s)", group.name or "N/A", group.object_type or "unknown"), "header")
  cb:styled("  " .. string.rep("─", 50), "muted")
  cb:blank()

  -- Text filter inputs
  cb:embedded_input("name_include", {
    label = "  Include Name  ",
    value = current_filters.name_include or "",
    placeholder = "(regex pattern)",
    width = 30,
  })
  cb:embedded_input("name_exclude", {
    label = "  Exclude Name  ",
    value = current_filters.name_exclude or "",
    placeholder = "(regex pattern)",
    width = 30,
  })
  cb:embedded_input("schema_include", {
    label = "  Include Schema",
    value = current_filters.schema_include or "",
    placeholder = "(regex pattern)",
    width = 25,
  })
  cb:embedded_input("schema_exclude", {
    label = "  Exclude Schema",
    value = current_filters.schema_exclude or "",
    placeholder = "(regex pattern)",
    width = 25,
  })

  cb:blank()

  -- Hide System Schemas toggle (for supported groups)
  if supports_sys_schema_filter then
    local hide_sys_value = current_filters.hide_system_schemas
    if hide_sys_value == nil then
      hide_sys_value = default_hide_system
    end
    cb:embedded_dropdown("hide_system_schemas", {
      label = "  System Schemas",
      options = {
        { value = "hide", label = "Hide" },
        { value = "show", label = "Show" },
      },
      selected = hide_sys_value and "hide" or "show",
      width = 8,
    })
  end

  -- Case Sensitive toggle
  cb:embedded_dropdown("case_sensitive", {
    label = "  Case Sensitive",
    options = {
      { value = "no", label = "No" },
      { value = "yes", label = "Yes" },
    },
    selected = current_filters.case_sensitive and "yes" or "no",
    width = 6,
  })

  -- Object type filters for schema nodes (multi-select)
  if is_schema_node then
    cb:blank()
    local object_types_map = current_filters.object_types or {}
    local type_options = {}
    local type_selected = {}
    for _, otype in ipairs(OBJECT_TYPES) do
      table.insert(type_options, { value = otype.key, label = otype.label })
      if object_types_map[otype.key] ~= false then
        table.insert(type_selected, otype.key)
      end
    end
    cb:embedded_multi_dropdown("object_types", {
      label = "  Object Types  ",
      options = type_options,
      selected = type_selected,
      width = 30,
      display_mode = "list",
    })
  end

  cb:blank()
  cb:styled("  ──────────────────────────────────────", "muted")
  cb:spans({
    { text = "  ", style = "text" },
    { text = "hjkl", style = "key" },
    { text = " Navigate  ", style = "muted" },
    { text = "s", style = "key" },
    { text = " Submit  ", style = "muted" },
    { text = "q/Esc", style = "key" },
    { text = " Cancel", style = "muted" },
  })
  cb:blank()

  -- Submit handler
  local function submit()
    if not current_float then return end

    local values = current_float:get_all_embedded_values()

    local filters = {
      name_include = values.name_include ~= "" and values.name_include or nil,
      name_exclude = values.name_exclude ~= "" and values.name_exclude or nil,
      schema_include = values.schema_include ~= "" and values.schema_include or nil,
      schema_exclude = values.schema_exclude ~= "" and values.schema_exclude or nil,
      case_sensitive = values.case_sensitive == "yes",
    }

    -- Add hide_system_schemas if applicable
    if supports_sys_schema_filter then
      filters.hide_system_schemas = values.hide_system_schemas == "hide"
    end

    -- Rebuild object_types map for schema nodes
    if is_schema_node then
      filters.object_types = {}
      local selected_types = values.object_types or {}
      -- Build a lookup of selected values
      local selected_set = {}
      for _, v in ipairs(selected_types) do
        selected_set[v] = true
      end
      for _, otype in ipairs(OBJECT_TYPES) do
        filters.object_types[otype.key] = selected_set[otype.key] or false
      end
    end

    current_float:close()
    current_float = nil
    callback(filters)
  end

  -- Cancel handler
  local function cancel()
    if current_float then
      current_float:close()
      current_float = nil
    end
    if on_cancel then
      on_cancel()
    end
  end

  -- Create the float with embedded containers
  current_float = UiFloat.create(nil, {
    title = " Filter Settings ",
    title_pos = "center",
    border = "rounded",
    width = 60,
    centered = true,
    default_keymaps = false,
    content_builder = cb,
    keymaps = {
      ["s"] = submit,
      ["q"] = cancel,
      ["<Esc>"] = cancel,
    },
  })
end

---Check if filter input is open
---@return boolean
function UiFilterInput.is_open()
  return current_float ~= nil
end

return UiFilterInput
