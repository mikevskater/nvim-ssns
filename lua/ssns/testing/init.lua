--- SSNS Testing Framework
--- Provides automated testing for IntelliSense/autocomplete features
local M = {}

-- Module dependencies
local runner = require("ssns.testing.runner")
local reporter = require("ssns.testing.reporter")
local utils = require("ssns.testing.utils")
local unit_runner = require("ssns.testing.unit_runner")

--- Default configuration
M.config = {
  test_file = vim.fn.stdpath("data") .. "/ssns/roadmap/phase-10/test_queries.sql",
  output_dir = vim.fn.stdpath("data") .. "/ssns/test_results",

  -- Connection strings by database type
  connections = {
    sqlserver = "sqlserver://.\\SQLEXPRESS",
    -- Future: Add other database types
    -- postgres = "postgres://localhost/test_db",
    -- mysql = "mysql://localhost/test_db",
    -- sqlite = "sqlite://./test.db",
  },

  -- Default connection type for tests
  default_connection_type = "sqlserver",
}

--- Initialize the testing framework
--- @param opts table|nil Optional configuration overrides
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
end

--- Run all tests in the test file
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_all_tests(opts)
  opts = opts or {}

  -- Run all tests
  local results = runner.run_all_tests(opts)

  if #results == 0 then
    vim.notify("No test results to report", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/ssns/test_results.md"
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run a specific test by number
--- @param test_number number The test number to run
--- @param opts table|nil Optional run configuration
--- @return table Test result
function M.run_test(test_number, opts)
  opts = opts or {}

  -- Find test by number
  local test_path = runner.find_test_by_number(test_number)

  if not test_path then
    vim.notify(string.format("Test #%d not found", test_number), vim.log.levels.ERROR)
    return {}
  end

  vim.notify(string.format("Running test #%d...", test_number), vim.log.levels.INFO)

  -- Run single test
  local result = runner.run_single_test(test_path, opts)

  -- Wrap in array for reporter
  local results = { result }

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/ssns/test_%d_result.md", test_number)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test result written to: %s", output_path), vim.log.levels.INFO)
  end

  return result
end

--- Run tests filtered by type
--- @param completion_type string The completion type (table, column, schema, etc.)
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_tests_by_type(completion_type, opts)
  opts = opts or {}

  vim.notify(string.format("Running tests for type: %s", completion_type), vim.log.levels.INFO)

  -- Run tests filtered by type
  local results = runner.run_tests_by_type(completion_type, opts)

  if #results == 0 then
    vim.notify(string.format("No tests found for type: %s", completion_type), vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/ssns/test_results_%s.md", completion_type)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run tests for a specific database type
--- @param database_type string The database type (sqlserver, postgres, mysql, sqlite)
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_tests_by_database(database_type, opts)
  opts = opts or {}

  vim.notify(string.format("Running tests for database type: %s", database_type), vim.log.levels.INFO)

  -- Scan for all test files
  local all_test_files = utils.scan_test_folders()

  -- Filter by database type
  local filtered_files = {}
  for _, test_file in ipairs(all_test_files) do
    if test_file.database_type == database_type then
      table.insert(filtered_files, test_file)
    end
  end

  if #filtered_files == 0 then
    vim.notify(string.format("No tests found for database type: %s", database_type), vim.log.levels.WARN)
    return {}
  end

  vim.notify(string.format("Found %d tests for %s", #filtered_files, database_type), vim.log.levels.INFO)

  local results = {}

  -- Run each test
  for i, test_file in ipairs(filtered_files) do
    if i % 10 == 0 or i == 1 then
      vim.notify(string.format("Running test %d/%d...", i, #filtered_files), vim.log.levels.INFO)
    end

    local result = runner.run_single_test(test_file.path, vim.tbl_extend("force", opts, { database_type = test_file.database_type }))
    result.category = test_file.category
    result.name = test_file.name
    result.database_type = test_file.database_type
    table.insert(results, result)
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/ssns/test_results_%s.md", database_type)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run all unit tests (tokenizer + parser)
--- @param opts table|nil Optional configuration {type?: string}
--- @return table results {total, passed, failed, results: table[]}
function M.run_unit_tests(opts)
  opts = opts or {}

  vim.notify("Running unit tests...", vim.log.levels.INFO)

  local results = unit_runner.run_all(opts)

  if results.total == 0 then
    vim.notify("No unit tests found", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/ssns/unit_test_results.md"
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Unit test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run only tokenizer tests
--- @param opts table|nil Optional configuration
--- @return table results
function M.run_tokenizer_tests(opts)
  opts = opts or {}
  opts.type = "tokenizer"

  vim.notify("Running tokenizer tests...", vim.log.levels.INFO)
  return M.run_unit_tests(opts)
end

--- Run only parser tests
--- @param opts table|nil Optional configuration
--- @return table results
function M.run_parser_tests(opts)
  opts = opts or {}
  opts.type = "parser"

  vim.notify("Running parser tests...", vim.log.levels.INFO)
  return M.run_unit_tests(opts)
end

--- Run a specific unit test by ID
--- @param test_id number The test ID (e.g., 1001 for tokenizer, 2001 for parser)
--- @param opts table|nil Optional configuration
--- @return table|nil result Test result or nil if not found
function M.run_unit_test(test_id, opts)
  opts = opts or {}

  vim.notify(string.format("Running unit test #%d...", test_id), vim.log.levels.INFO)

  local result = unit_runner.run_by_id(test_id)

  if not result then
    vim.notify(string.format("Unit test #%d not found", test_id), vim.log.levels.ERROR)
    return nil
  end

  -- Display result
  local status = result.passed and "PASS" or "FAIL"
  vim.notify(string.format("[%s] #%d: %s (%.2fms)", status, result.id, result.name, result.duration_ms),
    result.passed and vim.log.levels.INFO or vim.log.levels.WARN)

  if not result.passed and result.error then
    vim.notify(string.format("  Error: %s", result.error), vim.log.levels.ERROR)
  end

  return result
end

--- Expose submodules for direct access
M.runner = runner
M.reporter = reporter
M.utils = utils
M.unit_runner = unit_runner

return M
