---@class ObjectSearchRender
---Panel rendering functions for the object search module
local M = {}

local State = require('ssns.ui.panels.object_search.state')
local Helpers = require('ssns.ui.panels.object_search.helpers')
local ContentBuilder = require('ssns.ui.core.content_builder')
local Cache = require('ssns.cache')

---Forward reference for load_definition (injected by init.lua)
---@type fun(searchable: SearchableObject): string?
local load_definition_fn = nil

---Inject the load_definition function (called by init.lua)
---@param fn fun(searchable: SearchableObject): string?
function M.set_load_definition_fn(fn)
  load_definition_fn = fn
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Get selected search targets as values array
---@return string[]
local function get_search_targets_values()
  local ui_state = State.get_ui_state()
  local values = {}
  if ui_state.search_names then table.insert(values, "names") end
  if ui_state.search_definitions then table.insert(values, "defs") end
  if ui_state.search_metadata then table.insert(values, "meta") end
  return values
end

---Get selected object types as values array
---@return string[]
local function get_object_types_values()
  local ui_state = State.get_ui_state()
  local values = {}
  if ui_state.show_tables then table.insert(values, "table") end
  if ui_state.show_views then table.insert(values, "view") end
  if ui_state.show_procedures then table.insert(values, "procedure") end
  if ui_state.show_functions then table.insert(values, "function") end
  if ui_state.show_synonyms then table.insert(values, "synonym") end
  if ui_state.show_schemas then table.insert(values, "schema") end
  return values
end

---Invalidate the visible object count cache
---Called automatically by apply_current_search() when filters change
---Also called when loaded_objects changes to ensure count stays accurate
function M.invalidate_visible_count_cache()
  local ui_state = State.get_ui_state()
  ui_state._visible_count_cache = nil
end

---Calculate visible object count based on current filters (cached)
---@return number
local function get_visible_object_count()
  local ui_state = State.get_ui_state()

  -- Return cached value if available
  if ui_state._visible_count_cache ~= nil then
    return ui_state._visible_count_cache
  end

  -- Calculate and cache
  local count = 0
  for _, obj in ipairs(ui_state.loaded_objects) do
    -- Check system filter
    if ui_state.show_system or not Helpers.is_system_object(obj) then
      -- Check object type filter
      if Helpers.should_show_object_type(obj) then
        count = count + 1
      end
    end
  end

  ui_state._visible_count_cache = count
  return count
end

---Get object type style name for ContentBuilder
---@param object_type string
---@return string style
local function get_object_style(object_type)
  local styles = {
    table = "table",
    view = "view",
    procedure = "procedure",
    ["function"] = "func",
    synonym = "muted",
    schema = "schema",
  }
  return styles[object_type] or "normal"
end

-- ============================================================================
-- Settings Panel Helpers
-- ============================================================================

---Build server dropdown options from cache and connections
---Uses cached saved connections (loaded async on panel open)
---@return DropdownOption[] options
local function get_server_options()
  local ui_state = State.get_ui_state()
  local options = {}
  local seen = {}

  -- Connected servers first
  for _, server in ipairs(Cache.servers) do
    if not seen[server.name] then
      seen[server.name] = true
      local status = server:is_connected() and "● " or "○ "
      table.insert(options, {
        value = server.name,
        label = status .. server.name,
      })
    end
  end

  -- Saved connections (from async cache)
  local saved_connections = ui_state._cached_saved_connections or {}
  for _, conn in ipairs(saved_connections) do
    if not seen[conn.name] then
      seen[conn.name] = true
      table.insert(options, {
        value = conn.name,
        label = "○ " .. conn.name,
      })
    end
  end

  -- Config connections
  local Config = require('ssns.config')
  local config_connections = Config.get_connections()
  for name, _ in pairs(config_connections) do
    if not seen[name] then
      seen[name] = true
      table.insert(options, {
        value = name,
        label = "○ " .. name,
      })
    end
  end

  return options
end

---Build database dropdown options from selected server
---Note: This function only reads cached data - async loading is handled by server dropdown change handler
---@return DropdownOption[] options
local function get_database_options()
  local ui_state = State.get_ui_state()
  local options = {}

  if not ui_state.selected_server then
    return options
  end

  local server = ui_state.selected_server

  -- Ensure server is connected and loaded
  -- Don't trigger loading here - it's handled asynchronously by the server dropdown handler
  if not server:is_connected() or not server.is_loaded then
    return options
  end

  -- Get databases directly from server (already loaded)
  local databases = server.databases or {}

  for _, db in ipairs(databases) do
    -- Skip system databases if show_system is false
    if ui_state.show_system or not State.SYSTEM_DATABASES[db.db_name] then
      table.insert(options, {
        value = db.db_name,
        label = db.db_name,
      })
    end
  end

  return options
