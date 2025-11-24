--- Test reporter module
--- Formats and displays test results
local M = {}

local utils = require("ssns.testing.utils")

--- Format a single test result
--- @param result table Test result object
--- @return string formatted Formatted result as markdown
function M.format_result(result)
  local lines = {}

  -- Status indicator
  local status = result.passed and "✓" or "✗"
  local status_text = result.passed and "PASS" or "FAIL"

  -- Header
  table.insert(lines, string.format("### %s Test #%d: %s",
    status,
    result.test_number or "?",
    result.description or "Unknown"))

  -- Basic info
  table.insert(lines, string.format("- **Status**: %s", status_text))
  table.insert(lines, string.format("- **Database**: %s", result.database or "N/A"))
  table.insert(lines, string.format("- **Expected Type**: %s", result.expected_type or "N/A"))
  table.insert(lines, string.format("- **Duration**: %.2fms", result.duration_ms or 0))
  table.insert(lines, string.format("- **Category**: %s", utils.clean_category_name(result.category or "uncategorized")))

  -- Error details (if failed)
  if result.error then
    table.insert(lines, "")
    table.insert(lines, "**Error:**")
    table.insert(lines, "```")
    table.insert(lines, result.error)
    table.insert(lines, "```")
  end

  -- Comparison details
  if result.comparison then
    table.insert(lines, "")
    table.insert(lines, "**Results:**")
    table.insert(lines, string.format("- Expected: %d items", result.comparison.expected_count))
    table.insert(lines, string.format("- Actual: %d items", result.comparison.actual_count))

    if #result.comparison.missing > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Missing Items:**")
      table.insert(lines, string.format("- %s", utils.format_item_list(result.comparison.missing)))
    end

    if #result.comparison.unexpected > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Unexpected Items:**")
      table.insert(lines, string.format("- %s", utils.format_item_list(result.comparison.unexpected)))
    end
  end

  table.insert(lines, "")
  return table.concat(lines, "\n")
end

--- Create summary table by category
--- @param results table[] Array of test results
--- @return string markdown Markdown table
function M.create_summary_table(results)
  -- Group results by category
  local by_category = {}
  for _, result in ipairs(results) do
    local category = result.category or "uncategorized"
    if not by_category[category] then
      by_category[category] = { total = 0, passed = 0, failed = 0 }
    end
    by_category[category].total = by_category[category].total + 1
    if result.passed then
      by_category[category].passed = by_category[category].passed + 1
    else
      by_category[category].failed = by_category[category].failed + 1
    end
  end

  -- Sort categories
  local categories = {}
  for category, _ in pairs(by_category) do
    table.insert(categories, category)
  end
  table.sort(categories)

  -- Build markdown table
  local lines = {}
  table.insert(lines, "| Category | Total | Passed | Failed | Pass Rate |")
  table.insert(lines, "|----------|-------|--------|--------|-----------|")

  for _, category in ipairs(categories) do
    local stats = by_category[category]
    local pass_rate = stats.total > 0 and (stats.passed / stats.total * 100) or 0

    table.insert(lines, string.format("| %s | %d | %d | %d | %.1f%% |",
      utils.clean_category_name(category),
      stats.total,
      stats.passed,
      stats.failed,
      pass_rate))
  end

  return table.concat(lines, "\n")
end

