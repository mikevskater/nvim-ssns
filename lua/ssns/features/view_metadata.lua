---@class ViewMetadata
---View SQL object metadata in a floating window
---Uses standardized get_metadata_info() method from object classes
local ViewMetadata = {}

local GoTo = require('ssns.features.go_to')
local UiFloat = require('ssns.ui.float')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewMetadata.close_current_float()
  if current_float then
    if current_float.bufnr then
      local success, UiQuery = pcall(require, 'ssns.ui.query')
      if success then
        UiQuery.query_buffers[current_float.bufnr] = nil
      end
    end
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---Pad string to width
---@param str string
---@param width number
---@return string
local function pad(str, width)
  str = tostring(str or "")
  if #str >= width then
    return str:sub(1, width)
  end
  return str .. string.rep(" ", width - #str)
end

---Format a metadata section into display lines
---@param section table Section with title, headers, rows
---@return string[] lines
local function format_section(section)
  local lines = {}

  -- Title
  table.insert(lines, section.title)
  table.insert(lines, "")

  local headers = section.headers or {}
  local rows = section.rows or {}

  if #rows == 0 then
    table.insert(lines, "  (No data)")
    return lines
  end

  -- Calculate column widths
  local widths = {}
  for i, header in ipairs(headers) do
    widths[i] = #tostring(header)
  end
  for _, row in ipairs(rows) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i] or 0, #tostring(cell or ""))
    end
  end

  -- Cap widths at reasonable max
  for i, w in ipairs(widths) do
    widths[i] = math.min(w, 40)
  end

  -- Build header line
  local header_parts = {}
  for i, header in ipairs(headers) do
    table.insert(header_parts, pad(header, widths[i]))
  end
  table.insert(lines, "  " .. table.concat(header_parts, "  "))

  -- Build separator line
  local sep_parts = {}
  for i, _ in ipairs(headers) do
    table.insert(sep_parts, string.rep("-", widths[i]))
  end
  table.insert(lines, "  " .. table.concat(sep_parts, "  "))

  -- Build data rows
  for _, row in ipairs(rows) do
    local row_parts = {}
    for i, _ in ipairs(headers) do
      local cell = row[i] or "-"
      table.insert(row_parts, pad(cell, widths[i]))
    end
    table.insert(lines, "  " .. table.concat(row_parts, "  "))
  end

  return lines
end

---Format metadata info into display lines
---@param metadata table Metadata with sections array
---@return string[] lines
local function format_metadata(metadata)
  local lines = {}

  for i, section in ipairs(metadata.sections or {}) do
    if i > 1 then
      table.insert(lines, "")  -- Blank line between sections
    end
    local section_lines = format_section(section)
    for _, line in ipairs(section_lines) do
      table.insert(lines, line)
    end
  end

  return lines
end

---Get display name for an object
---@param obj BaseDbObject
---@return string
local function get_object_display_name(obj)
  return obj.table_name or obj.view_name or obj.procedure_name
         or obj.function_name or obj.synonym_name or obj.name or "unknown"
end

---Show metadata in a floating window
---@param target_object BaseDbObject The resolved object
---@param identifier string The original identifier string
function ViewMetadata.show_metadata_float(target_object, identifier)
  ViewMetadata.close_current_float()

  -- Get metadata from object
  local metadata = target_object:get_metadata_info()
  if not metadata or not metadata.sections or #metadata.sections == 0 then
    vim.notify("No metadata available", vim.log.levels.WARN)
    return
  end

  -- Format into lines
  local lines = format_metadata(metadata)

  -- Build title
  local obj_type = (target_object.object_type or "object"):upper()
  local obj_name = get_object_display_name(target_object)
  local schema_name = target_object.schema_name
  local display_name = schema_name and (schema_name .. "." .. obj_name) or obj_name
  local title = string.format(" %s: %s ", obj_type, display_name)

  -- Create floating window
  current_float = UiFloat.create(lines, {
    title = title,
    title_pos = "center",
    footer = " q/ESC/<CR>: close ",
    footer_pos = "center",
    border = "rounded",
    filetype = "ssns-metadata",
    readonly = true,
    modifiable = false,
    cursorline = true,
    wrap = false,
    centered = true,
    max_width = math.floor(vim.o.columns * 0.85),
    max_height = math.floor(vim.o.lines * 0.85),
    min_width = 50,
    min_height = 5,
    default_keymaps = false,
    keymaps = {
      ["q"] = function() ViewMetadata.close_current_float() end,
      ["<Esc>"] = function() ViewMetadata.close_current_float() end,
      ["<CR>"] = function() ViewMetadata.close_current_float() end,
    },
  })
end

---View the metadata of the object under cursor
function ViewMetadata.view_metadata_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    vim.notify("Cannot read current line", vim.log.levels.WARN)
    return
  end

  local identifier = GoTo.get_identifier_at_cursor(line, col)
  if not identifier or identifier == "" then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  local database_name, schema_name, object_name = GoTo.parse_identifier(identifier)

  local target_object, error_msg = GoTo.resolve_object(bufnr, object_name, schema_name, database_name)
  if not target_object then
    vim.notify(error_msg or "Object not found", vim.log.levels.WARN)
    return
  end

  -- Check if object has get_metadata_info method
  if not target_object.get_metadata_info then
    vim.notify(string.format("'%s' does not have viewable metadata", identifier), vim.log.levels.WARN)
    return
  end

  ViewMetadata.show_metadata_float(target_object, identifier)
end

return ViewMetadata
