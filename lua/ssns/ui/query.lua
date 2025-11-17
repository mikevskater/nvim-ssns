---@class UiQuery
---Query buffer management for SSNS
local UiQuery = {}

---Track query buffers
---@type table<number, {server: ServerClass, database: DbClass?}>
UiQuery.query_buffers = {}

---Track buffer counter for unique names
---@type table<string, number>
UiQuery.buffer_counter = {}

---Generate a unique buffer name
---@param object_name string? The object name (table, view, etc.)
---@param server ServerClass? The server
---@param database DbClass? The database
---@return string buffer_name
function UiQuery.generate_buffer_name(object_name, server, database)
  local base_name = object_name or "query"

  -- Initialize counter for this base name if needed
  if not UiQuery.buffer_counter[base_name] then
    UiQuery.buffer_counter[base_name] = 0
  end

  -- Increment counter
  UiQuery.buffer_counter[base_name] = UiQuery.buffer_counter[base_name] + 1
  local count = UiQuery.buffer_counter[base_name]

  -- Generate unique name
  local buf_name = string.format("[%s-%d]", base_name, count)

  return buf_name
end

---Prepend USE statement for SQL Server databases
---@param sql string The SQL to prepend USE statement to
---@param server ServerClass? The server
---@param database DbClass? The database
---@return string sql SQL with USE statement prepended if applicable
function UiQuery.prepend_use_statement(sql, server, database)
  -- Only add USE statement for SQL Server and if database is specified
  if not server or not database then
    return sql
  end

  local adapter = server:get_adapter()
  if not adapter or adapter.db_type ~= "sqlserver" then
    return sql
  end

  -- Prepend USE [database];
  return string.format("USE [%s];\n\n%s", database.db_name, sql)
end

---Find or create a window for query buffers (not the SSNS tree window)
---@return number winid
function UiQuery.focus_query_window()
  local ssns_buffer = require('ssns.ui.buffer')

  -- Look for an existing query buffer window (not SSNS tree, not special buffers)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')

    -- Skip SSNS tree window
    if bufnr == ssns_buffer.bufnr then
      goto continue
    end

    -- Skip special buffers (nofile, help, etc.)
    if buftype ~= '' and buftype ~= 'acwrite' then
      goto continue
    end

    -- Found a suitable window (normal buffer or query buffer)
    if modifiable then
      vim.api.nvim_set_current_win(win)
      return win
    end

    ::continue::
  end

  -- No suitable window found, create new one
  -- Determine position based on SSNS tree position
  local Config = require('ssns.config')
  local ui_config = Config.get_ui()
  local win_pos = ui_config.position == 'left' and 'botright' or 'topleft'

  vim.cmd(win_pos .. ' new')
  return vim.api.nvim_get_current_win()
end

---Create a new query buffer with optional SQL
---@param server ServerClass? The server to associate with this query
---@param database DbClass? The database to associate with this query
---@param sql string? Optional SQL to populate the buffer
---@param object_name string? The object name for the buffer title
---@return number bufnr The buffer number
function UiQuery.create_query_buffer(server, database, sql, object_name)
  -- Focus or create query window
  UiQuery.focus_query_window()

  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(true, false)

  -- Generate unique buffer name
  local buf_name = UiQuery.generate_buffer_name(object_name, server, database)
  vim.api.nvim_buf_set_name(bufnr, buf_name)

  -- Set filetype to sql for syntax highlighting
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'sql')
  vim.api.nvim_buf_set_option(bufnr, 'buftype', '')

  -- Enable line numbers
  vim.api.nvim_buf_set_option(bufnr, 'buflisted', true)

  -- Track this buffer
  UiQuery.query_buffers[bufnr] = {
    server = server,
    database = database,
  }

  -- Set buffer-local keymaps
  UiQuery.setup_query_keymaps(bufnr)

  -- If SQL provided, prepend USE statement and set it in the buffer
  if sql then
    local final_sql = UiQuery.prepend_use_statement(sql, server, database)
    local lines = vim.split(final_sql, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  -- Switch to the new buffer in the current window
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Set modifiable
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)

  -- Enable line numbers in this window
  vim.api.nvim_win_set_option(0, 'number', true)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)

  return bufnr
end

