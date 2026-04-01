---@class XlsxReader
---Wraps nvim-xlsx to produce EtlResult-compatible data for ETL Lua blocks
local XlsxReader = {}

---@class XlsxReadOptions
---@field sheet string? Sheet name (default: first sheet)
---@field sheet_index integer? Sheet index (1-based, alternative to sheet)
---@field headers boolean? Whether row 1 is headers (default: true)
---@field skip_rows integer? Skip N rows after header (default: 0)
---@field max_rows integer? Limit rows read (default: nil = all)
---@field columns table<string, string>? Column rename map: {["Excel Col"] = "sql_col"}
---@field sanitize_names boolean? Sanitize column names for SQL (default: true)
---@field date_columns string[]|integer[]? Column names or indices to force-treat as dates
---@field empty_row_limit integer? Stop after N consecutive empty rows (default: 50)

---@class XlsxReadResult
---@field rows table[] Array of keyed row objects
---@field columns table[] Array of {name, type, index}
---@field row_count integer Number of rows
---@field sheet_name string Name of the sheet read

-- Standard Excel date format IDs (built-in)
local DATE_FORMAT_IDS = {
  [14] = true, -- mm-dd-yy
  [15] = true, -- d-mmm-yy
  [16] = true, -- d-mmm
  [17] = true, -- mmm-yy
  [18] = true, -- h:mm AM/PM
  [19] = true, -- h:mm:ss AM/PM
  [20] = true, -- h:mm
  [21] = true, -- h:mm:ss
  [22] = true, -- m/d/yy h:mm
}

-- Time-only formats (18-21) should include time in ISO output
local TIME_FORMAT_IDS = {
  [18] = true,
  [19] = true,
  [20] = true,
  [21] = true,
  [22] = true,
}

---Check if a custom format code looks like a date/time format
---@param code string Number format code
---@return boolean is_date
---@return boolean has_time
local function is_date_format_code(code)
  if not code then return false, false end
  -- Strip quoted strings to avoid false positives
  local stripped = code:gsub('%b""', ''):gsub("%b''", '')
  local has_date = stripped:match('[dmyDMY]') ~= nil
  local has_time = stripped:match('[hHsS]') ~= nil
  return has_date or has_time, has_time
end

---Sanitize a column name for SQL compatibility
---@param name string
---@return string
local function sanitize_column_name(name)
  if not name or name == "" then return "column" end
  -- Replace spaces and special chars with underscores
  local sanitized = name:gsub('[%s%p]', '_')
  -- Remove leading/trailing underscores
  sanitized = sanitized:gsub('^_+', ''):gsub('_+$', '')
  -- Collapse multiple underscores
  sanitized = sanitized:gsub('_+', '_')
  -- Ensure it doesn't start with a digit
  if sanitized:match('^%d') then
    sanitized = '_' .. sanitized
  end
  return sanitized ~= '' and sanitized or 'column'
end

---Build a set of date column indices from the date_columns option
---@param date_columns string[]|integer[]|nil
---@param header_map table<string, integer> Map of header name -> column index
---@return table<integer, boolean> Set of column indices that are dates
local function build_date_column_set(date_columns, header_map)
  local set = {}
  if not date_columns then return set end
  for _, col in ipairs(date_columns) do
    if type(col) == "number" then
      set[col] = true
    elseif type(col) == "string" and header_map[col] then
      set[header_map[col]] = true
    end
  end
  return set
end

---Detect if a cell's number format indicates a date
---@param styles table? Workbook styles data
---@param style_index integer? Cell style index
---@return boolean is_date
---@return boolean include_time
local function is_date_cell(styles, style_index)
  if not styles or not style_index then return false, false end

  local styles_part_ok, styles_part = pcall(require, "nvim-xlsx.parts.styles_part")
  if not styles_part_ok then return false, false end

  local xf = styles_part.get_cell_xf(styles, style_index)
  if not xf or not xf.num_fmt_id then return false, false end

  local fmt_id = xf.num_fmt_id

  -- Check built-in date formats
  if DATE_FORMAT_IDS[fmt_id] then
    return true, TIME_FORMAT_IDS[fmt_id] or false
  end

  -- Check custom formats
  local code = styles_part.get_number_format(styles, fmt_id)
  if code then
    return is_date_format_code(code)
  end

  return false, false
