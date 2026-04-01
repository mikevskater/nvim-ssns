---@class SsnsImportCommands
---Import wizard and preview for Excel files using nvim-float TUI
local M = {}

local UiFloat = require('nvim-float.window')
local ContentBuilder = require('nvim-float.content')

---@class ImportState
---@field filepath string?
---@field sheet_name string?
---@field sheet_options {value:string,label:string}[]
---@field preview_data XlsxReadResult?
---@field columns table[]?
---@field server_name string?
---@field server_options {value:string,label:string}[]
---@field database_name string?
---@field database_options {value:string,label:string}[]
---@field table_name string?
---@field mode string?
---@field headers string

-- ============================================================================
-- Utilities
-- ============================================================================

---@type FloatWindow?
local current_float = nil

local function notify_error(msg)
  vim.notify("[SSNS Import] " .. msg, vim.log.levels.ERROR)
end

local function notify_info(msg)
  vim.notify("[SSNS Import] " .. msg, vim.log.levels.INFO)
end

local function has_xlsx()
  return pcall(require, "nvim-xlsx")
end

-- ============================================================================
-- OS File Picker (Windows: PowerShell OpenFileDialog)
-- ============================================================================

---Open native OS file picker asynchronously
---@param callback fun(filepath: string?)
local function open_file_picker(callback)
  local ps_script = table.concat({
    'Add-Type -AssemblyName System.Windows.Forms;',
    '$d = New-Object System.Windows.Forms.OpenFileDialog;',
    "$d.Title = 'Select file to import';",
    "$d.Filter = 'Excel Files (*.xlsx)|*.xlsx|CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';",
    'if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $d.FileName }',
  }, ' ')

  local stdout_chunks = {}
  local stdout = vim.uv.new_pipe()

  local handle
  handle = vim.uv.spawn('powershell', {
    args = { '-NoProfile', '-Command', ps_script },
    stdio = { nil, stdout, nil },
  }, function(code)
    stdout:close()
    handle:close()
    vim.schedule(function()
      if code == 0 then
        local path = table.concat(stdout_chunks):gsub('%s+$', '')
        callback(path ~= '' and path or nil)
      else
        callback(nil)
      end
    end)
  end)

  if stdout then
    stdout:read_start(function(_, data)
      if data then table.insert(stdout_chunks, data) end
    end)
  end
end

-- ============================================================================
-- State Management
-- ============================================================================

---Sync embedded container values back into state
---@param state ImportState
local function sync_state(state)
  if not current_float then return end
  local values = current_float:get_all_embedded_values()
  if values.filepath then state.filepath = values.filepath end
  if values.table_name then state.table_name = values.table_name end
  if values.sheet then state.sheet_name = values.sheet end
  if values.server then state.server_name = values.server end
  if values.database then state.database_name = values.database end
  if values.mode then state.mode = values.mode end
  if values.headers then state.headers = values.headers end
end

---Build server options from cache
---@return {value:string,label:string}[]
local function build_server_options()
  local Cache = require("nvim-ssns.cache")
  local servers = Cache.get_all_servers()
  local options = {}
  if servers then
    for _, server in ipairs(servers) do
      table.insert(options, { value = server.name, label = server.name })
    end
  end
  return options
end

---Build database options for a server
---@param server_name string?
---@return {value:string,label:string}[]
local function build_database_options(server_name)
  if not server_name then return {} end
  local Cache = require("nvim-ssns.cache")
  local server = Cache.find_server(server_name)
  if not server then return {} end

  local databases = server:get_databases()
  local options = {}
  if databases then
    for _, db in ipairs(databases) do
      table.insert(options, { value = db.name, label = db.name })
    end
  end
  return options
end

