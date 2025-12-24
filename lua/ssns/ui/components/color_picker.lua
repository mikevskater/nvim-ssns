---@class ColorPicker
---Interactive color picker with HSL grid navigation
local ColorPicker = {}

local ColorUtils = require('ssns.ui.components.color_utils')

-- ============================================================================
-- Types
-- ============================================================================

---@class ColorPickerColor
---@field fg string? Foreground hex color
---@field bg string? Background hex color
---@field bold boolean?
---@field italic boolean?
---@field underline boolean?

---@class ColorPickerOptions
---@field initial ColorPickerColor Initial color value
---@field title string? Title for the picker (e.g., color key name)
---@field on_change fun(color: ColorPickerColor)? Called on every navigation
---@field on_select fun(color: ColorPickerColor)? Called when user confirms
---@field on_cancel fun()? Called when user cancels

---@class ColorPickerState
---@field current ColorPickerColor Current working color
---@field original ColorPickerColor Original color for reset
---@field editing_bg boolean Whether editing background instead of foreground
---@field grid_width number Current grid width
---@field grid_height number Current grid height
---@field win number? Window handle
---@field buf number? Buffer handle
---@field ns number Namespace for highlights
---@field options ColorPickerOptions

-- ============================================================================
-- Constants
-- ============================================================================

local PREVIEW_HEIGHT = 2    -- Rows for color preview
local FOOTER_HEIGHT = 3     -- Rows for info and controls
local HEADER_HEIGHT = 2     -- Title + blank line
local PADDING = 2           -- Left/right padding

local STEP_HUE = 3          -- Hue degrees per grid cell
local STEP_LIGHTNESS = 2    -- Lightness percent per grid row
local STEP_SATURATION = 2   -- Saturation percent per J/K press

-- ============================================================================
-- State
-- ============================================================================

---@type ColorPickerState?
local state = nil

-- ============================================================================
-- Helpers
-- ============================================================================

---Get the active color (fg or bg based on editing mode)
---@return string hex
local function get_active_color()
  if not state then return "#808080" end
  if state.editing_bg then
    return state.current.bg or "#1E1E1E"
  else
    return state.current.fg or "#FFFFFF"
  end
end

---Set the active color
---@param hex string
local function set_active_color(hex)
  if not state then return end
  hex = ColorUtils.normalize_hex(hex)
  if state.editing_bg then
    state.current.bg = hex
  else
    state.current.fg = hex
  end
end

---Calculate grid dimensions based on window size
---@param win_width number
---@param win_height number
---@return number grid_width, number grid_height
local function calculate_grid_size(win_width, win_height)
  local available_width = win_width - PADDING * 2
  local available_height = win_height - HEADER_HEIGHT - PREVIEW_HEIGHT - FOOTER_HEIGHT - 2 -- 2 for borders around preview

  -- Ensure odd numbers for center alignment
  if available_width % 2 == 0 then available_width = available_width - 1 end
  if available_height % 2 == 0 then available_height = available_height - 1 end

  -- Minimum sizes
  available_width = math.max(11, available_width)
  available_height = math.max(5, available_height)

  return available_width, available_height
end

---Generate highlight group name for a grid cell
---@param row number
---@param col number
---@return string
local function get_cell_hl_group(row, col)
  return string.format("ColorPickerCell_%d_%d", row, col)
end

-- ============================================================================
-- Rendering
-- ============================================================================

