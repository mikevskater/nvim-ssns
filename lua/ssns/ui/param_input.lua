---@class UiParamInput
---Parameter input UI for stored procedures
local UiParamInput = {}

---@class ProcedureParameter
---@field name string Parameter name (e.g., "@param1")
---@field data_type string Data type (e.g., "int", "varchar(50)")
---@field direction string Direction: "IN", "OUT", "INOUT"
---@field default_value string? Default value if available
---@field is_nullable boolean Whether parameter accepts NULL
---@field value string User-entered value

---@class ParamInputState
---@field main_buf number Main window buffer
---@field main_win number Main window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field procedure_name string Full procedure name (schema.name)
---@field server_name string Server name
---@field database_name string? Database name
---@field parameters ProcedureParameter[] List of parameters
---@field selected_param_idx number Currently selected parameter index
---@field callback function Callback function with parameter values

---@type ParamInputState?
local state = nil

---Show parameter input form
---@param procedure_name string The procedure name
---@param server_name string The server name
---@param database_name string? The database name
---@param parameters ProcedureParameter[] List of parameters
---@param callback function Callback function(values: table<string, string>)
function UiParamInput.show_input(procedure_name, server_name, database_name, parameters, callback)
  if #parameters == 0 then
    vim.notify("SSNS: Procedure has no input parameters", vim.log.levels.INFO)
    callback({})
    return
  end

  -- Filter out output-only parameters
  local input_params = {}
  for _, param in ipairs(parameters) do
    if param.direction == "IN" or param.direction == "INOUT" then
      param.value = param.default_value or ""
      table.insert(input_params, param)
    end
  end

  if #input_params == 0 then
    vim.notify("SSNS: Procedure has no input parameters", vim.log.levels.INFO)
    callback({})
    return
  end

  -- Initialize state
  state = {
    procedure_name = procedure_name,
    server_name = server_name,
    database_name = database_name,
    parameters = input_params,
    selected_param_idx = 1,
    callback = callback,
  }

  -- Create the layout
  UiParamInput._create_layout()

  -- Render content
  UiParamInput._render()

  -- Setup keymaps
  UiParamInput._setup_keymaps()
end

---Create the floating window layout
function UiParamInput._create_layout()
  local cols = vim.o.columns
  local lines = vim.o.lines

  -- Calculate dimensions: 50% width, auto height based on parameter count
  local width = math.floor(cols * 0.5)
  local height = math.min(3 + (#state.parameters * 3), math.floor(lines * 0.7))  -- 3 lines per param + header
  local row = math.floor((lines - height) / 2) - 2  -- -2 for footer
  local col = math.floor((cols - width) / 2)

  -- Create main buffer
  state.main_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.main_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(state.main_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(state.main_buf, 'bufhidden', 'wipe')

  -- Create main window
  state.main_win = vim.api.nvim_open_win(state.main_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" Procedure Parameters: %s ", state.procedure_name),
    title_pos = "center",
    zindex = 50,
  })

  -- Configure window options
  vim.api.nvim_set_option_value('number', false, { win = state.main_win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = state.main_win })
  vim.api.nvim_set_option_value('cursorline', false, { win = state.main_win })
  vim.api.nvim_set_option_value('wrap', false, { win = state.main_win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = state.main_win })

  -- Create footer
  state.footer_buf = vim.api.nvim_create_buf(false, true)
  local footer_text = " <Enter>=Execute | <Esc>=Cancel | <Tab>=Next | j/k=Navigate | i=Edit "
  local footer_padding = math.floor((width - #footer_text) / 2)
  local centered_footer = string.rep(" ", footer_padding) .. footer_text

  vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_footer})
  vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

  state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    row = row + height + 2,
    col = col,
    style = "minimal",
    border = "none",
    zindex = 51,
    focusable = false,
  })

  vim.api.nvim_set_option_value('winhighlight', 'Normal:Comment', { win = state.footer_win })
end