---Load sheet info from Excel file and populate state
---@param state ImportState
local function load_sheets(state)
  state.sheet_options = {}
  state.preview_data = nil
  state.columns = nil

  if not state.filepath or state.filepath == "" then return end

  local filepath = vim.fn.expand(state.filepath)
  if vim.fn.filereadable(filepath) == 0 then return end

  local XlsxReader = require("nvim-ssns.etl.xlsx_reader")
  local ok, info = pcall(XlsxReader.info, filepath)
  if not ok or not info then return end

  for _, sheet in ipairs(info.sheets) do
    table.insert(state.sheet_options, {
      value = sheet.name,
      label = sheet.name .. " (" .. (sheet.dimension or "empty") .. ")",
    })
  end

  -- Auto-select first sheet if none selected
  if not state.sheet_name and #state.sheet_options > 0 then
    state.sheet_name = state.sheet_options[1].value
  end
end

---Load preview data for current sheet
---@param state ImportState
local function load_preview(state)
  state.preview_data = nil
  state.columns = nil

  if not state.filepath or not state.sheet_name then return end

  local filepath = vim.fn.expand(state.filepath)
  if vim.fn.filereadable(filepath) == 0 then return end

  local XlsxReader = require("nvim-ssns.etl.xlsx_reader")
  local ok, result = pcall(XlsxReader.read, filepath, {
    sheet = state.sheet_name,
    headers = state.headers == "yes",
    max_rows = 20,
  })

  if ok and result then
    state.preview_data = result
    state.columns = result.columns

    -- Suggest table name from sheet name if not set
    if not state.table_name or state.table_name == "" then
      local suggested = state.sheet_name:gsub('[%s%p]', '_'):gsub('_+', '_')
      state.table_name = "dbo." .. suggested
    end
  end
end

---Load databases for current server
---@param state ImportState
local function load_databases(state)
  state.database_options = build_database_options(state.server_name)
  if not state.database_name and #state.database_options > 0 then
    state.database_name = state.database_options[1].value
  end
end

-- ============================================================================
-- Column Preview Builder (result_table)
-- ============================================================================

---Map xlsx column type to SQL datatype string for result_table coloring
---@param col_type string
---@return string
local function type_to_datatype(col_type)
  if col_type == "number" then return "int"
  elseif col_type == "date" then return "date"
  elseif col_type == "boolean" then return "bit"
  else return "varchar"
  end
end

