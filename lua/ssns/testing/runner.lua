--- Test runner module
--- Executes parsed tests and collects results
local M = {}

local utils = require("ssns.testing.utils")

--- Run a single test file
--- @param test_file_path string Absolute path to test file
--- @param opts table? Optional configuration { timeout_ms: number }
--- @return table result Test result object
function M.run_single_test(test_file_path, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 5000 -- 5 second default timeout

  local result = {
    path = test_file_path,
    test_number = nil,
    description = nil,
    database = nil,
    expected_type = nil,
    passed = false,
    error = nil,
    comparison = nil,
    duration_ms = 0,
  }

  -- Load test data
  local test_data, load_err = utils.load_test_file(test_file_path)
  if not test_data then
    result.error = string.format("Failed to load test: %s", load_err)
    return result
  end

  -- Set basic info from test data
  result.test_number = test_data.number
  result.description = test_data.description
  result.database = test_data.database
  result.expected_type = test_data.expected.type

  -- Start timer
  local start_time = vim.loop.hrtime()

  -- Create mock buffer with test data
  local bufnr
  local success, create_err = pcall(function()
    bufnr = utils.create_mock_buffer(test_data)
  end)

  if not success then
    result.error = string.format("Failed to create mock buffer: %s", create_err)
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Create mock context
  local ctx = utils.create_mock_context(test_data, bufnr)

  -- Get completion source
  local Source = require("ssns.completion.source")

  -- Capture completion items
  local completion_items = nil
  local completion_error = nil
  local completion_done = false

  -- Call get_completions with callback
  local callback_success, callback_err = pcall(function()
    Source:get_completions(ctx, function(response)
      completion_items = response.items or {}
      completion_done = true
    end)
  end)

  if not callback_success then
    result.error = string.format("get_completions failed: %s", callback_err)
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    -- Clean up buffer
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    return result
  end

  -- Wait for completion callback (with timeout)
  local wait_start = vim.loop.hrtime()
  while not completion_done do
    -- Process pending events
    vim.wait(10, function()
      return completion_done
    end, 10)

    -- Check timeout
    local elapsed = (vim.loop.hrtime() - wait_start) / 1e6
    if elapsed > timeout_ms then
      result.error = string.format("Timeout waiting for completion (>%dms)", timeout_ms)
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

      -- Clean up buffer
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      return result
    end
  end

  -- Compare results
  result.comparison = utils.compare_results(completion_items or {}, test_data.expected)
  result.passed = result.comparison.passed

  -- Calculate duration
  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

  -- Clean up buffer
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

  return result
end

--- Run all tests in the test directory
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_all_tests(opts)
  opts = opts or {}

  -- Scan for test files
  local test_files = utils.scan_test_folders()

  if #test_files == 0 then
    vim.notify("No test files found", vim.log.levels.WARN)
    return {}
  end

  vim.notify(string.format("Running %d tests...", #test_files), vim.log.levels.INFO)

  local results = {}

  -- Run each test
  for i, test_file in ipairs(test_files) do
    -- Show progress
    if i % 10 == 0 or i == 1 then
      vim.notify(string.format("Running test %d/%d...", i, #test_files), vim.log.levels.INFO)
    end

    local result = M.run_single_test(test_file.path, opts)
    result.category = test_file.category
    result.name = test_file.name
    table.insert(results, result)
  end

  vim.notify(string.format("Completed %d tests", #results), vim.log.levels.INFO)

  return results
end

--- Run tests in a specific category folder
--- @param category_folder string Category folder name (e.g., "01_schema_table_qualification")
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_category_tests(category_folder, opts)
  opts = opts or {}

  -- Scan for all test files
  local all_test_files = utils.scan_test_folders()

  -- Filter by category
  local category_tests = {}
  for _, test_file in ipairs(all_test_files) do
    -- Match category with or without numeric prefix
    if test_file.category == category_folder or test_file.category:match("^%d+_" .. category_folder .. "$") then
      table.insert(category_tests, test_file)
    end
  end

  if #category_tests == 0 then
    vim.notify(string.format("No tests found in category: %s", category_folder), vim.log.levels.WARN)
    return {}
  end

  vim.notify(string.format("Running %d tests in category: %s", #category_tests, category_folder), vim.log.levels.INFO)

  local results = {}

  -- Run each test in category
  for i, test_file in ipairs(category_tests) do
    vim.notify(string.format("Running test %d/%d: %s", i, #category_tests, test_file.name), vim.log.levels.INFO)

    local result = M.run_single_test(test_file.path, opts)
    result.category = test_file.category
    result.name = test_file.name
    table.insert(results, result)
  end

  return results
end

--- Run tests filtered by completion type
--- @param completion_type string Completion type (e.g., "table", "column", "schema")
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_tests_by_type(completion_type, opts)
  opts = opts or {}

  -- Scan for all test files
  local all_test_files = utils.scan_test_folders()

  vim.notify(string.format("Filtering tests by type: %s", completion_type), vim.log.levels.INFO)

  local filtered_results = {}

  -- Run each test and filter by type
  for i, test_file in ipairs(all_test_files) do
    -- Load test data to check expected type
    local test_data, _ = utils.load_test_file(test_file.path)

    if test_data and test_data.expected.type == completion_type then
      vim.notify(string.format("Running test %s (%s)", test_file.name, completion_type), vim.log.levels.INFO)

      local result = M.run_single_test(test_file.path, opts)
      result.category = test_file.category
      result.name = test_file.name
      table.insert(filtered_results, result)
    end
  end

  if #filtered_results == 0 then
    vim.notify(string.format("No tests found for type: %s", completion_type), vim.log.levels.WARN)
  else
    vim.notify(string.format("Completed %d tests for type: %s", #filtered_results, completion_type), vim.log.levels.INFO)
  end

  return filtered_results
end

--- Find a specific test by number
--- @param test_number number Test number to find
--- @return string? path Path to test file or nil if not found
function M.find_test_by_number(test_number)
  local all_test_files = utils.scan_test_folders()

  for _, test_file in ipairs(all_test_files) do
    local test_data, _ = utils.load_test_file(test_file.path)
    if test_data and test_data.number == test_number then
      return test_file.path
    end
  end

  return nil
end

return M
