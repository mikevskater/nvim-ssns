---@class SsnsCommands
---Command registration module for SSNS plugin
---Loads and registers all command modules
local M = {}

---Register all SSNS commands
---Called during plugin setup
function M.register()
  -- Load command modules
  local tree = require('ssns.commands.tree')
  local server = require('ssns.commands.server')
  local query = require('ssns.commands.query')
  local debug = require('ssns.commands.debug')
  local export = require('ssns.commands.export')
  local testing = require('ssns.commands.testing')
  local features = require('ssns.commands.features')
  local cast = require('ssns.commands.cast')

  -- Register each module's commands
  tree.register()
  server.register()
  query.register()
  debug.register()
  export.register()
  testing.register()
  features.register()
  cast.register()

  -- Note: ETL commands are lazy-loaded via ftplugin/ssns.lua
  -- when .ssns files are opened (see M.setup_etl below)
end

---Setup ETL commands and macros (lazy-loaded for .ssns files)
---Called from ftplugin/ssns.lua on first .ssns file open
function M.setup_etl()
  -- Only initialize once
  if vim.g.ssns_etl_initialized then
    return
  end
  vim.g.ssns_etl_initialized = true

  local etl = require('ssns.commands.etl')
  etl.setup()
end

return M
