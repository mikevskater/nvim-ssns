--- Testing utilities module
--- Helper functions for testing framework
local M = {}

--- Load test data from a .lua file
--- @param filepath string Absolute path to test file
--- @return table? test_data The test data table or nil on error
--- @return string? error Error message if loading failed
function M.load_test_file(filepath)
  -- Verify file exists
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return nil, string.format("Test file not found: %s", filepath)
  end

  -- Load the file as a Lua module
  local success, test_data = pcall(dofile, filepath)
  if not success then
    return nil, string.format("Failed to load test file %s: %s", filepath, test_data)
  end

  -- Validate test data structure
  if type(test_data) ~= "table" then
    return nil, string.format("Test file %s did not return a table", filepath)
  end

  -- Validate required fields
  local required_fields = { "number", "description", "database", "query", "cursor", "expected" }
  for _, field in ipairs(required_fields) do
    if test_data[field] == nil then
      return nil, string.format("Test file %s missing required field: %s", filepath, field)
    end
  end

  -- Validate cursor structure
  if type(test_data.cursor) ~= "table" or test_data.cursor.line == nil or test_data.cursor.col == nil then
    return nil, string.format("Test file %s has invalid cursor structure", filepath)
  end

  -- Validate expected structure
  if type(test_data.expected) ~= "table" or not test_data.expected.type or not test_data.expected.items then
    return nil, string.format("Test file %s has invalid expected structure", filepath)
  end

  return test_data, nil
end

--- Recursively scan test folders and return all test files
--- @param base_path string? Base path to scan (defaults to testing/tests)
--- @return table test_files Array of {path: string, category: string, database_type: string, name: string}
function M.scan_test_folders(base_path)
  base_path = base_path or (vim.fn.stdpath("data") .. "/ssns/lua/ssns/testing/tests")

  -- Ensure path exists
  local stat = vim.loop.fs_stat(base_path)
  if not stat or stat.type ~= "directory" then
    return {}
  end

  local test_files = {}

  -- Scan directory recursively with three levels: database_type / category / test_file
  local function scan_dir(dir_path, database_type, category)
    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir_path .. "/" .. name

      if type == "directory" then
        if not database_type then
          -- First level: database type folder (sqlserver, postgres, mysql, sqlite)
          scan_dir(full_path, name, nil)
        elseif not category then
          -- Second level: category folder (e.g., "01_schema_table_qualification")
          scan_dir(full_path, database_type, name)
        end
      elseif type == "file" and name:match("%.lua$") then
        -- Found a test file
        table.insert(test_files, {
          path = full_path,
          category = category or "uncategorized",
          database_type = database_type or "sqlserver", -- Default to sqlserver for backward compat
          name = name:gsub("%.lua$", ""),
        })
      end
    end
  end

  scan_dir(base_path, nil, nil)

  -- Sort by path for consistent ordering
  table.sort(test_files, function(a, b)
    return a.path < b.path
  end)

  return test_files
end

--- Create mock context object from test data
--- Mimics what blink.cmp passes to source.get_completions()
--- @param test_data table Test data from test file
--- @param bufnr number? Buffer number (defaults to fake bufnr)
--- @return table context Mock context object
function M.create_mock_context(test_data, bufnr)
  bufnr = bufnr or 999999 -- Fake buffer number

  -- Split query into lines
  local lines = vim.split(test_data.query, "\n", { plain = true })

  -- Get cursor position (convert 0-indexed to 1-indexed for Lua)
  local cursor_line = test_data.cursor.line + 1 -- Convert to 1-indexed
  local cursor_col = test_data.cursor.col -- Already byte offset

  -- Get current line
  local line = lines[cursor_line] or ""

  return {
    bufnr = bufnr,
    cursor = { cursor_line, cursor_col },
    line = line,
    bounds = {
      start_col = 1,
      end_col = #line,
    },
    filetype = "sql",
  }
end

