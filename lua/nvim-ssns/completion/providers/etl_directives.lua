---ETL directive completion provider
---Provides IntelliSense for --@ directives and --new block snippets in .ssns files
---
---Uses textEdit with explicit range for all items because --@ contains special
---characters that confuse blink.cmp's default word boundary detection.
---@class EtlDirectivesProvider
local M = {}

local Utils = require('nvim-ssns.completion.utils')
local Directives = require('nvim-ssns.etl.directives')
local EtlSnippets = require('nvim-ssns.completion.data.etl_snippets')

-- ============================================================================
-- Directive metadata for completion items
-- ============================================================================

---Category sort priorities (lower = higher priority)
---@type table<string, number>
local category_priority = {
  block_starter = 1,
  connection = 2,
  documentation = 3,
  data_flow = 4,
  etl_ops = 5,
  execution = 6,
  script = 7,
}

---Map directive names to categories
---@type table<string, string>
local directive_category = {
  block = "block_starter",
  lua = "block_starter",
  server = "connection",
  database = "connection",
  description = "documentation",
  input = "data_flow",
  output = "data_flow",
  mode = "etl_ops",
  target = "etl_ops",
  skip_on_empty = "execution",
  continue_on_error = "execution",
  timeout = "execution",
  var = "script",
}

---Type labels for display
---@type table<string, string>
local type_labels = {
  string = "(string)",
  boolean = "(flag)",
  number = "(number)",
  enum = nil, -- built dynamically from enum_values
}

---Get the type label for a directive definition
---@param def DirectiveDefinition
---@return string
local function get_type_label(def)
  if def.type == "enum" and def.enum_values then
    return "(enum: " .. table.concat(def.enum_values, "|") .. ")"
  end
  return type_labels[def.type] or ("(" .. def.type .. ")")
end

---Build markdown documentation for a directive
---@param def DirectiveDefinition
---@return string
local function build_docs(def)
  local lines = {
    "### @" .. def.name,
    "",
    def.description,
    "",
    "**Type**: `" .. def.type .. "`",
  }
  if def.required then
    table.insert(lines, "**Required**: yes")
  end
  if def.default ~= nil then
    table.insert(lines, "**Default**: `" .. tostring(def.default) .. "`")
  end
  if def.enum_values then
    table.insert(lines, "**Values**: " .. table.concat(def.enum_values, ", "))
  end
  if def.block_start then
    table.insert(lines, "")
    table.insert(lines, "*Starts a new block*")
  end
  return table.concat(lines, "\n")
end