--- Write test results to markdown file
--- @param results table[] Array of test results
--- @param output_path string Output file path
--- @return boolean success True if write succeeded
function M.write_markdown(results, output_path)
  -- Ensure output directory exists
  local output_dir = vim.fn.fnamemodify(output_path, ":h")
  vim.fn.mkdir(output_dir, "p")

  -- Calculate summary statistics
  local total = #results
  local passed = 0
  local failed = 0
  local total_duration = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
    total_duration = total_duration + (result.duration_ms or 0)
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Build markdown content
  local lines = {}

  -- Header
  table.insert(lines, "# SSNS IntelliSense Test Results")
  table.insert(lines, "")
  table.insert(lines, string.format("**Generated**: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")

  -- Summary section
  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, string.format("- **Total Tests**: %d", total))
  table.insert(lines, string.format("- **Passed**: %d", passed))
  table.insert(lines, string.format("- **Failed**: %d", failed))
  table.insert(lines, string.format("- **Pass Rate**: %.1f%%", pass_rate))
  table.insert(lines, string.format("- **Total Duration**: %.2fms", total_duration))
  table.insert(lines, string.format("- **Average Duration**: %.2fms", total > 0 and (total_duration / total) or 0))
  table.insert(lines, "")

  -- Results by category
  table.insert(lines, "## Results by Category")
  table.insert(lines, "")
  table.insert(lines, M.create_summary_table(results))
  table.insert(lines, "")

  -- Detailed results
  table.insert(lines, "## Detailed Results")
  table.insert(lines, "")

  -- Group by category for organized output
  local by_category = {}
  for _, result in ipairs(results) do
    local category = result.category or "uncategorized"
    if not by_category[category] then
      by_category[category] = {}
    end
    table.insert(by_category[category], result)
  end

  -- Sort categories
  local categories = {}
  for category, _ in pairs(by_category) do
    table.insert(categories, category)
  end
  table.sort(categories)

  -- Output results by category
  for _, category in ipairs(categories) do
    table.insert(lines, string.format("### %s", utils.clean_category_name(category)))
    table.insert(lines, "")

    local category_results = by_category[category]
    -- Sort by test number
    table.sort(category_results, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(category_results) do
      table.insert(lines, M.format_result(result))
    end
  end

  -- Failed tests summary (if any)
  if failed > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Failed Tests Summary")
    table.insert(lines, "")

    local failed_tests = {}
    for _, result in ipairs(results) do
      if not result.passed then
        table.insert(failed_tests, result)
      end
    end

    -- Sort by test number
    table.sort(failed_tests, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(failed_tests) do
      table.insert(lines, string.format("- **Test #%d**: %s (Category: %s)",
        result.test_number or "?",
        result.description or "Unknown",
        utils.clean_category_name(result.category or "uncategorized")))

      if result.error then
        table.insert(lines, string.format("  - Error: %s", result.error:gsub("\n", " ")))
      elseif result.comparison then
        if #result.comparison.missing > 0 then
          table.insert(lines, string.format("  - Missing: %s", utils.format_item_list(result.comparison.missing, 5)))
        end
        if #result.comparison.unexpected > 0 then
          table.insert(lines, string.format("  - Unexpected: %s", utils.format_item_list(result.comparison.unexpected, 5)))
        end
      end
    end
  end

  -- Write to file
  local content = table.concat(lines, "\n")
  local file = io.open(output_path, "w")
  if not file then
    vim.notify(string.format("Failed to open file for writing: %s", output_path), vim.log.levels.ERROR)
    return false
  end

  file:write(content)
  file:close()

  return true
end

--- Display test results in Neovim messages
--- @param results table[] Array of test results
function M.display_results(results)
  local total = #results
  local passed = 0
  local failed = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Display summary
  vim.notify(string.format("===== Test Results ====="), vim.log.levels.INFO)
  vim.notify(string.format("Total: %d | Passed: %d | Failed: %d | Pass Rate: %.1f%%",
    total, passed, failed, pass_rate), vim.log.levels.INFO)

  -- Display failed tests
  if failed > 0 then
    vim.notify(string.format("\nFailed Tests:"), vim.log.levels.WARN)

    local failed_tests = {}
    for _, result in ipairs(results) do
      if not result.passed then
        table.insert(failed_tests, result)
      end
    end

    -- Sort by test number
    table.sort(failed_tests, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(failed_tests) do
      local msg = string.format("  Test #%d: %s", result.test_number or "?", result.description or "Unknown")

      if result.error then
        msg = msg .. string.format("\n    Error: %s", result.error:gsub("\n", " "))
      elseif result.comparison then
        if #result.comparison.missing > 0 then
          msg = msg .. string.format("\n    Missing: %s", utils.format_item_list(result.comparison.missing, 5))
        end
        if #result.comparison.unexpected > 0 then
          msg = msg .. string.format("\n    Unexpected: %s", utils.format_item_list(result.comparison.unexpected, 5))
        end
      end

      vim.notify(msg, vim.log.levels.WARN)
    end
  end

  vim.notify("========================", vim.log.levels.INFO)
end

--- Create a concise summary string
--- @param results table[] Array of test results
--- @return string summary Summary string
function M.create_summary(results)
  local total = #results
  local passed = 0
  local failed = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  return string.format("Total: %d | Passed: %d | Failed: %d | Pass Rate: %.1f%%",
    total, passed, failed, pass_rate)
end

return M
