--- SSNS Testing Framework
--- Provides automated testing for IntelliSense/autocomplete features
local M = {}

-- Module dependencies
local runner = require("ssns.testing.runner")
local reporter = require("ssns.testing.reporter")
local utils = require("ssns.testing.utils")

--- Default configuration
M.config = {
  test_file = vim.fn.stdpath("data") .. "/ssns/roadmap/phase-10/test_queries.sql",
  output_dir = vim.fn.stdpath("data") .. "/ssns/test_results",
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

--- Expose submodules for direct access
M.runner = runner
M.reporter = reporter
M.utils = utils

return M
