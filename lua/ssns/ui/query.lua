---@class UiQuery
---Query buffer management for SSNS
local UiQuery = {}

---Track query buffers
---@type table<number, {server: ServerClass, database: DbClass?}>
UiQuery.query_buffers = {}

---Create a new query buffer with optional SQL
---@param server ServerClass? The server to associate with this query
---@param database DbClass? The database to associate with this query
---@param sql string? Optional SQL to populate the buffer
---@return number bufnr The buffer number
function UiQuery.create_query_buffer(server, database, sql)
  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(true, false)

  -- Set buffer name
  local buf_name = "SSNS Query"
  if server then
    buf_name = buf_name .. " - " .. server.name
    if database then
      buf_name = buf_name .. "." .. database.db_name
    end
  end
  vim.api.nvim_buf_set_name(bufnr, buf_name)

  -- Set filetype to sql for syntax highlighting
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'sql')
  vim.api.nvim_buf_set_option(bufnr, 'buftype', '')

  -- Track this buffer
  UiQuery.query_buffers[bufnr] = {
    server = server,
    database = database,
  }

  -- Set buffer-local keymaps
  UiQuery.setup_query_keymaps(bufnr)

  -- If SQL provided, set it in the buffer
  if sql then
    local lines = vim.split(sql, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  -- Open the buffer in a new window
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Set modifiable
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)

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
  local success, results = pcall(adapter.execute, adapter, server.connection, sql)

  if not success then
    vim.notify(string.format("SSNS: Query failed: %s", results), vim.log.levels.ERROR)
    return
  end

  -- Display results
  UiQuery.display_results(results, sql)
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
  local success, results = pcall(adapter.execute, adapter, server.connection, sql)

  if not success then
    vim.notify(string.format("SSNS: Query failed: %s", results), vim.log.levels.ERROR)
    return
  end

  UiQuery.display_results(results, sql)
end

---Display query results
---@param results any The query results
---@param sql string The SQL that was executed
function UiQuery.display_results(results, sql)
  -- Create a results buffer
  local result_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(result_buf, "SSNS Results")
  vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', false)

  -- Format results
  local lines = UiQuery.format_results(results, sql)

  -- Set lines in buffer
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', false)

  -- Open in horizontal split below
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, result_buf)

  -- Setup close keymap
  vim.api.nvim_buf_set_keymap(result_buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
end

---Format query results for display
---@param results any The query results
---@param sql string The SQL that was executed
---@return string[] lines
function UiQuery.format_results(results, sql)
  local lines = {
    "=== SSNS Query Results ===",
    "",
    "SQL:",
    sql,
    "",
    "Results:",
    "",
  }

  -- Check if results is a table
  if type(results) ~= "table" then
    table.insert(lines, tostring(results))
    return lines
  end

  -- Check if empty
  if #results == 0 then
    table.insert(lines, "(No rows returned)")
    return lines
  end

  -- Format as table
  -- Get column names from first row
  local first_row = results[1]
  local columns = {}
  for key, _ in pairs(first_row) do
    table.insert(columns, key)
  end
  table.sort(columns)

  -- Calculate column widths
  local widths = {}
  for _, col in ipairs(columns) do
    widths[col] = #col
  end

  for _, row in ipairs(results) do
    for _, col in ipairs(columns) do
      local value = tostring(row[col] or "")
      if #value > widths[col] then
        widths[col] = #value
      end
    end
  end

  -- Build header
  local header_parts = {}
  for _, col in ipairs(columns) do
    local padded = col .. string.rep(" ", widths[col] - #col)
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
  for _, row in ipairs(results) do
    local row_parts = {}
    for _, col in ipairs(columns) do
      local value = tostring(row[col] or "")
      local padded = value .. string.rep(" ", widths[col] - #value)
      table.insert(row_parts, padded)
    end
    table.insert(lines, table.concat(row_parts, " | "))
  end

  -- Add row count
  table.insert(lines, "")
  table.insert(lines, string.format("(%d row%s)", #results, #results == 1 and "" or "s"))

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