---Setup keymaps for query buffer
---@param bufnr number The buffer number
function UiQuery.setup_query_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Execute query (visual selection or entire buffer)
  vim.keymap.set('n', '<Leader>r', function()
    UiQuery.execute_query(bufnr, false)
  end, vim.tbl_extend('force', opts, { desc = 'Execute query' }))

  vim.keymap.set('v', '<Leader>r', function()
    UiQuery.execute_query(bufnr, true)
  end, vim.tbl_extend('force', opts, { desc = 'Execute selected query' }))

  -- Execute query under cursor
  vim.keymap.set('n', '<Leader>R', function()
    UiQuery.execute_statement_under_cursor(bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Execute statement under cursor' }))

  -- Save query
  vim.keymap.set('n', '<Leader>s', function()
    UiQuery.save_query(bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Save query' }))
end

---Execute query in buffer
---@param bufnr number The buffer number
---@param visual boolean Whether to execute visual selection
function UiQuery.execute_query(bufnr, visual)
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info then
    vim.notify("SSNS: Not a query buffer", vim.log.levels.ERROR)
    return
  end

  local server = buffer_info.server
  if not server then
    vim.notify("SSNS: No server associated with this query buffer", vim.log.levels.ERROR)
    return
  end

  if not server:is_connected() then
    vim.notify("SSNS: Server is not connected", vim.log.levels.ERROR)
    return
  end

  -- Get SQL to execute
  local sql
  if visual then
    -- Get visual selection
    local start_line = vim.fn.line("'<") - 1
    local end_line = vim.fn.line("'>")
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    sql = table.concat(lines, "\n")
  else
    -- Get entire buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    sql = table.concat(lines, "\n")
  end

  -- Trim whitespace
  sql = sql:match("^%s*(.-)%s*$")

  if sql == "" then
    vim.notify("SSNS: No SQL to execute", vim.log.levels.WARN)
    return
  end

  -- Execute query
  vim.notify("SSNS: Executing query...", vim.log.levels.INFO)

  local adapter = server:get_adapter()
  local start_time = vim.loop.hrtime()
  local result = adapter:execute(server.connection, sql)
  local end_time = vim.loop.hrtime()
  local execution_time_ms = (end_time - start_time) / 1000000  -- Convert nanoseconds to milliseconds

  -- Check if query succeeded
  if not result.success then
    -- Display detailed error with structured information
    UiQuery.display_error(result.error, sql, bufnr)
    return
  end

  -- Display results with execution metadata
  UiQuery.display_results(result, sql, execution_time_ms)
end

---Execute statement under cursor
---@param bufnr number The buffer number
function UiQuery.execute_statement_under_cursor(bufnr)
  -- Find the SQL statement under cursor
  -- For now, just execute the current line
  -- TODO: Implement proper statement detection (find ; or GO boundaries)
  local cursor_line = vim.fn.line('.') - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, cursor_line, cursor_line + 1, false)

  if #lines == 0 then
    vim.notify("SSNS: No statement under cursor", vim.log.levels.WARN)
    return
  end

  local sql = lines[1]:match("^%s*(.-)%s*$")

  if sql == "" then
    vim.notify("SSNS: No SQL to execute", vim.log.levels.WARN)
    return
  end

  -- For now, just execute this line
  -- TODO: Expand to full statement
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info or not buffer_info.server then
    vim.notify("SSNS: No server associated with this query buffer", vim.log.levels.ERROR)
    return
  end

  local server = buffer_info.server
  local adapter = server:get_adapter()
  local result = adapter:execute(server.connection, sql)

  if not result.success then
    UiQuery.display_error(result.error, sql, bufnr)
    return
  end

  UiQuery.display_results(result, sql)
end

---Display query results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@param sql string The SQL that was executed
---@param execution_time_ms number? Execution time in milliseconds
function UiQuery.display_results(result, sql, execution_time_ms)
  -- Try to find existing results buffer
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match("SSNS Results") then
        result_buf = buf
        break
      end
    end
  end

  -- Create new buffer if not found
  if not result_buf then
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, "SSNS Results")
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
  end

  -- Format results from Node.js format
  local lines = UiQuery.format_results(result.resultSets, sql, execution_time_ms)

  -- Set lines in buffer
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', false)

  -- Check if buffer is already visible in a window
  local result_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == result_buf then
      result_win = win
      break
    end
  end

  -- If buffer is not visible, open it in a split
  if not result_win then
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, result_buf)
    result_win = vim.api.nvim_get_current_win()
  else
    -- If already visible, just focus it
    vim.api.nvim_set_current_win(result_win)
  end

  -- Setup close keymap
  vim.api.nvim_buf_set_keymap(result_buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
end

---Parse divider format string and generate lines
---@param format string Divider format (e.g., "20#", "10-\n10-", "5-(%row_count% rows)5-", "%fit%=")
---@param metadata table Metadata for variable replacement
---@return string[] lines Array of divider lines
function UiQuery.parse_divider_format(format, metadata)
  if not format or format == "" then
    return { "" }  -- Default: single blank line
  end

  -- Replace variables with metadata values (except %fit%)
  local processed = format
  for key, value in pairs(metadata) do
    processed = processed:gsub("%%" .. key .. "%%", tostring(value))
  end

  -- Split by \n for multiple lines
  -- Handle both actual newlines and escaped \n
  local parts = vim.split(processed, "\n", { plain = true })

  -- PASS 1: Generate lines with %fit% placeholder, track max width
  local lines = {}
  local max_width = 0
  local has_fit_pattern = false

  for _, part in ipairs(parts) do
    local line

    -- Check if this part contains %fit% pattern
    if part:match("%%fit%%") then
      has_fit_pattern = true
      -- Temporarily replace %fit% with empty string to calculate the base line
      local temp_part = part:gsub("%%fit%%", "")
      line = temp_part
    else
      -- Parse repeat patterns like "20#" or "10-"
      -- Pattern: <number><character(s)>
      local count, char = part:match("^(%d+)(.+)$")
      if count and char then
        -- Repeat pattern found
        line = string.rep(char, tonumber(count))
      else
        -- Raw string
        line = part
      end
    end

    table.insert(lines, line)

    -- Track maximum width
    if #line > max_width then
      max_width = #line
    end
  end

  -- PASS 2: If %fit% pattern exists, replace with max_width
  if has_fit_pattern then
    for i, part in ipairs(parts) do
      if part:match("%%fit%%") then
        -- Extract character after %fit%
        local char = part:match("%%fit%%(.)")
        if char then
          -- Replace %fit% with the max_width count
          lines[i] = part:gsub("%%fit%%", tostring(max_width))

          -- Now parse the repeat pattern
          local count_str, repeat_char = lines[i]:match("^(%d+)(.+)$")
          if count_str and repeat_char then
            lines[i] = string.rep(repeat_char, tonumber(count_str))
          end
        end
      end
    end
  end

  return lines
end

---Format query results for display
---@param results any The query results (can be array of result sets or single result set)
---@param sql string The SQL that was executed
---@param execution_time_ms number? Execution time in milliseconds
---@return string[] lines
function UiQuery.format_results(results, sql, execution_time_ms)
  local lines = {}

  -- Get current date/time
  local date_str = os.date("%Y-%m-%d")
  local time_str = os.date("%H:%M:%S")

  -- Check if results is a table
  if type(results) ~= "table" then
    table.insert(lines, tostring(results))
    return lines
  end

  -- Check if empty
  if #results == 0 then
    -- Return empty for no rows (silent like SSMS)
    return lines
  end

  -- Check if this is multiple result sets (array of arrays)
  -- If first element is an array of objects with string keys, it's a result set
  local is_multiple_sets = false
  if #results > 0 and type(results[1]) == "table" then
    -- Check if first element is an array (result set) or a row object
    local first_elem = results[1]
    if #first_elem > 0 and type(first_elem[1]) == "table" then
      -- It's an array of result sets
      is_multiple_sets = true
    elseif first_elem[1] == nil then
      -- Check if it has string keys (it's a row object)
      local has_string_keys = false
      for key, _ in pairs(first_elem) do
        if type(key) == "string" and key ~= "name" then
          has_string_keys = true
          break
        end
      end
      if not has_string_keys then
        -- Could be multiple result sets
        is_multiple_sets = true
      end
    end
  end

  -- Get config
  local Config = require('ssns.config')
  local ui_config = Config.get_ui()
  local divider_format = ui_config.result_set_divider or ""
  local show_result_set_info = ui_config.show_result_set_info or false

  -- Handle multiple result sets
  if is_multiple_sets then
    for i, result_set in ipairs(results) do
      if i > 1 or show_result_set_info then
        -- Build metadata for divider
        -- For first result set (i==1), use current result set metadata
        -- For subsequent sets, use previous result set metadata
        local target_result_set = (i == 1) and result_set or results[i - 1]
        local row_count = #target_result_set
        local col_count = 0
        if row_count > 0 then
          -- Count columns from first row (excluding 'name' helper field)
          for key, _ in pairs(target_result_set[1]) do
            if key ~= "name" or #target_result_set[1] == 1 then
              col_count = col_count + 1
            end
          end
        end

        -- Format execution time
        local run_time = ""
        if execution_time_ms then
          if execution_time_ms < 1000 then
            run_time = string.format("%.0fms", execution_time_ms)
          else
            run_time = string.format("%.2fs", execution_time_ms / 1000)
          end
        end

        local metadata = {
          row_count = row_count,
          col_count = col_count,
          result_set_num = i,
          total_result_sets = #results,
          run_time = run_time,
          date = date_str,
          time = time_str,
        }

        -- Add custom divider
        local divider_lines = UiQuery.parse_divider_format(divider_format, metadata)
        for _, divider_line in ipairs(divider_lines) do
          table.insert(lines, divider_line)
        end
      end

      -- Format this result set
      local set_lines = UiQuery.format_single_result_set(result_set)
      for _, line in ipairs(set_lines) do
        table.insert(lines, line)
      end
    end
    return lines
  end

  -- Single result set - show info if configured
  if show_result_set_info then
    local row_count = #results
    local col_count = 0
    if row_count > 0 then
      for key, _ in pairs(results[1]) do
        if key ~= "name" or #results[1] == 1 then
          col_count = col_count + 1
        end
      end
    end

    -- Format execution time
    local run_time = ""
    if execution_time_ms then
      if execution_time_ms < 1000 then
        run_time = string.format("%.0fms", execution_time_ms)
      else
        run_time = string.format("%.2fs", execution_time_ms / 1000)
      end
    end

    local metadata = {
      row_count = row_count,
      col_count = col_count,
      result_set_num = 1,
      total_result_sets = 1,
      run_time = run_time,
      date = date_str,
      time = time_str,
    }

    -- Add divider before single result set
    local divider_lines = UiQuery.parse_divider_format(divider_format, metadata)
    for _, divider_line in ipairs(divider_lines) do
      table.insert(lines, divider_line)
    end
  end

  -- Format single result set
  local set_lines = UiQuery.format_single_result_set(results)
  for _, line in ipairs(set_lines) do
    table.insert(lines, line)
  end

  return lines
end

---Format a single result set for display
---@param result_set table Array of row objects
---@return string[] lines
function UiQuery.format_single_result_set(result_set)
  local lines = {}

  if #result_set == 0 then
    return lines
  end

  -- Get column names from first row
  local first_row = result_set[1]
  local columns = {}
  for key, _ in pairs(first_row) do
    if key ~= "name" or #result_set[1] == 1 then
      table.insert(columns, key)
    end
  end
  table.sort(columns)

  -- Calculate column widths
  local widths = {}
  for _, col in ipairs(columns) do
    widths[col] = #tostring(col)
  end

  for _, row in ipairs(result_set) do
    for _, col in ipairs(columns) do
      local value = tostring(row[col] or "")
      -- Replace newlines with space for width calculation
      value = value:gsub("\n", " ")
      if #value > widths[col] then
        widths[col] = #value
      end
    end
  end

  -- Build header
  local header_parts = {}
  for _, col in ipairs(columns) do
    local padded = tostring(col) .. string.rep(" ", widths[col] - #tostring(col))
    table.insert(header_parts, padded)
  end
  table.insert(lines, table.concat(header_parts, " | "))

  -- Build separator
  local sep_parts = {}
  for _, col in ipairs(columns) do
    table.insert(sep_parts, string.rep("-", widths[col]))
  end
  table.insert(lines, table.concat(sep_parts, "-+-"))

  -- Build rows
  for _, row in ipairs(result_set) do
    local row_parts = {}
    for _, col in ipairs(columns) do
      local value = tostring(row[col] or "")
      -- Replace newlines with space for display
      value = value:gsub("\n", " ")
      local padded = value .. string.rep(" ", widths[col] - #value)
      table.insert(row_parts, padded)
    end
    table.insert(lines, table.concat(row_parts, " | "))
  end

  return lines
end

---Save query to file
---@param bufnr number The buffer number
function UiQuery.save_query(bufnr)
  -- Get buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local sql = table.concat(lines, "\n")

  -- Prompt for filename
  local filename = vim.fn.input("Save query as: ", "", "file")

  if filename == "" then
    return
  end

  -- Write to file
  local file = io.open(filename, "w")
  if not file then
    vim.notify(string.format("SSNS: Failed to save query to %s", filename), vim.log.levels.ERROR)
    return
  end

  file:write(sql)
  file:close()

  vim.notify(string.format("SSNS: Query saved to %s", filename), vim.log.levels.INFO)
end

---Check if buffer is a query buffer
---@param bufnr number The buffer number
---@return boolean
function UiQuery.is_query_buffer(bufnr)
  return UiQuery.query_buffers[bufnr] ~= nil
end

---Get server for query buffer
---@param bufnr number The buffer number
---@return ServerClass?
function UiQuery.get_server(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  return info and info.server
end

---Get database for query buffer
---@param bufnr number The buffer number
---@return DbClass?
function UiQuery.get_database(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  return info and info.database
end

return UiQuery