---Create highlight groups for the color grid
---@param grid string[][] The color grid
local function create_grid_highlights(grid)
  if not state then return end

  local center_row = math.ceil(#grid / 2)
  local center_col = math.ceil(#grid[1] / 2)

  for row_idx, row in ipairs(grid) do
    for col_idx, color in ipairs(row) do
      local hl_name = get_cell_hl_group(row_idx, col_idx)
      local hl_def = { bg = color }

      -- Center cell gets contrasting foreground for the X marker
      if row_idx == center_row and col_idx == center_col then
        hl_def.fg = ColorUtils.get_contrast_color(color)
        hl_def.bold = true
      end

      vim.api.nvim_set_hl(0, hl_name, hl_def)
    end
  end
end

---Render the color grid to buffer
---@return string[] lines
---@return table[] highlights
local function render_grid()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}

  local center_color = get_active_color()
  local grid = ColorUtils.generate_color_grid(
    center_color,
    state.grid_width,
    state.grid_height,
    STEP_HUE,
    STEP_LIGHTNESS
  )

  -- Create highlight groups
  create_grid_highlights(grid)

  local center_row = math.ceil(#grid / 2)
  local center_col = math.ceil(#grid[1] / 2)

  -- Padding string
  local pad = string.rep(" ", PADDING)

  for row_idx, row in ipairs(grid) do
    local line_chars = {}
    local line_hls = {}

    for col_idx, _ in ipairs(row) do
      local char = " "
      -- Center cell gets X marker
      if row_idx == center_row and col_idx == center_col then
        char = "X"
      end
      table.insert(line_chars, char)

      -- Store highlight info
      table.insert(line_hls, {
        col_start = PADDING + col_idx - 1,
        col_end = PADDING + col_idx,
        hl_group = get_cell_hl_group(row_idx, col_idx),
      })
    end

    local line = pad .. table.concat(line_chars)
    table.insert(lines, line)

    -- Add highlights for this line
    for _, hl in ipairs(line_hls) do
      table.insert(highlights, {
        line = #lines - 1, -- 0-indexed
        col_start = hl.col_start,
        col_end = hl.col_end,
        hl_group = hl.hl_group,
      })
    end
  end

  return lines, highlights
end

---Render the preview section
---@return string[] lines
---@return table[] highlights
local function render_preview()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}
  local pad = string.rep(" ", PADDING)

  -- Create preview highlight
  local preview_color = get_active_color()
  vim.api.nvim_set_hl(0, "ColorPickerPreview", { bg = preview_color })

  -- Preview border
  local preview_width = state.grid_width
  table.insert(lines, pad .. string.rep("─", preview_width))

  -- Preview rows (filled with spaces using background color)
  for i = 1, PREVIEW_HEIGHT do
    local preview_line = pad .. string.rep(" ", preview_width)
    table.insert(lines, preview_line)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = PADDING,
      col_end = PADDING + preview_width,
      hl_group = "ColorPickerPreview",
    })
  end

  table.insert(lines, pad .. string.rep("─", preview_width))

  return lines, highlights
end

---Render the info footer
---@return string[] lines
local function render_footer()
  if not state then return {} end

  local lines = {}
  local pad = string.rep(" ", PADDING)

  -- Original and current color info
  local orig_color = state.editing_bg
    and (state.original.bg or "none")
    or (state.original.fg or "none")
  local curr_color = get_active_color()

  local mode = state.editing_bg and "[bg]" or "[fg]"
  local bold_indicator = state.current.bold and "[B]" or "[ ]"
  local italic_indicator = state.current.italic and "[I]" or "[ ]"

  table.insert(lines, "")
  table.insert(lines, string.format(
    "%sOriginal: %s   Current: %s   %s %s bold %s italic",
    pad, orig_color, curr_color, mode, bold_indicator, italic_indicator
  ))
  table.insert(lines, "")
  table.insert(lines, pad .. "h/l=hue  j/k=light  J/K=sat  b=bold  i=italic  B=bg  r=reset  #=hex")
  table.insert(lines, pad .. "Enter=apply  q/Esc=cancel")

  return lines
end