---Build the newText (snippet body) for a directive
---@param def DirectiveDefinition
---@return string newText
---@return number insertTextFormat 1=plain, 2=snippet
local function build_new_text(def)
  if def.type == "enum" and def.enum_values then
    -- Use first enum value as default placeholder (no choice syntax — blink.cmp doesn't support it)
    return "--@" .. def.name .. " ${1:" .. def.enum_values[1] .. "}", 2
  elseif def.type == "boolean" then
    return "--@" .. def.name, 1
  elseif def.type == "number" then
    return "--@" .. def.name .. " ${1:0}", 2
  else
    local placeholder = def.name
    if def.name == "var" then
      placeholder = "name = value"
    end
    return "--@" .. def.name .. " ${1:" .. placeholder .. "}", 2
  end
end

---Build a textEdit with explicit range (0-indexed line/character, end-exclusive)
---@param new_text string The replacement text
---@param cursor_row number 1-indexed row from cursor
---@param replace_start number 0-indexed character where replacement begins
---@param replace_end number 0-indexed character where replacement ends (exclusive)
---@return table textEdit LSP TextEdit object
local function make_text_edit(new_text, cursor_row, replace_start, replace_end)
  return {
    newText = new_text,
    range = {
      start = { line = cursor_row - 1, character = replace_start },
      ["end"] = { line = cursor_row - 1, character = replace_end },
    },
  }
end

---Build markdown documentation for a snippet template
---@param template table Template from EtlSnippets data { label, detail, description?, body }
---@return string markdown
local function build_snippet_docs(template)
  local lines = {
    "### " .. template.label,
    "",
    template.description or template.detail,
  }
  -- Show a preview of what the template expands to (strip snippet placeholders)
  local preview = {}
  for _, line in ipairs(template.body) do
    -- Strip ${n:text} → text, ${0:text} → text
    local clean = line:gsub("%${%d+:([^}]*)}", "%1")
    -- Strip bare $n
    clean = clean:gsub("%$%d+", "")
    table.insert(preview, clean)
  end
  table.insert(lines, "")
  table.insert(lines, "```")
  vim.list_extend(lines, preview)
  table.insert(lines, "```")
  return table.concat(lines, "\n")
end

-- ============================================================================
-- Completion logic
-- ============================================================================

---Find the 0-indexed character offset where the directive prefix starts on the line
---@param line string Full line text
---@return number start_char 0-indexed start of the -- prefix
local function find_prefix_start(line)
  local leading_ws = line:match("^(%s*)")
  return leading_ws and #leading_ws or 0
end

---Parse the directive line to determine what kind of completion is needed
---@param line string Current line text
---@param cursor number[] {row, col} cursor position — row is 1-indexed, col is 0-indexed
---@return string scenario "name"|"value"|"snippet"|"none"
---@return string? directive_name For "value" scenario, the directive being completed
---@return string? typed For filtering, what the user has typed so far
local function parse_line(line, cursor)
  local col = cursor[2] -- 0-indexed byte column
  local before_cursor = line:sub(1, col)
  local trimmed = before_cursor:match("^%s*(.-)$")

  -- Check for block snippet trigger: --new...
  if trimmed:match("^%-%-new") then
    return "snippet", nil, trimmed
  end

  -- Check for bare -- (just started typing a comment/directive)
  if trimmed == "--" then
    return "name", nil, "--"
  end

  -- Check for --@ pattern (directive name or value)
  local directive_prefix = trimmed:match("^%-%-@(%S*)$")
  if directive_prefix then
    return "name", nil, "--@" .. directive_prefix
  end

  -- Check for --@directive_name followed by space and value
  local dir_name, value_text = trimmed:match("^%-%-@(%S+)%s(.*)$")
  if dir_name then
    return "value", dir_name, value_text
  end

  return "none", nil, nil
end

---Build completion items for directive names
---@param cursor_row number 1-indexed cursor row
---@param cursor_col number 0-indexed cursor column
---@param prefix_start number 0-indexed character where -- starts
---@return table[] items
local function complete_directive_names(cursor_row, cursor_col, prefix_start)
  local items = {}

  for name, def in pairs(Directives.definitions) do
    local cat = directive_category[name] or "script"
    local priority = category_priority[cat] or 7
    local new_text, text_format = build_new_text(def)

    local item = {
      label = "--@" .. name,
      kind = def.block_start and Utils.CompletionItemKind.Snippet or Utils.CompletionItemKind.Keyword,
      detail = get_type_label(def),
      documentation = {
        kind = "markdown",
        value = build_docs(def),
      },
      insertTextFormat = text_format,
      filterText = "--@" .. name,
      sortText = Utils.generate_sort_text(priority, name),
      textEdit = make_text_edit(new_text, cursor_row, prefix_start, cursor_col),
      data = { type = "directive", directive = name },
    }
    table.insert(items, item)
  end

  return items
end

---Build completion items for directive enum values
---@param directive_name string The directive name (e.g. "mode")
---@param cursor_row number 1-indexed cursor row
---@param cursor_col number 0-indexed cursor column
---@param value_start number 0-indexed character where the value starts
---@return table[] items
local function complete_directive_values(directive_name, cursor_row, cursor_col, value_start)
  local def = Directives.definitions[directive_name]
  if not def then
    return {}
  end

  if def.type ~= "enum" or not def.enum_values then
    return {}
  end

  local items = {}
  for i, value in ipairs(def.enum_values) do
    local item = {
      label = value,
      kind = Utils.CompletionItemKind.EnumMember,
      detail = "@" .. directive_name .. " value",
      documentation = {
        kind = "markdown",
        value = string.format("Set `@%s` to `%s`.", directive_name, value),
      },
      filterText = value,
      sortText = Utils.generate_sort_text(1, string.format("%02d", i)),
      textEdit = make_text_edit(value, cursor_row, value_start, cursor_col),
      data = { type = "directive_value", directive = directive_name, value = value },
    }
    table.insert(items, item)
  end

  return items
end

---Build completion items for block template snippets
---@param cursor_row number 1-indexed cursor row
---@param cursor_col number 0-indexed cursor column
---@param prefix_start number 0-indexed character where -- starts
---@return table[] items
local function complete_block_snippets(cursor_row, cursor_col, prefix_start)
  local templates = EtlSnippets.get_all()
  local items = {}

  for i, template in ipairs(templates) do
    local new_text = table.concat(template.body, "\n")
    local item = {
      label = template.label,
      kind = Utils.CompletionItemKind.Snippet,
      detail = template.detail,
      documentation = {
        kind = "markdown",
        value = build_snippet_docs(template),
      },
      insertTextFormat = 2, -- Snippet format
      filterText = template.label,
      sortText = Utils.generate_sort_text(1, string.format("%02d", i)),
      textEdit = make_text_edit(new_text, cursor_row, prefix_start, cursor_col),
      data = { type = "directive_snippet", snippet = template.label },
    }
    table.insert(items, item)
  end

  return items
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get completions for a directive line
---@param line string Current line text
---@param cursor number[] {row, col} — row is 1-indexed, col is 0-indexed
---@return table[] items Array of LSP CompletionItems
function M.get_completions(line, cursor)
  local scenario, directive_name, typed = parse_line(line, cursor)
  local cursor_row = cursor[1]
  local cursor_col = cursor[2]
  local prefix_start = find_prefix_start(line)

  if scenario == "name" then
    local items = complete_directive_names(cursor_row, cursor_col, prefix_start)
    -- Also include block snippets when user typed -- or --new prefix
    if typed and (typed == "--" or typed:match("^%-%-[^@]")) then
      vim.list_extend(items, complete_block_snippets(cursor_row, cursor_col, prefix_start))
    end
    return items
  elseif scenario == "value" then
    -- Value starts after "--@directive_name " — find the space after directive name
    local value_start = line:find("^%s*%-%-@%S+%s", 1)
    if value_start then
      -- value_start points to start of match; find end of the pattern (after the space)
      local _, space_end = line:find("^%s*%-%-@%S+%s", 1)
      value_start = space_end -- 1-indexed byte right after the space
    else
      value_start = cursor_col
    end
    -- Convert to 0-indexed
    return complete_directive_values(directive_name, cursor_row, cursor_col, value_start)
  elseif scenario == "snippet" then
    return complete_block_snippets(cursor_row, cursor_col, prefix_start)
  end

  return {}
end

return M
