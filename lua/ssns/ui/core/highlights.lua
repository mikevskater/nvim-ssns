---@class UiHighlights
---Syntax highlighting and icons for SSNS UI
local UiHighlights = {}

---Setup highlight groups
---Now delegates to ThemeManager for actual highlight setup
function UiHighlights.setup()
  -- Initialize and apply theme manager
  local ThemeManager = require('ssns.ui.themes.theme_manager')
  ThemeManager.setup()
end

---Apply highlights to buffer
---@param line_map table<number, BaseDbObject>? Optional line map from tree
function UiHighlights.apply(line_map)
  local Buffer = require('ssns.ui.core.buffer')

  if not Buffer.exists() then
    return
  end

  local bufnr = Buffer.bufnr
  local ns = vim.api.nvim_create_namespace('ssns_highlights')

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- If no line_map provided, try to get it from tree
  if not line_map then
    local Tree = require('ssns.ui.core.tree')
    line_map = Tree.line_map
  end

  if not line_map then
    return
  end

  -- Apply highlights based on object types
  for line_number, obj in pairs(line_map) do
    if obj and obj.object_type then
      local hl_group = UiHighlights.get_highlight_group(obj)
      if hl_group then
        -- Highlight the entire line
        vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, line_number - 1, 0, -1)
      end
    end
  end
end

---Get highlight group for object
---@param obj BaseDbObject
---@return string?
function UiHighlights.get_highlight_group(obj)
  local object_type = obj.object_type

  -- Special handling for servers - use database-type specific colors
  if object_type == "server" then
    -- Get database type, handling cases where method might not exist
    local db_type = nil
    if obj.get_db_type then
      db_type = obj:get_db_type()
    elseif obj.adapter and obj.adapter.db_type then
      db_type = obj.adapter.db_type
    end

    if db_type == "sqlserver" then
      return "SsnsServerSqlServer"
    elseif db_type == "postgres" or db_type == "postgresql" then
      return "SsnsServerPostgres"
    elseif db_type == "mysql" then
      return "SsnsServerMysql"
    elseif db_type == "sqlite" then
      return "SsnsServerSqlite"
    elseif db_type == "bigquery" then
      return "SsnsServerBigQuery"
    else
      return "SsnsServer"  -- Default/unknown
    end
  end

  -- Special handling for object references - use the referenced object's type
  if object_type == "object_reference" and obj.referenced_object then
    object_type = obj.referenced_object.object_type
  end

  -- Standard object type mapping
  local hl_map = {
    database = "SsnsDatabase",
    schema = "SsnsSchema",
    table = "SsnsTable",
    view = "SsnsView",
    procedure = "SsnsProcedure",
    ["function"] = "SsnsFunction",
    column = "SsnsColumn",
    index = "SsnsIndex",
    key = "SsnsKey",
    parameter = "SsnsParameter",
    sequence = "SsnsSequence",
    synonym = "SsnsSynonym",
    action = "SsnsAction",
    add_server_action = "SsnsAddServerAction",
    -- Groups
    databases_group = "SsnsGroup",
    tables_group = "SsnsGroup",
    views_group = "SsnsGroup",
    procedures_group = "SsnsGroup",
    functions_group = "SsnsGroup",
    scalar_functions_group = "SsnsGroup",
    table_functions_group = "SsnsGroup",
    sequences_group = "SsnsGroup",
    synonyms_group = "SsnsGroup",
    schemas_group = "SsnsGroup",
    system_databases_group = "SsnsGroup",
    system_schemas_group = "SsnsGroup",
    column_group = "SsnsGroup",
    index_group = "SsnsGroup",
    key_group = "SsnsGroup",
    parameter_group = "SsnsGroup",
    actions_group = "SsnsGroup",
    -- Schema nodes
    schema_view = "SsnsSchema",
  }

  return hl_map[object_type]
end

---Setup filetype detection
function UiHighlights.setup_filetype()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ssns",
    callback = function()
      UiHighlights.setup()
      UiHighlights.apply()
    end,
  })
end

return UiHighlights