---Full render of the picker
local function render()
  if not state or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = {}
  local all_highlights = {}

  -- Header
  local pad = string.rep(" ", PADDING)
  local title = state.options.title or "Pick Color"
  table.insert(lines, "")
  table.insert(lines, pad .. title)
  table.insert(lines, "")

  -- Track line offset for highlights
  local line_offset = #lines

  -- Grid
  local grid_lines, grid_highlights = render_grid()
  for _, line in ipairs(grid_lines) do
    table.insert(lines, line)
  end
  for _, hl in ipairs(grid_highlights) do
    hl.line = hl.line + line_offset
    table.insert(all_highlights, hl)
  end

  line_offset = #lines
  table.insert(lines, "") -- Spacing before preview

  -- Preview
  line_offset = #lines
  local preview_lines, preview_highlights = render_preview()
  for _, line in ipairs(preview_lines) do
    table.insert(lines, line)
  end
  for _, hl in ipairs(preview_highlights) do
    hl.line = hl.line + line_offset
    table.insert(all_highlights, hl)
  end

  -- Footer
  local footer_lines = render_footer()
  for _, line in ipairs(footer_lines) do
    table.insert(lines, line)
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  for _, hl in ipairs(all_highlights) do
    vim.api.nvim_buf_add_highlight(
      state.buf,
      state.ns,
      hl.hl_group,
      hl.line,
      hl.col_start,
      hl.col_end
    )
  end

  -- Title highlight
  vim.api.nvim_buf_add_highlight(state.buf, state.ns, "SsnsFloatTitle", 1, 0, -1)

  -- Trigger on_change callback
  if state.options.on_change then
    state.options.on_change(vim.deepcopy(state.current))
  end
end

-- ============================================================================
-- Navigation
-- ============================================================================

---Shift hue
---@param delta number Positive = right (increase hue), negative = left
local function shift_hue(delta)
  if not state then return end
  local current = get_active_color()
  local step = delta * STEP_HUE
  local new_color = ColorUtils.adjust_hue(current, step)
  set_active_color(new_color)
  render()
end

---Shift lightness
---@param delta number Positive = up (increase lightness), negative = down
local function shift_lightness(delta)
  if not state then return end
  local current = get_active_color()
  local step = delta * STEP_LIGHTNESS
  local new_color = ColorUtils.adjust_lightness(current, step)
  set_active_color(new_color)
  render()
end

---Shift saturation
---@param delta number Positive = increase, negative = decrease
local function shift_saturation(delta)
  if not state then return end
  local current = get_active_color()
  local step = delta * STEP_SATURATION
  local new_color = ColorUtils.adjust_saturation(current, step)
  set_active_color(new_color)
  render()
end

---Toggle bold
local function toggle_bold()
  if not state then return end
  state.current.bold = not state.current.bold
  render()
end

---Toggle italic
local function toggle_italic()
  if not state then return end
  state.current.italic = not state.current.italic
  render()
end

---Toggle editing fg/bg
local function toggle_bg_mode()
  if not state then return end
  state.editing_bg = not state.editing_bg
  render()
end

---Reset to original color
local function reset_color()
  if not state then return end
  state.current = vim.deepcopy(state.original)
  state.editing_bg = false
  render()
end

---Enter hex input mode
local function enter_hex_input()
  if not state then return end

  local current = get_active_color()

  vim.ui.input({
    prompt = "Enter hex color: ",
    default = current,
  }, function(input)
    if input and ColorUtils.is_valid_hex(input) then
      set_active_color(input)
      render()
    elseif input then
      vim.notify("Invalid hex color: " .. input, vim.log.levels.WARN)
    end
  end)
end

---Apply and close
local function apply()
  if not state then return end

  local result = vim.deepcopy(state.current)

  if state.options.on_select then
    state.options.on_select(result)
  end

  ColorPicker.close()
end

---Cancel and close
local function cancel()
  if not state then return end

  if state.options.on_cancel then
    state.options.on_cancel()
  end

  ColorPicker.close()
end

-- ============================================================================
-- Keymaps
-- ============================================================================