---Build a ContentBuilder with result_table for column preview
---@param state ImportState
---@return ContentBuilder
local function build_column_preview(state)
  local preview_cb = ContentBuilder.new()

  if not state.preview_data or #state.preview_data.columns == 0 then
    preview_cb:styled("  No data loaded. Enter a file path and press Enter.", "muted")
    return preview_cb
  end

  local data = state.preview_data

  -- Calculate column widths from data
  local col_defs = {}
  local sample_values = {} -- col_name -> first non-nil value

  for _, col in ipairs(data.columns) do
    local max_w = math.max(#col.name, #col.type + 2)
    for i = 1, math.min(10, #data.rows) do
      local val = data.rows[i] and data.rows[i][col.name]
      if val ~= nil then
        max_w = math.max(max_w, math.min(20, #tostring(val)))
        if not sample_values[col.name] then
          sample_values[col.name] = tostring(val)
        end
      end
    end
    table.insert(col_defs, { name = col.name, width = max_w })
  end

  -- Build result table
  local row_num_width = #tostring(math.min(10, #data.rows))
  row_num_width = math.max(row_num_width, 2)

  preview_cb:begin_result_table()
  preview_cb:result_top_border_with_rownum(col_defs, "ascii", row_num_width)
  preview_cb:result_header_row_with_rownum(col_defs, "ascii", row_num_width)
  preview_cb:result_separator_with_rownum(col_defs, "ascii", row_num_width)

  local rows_to_show = math.min(10, #data.rows)
  for i = 1, rows_to_show do
    local row = data.rows[i]
    local values = {}
    for _, col in ipairs(data.columns) do
      local val = row[col.name]
      local is_null = val == nil or val == vim.NIL
      table.insert(values, {
        value = is_null and "NULL" or tostring(val),
        width = col_defs[#values + 1].width,
        datatype = type_to_datatype(col.type),
        is_null = is_null,
      })
    end
    preview_cb:result_multiline_data_row(
      vim.tbl_map(function(v)
        return { lines = { v.value }, width = v.width, datatype = v.datatype, is_null = v.is_null }
      end, values),
      "datatype", "ascii", true, i, row_num_width
    )
  end

  preview_cb:result_bottom_border_with_rownum(col_defs, "ascii", row_num_width)

  if #data.rows >= 20 then
    preview_cb:blank()
    preview_cb:styled("  ... more rows available. Press p for full preview.", "muted")
  end

  -- Column type summary below the table
  preview_cb:blank()
  preview_cb:styled("  Column Types:", "section")
  for _, col in ipairs(data.columns) do
    preview_cb:spans({
      { text = "    " },
      { text = string.format("%-20s", col.name), style = "identifier" },
      { text = col.type, style = "muted" },
    })
  end

  return preview_cb
end

-- ============================================================================
-- Script Generation
-- ============================================================================

---Generate .ssns script content from wizard state
---@param state ImportState
---@return string
local function generate_ssns_script(state)
  local lines = {}
  local escaped_path = state.filepath:gsub("\\", "/")
  local use_headers = state.headers == "yes"
  local table_name = state.table_name or "dbo.ImportTable"

  table.insert(lines, "--@var xlsx_file = " .. escaped_path)
  table.insert(lines, "--@var xlsx_sheet = " .. (state.sheet_name or "Sheet1"))
  table.insert(lines, "")

  -- Lua block: read Excel file and return data with column order preserved
  table.insert(lines, "--@lua read_excel")
  table.insert(lines, "--@description Import from " .. vim.fn.fnamemodify(state.filepath, ":t") .. " (" .. (state.sheet_name or "Sheet1") .. ")")
  table.insert(lines, "local result = read_xlsx(var('xlsx_file'), {")
  table.insert(lines, "  sheet = var('xlsx_sheet'),")
  table.insert(lines, "  headers = " .. tostring(use_headers) .. ",")
  table.insert(lines, "})")
  table.insert(lines, "return data(result.rows, result.column_order)")
  table.insert(lines, "")

  -- Drop + Create table block (if create_insert mode)
  if state.mode == "create_insert" and state.columns then
    table.insert(lines, "--@block create_table")
    table.insert(lines, "--@server " .. (state.server_name or ""))
    table.insert(lines, "--@database " .. (state.database_name or ""))
    table.insert(lines, "--@description Drop and recreate target table")

    -- DROP IF EXISTS first
    table.insert(lines, "IF OBJECT_ID('" .. table_name .. "', 'U') IS NOT NULL")
    table.insert(lines, "  DROP TABLE " .. table_name)
    table.insert(lines, "GO")

    -- CREATE TABLE with columns in xlsx order
    local col_defs = {}
    for _, col in ipairs(state.columns) do
      local sql_type = "NVARCHAR(255)"
      if col.type == "number" then sql_type = "FLOAT"
      elseif col.type == "boolean" then sql_type = "BIT"
      elseif col.type == "date" then sql_type = "DATETIME"
      end
      table.insert(col_defs, string.format("  [%s] %s NULL", col.name, sql_type))
    end

    table.insert(lines, "CREATE TABLE " .. table_name .. " (")
    table.insert(lines, table.concat(col_defs, ",\n"))
    table.insert(lines, ")")
    table.insert(lines, "")
  end

  -- Truncate block (if truncate_insert mode)
  if state.mode == "truncate_insert" then
    table.insert(lines, "--@block truncate_table")
    table.insert(lines, "--@server " .. (state.server_name or ""))
    table.insert(lines, "--@database " .. (state.database_name or ""))
    table.insert(lines, "--@description Truncate target table before import")
    table.insert(lines, "TRUNCATE TABLE " .. table_name)
    table.insert(lines, "")
  end

  -- Insert block: explicit INSERT INTO ... SELECT FROM @input
  table.insert(lines, "--@block import_data")
  table.insert(lines, "--@server " .. (state.server_name or ""))
  table.insert(lines, "--@database " .. (state.database_name or ""))
  table.insert(lines, "--@input read_excel")
  table.insert(lines, "--@description Insert Excel data into " .. table_name)
  table.insert(lines, "INSERT INTO " .. table_name)
  table.insert(lines, "SELECT * FROM @input")

  return table.concat(lines, "\n")
end

-- ============================================================================
-- Import Wizard (single-window TUI)
-- ============================================================================

---Show the import wizard window
---@param state ImportState
local function show_wizard(state)
  -- Close existing float
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  local cb = ContentBuilder.new()

  -- ── FILE section ──
  cb:blank()
  cb:styled("  FILE", "section")
  cb:styled("  " .. string.rep("─", 56), "muted")

  cb:embedded_input("filepath", {
    label = "  File Path    ",
    value = state.filepath or "",
    placeholder = "(path to .xlsx file — Alt+O to browse)",
    width = 40,
    on_submit = function(_, value)
      sync_state(state)
      state.filepath = value
      load_sheets(state)
      if state.sheet_name then
        load_preview(state)
      end
      show_wizard(state)
    end,
  })

  cb:embedded_dropdown("sheet", {
    label = "  Sheet        ",
    options = #state.sheet_options > 0 and state.sheet_options or {{ value = "", label = "(load file first)" }},
    selected = state.sheet_name,
    width = 30,
    on_change = function(_, value)
      sync_state(state)
      state.sheet_name = value
      load_preview(state)
      show_wizard(state)
    end,
  })

  cb:embedded_dropdown("headers", {
    label = "  Headers      ",
    options = {
      { value = "yes", label = "Yes (row 1 is headers)" },
      { value = "no", label = "No (generate column names)" },
    },
    selected = state.headers,
    width = 28,
    on_change = function(_, value)
      sync_state(state)
      state.headers = value
      load_preview(state)
      show_wizard(state)
    end,
  })

  cb:blank()

  -- ── DESTINATION section ──
  cb:styled("  DESTINATION", "section")
  cb:styled("  " .. string.rep("─", 56), "muted")

  cb:embedded_dropdown("server", {
    label = "  Server       ",
    options = #state.server_options > 0 and state.server_options or {{ value = "", label = "(no servers available)" }},
    selected = state.server_name,
    width = 30,
    on_change = function(_, value)
      sync_state(state)
      state.server_name = value
      load_databases(state)
      show_wizard(state)
    end,
  })

  cb:embedded_dropdown("database", {
    label = "  Database     ",
    options = #state.database_options > 0 and state.database_options or {{ value = "", label = "(select server first)" }},
    selected = state.database_name,
    width = 30,
  })

  cb:embedded_input("table_name", {
    label = "  Table        ",
    value = state.table_name or "",
    placeholder = "dbo.TableName",
    width = 30,
  })

  cb:embedded_dropdown("mode", {
    label = "  Mode         ",
    options = {
      { value = "create_insert", label = "Create table & insert" },
      { value = "insert", label = "Insert into existing" },
      { value = "truncate_insert", label = "Truncate & insert" },
    },
    selected = state.mode,
    width = 26,
  })

  cb:blank()

  -- ── COLUMN PREVIEW section ──
  cb:styled("  COLUMN PREVIEW", "section")
  cb:styled("  " .. string.rep("─", 56), "muted")

  local preview_cb = build_column_preview(state)
  local preview_line_count = preview_cb:line_count()
  local container_height = math.max(5, math.min(20, preview_line_count + 1))

  cb:container("column_preview", {
    height = container_height,
    content_builder = preview_cb,
    scrollbar = true,
    focusable = true,
    border = "rounded",
  })

  cb:blank()

  -- ── Controls footer ──
  cb:styled("  " .. string.rep("─", 56), "muted")
  cb:spans({
    { text = "  " },
    { text = "s", style = "key" },
    { text = " Execute  ", style = "muted" },
    { text = "g", style = "key" },
    { text = " Generate .ssns  ", style = "muted" },
    { text = "p", style = "key" },
    { text = " Full Preview  ", style = "muted" },
    { text = "Alt+O", style = "key" },
    { text = " Browse", style = "muted" },
  })
  cb:spans({
    { text = "  " },
    { text = "q/Esc", style = "key" },
    { text = " Close  ", style = "muted" },
    { text = "Enter", style = "key" },
    { text = " Activate field", style = "muted" },
  })
  cb:blank()

  -- ── Build keymaps ──
  local keymaps = {}

  -- Cancel
  keymaps["q"] = function()
    if current_float then
      current_float:close()
      current_float = nil
    end
  end
  keymaps["<Esc>"] = keymaps["q"]

  -- Submit (execute immediately)
  keymaps["s"] = function()
    sync_state(state)

    -- Validate
    if not state.filepath or state.filepath == "" then
      notify_error("File path is required.") return
    end
    if not state.server_name or state.server_name == "" then
      notify_error("Server is required.") return
    end
    if not state.database_name or state.database_name == "" then
      notify_error("Database is required.") return
    end
    if not state.table_name or state.table_name == "" then
      notify_error("Table name is required.") return
    end

    local script = generate_ssns_script(state)

    if current_float then
      current_float:close()
      current_float = nil
    end

    local Etl = require("nvim-ssns.etl")
    local EtlParser = require("nvim-ssns.etl.parser")

    local parse_ok, parsed = pcall(EtlParser.parse, script, "import")
    if not parse_ok then
      notify_error("Failed to parse generated script: " .. tostring(parsed))
      return
    end

    notify_info("Executing import...")
    Etl.execute(parsed)
  end

  -- Generate .ssns script in new buffer
  keymaps["g"] = function()
    sync_state(state)

    if not state.filepath or state.filepath == "" then
      notify_error("File path is required.") return
    end

    local script = generate_ssns_script(state)

    if current_float then
      current_float:close()
      current_float = nil
    end

    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = "ssns"
    vim.bo[buf].buftype = ""

    local suggested_name = vim.fn.fnamemodify(state.filepath, ":t:r") .. "_import.ssns"
    vim.api.nvim_buf_set_name(buf, suggested_name)

    local script_lines = vim.split(script, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, script_lines)

    notify_info("Import script generated. Review and run with :SSNSEtl")
  end

  -- Full preview
  keymaps["p"] = function()
    sync_state(state)
    if state.filepath and state.filepath ~= "" then
      M.preview_xlsx(state.filepath)
    else
      notify_error("Enter a file path first.")
    end
  end

  -- OS file picker
  keymaps["<A-o>"] = function()
    open_file_picker(function(filepath)
      if filepath then
        sync_state(state)
        state.filepath = filepath
        load_sheets(state)
        if state.sheet_name then
          load_preview(state)
        end
        show_wizard(state)
      end
    end)
  end

  -- Create the float
  current_float = UiFloat.create(nil, {
    title = " Import Excel ",
    title_pos = "center",
    footer = " ? = Help ",
    border = "rounded",
    width = 68,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
    content_builder = cb,
    scrollbar = true,
  })
end

---Run the import wizard
---@param filepath string? Optional pre-selected file path
function M.import_wizard(filepath)
  if not has_xlsx() then
    notify_error("nvim-xlsx plugin is required for Excel import. Please install it.")
    return
  end

  ---@type ImportState
  local state = {
    filepath = filepath and vim.fn.expand(filepath) or nil,
    sheet_options = {},
    server_options = build_server_options(),
    database_options = {},
    headers = "yes",
    mode = "create_insert",
  }

  -- Pre-populate if filepath provided
  if state.filepath and vim.fn.filereadable(state.filepath) == 1 then
    load_sheets(state)
    if state.sheet_name then
      load_preview(state)
    end
  end

  -- Pre-populate server/database
  if #state.server_options > 0 then
    state.server_name = state.server_options[1].value
    load_databases(state)
  end

  show_wizard(state)
end

-- ============================================================================
-- Excel Preview (standalone, result_table based)
-- ============================================================================

---Show a standalone data preview for an Excel file
---@param filepath string? Optional file path
function M.preview_xlsx(filepath)
  if not has_xlsx() then
    notify_error("nvim-xlsx plugin is required. Please install it.")
    return
  end

  ---@param fpath string
  ---@param sheet_name string?
  local function show_preview(fpath, sheet_name)
    local XlsxReader = require("nvim-ssns.etl.xlsx_reader")

    -- Get file info for sheet list
    local info_ok, info = pcall(XlsxReader.info, fpath)
    if not info_ok or not info then
      notify_error("Failed to read file: " .. tostring(info))
      return
    end

    -- Pick sheet
    local target_sheet = sheet_name or (info.sheets[1] and info.sheets[1].name)
    if not target_sheet then
      notify_error("No sheets found in file.")
      return
    end

    -- Read data
    local ok, result = pcall(XlsxReader.read, fpath, {
      sheet = target_sheet,
      headers = true,
      max_rows = 100,
    })

    if not ok or not result then
      notify_error("Failed to read sheet: " .. tostring(result))
      return
    end

    -- Build styled content
    local cb = ContentBuilder.new()

    cb:blank()
    cb:header("  " .. vim.fn.fnamemodify(fpath, ":t"))
    cb:blank()

    -- File info
    cb:label_value("  Sheet", target_sheet, { label_style = "muted", value_style = "string" })
    cb:label_value("  Rows", tostring(result.row_count) .. (result.row_count >= 100 and "+" or ""), { label_style = "muted", value_style = "number" })
    cb:label_value("  Columns", tostring(#result.columns), { label_style = "muted", value_style = "number" })

    if info.sheet_count > 1 then
      local sheet_names = {}
      for _, s in ipairs(info.sheets) do table.insert(sheet_names, s.name) end
      cb:label_value("  Sheets", table.concat(sheet_names, ", "), { label_style = "muted", value_style = "muted" })
    end

    cb:blank()

    -- Build result table
    if #result.columns > 0 and #result.rows > 0 then
      -- Calculate column widths
      local col_defs = {}
      for _, col in ipairs(result.columns) do
        local max_w = math.max(#col.name, 6)
        for i = 1, math.min(20, #result.rows) do
          local val = result.rows[i][col.name]
          if val ~= nil then
            max_w = math.max(max_w, math.min(25, #tostring(val)))
          end
        end
        table.insert(col_defs, { name = col.name, width = max_w })
      end

      local row_num_width = math.max(2, #tostring(#result.rows))

      cb:begin_result_table()
      cb:result_top_border_with_rownum(col_defs, "ascii", row_num_width)
      cb:result_header_row_with_rownum(col_defs, "ascii", row_num_width)
      cb:result_separator_with_rownum(col_defs, "ascii", row_num_width)

      for i, row in ipairs(result.rows) do
        local cell_lines = {}
        for ci, col in ipairs(result.columns) do
          local val = row[col.name]
          local is_null = val == nil or val == vim.NIL
          local display = is_null and "NULL" or tostring(val)
          table.insert(cell_lines, {
            lines = { display },
            width = col_defs[ci].width,
            datatype = type_to_datatype(col.type),
            is_null = is_null,
          })
        end
        cb:result_multiline_data_row(cell_lines, "datatype", "ascii", true, i, row_num_width)
      end

      cb:result_bottom_border_with_rownum(col_defs, "ascii", row_num_width)
    else
      cb:styled("  (no data)", "muted")
    end

    cb:blank()

    -- Controls
    local controls_parts = {
      { text = "  " },
      { text = "q/Esc", style = "key" },
      { text = " Close", style = "muted" },
    }
    if info.sheet_count > 1 then
      table.insert(controls_parts, { text = "   " })
      table.insert(controls_parts, { text = "s", style = "key" })
      table.insert(controls_parts, { text = " Switch sheet", style = "muted" })
    end
    cb:spans(controls_parts)
    cb:blank()

    -- Create float
    local preview_keymaps = {}

    preview_keymaps["q"] = function()
      -- will be set with the window reference below
    end
    preview_keymaps["<Esc>"] = preview_keymaps["q"]

    if info.sheet_count > 1 then
      preview_keymaps["s"] = function()
        -- Close and show sheet picker
        local sheet_items = {}
        for _, s in ipairs(info.sheets) do
          table.insert(sheet_items, s.name .. " (" .. (s.dimension or "empty") .. ")")
        end
        vim.ui.select(sheet_items, { prompt = "Select sheet:" }, function(_, idx)
          if idx then
            show_preview(fpath, info.sheets[idx].name)
          end
        end)
      end
    end

    -- Calculate window width from content
    local total_width = 4 -- borders + padding
    if #result.columns > 0 then
      local row_num_width = math.max(2, #tostring(#result.rows))
      total_width = total_width + row_num_width + 3
      for _, col in ipairs(result.columns) do
        local max_w = math.max(#col.name, 6)
        for i = 1, math.min(20, #result.rows) do
          local val = result.rows[i][col.name]
          if val ~= nil then
            max_w = math.max(max_w, math.min(25, #tostring(val)))
          end
        end
        total_width = total_width + max_w + 3
      end
    end
    total_width = math.max(50, math.min(total_width, vim.o.columns - 4))

    local win = UiFloat.create(nil, {
      title = " Excel Preview ",
      title_pos = "center",
      border = "rounded",
      width = total_width,
      max_height = math.min(50, vim.o.lines - 4),
      centered = true,
      default_keymaps = false,
      content_builder = cb,
      scrollbar = true,
      keymaps = preview_keymaps,
    })

    -- Wire up close keymaps with actual window reference
    if win then
      local close_fn = function()
        if win:is_valid() then win:close() end
      end
      vim.keymap.set("n", "q", close_fn, { buffer = win.bufnr, nowait = true })
      vim.keymap.set("n", "<Esc>", close_fn, { buffer = win.bufnr, nowait = true })

      if info.sheet_count > 1 then
        vim.keymap.set("n", "s", function()
          if win:is_valid() then win:close() end
          local sheet_items = {}
          for _, s in ipairs(info.sheets) do
            table.insert(sheet_items, s.name .. " (" .. (s.dimension or "empty") .. ")")
          end
          vim.ui.select(sheet_items, { prompt = "Select sheet:" }, function(_, idx)
            if idx then
              show_preview(fpath, info.sheets[idx].name)
            end
          end)
        end, { buffer = win.bufnr, nowait = true })
      end
    end
  end

  -- Entry point: determine filepath
  if filepath then
    local fpath = vim.fn.expand(filepath)
    if vim.fn.filereadable(fpath) == 0 then
      notify_error("File not found: " .. fpath)
      return
    end
    show_preview(fpath)
  else
    -- Use OS file picker on Windows, fallback to vim.ui.input
    if vim.fn.has("win32") == 1 then
      open_file_picker(function(fpath)
        if fpath and vim.fn.filereadable(fpath) == 1 then
          show_preview(fpath)
        elseif fpath then
          notify_error("File not found: " .. fpath)
        end
      end)
    else
      vim.ui.input({
        prompt = "Excel file to preview: ",
        completion = "file",
      }, function(input)
        if not input or input == "" then return end
        local fpath = vim.fn.expand(input)
        if vim.fn.filereadable(fpath) == 0 then
          notify_error("File not found: " .. fpath)
          return
        end
        show_preview(fpath)
      end)
    end
  end
end

-- ============================================================================
-- Command Registration
-- ============================================================================

---Register import commands
function M.register()
  vim.api.nvim_create_user_command("SSNSImportXlsx", function(opts)
    M.import_wizard(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Import Excel file into database (wizard)",
    complete = "file",
  })

  vim.api.nvim_create_user_command("SSNSPreviewXlsx", function(opts)
    M.preview_xlsx(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Preview Excel file contents",
    complete = "file",
  })
end

return M