--- Create mock buffer with test data
--- Sets up a real buffer with the query text and database context
--- @param test_data table Test data from test file
--- @param connection_info table? Connection info { server, database, connection_string }
--- @return number bufnr The created buffer number
function M.create_mock_buffer(test_data, connection_info)
  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer

  -- Set buffer filetype
  vim.api.nvim_buf_set_option(bufnr, "filetype", "sql")

  -- Set buffer lines
  local lines = vim.split(test_data.query, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Set database context using REAL connection
  if connection_info then
    local db_key = string.format("%s:%s", connection_info.server.name, connection_info.database.db_name)
    vim.api.nvim_buf_set_var(bufnr, "ssns_db_key", db_key)
  else
    -- Fallback to fake server name if no connection info provided
    local db_key = string.format("test_server:%s", test_data.database)
    vim.api.nvim_buf_set_var(bufnr, "ssns_db_key", db_key)
  end

  return bufnr
end

--- Compare actual completion items with expected items
--- @param actual table[] Array of completion items from provider
--- @param expected table Expected results with type and items
--- @return table result { passed: boolean, missing: string[], unexpected: string[], details: string }
function M.compare_results(actual, expected)
  -- Extract labels from actual items
  local actual_labels = {}
  for _, item in ipairs(actual) do
    table.insert(actual_labels, item.label)
  end

  -- Create sets for comparison
  local expected_set = {}
  for _, label in ipairs(expected.items) do
    expected_set[label] = true
  end

  local actual_set = {}
  for _, label in ipairs(actual_labels) do
    actual_set[label] = true
  end

  -- Find missing items (expected but not in actual)
  local missing = {}
  for _, label in ipairs(expected.items) do
    if not actual_set[label] then
      table.insert(missing, label)
    end
  end

  -- Find unexpected items (in actual but not expected)
  local unexpected = {}
  for _, label in ipairs(actual_labels) do
    if not expected_set[label] then
      table.insert(unexpected, label)
    end
  end

  -- Sort for consistent output
  table.sort(missing)
  table.sort(unexpected)

  -- Determine if test passed
  local passed = #missing == 0 and #unexpected == 0

  -- Build details string
  local details_parts = {}
  table.insert(details_parts, string.format("Expected %d items, got %d items", #expected.items, #actual_labels))

  if #missing > 0 then
    table.insert(details_parts, string.format("Missing: %s", table.concat(missing, ", ")))
  end

  if #unexpected > 0 then
    table.insert(details_parts, string.format("Unexpected: %s", table.concat(unexpected, ", ")))
  end

  if passed then
    table.insert(details_parts, "All expected items found")
  end

  return {
    passed = passed,
    missing = missing,
    unexpected = unexpected,
    details = table.concat(details_parts, "\n"),
    expected_count = #expected.items,
    actual_count = #actual_labels,
  }
end

--- Format a list of items for display
--- @param items string[] Array of item labels
--- @param max_items number? Maximum items to display (default: 10)
--- @return string formatted Formatted string
function M.format_item_list(items, max_items)
  max_items = max_items or 10

  if #items == 0 then
    return "(none)"
  end

  if #items <= max_items then
    return table.concat(items, ", ")
  end

  -- Show first max_items and indicate there are more
  local visible = vim.list_slice(items, 1, max_items)
  return string.format("%s ... (%d more)", table.concat(visible, ", "), #items - max_items)
end

--- Extract category name from file path
--- @param filepath string Full path to test file
--- @return string category Category name (e.g., "schema_table_qualification")
function M.extract_category(filepath)
  -- Extract category from path like .../tests/01_schema_table_qualification/test.lua
  local category = filepath:match("/tests/(%d+_[^/]+)/")
  if category then
    -- Remove numeric prefix (e.g., "01_")
    category = category:gsub("^%d+_", "")
    return category
  end
  return "uncategorized"
end

--- Clean category name for display
--- @param category string Raw category name
--- @return string cleaned Cleaned category name
function M.clean_category_name(category)
  -- Convert underscores to spaces and capitalize words
  local cleaned = category:gsub("_", " ")
  cleaned = cleaned:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return cleaned
end

return M