end

---Read an Excel file and return EtlResult-compatible data
---@param filepath string Path to .xlsx file
---@param opts XlsxReadOptions?
---@return XlsxReadResult
function XlsxReader.read(filepath, opts)
  opts = opts or {}
  local headers = opts.headers ~= false -- default true
  local skip_rows = opts.skip_rows or 0
  local sanitize = opts.sanitize_names ~= false -- default true

  -- Load nvim-xlsx
  local ok, xlsx = pcall(require, "nvim-xlsx")
  if not ok then
    error("read_xlsx() requires the nvim-xlsx plugin. Install it to use Excel import.", 2)
  end

  local reader = require("nvim-xlsx.reader")
  local date_utils = require("nvim-xlsx.utils.date")

  -- Open workbook
  local workbook, err = xlsx.open(filepath)
  if not workbook then
    error("Failed to open Excel file: " .. (err or "unknown error"), 2)
  end

  -- Get sheet
  local sheet
  local sheet_name
  if opts.sheet then
    sheet = reader.get_sheet(workbook, opts.sheet)
    sheet_name = opts.sheet
    if not sheet then
      error("Sheet not found: " .. opts.sheet, 2)
    end
  elseif opts.sheet_index then
    sheet = reader.get_sheet_by_index(workbook, opts.sheet_index)
    local names = reader.get_sheet_names(workbook)
    sheet_name = names[opts.sheet_index] or ("Sheet" .. opts.sheet_index)
    if not sheet then
      error("Sheet index out of range: " .. opts.sheet_index, 2)
    end
  else
    sheet = reader.get_sheet_by_index(workbook, 1)
    local names = reader.get_sheet_names(workbook)
    sheet_name = names[1] or "Sheet1"
    if not sheet then
      error("Workbook has no sheets", 2)
    end
  end

  -- Get data bounds
  local _, min_row, min_col, max_row, max_col = reader.get_all_data(sheet)
  if not min_row then
    return { rows = {}, columns = {}, row_count = 0, sheet_name = sheet_name }
  end

  -- Extract column headers
  local col_names = {}
  local header_map = {} -- name -> col index
  local data_start_row = min_row

  if headers then
    for col = min_col, max_col do
      local val = reader.get_cell(sheet, min_row, col)
      local name = val and tostring(val) or ("column_" .. col)
      if opts.columns and opts.columns[name] then
        name = opts.columns[name]
      elseif sanitize then
        name = sanitize_column_name(name)
      end
      -- Handle duplicate names
      if header_map[name] then
        local suffix = 2
        while header_map[name .. "_" .. suffix] do suffix = suffix + 1 end
        name = name .. "_" .. suffix
      end
      col_names[col] = name
      header_map[name] = col
    end
    data_start_row = min_row + 1
  else
    -- Generate column names: column_1, column_2, ...
    for col = min_col, max_col do
      local name = "column_" .. col
      if opts.columns and opts.columns[name] then
        name = opts.columns[name]
      end
      col_names[col] = name
      header_map[name] = col
    end
  end

  -- Skip rows after header
  data_start_row = data_start_row + skip_rows

  -- Build forced date column set
  local forced_date_cols = build_date_column_set(opts.date_columns, header_map)

  -- Build column type tracking
  local col_types = {} -- col_index -> {string_count, number_count, bool_count, date_count, nil_count}
  for col = min_col, max_col do
    col_types[col] = { string = 0, number = 0, boolean = 0, date = 0, ["nil"] = 0 }
  end

  -- Build ordered column list (preserves Excel column order)
  local ordered_col_indices = {}
  for col = min_col, max_col do
    table.insert(ordered_col_indices, col)
  end

  -- Read data rows
  -- Stop after N consecutive empty rows to handle Excel files with formatting
  -- extending far beyond actual data (e.g., formatting to row 1M)
  local empty_row_limit = opts.empty_row_limit or 50
  local consecutive_empty = 0

  local rows = {}
  local row_count = 0
  for row = data_start_row, max_row do
    if opts.max_rows and row_count >= opts.max_rows then break end

    local row_obj = {}
    local has_value = false

    for _, col in ipairs(ordered_col_indices) do
      local col_name = col_names[col]
      local cell = reader.get_cell_data(sheet, row, col)

      -- Check for actual non-empty value (not just whitespace)
      local cell_has_value = false
      if cell and cell.value ~= nil then
        local value = cell.value
        -- Treat whitespace-only strings as empty
        if type(value) == "string" then
          if value:match("%S") then
            cell_has_value = true
          end
        else
          cell_has_value = true
        end
      end

      if cell_has_value then
        has_value = true
        local value = cell.value
        local value_type = cell.value_type

        -- Determine if this is a date cell
        local is_date = forced_date_cols[col]
        local include_time = false
        if not is_date and type(value) == "number" and (value_type == nil or value_type == "n") then
          is_date, include_time = is_date_cell(workbook.styles, cell.style_index)
        end

        if is_date and type(value) == "number" then
          value = date_utils.format_iso(value, include_time)
          col_types[col].date = col_types[col].date + 1
        elseif value_type == "b" then
          col_types[col].boolean = col_types[col].boolean + 1
        elseif type(value) == "number" then
          col_types[col].number = col_types[col].number + 1
        else
          value = tostring(value)
          col_types[col].string = col_types[col].string + 1
        end

        row_obj[col_name] = value
      else
        -- Explicitly set nil columns so they appear in pairs() and preserve column presence
        row_obj[col_name] = vim.NIL
        col_types[col]["nil"] = col_types[col]["nil"] + 1
      end
    end

    if has_value then
      consecutive_empty = 0
      table.insert(rows, row_obj)
      row_count = row_count + 1
    else
      consecutive_empty = consecutive_empty + 1
      if consecutive_empty >= empty_row_limit then
        break -- Data region ended; remaining rows are empty formatting
      end
    end
  end

  -- Build column metadata (ordered array matching Excel column order)
  local columns = {}
  local column_order = {} -- ordered list of column names for downstream consumers
  local col_index = 0
  for _, col in ipairs(ordered_col_indices) do
    col_index = col_index + 1
    local counts = col_types[col]
    -- Determine dominant type (exclude nil counts from comparison)
    local inferred_type = "string"
    local max_count = counts.string
    if counts.number > max_count then
      inferred_type = "number"
      max_count = counts.number
    end
    if counts.date > max_count then
      inferred_type = "date"
      max_count = counts.date
    end
    if counts.boolean > max_count then
      inferred_type = "boolean"
    end

    local col_name = col_names[col]
    table.insert(columns, {
      name = col_name,
      type = inferred_type,
      index = col_index,
    })
    table.insert(column_order, col_name)
  end

  return {
    rows = rows,
    columns = columns,
    column_order = column_order,
    row_count = row_count,
    sheet_name = sheet_name,
  }
end

---Get summary info about an Excel file (sheets, dimensions)
---@param filepath string
---@return table? info {sheets: {name, dimension, index}[], sheet_count: integer}
function XlsxReader.info(filepath)
  local ok, xlsx = pcall(require, "nvim-xlsx")
  if not ok then
    error("read_xlsx() requires the nvim-xlsx plugin.", 2)
  end
  return xlsx.info(filepath)
end

return XlsxReader
