---@class UiFilterEditor
---Filter editor popup UI for tree groups
local UiFilterEditor = {}

local current_popup = nil
local debounce_timer = nil
local ns_id = vim.api.nvim_create_namespace('ssns_filter_editor')

---Close the current filter editor popup
---@param cancel boolean? If true, restore original filters
local function close_popup(cancel)
  if current_popup and current_popup.bufnr then
    -- Restore original filters if cancelled
    if cancel and current_popup.original_filters and current_popup.group then
      local UiFilters = require('ssns.ui.filters')
      UiFilters.set(current_popup.group, current_popup.original_filters)

      -- Re-render tree to show original state
      local UiTree = require('ssns.ui.tree')
      UiTree.render()
    end

    if vim.api.nvim_buf_is_valid(current_popup.bufnr) then
      -- Remove autocmds
      vim.api.nvim_clear_autocmds({ buffer = current_popup.bufnr })
      vim.api.nvim_buf_delete(current_popup.bufnr, { force = true })
    end
    current_popup = nil
  end

  -- Clear debounce timer
  if debounce_timer then
    vim.fn.timer_stop(debounce_timer)
    debounce_timer = nil
  end
end

---Parse filter values from buffer using extmarks
---@param bufnr number The buffer number
---@param extmarks table Extmark positions
---@return table state Current editor state
local function parse_buffer_state(bufnr, extmarks)
  local state = {
    name_include = "",
    name_exclude = "",
    schema_include = "",
    schema_exclude = "",
    object_types = {},
    case_sensitive = false,
    hide_system_schemas = false
  }

  -- Parse each field by getting text between extmarks
  for field, mark_id in pairs(extmarks) do
    if field:match("_start$") then
      local field_name = field:gsub("_start$", "")
      local end_mark_id = extmarks[field_name .. "_end"]

      if end_mark_id then
        -- Get positions of start and end marks
        local start_pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, mark_id, {})
        local end_pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, end_mark_id, {})

        if #start_pos > 0 and #end_pos > 0 then
          local start_row, start_col = start_pos[1], start_pos[2]
          local end_row, end_col = end_pos[1], end_pos[2]

          -- Get text between marks
          if start_row == end_row then
            local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
            if line then
              state[field_name] = line:sub(start_col + 1, end_col)
            end
          end
        end
      end
    end
  end

  -- Parse checkboxes from buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    -- Case sensitive checkbox
    if line:match("^Case Sensitive:") then
      state.case_sensitive = line:match("%[x%]") ~= nil
    end

    -- Hide system schemas checkbox
    if line:match("^Hide System Schemas:") then
      state.hide_system_schemas = line:match("%[x%]") ~= nil
    end

    -- Object types
    if line:match("^%s*%[.%]%s+Tables") then
      state.object_types.table = line:match("%[x%]") ~= nil
    end
    if line:match("^%s*%[.%]%s+Views") then
      state.object_types.view = line:match("%[x%]") ~= nil
    end
    if line:match("^%s*%[.%]%s+Procedures") then
      state.object_types.procedure = line:match("%[x%]") ~= nil
    end
    if line:match("^%s*%[.%]%s+Functions") then
      state.object_types["function"] = line:match("%[x%]") ~= nil
    end
    if line:match("^%s*%[.%]%s+Synonyms") then
      state.object_types.synonym = line:match("%[x%]") ~= nil
    end
  end

  return state
end

---Apply current filters and refresh the tree
---@param group BaseDbObject The group being filtered
---@param bufnr number The buffer number
---@param extmarks table Extmark positions
---@param live boolean Whether this is live filtering or final apply
local function apply_filters(group, bufnr, extmarks, live)
  local UiFilters = require('ssns.ui.filters')
  local UiTree = require('ssns.ui.tree')

  -- Parse current state from buffer
  local state = parse_buffer_state(bufnr, extmarks)

  -- Build filter object from state
  local filters = {
    name_include = state.name_include ~= "" and state.name_include or nil,
    name_exclude = state.name_exclude ~= "" and state.name_exclude or nil,
    schema_include = state.schema_include ~= "" and state.schema_include or nil,
    schema_exclude = state.schema_exclude ~= "" and state.schema_exclude or nil,
    object_types = next(state.object_types) and state.object_types or nil,
    case_sensitive = state.case_sensitive,
    hide_system_schemas = state.hide_system_schemas
  }

  -- Save filters
  UiFilters.set(group, filters)

  -- Refresh the tree to apply filters
  UiTree.render()

  -- If not live filtering, close the popup
  if not live then
    close_popup()
  end
end