---Render parameter form
function UiParamInput._render()
  local lines = {}

  -- Header
  table.insert(lines, string.format("Server: %s | Database: %s",
    state.server_name, state.database_name or "N/A"))
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  -- Parameters
  for i, param in ipairs(state.parameters) do
    local prefix = i == state.selected_param_idx and "▶ " or "  "
    local has_default = param.has_default or param.default_value
    local optional_info = has_default and " [OPTIONAL]" or ""
    local default_info = param.default_value and string.format(", default: %s", param.default_value) or (has_default and ", has default" or "")

    table.insert(lines, string.format("%s%s (%s, %s%s)%s",
      prefix, param.name, param.data_type, param.direction, default_info, optional_info))
    table.insert(lines, string.format("  Value: %s", param.value or ""))
    table.insert(lines, "")
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.main_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.main_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.main_buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_param_input")
  vim.api.nvim_buf_clear_namespace(state.main_buf, ns_id, 0, -1)

  -- Highlight header
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Comment", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Comment", 1, 0, -1)

  -- Highlight selected parameter
  local selected_line = 3 + (state.selected_param_idx - 1) * 3
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "Title", selected_line, 0, -1)
  vim.api.nvim_buf_add_highlight(state.main_buf, ns_id, "String", selected_line + 1, 0, -1)

  -- Set cursor to selected parameter value line
  pcall(vim.api.nvim_win_set_cursor, state.main_win, {selected_line + 2, 8})
end

---Setup keymaps
function UiParamInput._setup_keymaps()
  -- Cancel
  vim.keymap.set('n', '<Esc>', function()
    UiParamInput._close(false)
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Cancel" })

  vim.keymap.set('n', 'q', function()
    UiParamInput._close(false)
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Cancel" })

  -- Execute
  vim.keymap.set('n', '<CR>', function()
    UiParamInput._execute()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Execute" })

  -- Navigation
  vim.keymap.set('n', 'j', function()
    UiParamInput._move_down()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Next parameter" })

  vim.keymap.set('n', 'k', function()
    UiParamInput._move_up()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Previous parameter" })

  vim.keymap.set('n', '<Tab>', function()
    UiParamInput._move_down()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Next parameter" })

  vim.keymap.set('n', '<S-Tab>', function()
    UiParamInput._move_up()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Previous parameter" })

  -- Edit value
  vim.keymap.set('n', 'i', function()
    UiParamInput._edit_value()
  end, { buffer = state.main_buf, noremap = true, silent = true, desc = "Edit value" })
end

---Move to next parameter
function UiParamInput._move_down()
  if state.selected_param_idx < #state.parameters then
    state.selected_param_idx = state.selected_param_idx + 1
    UiParamInput._render()
  end
end

---Move to previous parameter
function UiParamInput._move_up()
  if state.selected_param_idx > 1 then
    state.selected_param_idx = state.selected_param_idx - 1
    UiParamInput._render()
  end
end

---Edit current parameter value
function UiParamInput._edit_value()
  local param = state.parameters[state.selected_param_idx]
  local current_value = param.value or ""

  -- Prompt for new value
  vim.ui.input({
    prompt = string.format("%s (%s): ", param.name, param.data_type),
    default = current_value,
  }, function(input)
    if input ~= nil then
      param.value = input
      UiParamInput._render()
    end
  end)
end

---Execute with current parameter values
function UiParamInput._execute()
  -- Collect parameter values
  local values = {}
  for _, param in ipairs(state.parameters) do
    values[param.name] = param.value
  end

  UiParamInput._close(true, values)
end

---Close parameter input form
---@param execute boolean Whether to execute
---@param values table? Parameter values if executing
function UiParamInput._close(execute, values)
  if not state then
    return
  end

  -- Close windows
  if state.main_win and vim.api.nvim_win_is_valid(state.main_win) then
    pcall(vim.api.nvim_win_close, state.main_win, true)
  end
  if state.footer_win and vim.api.nvim_win_is_valid(state.footer_win) then
    pcall(vim.api.nvim_win_close, state.footer_win, true)
  end

  -- Call callback if executing
  if execute and values and state.callback then
    state.callback(values)
  end

  state = nil
end

return UiParamInput