end

---Get currently selected database names as array
---@return string[] names
local function get_selected_db_names()
  local ui_state = State.get_ui_state()
  local names = {}
  for name, _ in pairs(ui_state.selected_databases) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

---Get selected search options as values array
---@return string[]
local function get_search_options_values()
  local ui_state = State.get_ui_state()
  local values = {}
  if ui_state.case_sensitive then table.insert(values, "case") end
  if ui_state.use_regex then table.insert(values, "regex") end
  if ui_state.whole_word then table.insert(values, "word") end
  if ui_state.show_system then table.insert(values, "system") end
  return values
end

-- ============================================================================
-- Panel Render Functions
-- ============================================================================

---Render the search panel (now just shows search input)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_search(state)
  local ui_state = State.get_ui_state()
  local lines = {}
  local highlights = {}

  if ui_state.search_editing then
    return {""}, {}
  end

  -- Line 1: Search term or placeholder
  if ui_state.search_term == "" then
    table.insert(lines, " Press / to search")
    table.insert(highlights, {0, 0, -1, "Comment"})
  else
    table.insert(lines, " " .. ui_state.search_term)
    table.insert(highlights, {0, 0, -1, "SsnsUiHint"})
  end

  return lines, highlights
end

---Render the filters panel (filter toggles + status/counts)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_filters(state)
  local ui_state = State.get_ui_state()

  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["filters"] and state.panels["filters"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Search targets dropdown (what to search in)
  cb:multi_dropdown("search_targets", {
    label = "Search In",
    label_width = 11,
    options = {
      { value = "names", label = "Names {1}" },
      { value = "defs", label = "Definitions {2}" },
      { value = "meta", label = "Metadata {3}" },
    },
    values = get_search_targets_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 70,
  })

  -- Row 2: Object types dropdown (what types to show)
  cb:multi_dropdown("object_types", {
    label = "Types",
    label_width = 11,
    options = {
      { value = "table", label = "T Tables {!}" },
      { value = "view", label = "V Views {@}" },
      { value = "procedure", label = "P Procs {#}" },
      { value = "function", label = "F Funcs {$}" },
      { value = "synonym", label = "S Synonyms {%}" },
      { value = "schema", label = "σ Schemas {^}" },
    },
    values = get_object_types_values(),
    display_mode = "list",
    select_all_option = true,
    placeholder = "(none)",
    width = 70,
  })

  -- Row 3: Status/counts
  if ui_state.loading_status == "loading" then
    local filled = math.floor(ui_state.loading_progress / 10)
    local progress_bar = string.rep("█", filled) .. string.rep("░", 10 - filled)
    cb:spans({
      { text = " [", style = "muted" },
      { text = progress_bar, style = "success" },
      { text = "] ", style = "muted" },
      { text = string.format("%d%%", ui_state.loading_progress), style = "value" },
      { text = " " .. ui_state.loading_message, style = "comment" },
    })
  elseif ui_state.selected_server then
    cb:spans({
      { text = " Objects: ", style = "muted" },
      { text = tostring(get_visible_object_count()), style = "value" },
      { text = " | Matches: ", style = "muted" },
      { text = tostring(#ui_state.filtered_results), style = "value" },
    })
  else
    cb:styled(" Select a server to search", "muted")
  end

  return cb:build_lines(), cb:build_highlights()
end

---Render the settings panel with dropdowns and toggles
---@param state MultiPanelState
---@return ContentBuilder cb
function M.render_settings(state)
  local ui_state = State.get_ui_state()

  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["settings"] and state.panels["settings"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Server dropdown
  cb:dropdown("server", {
    label = "Server",
    label_width = 11,
    options = get_server_options(),
    value = ui_state.selected_server and ui_state.selected_server.name or "",
    placeholder = "(select server)",
    width = 70,
  })

  -- Row 2: Database multi-dropdown (show loading state when server is connecting/loading)
  local db_placeholder = "(select databases)"
  local db_options = {}
  local db_disabled = false

  if ui_state.server_loading then
    -- Show loading spinner in placeholder
    local spinner_char = State.get_loading_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end
    db_placeholder = spinner_char .. " Loading databases..."
    db_disabled = true
  elseif not ui_state.selected_server then
    db_placeholder = "(select server first)"
    db_disabled = true
  else
    db_options = get_database_options()
    if #db_options == 0 then
      db_placeholder = "(no databases found)"
      db_disabled = true
    end
  end

  cb:multi_dropdown("databases", {
    label = "Databases",
    label_width = 11,
    options = db_options,
    values = get_selected_db_names(),
    display_mode = "count",
    select_all_option = not db_disabled,
    placeholder = db_placeholder,
    width = 70,
    disabled = db_disabled,
  })

  -- Row 3: Search options multi-dropdown (list mode)
  cb:multi_dropdown("search_options", {
    label = "Options",
    label_width = 11,
    options = {
      { value = "case", label = "Case {c}" },
      { value = "regex", label = "Regex {x}" },
      { value = "word", label = "Word {w}" },
      { value = "system", label = "Sys Objs {S}" },
    },
    values = get_search_options_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 70,
  })

  return cb
end

---Render the results panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_results(state)
  local ui_state = State.get_ui_state()
  local cb = ContentBuilder.new()

  -- Show loading status header when loading (but continue to show results below)
  if ui_state.loading_status == "loading" then
    local spinner_char = State.get_loading_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end

    -- Get runtime from loading spinner (not search spinner)
    local runtime = "..."
    -- We need access to the loading spinner runtime - use a simple time counter
    -- The actual spinner has runtime, but we access it through State

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "success" },
      { text = " ", style = "normal" },
      { text = ui_state.loading_message, style = "emphasis" },
      { text = " · ", style = "muted" },
      { text = "<C-c>", style = "comment" },
      { text = " cancel", style = "muted" },
    })

    if ui_state.loading_detail then
      cb:spans({
        { text = " ", style = "normal" },
        { text = ui_state.loading_detail, style = "comment" },
      })
    end

    -- Show match count if we have results
    if #ui_state.filtered_results > 0 then
      cb:spans({
        { text = " Matches: ", style = "muted" },
        { text = tostring(#ui_state.filtered_results), style = "value" },
        { text = " (loading more...)", style = "comment" },
      })
    end

    cb:blank()
  end

  -- Show cancelled status header
  if ui_state.loading_status == "cancelled" then
    cb:spans({
      { text = " ", style = "normal" },
      { text = "✗", style = "error" },
      { text = " Loading cancelled", style = "warning" },
      { text = " · ", style = "muted" },
      { text = tostring(#ui_state.loaded_objects), style = "value" },
      { text = " objects loaded", style = "muted" },
    })
    cb:blank()
  end

  -- Show search filtering progress when actively searching (separate from object loading)
  if State.get_search_in_progress() then
    local spinner_char = State.get_search_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end
    local elapsed = State.get_search_elapsed_time()
    local total = State.get_search_total_objects()
    local progress = State.get_search_progress()
    local searched = math.floor(total * progress / 100)

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "warning" },
      { text = " Filtering: ", style = "emphasis" },
      { text = tostring(searched), style = "value" },
      { text = "/", style = "muted" },
      { text = tostring(total), style = "value" },
      { text = string.format(" (%d%%)", progress), style = "muted" },
      { text = " · ", style = "muted" },
      { text = elapsed, style = "value" },
      { text = " · ", style = "muted" },
      { text = tostring(#ui_state.filtered_results), style = "success" },
      { text = " matches", style = "muted" },
    })
    cb:blank()
  end

  -- Results list (show during loading AND after)
  for i, result in ipairs(ui_state.filtered_results) do
    local is_selected = (i == ui_state.selected_result_idx)
    local prefix = is_selected and " ▶ " or "   "
    local icon = Helpers.get_object_icon(result.searchable.object_type)
    local obj_style = get_object_style(result.searchable.object_type)
    local badge = result.match_type ~= "none" and string.format(" [%s]", result.match_type) or ""

    local spans = {
      { text = prefix, style = is_selected and "highlight" or "normal" },
      { text = icon .. " ", style = is_selected and "strong" or obj_style },
      { text = result.searchable.database_name, style = is_selected and "strong" or "database" },
      { text = ".", style = is_selected and "strong" or "muted" },
      { text = result.display_name, style = is_selected and "strong" or obj_style },
    }

    if badge ~= "" then
      table.insert(spans, { text = badge, style = "muted" })
    end

    cb:spans(spans)
  end

  if #ui_state.filtered_results == 0 then
    if ui_state.loading_status == "loading" then
      -- Don't show "no matches" during loading - more results may come
      if #ui_state.loaded_objects == 0 then
        cb:styled("   Waiting for objects...", "comment")
      end
    elseif #ui_state.loaded_objects == 0 then
      cb:styled("   Press 'd' to select databases and load objects", "comment")
    else
      cb:styled("   (No matches)", "comment")
    end
  end

  return cb:build_lines(), cb:build_highlights()
end

---Render the metadata panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_metadata(state)
  local ui_state = State.get_ui_state()
  local cb = ContentBuilder.new()

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    cb:blank()
    cb:styled(" Select an object to view metadata", "comment")
    return cb:build_lines(), cb:build_highlights()
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable
  local obj = searchable.object
  local obj_style = get_object_style(searchable.object_type)

  -- Header
  cb:blank()
  cb:spans({
    { text = " ", style = "normal" },
    { text = searchable.object_type:upper(), style = "muted" },
    { text = ": ", style = "muted" },
    { text = searchable.name, style = obj_style },
  })

  cb:spans({
    { text = " Schema: ", style = "label" },
    { text = searchable.schema_name or "N/A", style = "schema" },
  })

  cb:spans({
    { text = " Database: ", style = "label" },
    { text = searchable.database_name, style = "database" },
  })

  cb:blank()

  -- Object-specific metadata
  if searchable.object_type == "table" or searchable.object_type == "view" then
    -- Show columns
    cb:section(" Columns:")

    if obj and obj.get_columns then
      local ok, columns = pcall(function()
        return obj:get_columns({ skip_load = true })
      end)

      if ok and columns and #columns > 0 then
        for _, col in ipairs(columns) do
          local nullable_style = col.nullable and "muted" or "warning"
          local nullable_text = col.nullable and "NULL" or "NOT NULL"
          cb:spans({
            { text = "   ", style = "normal" },
            { text = col.name, style = "column" },
            { text = " (", style = "muted" },
            { text = col.data_type or "?", style = "keyword" },
            { text = ") ", style = "muted" },
            { text = nullable_text, style = nullable_style },
          })
        end
      else
        cb:styled("   (Load object to see columns)", "comment")
      end
    end
  elseif searchable.object_type == "procedure" or searchable.object_type == "function" then
    -- Show parameters
    cb:section(" Parameters:")

    if obj and obj.get_parameters then
      local ok, params = pcall(function()
        return obj:get_parameters({ skip_load = true })
      end)

      if ok and params and #params > 0 then
        for _, param in ipairs(params) do
          local direction = param.is_output and "OUT" or "IN"
          local dir_style = param.is_output and "warning" or "success"
          cb:spans({
            { text = "   ", style = "normal" },
            { text = direction, style = dir_style },
            { text = " ", style = "normal" },
            { text = param.name, style = "param" },
            { text = " (", style = "muted" },
            { text = param.data_type or "?", style = "keyword" },
            { text = ")", style = "muted" },
          })
        end
      else
        cb:styled("   (Load object to see parameters)", "comment")
      end
    end
  elseif searchable.object_type == "synonym" then
    -- Show synonym target
    cb:section(" Target:")

    if obj and obj.base_object_name then
      cb:spans({
        { text = "   ", style = "normal" },
        { text = obj.base_object_name, style = "table" },
      })
    else
      cb:styled("   (Unknown)", "comment")
    end
  elseif searchable.object_type == "schema" then
    -- Schema info
    cb:section(" Schema Info:")
    cb:styled("   Schema object - no additional metadata", "comment")
  end

  return cb:build_lines(), cb:build_highlights()
end

---Render the definition panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_definition(state)
  local ui_state = State.get_ui_state()
  local lines = {}
  local highlights = {}

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    table.insert(lines, "-- Select an object to view definition")
    return lines, highlights
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Header comments
  table.insert(lines, string.format("-- %s: %s", searchable.object_type:upper(), searchable.name))
  -- Show database and schema (only include schema if it exists and is meaningful)
  local db_display = searchable.database_name
  if searchable.schema_name and searchable.schema_name ~= "" then
    db_display = string.format("%s.%s", searchable.database_name, searchable.schema_name)
  end
  table.insert(lines, string.format("-- Database: %s", db_display))
  table.insert(lines, string.format("-- Server: %s", searchable.server_name))
  table.insert(lines, "")

  -- Get definition
  local definition = nil
  if load_definition_fn then
    definition = load_definition_fn(searchable)
  end

  if definition then
    for _, def_line in ipairs(vim.split(definition, "\n")) do
      table.insert(lines, def_line)
    end
  else
    table.insert(lines, "-- Definition not available")
    table.insert(lines, "-- (Schema objects and some system objects may not have definitions)")
  end

  -- Highlight header comments
  for i = 0, 3 do
    if lines[i + 1] and lines[i + 1]:match("^%-%-") then
      table.insert(highlights, {i, 0, -1, "Comment"})
    end
  end

  return lines, highlights
end

-- ============================================================================
-- Exports for external access
-- ============================================================================

-- Export helper functions that may be needed elsewhere
M.get_search_targets_values = get_search_targets_values
M.get_object_types_values = get_object_types_values
M.get_visible_object_count = get_visible_object_count
M.get_server_options = get_server_options
M.get_database_options = get_database_options
M.get_selected_db_names = get_selected_db_names
M.get_search_options_values = get_search_options_values

return M