---Debounced live filtering
---@param group BaseDbObject The group being filtered
---@param bufnr number The buffer number
---@param extmarks table Extmark positions
local function trigger_live_filter(group, bufnr, extmarks)
  -- Clear existing timer
  if debounce_timer then
    vim.fn.timer_stop(debounce_timer)
  end

  -- Set new timer (100ms debounce)
  debounce_timer = vim.fn.timer_start(100, function()
    apply_filters(group, bufnr, extmarks, true)
    debounce_timer = nil
  end)
end

---Render the filter editor UI with extmarks for editable regions
---@param bufnr number The buffer number
---@param group BaseDbObject The group being filtered
---@param state table Current editor state
---@return table extmarks Table of extmark IDs
local function render_editor(bufnr, group, state)
  local lines = {}
  local extmarks = {}
  local current_line = 0
  local option_num = 0

  -- Title (empty line for spacing)
  table.insert(lines, "")
  current_line = current_line + 1

  -- Name include filter
  table.insert(lines, "Include Name (regex):")
  current_line = current_line + 1

  local name_inc_value = state.name_include or ""
  table.insert(lines, string.format('  "%s"', name_inc_value))
  current_line = current_line + 1
  option_num = option_num + 1
  extmarks["option_" .. option_num] = {
    line = current_line,
    type = "text",
    field = "name_include"
  }

  table.insert(lines, "")
  current_line = current_line + 1

  -- Name exclude filter
  table.insert(lines, "Exclude Name (regex):")
  current_line = current_line + 1

  local name_exc_value = state.name_exclude or ""
  table.insert(lines, string.format('  "%s"', name_exc_value))
  current_line = current_line + 1
  option_num = option_num + 1
  extmarks["option_" .. option_num] = {
    line = current_line,
    type = "text",
    field = "name_exclude"
  }

  table.insert(lines, "")
  current_line = current_line + 1

  -- Schema filters (only for object groups like TABLES, VIEWS, etc.)
  local schema_inc_line, schema_exc_line
  local is_object_group = group.object_type and (
    group.object_type == "tables_group" or
    group.object_type == "views_group" or
    group.object_type == "procedures_group" or
    group.object_type == "functions_group" or
    group.object_type == "synonyms_group" or
    group.object_type == "sequences_group"
  )

  if is_object_group then
    table.insert(lines, "Include Schema (regex):")
    current_line = current_line + 1

    local schema_inc_value = state.schema_include or ""
    table.insert(lines, string.format('  "%s"', schema_inc_value))
    current_line = current_line + 1
    schema_inc_line = current_line
    option_num = option_num + 1
    extmarks["option_" .. option_num] = {
      line = current_line,
      type = "text",
      field = "schema_include"
    }

    table.insert(lines, "")
    current_line = current_line + 1

    table.insert(lines, "Exclude Schema (regex):")
    current_line = current_line + 1

    local schema_exc_value = state.schema_exclude or ""
    table.insert(lines, string.format('  "%s"', schema_exc_value))
    current_line = current_line + 1
    schema_exc_line = current_line
    option_num = option_num + 1
    extmarks["option_" .. option_num] = {
      line = current_line,
      type = "text",
      field = "schema_exclude"
    }

    table.insert(lines, "")
    current_line = current_line + 1
  end

  -- Object type filters (for individual schema nodes)
  local is_schema_node = group.object_type == "schema" or group.object_type == "schema_view"
  if is_schema_node then
    table.insert(lines, "Object Types: (Enter to toggle)")
    current_line = current_line + 1

    local types = {
      {"table", "Tables"},
      {"view", "Views"},
      {"procedure", "Procedures"},
      {"function", "Functions"},
      {"synonym", "Synonyms"}
    }
    for _, type_info in ipairs(types) do
      local obj_type = type_info[1]
      local label = type_info[2]
      local checked = state.object_types[obj_type] and "x" or " "
      table.insert(lines, string.format("  [%s] %s", checked, label))
      current_line = current_line + 1
      option_num = option_num + 1
      extmarks["option_" .. option_num] = {
        line = current_line,
        type = "checkbox",
        field = "object_type_" .. obj_type
      }
    end
    table.insert(lines, "")
    current_line = current_line + 1
  end

  -- Case sensitive checkbox
  local case_check = state.case_sensitive and "x" or " "
  table.insert(lines, string.format("Case Sensitive: [%s] (Enter to toggle)", case_check))
  current_line = current_line + 1
  option_num = option_num + 1
  extmarks["option_" .. option_num] = {
    line = current_line,
    type = "checkbox",
    field = "case_sensitive"
  }

  table.insert(lines, "")
  current_line = current_line + 1

  -- Hide system schemas checkbox (only for object groups that support it)
  local supports_system_filter = is_object_group or group.object_type == "schemas_group"
  if supports_system_filter then
    local sys_check = state.hide_system_schemas and "x" or " "
    table.insert(lines, string.format("Hide System Schemas: [%s] (Enter to toggle)", sys_check))
    current_line = current_line + 1
    option_num = option_num + 1
    extmarks["option_" .. option_num] = {
      line = current_line,
      type = "checkbox",
      field = "hide_system_schemas"
    }

    table.insert(lines, "")
    current_line = current_line + 1
  end

  -- Help text
  table.insert(lines, "Edit text between quotes with 'i' or 'a'")
  current_line = current_line + 1
  table.insert(lines, "<leader>a Apply  <Esc> Cancel  F Clear")

  -- Set lines first
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Now create extmarks for editable regions (between quotes) and option markers
  -- Name include: line 2 (0-indexed: 2)
  local name_inc_line_idx = 2
  extmarks.name_include_start = vim.api.nvim_buf_set_extmark(bufnr, ns_id, name_inc_line_idx, 3, {right_gravity = false})
  extmarks.name_include_end = vim.api.nvim_buf_set_extmark(bufnr, ns_id, name_inc_line_idx, 3 + #name_inc_value, {right_gravity = true})

  -- Name exclude: line 5 (0-indexed: 5)
  local name_exc_line_idx = 5
  extmarks.name_exclude_start = vim.api.nvim_buf_set_extmark(bufnr, ns_id, name_exc_line_idx, 3, {right_gravity = false})
  extmarks.name_exclude_end = vim.api.nvim_buf_set_extmark(bufnr, ns_id, name_exc_line_idx, 3 + #name_exc_value, {right_gravity = true})

  -- Schema filters if present
  if schema_inc_line then
    local schema_inc_line_idx = schema_inc_line - 1  -- Convert to 0-indexed
    local schema_inc_value = state.schema_include or ""
    extmarks.schema_include_start = vim.api.nvim_buf_set_extmark(bufnr, ns_id, schema_inc_line_idx, 3, {right_gravity = false})
    extmarks.schema_include_end = vim.api.nvim_buf_set_extmark(bufnr, ns_id, schema_inc_line_idx, 3 + #schema_inc_value, {right_gravity = true})
  end

  if schema_exc_line then
    local schema_exc_line_idx = schema_exc_line - 1  -- Convert to 0-indexed
    local schema_exc_value = state.schema_exclude or ""
    extmarks.schema_exclude_start = vim.api.nvim_buf_set_extmark(bufnr, ns_id, schema_exc_line_idx, 3, {right_gravity = false})
    extmarks.schema_exclude_end = vim.api.nvim_buf_set_extmark(bufnr, ns_id, schema_exc_line_idx, 3 + #schema_exc_value, {right_gravity = true})
  end

  -- Store total option count
  extmarks.total_options = option_num

  return extmarks
end

---Move cursor to next/previous option
---@param bufnr number The buffer number
---@param winid number The window ID
---@param extmarks table Extmark positions with option metadata
---@param direction number 1 for next, -1 for previous
local function move_to_next_field(bufnr, winid, extmarks, direction)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local current_line = cursor[1]

  -- Get all options from extmarks
  local options = {}
  for key, data in pairs(extmarks) do
    if key:match("^option_%d+$") and type(data) == "table" then
      local opt_num = tonumber(key:match("%d+"))
      options[opt_num] = data
    end
  end

  local total_options = extmarks.total_options or 0
  if total_options == 0 then
    return
  end

  -- Find current option number based on cursor line
  local current_option = nil
  for opt_num, data in pairs(options) do
    if data.line == current_line then
      current_option = opt_num
      break
    end
  end

  -- If not on an option line, find closest option
  if not current_option then
    if direction > 0 then
      -- Find first option after current line
      for opt_num = 1, total_options do
        if options[opt_num] and options[opt_num].line > current_line then
          current_option = opt_num - 1
          break
        end
      end
      current_option = current_option or total_options
    else
      -- Find first option before current line
      for opt_num = total_options, 1, -1 do
        if options[opt_num] and options[opt_num].line < current_line then
          current_option = opt_num + 1
          break
        end
      end
      current_option = current_option or 1
    end
  end

  -- Calculate next option with wrapping
  local next_option = current_option + direction
  if next_option > total_options then
    next_option = 1  -- Wrap to first
  elseif next_option < 1 then
    next_option = total_options  -- Wrap to last
  end

  -- Get target option data
  local target_data = options[next_option]
  if not target_data then
    return
  end

  local target_line = target_data.line
  local target_col = 0

  -- Position cursor based on option type
  if target_data.type == "text" then
    -- For text fields, position at end of text inside quotes
    local field_name = target_data.field
    local end_mark_id = extmarks[field_name .. "_end"]
    if end_mark_id then
      local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, end_mark_id, {})
      if #pos > 0 and pos[1] + 1 == target_line then
        target_col = pos[2]
      else
        target_col = 3  -- Default to start of quotes
      end
    else
      target_col = 3  -- Default to start of quotes
    end
  elseif target_data.type == "checkbox" then
    -- For checkboxes, position at the checkbox itself
    target_col = 2  -- Position at the '[' character
  end

  -- Set cursor to target position
  vim.api.nvim_win_set_cursor(winid, {target_line, target_col})
end

---Toggle checkbox on current line
---@param bufnr number The buffer number
---@param group BaseDbObject The group being filtered
---@param extmarks table Extmark positions
local function toggle_checkbox(bufnr, group, extmarks)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]

  if not line then
    return
  end

  -- Toggle case sensitive
  if line:match("^Case Sensitive:") then
    local new_line = line:match("%[x%]") and line:gsub("%[x%]", "[ ]") or line:gsub("%[ %]", "[x]")
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})
    trigger_live_filter(group, bufnr, extmarks)
    return
  end

  -- Toggle hide system schemas
  if line:match("^Hide System Schemas:") then
    local new_line = line:match("%[x%]") and line:gsub("%[x%]", "[ ]") or line:gsub("%[ %]", "[x]")
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})
    trigger_live_filter(group, bufnr, extmarks)
    return
  end

  -- Toggle object types
  if line:match("^%s*%[.%]%s+") then
    local new_line = line:match("%[x%]") and line:gsub("%[x%]", "[ ]") or line:gsub("%[ %]", "[x]")
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})
    trigger_live_filter(group, bufnr, extmarks)
    return
  end
