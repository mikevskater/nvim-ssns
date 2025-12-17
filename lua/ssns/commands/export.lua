---@class SsnsCommandsExport
---Export and yank related commands
local M = {}

---Register export commands
function M.register()
  local Ssns = require('ssns')

  -- :SSNSExportResults - Export query results to CSV
  vim.api.nvim_create_user_command("SSNSExportResults", function(opts)
    local Query = require('ssns.ui.core.query')
    Query.export_results_to_csv(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Export query results to CSV file and open in default app",
    complete = "file",
  })

  -- :SSNSYankResultsCSV - Yank query results as CSV to clipboard
  vim.api.nvim_create_user_command("SSNSYankResultsCSV", function()
    local Query = require('ssns.ui.core.query')
    Query.yank_results_as_csv()
  end, {
    nargs = 0,
    desc = "Yank query results as CSV to clipboard",
  })

  -- :SSNSUsageStats - Display usage statistics for the current connection
  vim.api.nvim_create_user_command("SSNSUsageStats", function()
    Ssns.show_usage_stats()
  end, {
    nargs = 0,
    desc = "Show usage-based completion statistics",
  })

  -- :SSNSUsageClear - Clear all usage weights
  vim.api.nvim_create_user_command("SSNSUsageClear", function()
    Ssns.clear_usage_weights()
  end, {
    nargs = 0,
    desc = "Clear all usage weights (requires confirmation)",
  })

  -- :SSNSUsageClearCurrent - Clear weights for current connection only
  vim.api.nvim_create_user_command("SSNSUsageClearCurrent", function()
    Ssns.clear_usage_weights_current()
  end, {
    nargs = 0,
    desc = "Clear usage weights for current connection (requires confirmation)",
  })

  -- :SSNSUsageExport - Export weights to a JSON file
  vim.api.nvim_create_user_command("SSNSUsageExport", function(opts)
    Ssns.export_usage_weights(opts.args)
  end, {
    nargs = "?",
    desc = "Export usage weights to JSON file",
    complete = "file",
  })

  -- :SSNSUsageImport - Import weights from a JSON file
  vim.api.nvim_create_user_command("SSNSUsageImport", function(opts)
    Ssns.import_usage_weights(opts.args)
  end, {
    nargs = "?",
    desc = "Import usage weights from JSON file",
    complete = "file",
  })

  -- :SSNSUsageToggle - Toggle usage tracking on/off
  vim.api.nvim_create_user_command("SSNSUsageToggle", function()
    Ssns.toggle_usage_tracking()
  end, {
    nargs = 0,
    desc = "Toggle usage tracking on/off",
  })
end

return M
