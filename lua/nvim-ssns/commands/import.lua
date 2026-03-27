---@class SsnsImportCommands
---Import wizard for Excel files into database tables
local M = {}

---@class ImportWizardState
---@field filepath string? Excel file path
---@field sheet_name string? Selected sheet
---@field sheet_info table? Sheet metadata from xlsx.info()
---@field preview_data XlsxReadResult? Preview result from xlsx_reader
---@field columns table[]? Column definitions with mapping
---@field server_name string? Target server nickname
---@field database_name string? Target database
---@field table_name string? Target table name
---@field mode string? Import mode: "create_insert"|"insert"|"truncate_insert"

---Show an error notification
---@param msg string
local function notify_error(msg)
  vim.notify("[SSNS Import] " .. msg, vim.log.levels.ERROR)
end

---Show an info notification
---@param msg string
local function notify_info(msg)
  vim.notify("[SSNS Import] " .. msg, vim.log.levels.INFO)
end

---Check if nvim-xlsx is available
---@return boolean
local function has_xlsx()
  local ok = pcall(require, "nvim-xlsx")
  return ok
end

---Step 1: Prompt for Excel file path
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_select_file(state, callback)
  local default = state.filepath or ""
  vim.ui.input({
    prompt = "Excel file path: ",
    default = default,
    completion = "file",
  }, function(input)
    if not input or input == "" then
      notify_info("Import cancelled.")
      return
    end

    -- Expand ~ and environment variables
    local filepath = vim.fn.expand(input)

    -- Validate file exists
    if vim.fn.filereadable(filepath) == 0 then
      notify_error("File not found: " .. filepath)
      return
    end

    -- Validate extension
    if not filepath:match("%.xlsx$") then
      notify_error("Only .xlsx files are supported.")
      return
    end

    state.filepath = filepath
    callback(state)
  end)
end

---Step 2: Select sheet from the workbook
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_select_sheet(state, callback)
  local XlsxReader = require("nvim-ssns.etl.xlsx_reader")
  local info, err = XlsxReader.info(state.filepath)
  if not info then
    notify_error("Failed to read Excel file: " .. (err or "unknown error"))
    return
  end

  state.sheet_info = info

  if info.sheet_count == 1 then
    -- Only one sheet, auto-select
    state.sheet_name = info.sheets[1].name
    callback(state)
    return
  end

  -- Build display items
  local items = {}
  for _, sheet in ipairs(info.sheets) do
    table.insert(items, string.format("%s (%s)", sheet.name, sheet.dimension or "empty"))
  end

  vim.ui.select(items, {
    prompt = "Select sheet:",
    format_item = function(item) return item end,
  }, function(choice, idx)
    if not choice then
      notify_info("Import cancelled.")
      return
    end
    state.sheet_name = info.sheets[idx].name
    callback(state)
  end)
end