end

---Open the filter editor for a group
---@param group BaseDbObject The group to filter
function UiFilterEditor.open(group)
  -- Close existing popup
  close_popup()

  local UiFilters = require('ssns.ui.filters')

  -- Get current filters or create new
  local current_filters = UiFilters.get(group)

  -- Check if this is a schema node (needs object_types)
  local is_schema_node = group.object_type == "schema" or group.object_type == "schema_view"

  -- Initialize editor state
  local state = {
    name_include = current_filters.name_include or "",
    name_exclude = current_filters.name_exclude or "",
    schema_include = current_filters.schema_include or "",
    schema_exclude = current_filters.schema_exclude or "",
    object_types = current_filters.object_types or (is_schema_node and {
      table = true,
      view = true,
      procedure = true,
      ["function"] = true,
      synonym = true
    } or {}),
    case_sensitive = current_filters.case_sensitive or false,
    hide_system_schemas = current_filters.hide_system_schemas or false
  }

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'ssns-filter')
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')

  -- Calculate window size
  local width = 48
  local height = group.object_type == "schemas_group" and 20 or 22
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Open floating window with title
  local title = string.format(" Filter: %s ", group.name)
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  })

  -- Set window options
  vim.api.nvim_win_set_option(winid, 'winhl', 'Normal:Normal')

  -- Render initial UI and get extmarks
  local extmarks = render_editor(bufnr, group, state)

  -- Keep buffer modifiable for editing
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)

  -- Save popup state with original filters for cancel support
  current_popup = {
    bufnr = bufnr,
    winid = winid,
    group = group,
    extmarks = extmarks,
    original_filters = vim.deepcopy(current_filters),  -- Deep copy for restore on cancel
  }

  -- Set up autocmds for live filtering
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    buffer = bufnr,
    callback = function()
      trigger_live_filter(group, bufnr, extmarks)
    end
  })

  -- Set up keymaps
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Cancel on Esc (restore original filters)
  vim.keymap.set('n', '<Esc>', function()
    close_popup(true)  -- true = cancel and restore original filters
  end, opts)

  -- Clear filters on F (don't restore, actually clear)
  vim.keymap.set('n', 'F', function()
    UiFilters.clear(group)
    close_popup(false)  -- false = don't cancel, keep the cleared state
    local UiTree = require('ssns.ui.tree')
    UiTree.render()
  end, opts)

  -- Apply on <leader>a
  vim.keymap.set('n', '<leader>a', function()
    apply_filters(group, bufnr, extmarks, false)
  end, opts)

  -- Toggle checkboxes on Enter
  vim.keymap.set('n', '<CR>', function()
    toggle_checkbox(bufnr, group, extmarks)
  end, opts)

  -- Smart navigation with j/k to jump between editable fields
  vim.keymap.set('n', 'j', function()
    move_to_next_field(bufnr, winid, extmarks, 1)
  end, opts)

  vim.keymap.set('n', 'k', function()
    move_to_next_field(bufnr, winid, extmarks, -1)
  end, opts)

  -- Move cursor to first editable field (between quotes on line 3)
  vim.api.nvim_win_set_cursor(winid, {3, 4})  -- Line 3, column 4 (inside quotes)
end

return UiFilterEditor