---Setup keymaps with vim count support
local function setup_keymaps()
  if not state or not state.buf then return end

  local buf = state.buf

  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  -- Navigation with count support
  map("h", function()
    local count = vim.v.count1
    shift_hue(-count)
  end)

  map("l", function()
    local count = vim.v.count1
    shift_hue(count)
  end)

  map("k", function()
    local count = vim.v.count1
    shift_lightness(count)
  end)

  map("j", function()
    local count = vim.v.count1
    shift_lightness(-count)
  end)

  -- Saturation with Shift + j/k
  map("K", function()
    local count = vim.v.count1
    shift_saturation(count)
  end)

  map("J", function()
    local count = vim.v.count1
    shift_saturation(-count)
  end)

  -- Toggles
  map("b", toggle_bold)
  map("i", toggle_italic)
  map("B", toggle_bg_mode)

  -- Actions
  map("r", reset_color)
  map("#", enter_hex_input)
  map("<CR>", apply)
  map("q", cancel)
  map("<Esc>", cancel)
end

-- ============================================================================
-- Window Management
-- ============================================================================

---Handle window resize
local function on_resize()
  if not state or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local win_width = vim.api.nvim_win_get_width(state.win)
  local win_height = vim.api.nvim_win_get_height(state.win)

  local new_width, new_height = calculate_grid_size(win_width, win_height)

  if new_width ~= state.grid_width or new_height ~= state.grid_height then
    state.grid_width = new_width
    state.grid_height = new_height
    render()
  end
end

---Close the color picker
function ColorPicker.close()
  if not state then return end

  -- Clean up highlight groups
  for row = 1, (state.grid_height or 20) do
    for col = 1, (state.grid_width or 60) do
      pcall(vim.api.nvim_set_hl, 0, get_cell_hl_group(row, col), {})
    end
  end
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerPreview", {})

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  state = nil
end

---Show the color picker
---@param options ColorPickerOptions
function ColorPicker.show(options)
  -- Close existing picker
  ColorPicker.close()

  -- Validate options
  if not options or not options.initial then
    vim.notify("ColorPicker: initial color required", vim.log.levels.ERROR)
    return
  end

  -- Normalize initial color
  local initial = vim.deepcopy(options.initial)
  if initial.fg then
    initial.fg = ColorUtils.normalize_hex(initial.fg)
  else
    initial.fg = "#808080"
  end
  if initial.bg then
    initial.bg = ColorUtils.normalize_hex(initial.bg)
  end

  -- Calculate window size
  local ui = vim.api.nvim_list_uis()[1]
  local max_width = math.floor(ui.width * 0.8)
  local max_height = math.floor(ui.height * 0.7)

  -- Ensure reasonable minimums
  max_width = math.max(50, max_width)
  max_height = math.max(15, max_height)

  local grid_width, grid_height = calculate_grid_size(max_width, max_height)

  -- Calculate actual window size needed
  local win_width = grid_width + PADDING * 2
  local win_height = HEADER_HEIGHT + grid_height + 1 + PREVIEW_HEIGHT + 2 + FOOTER_HEIGHT

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "ssns-colorpicker")

  -- Create window
  local row = math.floor((ui.height - win_height) / 2)
  local col = math.floor((ui.width - win_width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Color Picker ",
    title_pos = "center",
    zindex = 100,
  })

  -- Window options
  vim.api.nvim_win_set_option(win, "cursorline", false)
  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")

  -- Initialize state
  state = {
    current = vim.deepcopy(initial),
    original = vim.deepcopy(initial),
    editing_bg = false,
    grid_width = grid_width,
    grid_height = grid_height,
    win = win,
    buf = buf,
    ns = vim.api.nvim_create_namespace("ssns_color_picker"),
    options = options,
  }

  -- Setup keymaps
  setup_keymaps()

  -- Setup resize handler
  local augroup = vim.api.nvim_create_augroup("SSNSColorPicker", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = on_resize,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    callback = function()
      vim.api.nvim_del_augroup_by_id(augroup)
      state = nil
    end,
  })

  -- Initial render
  render()
end

---Check if picker is open
---@return boolean
function ColorPicker.is_open()
  return state ~= nil
end

---Get current state (for external access if needed)
---@return ColorPickerState?
function ColorPicker.get_state()
  return state
end

return ColorPicker
