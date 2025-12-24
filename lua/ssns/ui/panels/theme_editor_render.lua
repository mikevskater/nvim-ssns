---@class ThemeEditorRender
---Rendering functions for the theme editor
local M = {}

local ContentBuilder = require('ssns.ui.core.content_builder')
local Data = require('ssns.ui.panels.theme_editor_data')
local PreviewSql = require('ssns.ui.panels.theme_preview_sql')

-- ============================================================================
-- Themes Panel (Left)
-- ============================================================================

---Render the themes list panel
---@param state ThemeEditorState
---@return string[] lines, table[] highlights
function M.render_themes(state)
  local cb = ContentBuilder.new()

  if not state then
    return cb:build_lines(), cb:build_highlights()
  end

  cb:blank()

  local user_section_added = false

  for i, theme in ipairs(state.available_themes) do
    local is_selected = i == state.selected_theme_idx

    -- Add separator after Default option
    if theme.is_default then
      if is_selected then
        cb:spans({
          { text = " ▸ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
        })
      end

      cb:blank()
      cb:styled(" ─── Built-in ───", "muted")
      cb:blank()
    elseif theme.is_user and not user_section_added then
      cb:blank()
      cb:styled(" ─── User Themes ───", "muted")
      cb:blank()
      user_section_added = true

      if is_selected then
        cb:spans({
          { text = " ▸ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
        })
      end
    else
      if is_selected then
        cb:spans({
          { text = " ▸ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
        })
      end
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

-- ============================================================================
-- Colors Panel (Middle)
-- ============================================================================

---Format a color value for display
---@param color_def table? Color definition {fg, bg, bold, italic, etc.}
---@return string formatted_value
local function format_color_value(color_def)
  if not color_def or type(color_def) ~= "table" then
    return "─"
  end

  local parts = {}

  if color_def.fg then
    table.insert(parts, color_def.fg)
  end

  if color_def.bg then
    table.insert(parts, "bg:" .. color_def.bg)
  end

  local modifiers = {}
  if color_def.bold then table.insert(modifiers, "B") end
  if color_def.italic then table.insert(modifiers, "I") end
  if color_def.underline then table.insert(modifiers, "U") end

  if #modifiers > 0 then
    table.insert(parts, "[" .. table.concat(modifiers) .. "]")
  end

  if #parts == 0 then
    return "─"
  end

  return table.concat(parts, " ")
end

---Render the colors panel
---@param state ThemeEditorState
---@return string[] lines, table[] highlights
function M.render_colors(state)
  local cb = ContentBuilder.new()

  if not state or not state.current_colors then
    return cb:build_lines(), cb:build_highlights()
  end

  cb:blank()

  local current_category = nil

  for i, def in ipairs(Data.COLOR_DEFINITIONS) do
    -- Add category header if new category
    if def.category ~= current_category then
      if current_category ~= nil then
        cb:blank()
      end
      cb:styled(string.format(" ─── %s ───", def.category), "section")
      cb:blank()
      current_category = def.category
    end

    local color_value = state.current_colors[def.key]
    local display_value = format_color_value(color_value)
    local is_selected = (i == state.selected_color_idx)

    -- Format: "  ▸ Color Name        #HEXVAL [BI]"
    local prefix = is_selected and " ▸ " or "   "
    local name_width = 18
    local padded_name = def.name .. string.rep(" ", math.max(0, name_width - #def.name))

    -- Create a color swatch indicator using the actual color
    local swatch = "●"
    local swatch_hl = nil
    if color_value and color_value.fg then
      -- We'll create a dynamic highlight for the swatch
      swatch_hl = "ThemeEditorSwatch" .. i
    end

    if is_selected then
      cb:spans({
        { text = prefix, style = "emphasis" },
        { text = padded_name, style = "highlight" },
        { text = swatch .. " ", hl_group = swatch_hl or "SsnsFloatHint" },
        { text = display_value, style = "string" },
      })
    else
      cb:spans({
        { text = prefix, style = "muted" },
        { text = padded_name, style = "label" },
        { text = swatch .. " ", hl_group = swatch_hl or "SsnsFloatHint" },
        { text = display_value, style = "muted" },
      })
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

-- ============================================================================
-- Preview Panel (Right)
-- ============================================================================

---Render the preview panel
---Uses PreviewSql module for consistent preview across theme picker and editor
---@param state ThemeEditorState
---@return string[] lines, table[] highlights
function M.render_preview(state)
  -- Use pre-defined highlights from PreviewSql (no parser needed)
  return PreviewSql.build()
end

-- ============================================================================
-- Color Swatch Highlights
-- ============================================================================

---Apply color swatch highlights to the colors buffer
---Creates dynamic highlight groups for each color's swatch indicator
---@param bufnr number Buffer number for the colors panel
---@param state ThemeEditorState
function M.apply_swatch_highlights(bufnr, state)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not state or not state.current_colors then return end

  for i, def in ipairs(Data.COLOR_DEFINITIONS) do
    local color_value = state.current_colors[def.key]
    if color_value and color_value.fg then
      local hl_name = "ThemeEditorSwatch" .. i
      vim.api.nvim_set_hl(0, hl_name, { fg = color_value.fg })
    end
  end
end

---Clear swatch highlights
function M.clear_swatch_highlights()
  for i = 1, #Data.COLOR_DEFINITIONS do
    local hl_name = "ThemeEditorSwatch" .. i
    pcall(vim.api.nvim_set_hl, 0, hl_name, {})
  end
end

-- ============================================================================
-- Helpers
-- ============================================================================

---Get the line number for a color index (accounting for category headers)
---@param state ThemeEditorState
---@param color_idx number
---@return number line 1-based line number
function M.get_color_cursor_line(state, color_idx)
  if not state then return 2 end

  local line = 2 -- Start after initial blank line
  local current_category = nil

  for i, def in ipairs(Data.COLOR_DEFINITIONS) do
    -- Account for category headers
    if def.category ~= current_category then
      if current_category ~= nil then
        line = line + 1 -- Blank line before category
      end
      line = line + 1 -- Category header
      line = line + 1 -- Blank line after header
      current_category = def.category
    end

    if i == color_idx then
      return line
    end

    line = line + 1
  end

  return 2
end

---Get the line number for a theme index (accounting for section headers)
---@param state ThemeEditorState
---@param theme_idx number
---@return number line 1-based line number
function M.get_theme_cursor_line(state, theme_idx)
  if not state then return 2 end

  local line = 2 -- Start after initial blank line
  local user_section_added = false

  for i, theme in ipairs(state.available_themes) do
    if i == theme_idx then
      return line
    end

    line = line + 1

    -- Account for section separators
    if theme.is_default then
      line = line + 3 -- blank + header + blank
    elseif theme.is_user and not user_section_added then
      line = line + 2 -- blank + header + blank (but we already counted the theme line)
      user_section_added = true
    end
  end

  return 2
end

return M