---Step 3: Preview data and show column info
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_preview(state, callback)
  local XlsxReader = require("nvim-ssns.etl.xlsx_reader")

  -- Read first 20 rows for preview
  local ok, result = pcall(XlsxReader.read, state.filepath, {
    sheet = state.sheet_name,
    headers = true,
    max_rows = 20,
  })

  if not ok then
    notify_error("Failed to read sheet: " .. tostring(result))
    return
  end

  state.preview_data = result
  state.columns = result.columns

  -- Show preview in floating window
  local ContentBuilder = require("nvim-float.content")
  local cb = ContentBuilder.new()

  cb:header("Excel Import Preview")
  cb:separator("─", 70)
  cb:spans({
    { text = "  File: ", style = "muted" },
    { text = vim.fn.fnamemodify(state.filepath, ":t"), style = "string" },
  })
  cb:spans({
    { text = "  Sheet: ", style = "muted" },
    { text = state.sheet_name, style = "string" },
  })
  cb:spans({
    { text = "  Rows: ", style = "muted" },
    { text = tostring(result.row_count) .. (result.row_count >= 20 and "+" or ""), style = "number" },
    { text = "  Columns: ", style = "muted" },
    { text = tostring(#result.columns), style = "number" },
  })
  cb:blank()

  -- Column table
  cb:section("Columns")
  cb:separator("─", 70)
  cb:spans({
    { text = "  " .. string.format("%-4s %-30s %-10s", "#", "Name", "Type"), style = "keyword" },
  })
  cb:separator("─", 70)

  for _, col in ipairs(result.columns) do
    cb:spans({
      { text = "  " .. string.format("%-4d ", col.index), style = "number" },
      { text = string.format("%-30s ", col.name), style = "identifier" },
      { text = string.format("%-10s", col.type), style = "muted" },
    })
  end

  cb:blank()

  -- Data preview
  if #result.rows > 0 then
    cb:section("Data Preview (first " .. math.min(5, #result.rows) .. " rows)")
    cb:separator("─", 70)

    for i = 1, math.min(5, #result.rows) do
      local row = result.rows[i]
      local parts = {}
      for _, col in ipairs(result.columns) do
        local val = row[col.name]
        local display = val ~= nil and tostring(val) or "NULL"
        if #display > 20 then display = display:sub(1, 17) .. "..." end
        table.insert(parts, display)
      end
      cb:styled("  " .. table.concat(parts, " | "), i % 2 == 0 and "muted" or nil)
    end
  end

  cb:blank()
  cb:styled("  Press ENTER to continue, q to cancel", "comment")

  local Float = require("nvim-float.window")
  local win = Float.create_styled(cb, {
    title = " Import Preview ",
    min_width = 75,
    max_height = 40,
    center = true,
    focusable = true,
    footer = "Enter: continue | q: cancel",
  })

  if win then
    vim.keymap.set("n", "q", function()
      win:close()
      notify_info("Import cancelled.")
    end, { buffer = win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      win:close()
      notify_info("Import cancelled.")
    end, { buffer = win.buf, nowait = true })

    vim.keymap.set("n", "<CR>", function()
      win:close()
      callback(state)
    end, { buffer = win.buf, nowait = true })
  end
end

---Step 4: Select target server
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_select_server(state, callback)
  local Cache = require("nvim-ssns.cache")
  local servers = Cache.get_all_servers()

  if not servers or #servers == 0 then
    notify_error("No servers configured. Add a server connection first.")
    return
  end

  local items = {}
  for _, server in ipairs(servers) do
    table.insert(items, server.name)
  end

  if #items == 1 then
    state.server_name = items[1]
    callback(state)
    return
  end

  vim.ui.select(items, {
    prompt = "Select target server:",
  }, function(choice)
    if not choice then
      notify_info("Import cancelled.")
      return
    end
    state.server_name = choice
    callback(state)
  end)
end

---Step 5: Select target database
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_select_database(state, callback)
  local Cache = require("nvim-ssns.cache")
  local server = Cache.find_server(state.server_name)

  if not server then
    notify_error("Server not found: " .. state.server_name)
    return
  end

  local databases = server:get_databases()
  if not databases or #databases == 0 then
    -- No databases loaded, prompt manually
    vim.ui.input({
      prompt = "Database name: ",
    }, function(input)
      if not input or input == "" then
        notify_info("Import cancelled.")
        return
      end
      state.database_name = input
      callback(state)
    end)
    return
  end

  local items = {}
  for _, db in ipairs(databases) do
    table.insert(items, db.name)
  end

  vim.ui.select(items, {
    prompt = "Select target database:",
  }, function(choice)
    if not choice then
      notify_info("Import cancelled.")
      return
    end
    state.database_name = choice
    callback(state)
  end)
end

---Step 6: Enter target table name and import mode
---@param state ImportWizardState
---@param callback fun(state: ImportWizardState)
local function step_table_and_mode(state, callback)
  -- Suggest table name based on sheet name
  local suggested = state.sheet_name:gsub('[%s%p]', '_'):gsub('_+', '_')

  vim.ui.input({
    prompt = "Target table name (schema.table): ",
    default = "dbo." .. suggested,
  }, function(input)
    if not input or input == "" then
      notify_info("Import cancelled.")
      return
    end
    state.table_name = input

    -- Select import mode
    local modes = {
      { label = "Create table & insert", value = "create_insert" },
      { label = "Insert into existing table", value = "insert" },
      { label = "Truncate & insert", value = "truncate_insert" },
    }

    vim.ui.select(modes, {
      prompt = "Import mode:",
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then
        notify_info("Import cancelled.")
        return
      end
      state.mode = choice.value
      callback(state)
    end)
  end)
end

---Map import mode to ETL mode directive value
---@param mode string
---@return string etl_mode
local function mode_to_etl_mode(mode)
  if mode == "truncate_insert" then
    return "truncate_insert"
  end
  return "insert"
end

---Generate .ssns script content from wizard state
---@param state ImportWizardState
---@return string script_content
local function generate_ssns_script(state)
  local lines = {}

  -- Normalize filepath for use in Lua string (escape backslashes)
  local escaped_path = state.filepath:gsub("\\", "/")

  -- Variables
  table.insert(lines, "--@var xlsx_file = " .. escaped_path)
  table.insert(lines, "--@var xlsx_sheet = " .. state.sheet_name)
  table.insert(lines, "")

  -- Lua block to read Excel
  table.insert(lines, "--@lua read_excel")
  table.insert(lines, "--@description Import from " .. vim.fn.fnamemodify(state.filepath, ":t") .. " (" .. state.sheet_name .. ")")
  table.insert(lines, "local result = read_xlsx(var('xlsx_file'), {")
  table.insert(lines, "  sheet = var('xlsx_sheet'),")
  table.insert(lines, "  headers = true,")
  table.insert(lines, "})")

  -- Check if column mapping is needed (names differ from originals)
  local needs_mapping = false
  if state.columns then
    for _, col in ipairs(state.columns) do
      if col.original_name and col.original_name ~= col.name then
        needs_mapping = true
        break
      end
    end
  end

  if needs_mapping and state.columns then
    table.insert(lines, "")
    table.insert(lines, "-- Column mapping")
    table.insert(lines, "local mapped = {}")
    table.insert(lines, "for _, row in ipairs(result.rows) do")
    table.insert(lines, "  table.insert(mapped, {")
    for _, col in ipairs(state.columns) do
      local src = col.original_name or col.name
      table.insert(lines, string.format('    %s = row["%s"],', col.name, src))
    end
    table.insert(lines, "  })")
    table.insert(lines, "end")
    table.insert(lines, "return data(mapped)")
  else
    table.insert(lines, "return data(result.rows)")
  end

  table.insert(lines, "")

  -- SQL block to insert data
  if state.mode == "create_insert" then
    -- For create_insert, generate a CREATE TABLE block first
    table.insert(lines, "--@block create_table")
    table.insert(lines, "--@server " .. state.server_name)
    table.insert(lines, "--@database " .. state.database_name)
    table.insert(lines, "--@description Create target table")
    table.insert(lines, "--@continue_on_error")

    -- Build CREATE TABLE from inferred types
    local col_defs = {}
    if state.columns then
      for _, col in ipairs(state.columns) do
        local sql_type = "NVARCHAR(255)"
        if col.type == "number" then
          sql_type = "FLOAT"
        elseif col.type == "boolean" then
          sql_type = "BIT"
        elseif col.type == "date" then
          sql_type = "DATETIME"
        end
        table.insert(col_defs, string.format("  [%s] %s NULL", col.name, sql_type))
      end
    end

    table.insert(lines, "CREATE TABLE " .. state.table_name .. " (")
    table.insert(lines, table.concat(col_defs, ",\n"))
    table.insert(lines, ")")
    table.insert(lines, "")
  end

  -- Insert block
  table.insert(lines, "--@block import_data")
  table.insert(lines, "--@server " .. state.server_name)
  table.insert(lines, "--@database " .. state.database_name)
  table.insert(lines, "--@input read_excel")
  table.insert(lines, "--@mode " .. mode_to_etl_mode(state.mode))
  table.insert(lines, "--@target " .. state.table_name)
  table.insert(lines, "--@description Insert Excel data into " .. state.table_name)
  table.insert(lines, "SELECT * FROM @input")

  return table.concat(lines, "\n")
end

---Step 7: Generate script and show in buffer or execute
---@param state ImportWizardState
local function step_generate(state)
  local script = generate_ssns_script(state)

  vim.ui.select({
    "Open in new buffer (review & edit before running)",
    "Execute immediately",
  }, {
    prompt = "Output:",
  }, function(_, idx)
    if not idx then
      notify_info("Import cancelled.")
      return
    end

    if idx == 1 then
      -- Open in new buffer
      vim.cmd("enew")
      local buf = vim.api.nvim_get_current_buf()
      vim.bo[buf].filetype = "ssns"
      vim.bo[buf].buftype = ""

      -- Set a suggested filename
      local suggested_name = vim.fn.fnamemodify(state.filepath, ":t:r") .. "_import.ssns"
      vim.api.nvim_buf_set_name(buf, suggested_name)

      local lines = vim.split(script, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      notify_info("Import script generated. Review and run with :SSNSEtl")
    else
      -- Execute immediately
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
  end)
end

---Run the full import wizard
---@param filepath string? Optional pre-selected file path
function M.import_wizard(filepath)
  if not has_xlsx() then
    notify_error("nvim-xlsx plugin is required for Excel import. Please install it.")
    return
  end

  ---@type ImportWizardState
  local state = {
    filepath = filepath,
  }

  -- Chain wizard steps
  local function after_table(s) step_generate(s) end
  local function after_database(s) step_table_and_mode(s, after_table) end
  local function after_server(s) step_select_database(s, after_database) end
  local function after_preview(s) step_select_server(s, after_server) end
  local function after_sheet(s) step_preview(s, after_preview) end
  local function after_file(s) step_select_sheet(s, after_sheet) end

  if filepath then
    -- Skip file selection if already provided
    state.filepath = vim.fn.expand(filepath)
    if vim.fn.filereadable(state.filepath) == 0 then
      notify_error("File not found: " .. state.filepath)
      return
    end
    step_select_sheet(state, after_sheet)
  else
    step_select_file(state, after_file)
  end
end

---Preview an Excel file's contents in a floating window
---@param filepath string? Optional file path
function M.preview_xlsx(filepath)
  if not has_xlsx() then
    notify_error("nvim-xlsx plugin is required. Please install it.")
    return
  end

  local function show_preview(fpath)
    local XlsxReader = require("nvim-ssns.etl.xlsx_reader")

    -- Get file info
    local info_ok, info = pcall(XlsxReader.info, fpath)
    if not info_ok then
      notify_error("Failed to read file: " .. tostring(info))
      return
    end

    -- If multiple sheets, let user pick
    local function preview_sheet(sheet_name)
      local ok, result = pcall(XlsxReader.read, fpath, {
        sheet = sheet_name,
        headers = true,
        max_rows = 50,
      })

      if not ok then
        notify_error("Failed to read sheet: " .. tostring(result))
        return
      end

      local ContentBuilder = require("nvim-float.content")
      local cb = ContentBuilder.new()

      cb:header("Excel Preview: " .. vim.fn.fnamemodify(fpath, ":t"))
      cb:separator("═", 80)
      cb:spans({
        { text = "  Sheet: ", style = "muted" },
        { text = sheet_name, style = "string" },
        { text = "  |  Rows: ", style = "muted" },
        { text = tostring(result.row_count) .. (result.row_count >= 50 and "+" or ""), style = "number" },
        { text = "  |  Columns: ", style = "muted" },
        { text = tostring(#result.columns), style = "number" },
      })
      cb:separator("─", 80)
      cb:blank()

      -- Column headers
      local col_widths = {}
      for _, col in ipairs(result.columns) do
        col_widths[col.name] = math.max(#col.name, 8)
        -- Scan data for width
        for i = 1, math.min(10, #result.rows) do
          local val = result.rows[i][col.name]
          if val ~= nil then
            col_widths[col.name] = math.min(25, math.max(col_widths[col.name], #tostring(val)))
          end
        end
      end

      -- Header row
      local header_parts = {}
      for _, col in ipairs(result.columns) do
        local w = col_widths[col.name]
        table.insert(header_parts, { text = string.format(" %-" .. w .. "s ", col.name), style = "keyword" })
        table.insert(header_parts, { text = "│", style = "muted" })
      end
      cb:spans(header_parts)
      cb:separator("─", 80)

      -- Data rows
      for i, row in ipairs(result.rows) do
        local parts = {}
        for _, col in ipairs(result.columns) do
          local w = col_widths[col.name]
          local val = row[col.name]
          local display = val ~= nil and tostring(val) or "NULL"
          if #display > w then display = display:sub(1, w - 3) .. "..." end

          local style = nil
          if val == nil then
            style = "comment"
          elseif col.type == "number" then
            style = "number"
          elseif col.type == "date" then
            style = "string"
          elseif col.type == "boolean" then
            style = "keyword"
          end

          table.insert(parts, { text = string.format(" %-" .. w .. "s ", display), style = style })
          table.insert(parts, { text = "│", style = "muted" })
        end
        cb:spans(parts)

        if i % 2 == 0 then
          -- Visual separator every few rows for readability
        end
      end

      cb:blank()
      cb:styled("  q: close | s: switch sheet", "comment")

      local Float = require("nvim-float.window")
      local win = Float.create_styled(cb, {
        title = " Excel Preview ",
        min_width = 80,
        max_height = 50,
        center = true,
        focusable = true,
        footer = "q: close | s: switch sheet",
      })

      if win then
        vim.keymap.set("n", "q", function() win:close() end, { buffer = win.buf, nowait = true })
        vim.keymap.set("n", "<Esc>", function() win:close() end, { buffer = win.buf, nowait = true })

        -- Switch sheet
        if info.sheet_count > 1 then
          vim.keymap.set("n", "s", function()
            win:close()
            local sheet_items = {}
            for _, s in ipairs(info.sheets) do
              table.insert(sheet_items, s.name .. " (" .. (s.dimension or "empty") .. ")")
            end
            vim.ui.select(sheet_items, { prompt = "Select sheet:" }, function(_, idx)
              if idx then
                preview_sheet(info.sheets[idx].name)
              end
            end)
          end, { buffer = win.buf, nowait = true })
        end
      end
    end

    -- Start with first sheet or let user pick
    if info.sheet_count == 1 then
      preview_sheet(info.sheets[1].name)
    else
      local items = {}
      for _, s in ipairs(info.sheets) do
        table.insert(items, s.name .. " (" .. (s.dimension or "empty") .. ")")
      end
      vim.ui.select(items, { prompt = "Select sheet to preview:" }, function(_, idx)
        if idx then
          preview_sheet(info.sheets[idx].name)
        end
      end)
    end
  end

  if filepath then
    local fpath = vim.fn.expand(filepath)
    if vim.fn.filereadable(fpath) == 0 then
      notify_error("File not found: " .. fpath)
      return
    end
    show_preview(fpath)
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
