---@class FormatterRulesEditorRender
---Rendering functions for the formatter rules editor
---Uses ContentBuilder for themed UI in presets and rules panels
local M = {}

local Helpers = require('nvim-ssns.formatter.rules_editor_helpers')
local Formatter = require('nvim-ssns.formatter')
local Data = require('nvim-ssns.formatter.rules_editor_data')
local ContentBuilder = require('nvim-float.content')

---Render the presets panel using ContentBuilder
---@param state RulesEditorState
---@return string[] lines, table[] highlights
function M.render_presets(state)
  local cb = ContentBuilder.new()

  if not state then
    return cb:build_lines(), cb:build_highlights()
  end

  cb:blank()

  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Add section headers
    if not preset.is_user and not builtin_added then
      cb:styled(" ─── Built-in ───", "muted")
      cb:blank()
      builtin_added = true
    elseif preset.is_user and not user_added then
      if builtin_added then
        cb:blank()
      end
      cb:styled(" ─── User ───", "muted")
      cb:blank()
      user_added = true
    end

    local is_selected = (i == state.selected_preset_idx)
    local prefix = is_selected and " ▸ " or "   "

    if is_selected then
      -- Selected preset - highlight entire line
      cb:spans({
        { text = prefix, style = "emphasis" },
        { text = preset.name, style = "highlight" },
      })
    else
      cb:spans({
        { text = prefix, style = "muted" },
        { text = preset.name, style = "normal" },
      })
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

---Render the rules panel using embedded containers
---@param state RulesEditorState
---@param multi_panel MultiPanelState? Multi-panel for re-rendering preview on change
---@return ContentBuilder cb
function M.render_rules(state, multi_panel)
  local cb = ContentBuilder.new()

  if not state then
    return cb
  end

  cb:blank()

  local current_category = nil

  -- Helper to re-render preview after a rule change
  local function on_rule_changed()
    state.is_dirty = true
    if multi_panel and multi_panel:is_valid() then
      multi_panel:render_panel("preview")
      M.apply_preview_highlights(multi_panel)
    end
  end

  for _, rule in ipairs(state.rule_definitions) do
    -- Add category header if new category
    if rule.category ~= current_category then
      if current_category ~= nil then
        cb:blank()
      end
      cb:styled(string.format(" ─── %s ───", rule.category), "section")
      cb:blank()
      current_category = rule.category
    end

    local value = Helpers.get_config_value(state.current_config, rule.key)
    local container_key = "rule_" .. rule.key:gsub("%.", "_")

    if rule.type == "boolean" then
      cb:embedded_dropdown(container_key, {
        label = "   " .. rule.name,
        options = {
          { value = "true", label = "On" },
          { value = "false", label = "Off" },
        },
        selected = value and "true" or "false",
        width = 6,
        on_change = function(_, v)
          Helpers.set_config_value(state.current_config, rule.key, v == "true")
          on_rule_changed()
        end,
      })
    elseif rule.type == "number" then
      cb:embedded_input(container_key, {
        label = "   " .. rule.name,
        value = tostring(value or 0),
        width = 6,
        on_change = function(_, v)
          local num = tonumber(v)
          if num then
            if rule.min and num < rule.min then num = rule.min end
            if rule.max and num > rule.max then num = rule.max end
            Helpers.set_config_value(state.current_config, rule.key, num)
            on_rule_changed()
          end
        end,
      })
    elseif rule.type == "enum" then
      local enum_options = {}
      for _, opt in ipairs(rule.options or {}) do
        table.insert(enum_options, { value = opt, label = opt })
      end
      cb:embedded_dropdown(container_key, {
        label = "   " .. rule.name,
        options = enum_options,
        selected = tostring(value or ""),
        width = 15,
        on_change = function(_, v)
          Helpers.set_config_value(state.current_config, rule.key, v)
          on_rule_changed()
        end,
      })
    end
  end

  cb:blank()

  return cb
end

---Render the preview panel (raw SQL buffer - no ContentBuilder)
---Returns plain lines for the buffer, semantic highlighting applied separately
---@param state RulesEditorState
---@return string[] lines, table[] highlights (empty - semantic highlighter handles it)
function M.render_preview(state)
  if not state then
    return {}, {}
  end

  -- Format the preview SQL with current config
  local formatted = Formatter.format(Data.PREVIEW_SQL, state.current_config)
  local lines = vim.split(formatted, '\n')

  -- Return empty highlights - semantic highlighter will handle SQL highlighting
  return lines, {}
end

---Apply semantic highlighting to preview buffer
---@param multi_panel MultiPanelState
function M.apply_preview_highlights(multi_panel)
  if not multi_panel then return end
  local preview_buf = multi_panel:get_panel_buffer("preview")
  if not preview_buf then return end

  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.enable then
    pcall(SemanticHighlighter.enable, preview_buf)
    vim.defer_fn(function()
      if multi_panel and preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
        pcall(SemanticHighlighter.update, preview_buf)
      end
    end, 50)
  end
end

---Disable semantic highlighting on preview
---@param multi_panel MultiPanelState
function M.disable_preview_highlights(multi_panel)
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.disable and multi_panel then
    local preview_buf = multi_panel:get_panel_buffer("preview")
    if preview_buf then
      pcall(SemanticHighlighter.disable, preview_buf)
    end
  end
end

return M
