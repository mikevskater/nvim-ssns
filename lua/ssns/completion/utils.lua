---Utility functions for formatting LSP CompletionItems
---Used by completion providers to format database objects as LSP-compliant items
---@class CompletionUtils
local Utils = {}

---LSP CompletionItemKind enumeration
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
Utils.CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25,
}

---Generate sort text with priority prefix
---@param priority number Priority level (1 = highest, 9 = lowest)
---@param name string Item name
---@return string sort_text Formatted sort text (e.g., "0001_EmployeeID")
function Utils.generate_sort_text(priority, name)
  return string.format("%04d_%s", priority, name)
end

---Format markdown documentation from key-value pairs
---@param title string Documentation title
---@param items table<string, any> Key-value pairs to format
---@return string markdown Formatted markdown string
function Utils.format_markdown_docs(title, items)
  local lines = { "### " .. title, "" }

  for key, value in pairs(items) do
    if value ~= nil and value ~= "" then
      table.insert(lines, string.format("**%s**: %s", key, tostring(value)))
    end
  end

  return table.concat(lines, "\n")
end

---Format a table/view as an LSP CompletionItem
---@param table_obj table Table object { name: string, schema: string, type?: string }
---@param opts table? Options { show_schema: boolean? }
---@return table completion_item LSP CompletionItem
function Utils.format_table(table_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true

  local label = table_obj.name or table_obj.table_name
  local schema = table_obj.schema or table_obj.schema_name
  local obj_type = table_obj.type or "TABLE"

  -- Detail shows schema.table and type
  local detail
  if show_schema and schema then
    detail = string.format("%s.%s (%s)", schema, label, obj_type)
  else
    detail = string.format("%s (%s)", label, obj_type)
  end

  -- Sort priority: tables = 1, views = 2, others = 3
  local priority = 2
  if obj_type == "TABLE" then
    priority = 1
  elseif obj_type == "VIEW" then
    priority = 2
  else
    priority = 3
  end

  return {
    label = label,
    kind = Utils.CompletionItemKind.Class,
    detail = detail,
    documentation = nil, -- Can be loaded lazily via resolve()
    insertText = label,
    filterText = label,
    sortText = Utils.generate_sort_text(priority, label),
    data = {
      type = "table",
      schema = schema,
      name = label,
      object_type = obj_type,
    }
  }
end

---Format a column as an LSP CompletionItem
---@param column_obj table Column object { name: string, data_type: string, nullable?: boolean, is_primary_key?: boolean, is_foreign_key?: boolean, default_value?: string, ordinal_position?: number }
---@param opts table? Options { show_type: boolean?, show_nullable: boolean? }
---@return table completion_item LSP CompletionItem
function Utils.format_column(column_obj, opts)
  opts = opts or {}
  local show_type = opts.show_type ~= false -- Default true
  local show_nullable = opts.show_nullable ~= false -- Default true

  local name = column_obj.name or column_obj.column_name
  local data_type = column_obj.data_type or column_obj.type or "unknown"
  local nullable = column_obj.nullable or column_obj.is_nullable
  local is_pk = column_obj.is_primary_key or column_obj.is_pk
  local is_fk = column_obj.is_foreign_key or column_obj.is_fk
  local default_value = column_obj.default_value
  local ordinal = column_obj.ordinal_position or 999

  -- Build detail string (type + nullable + constraints)
  local detail_parts = {}

  if show_type then
    table.insert(detail_parts, data_type)
  end

  if show_nullable then
    if nullable == false or nullable == "NO" then
      table.insert(detail_parts, "NOT NULL")
    end
  end

  if is_pk then
    table.insert(detail_parts, "PK")
  end

  if is_fk then
    table.insert(detail_parts, "FK")
  end

  local detail = table.concat(detail_parts, " ")

  -- Build documentation (markdown)
  local doc_items = {
    Type = string.format("`%s`", data_type),
  }

  if nullable ~= nil then
    doc_items.Nullable = (nullable == true or nullable == "YES") and "YES" or "NO"
  end

  if is_pk then
    doc_items["Primary Key"] = "✓"
  end

  if is_fk then
    doc_items["Foreign Key"] = "✓"
  end

  if default_value then
    doc_items.Default = string.format("`%s`", default_value)
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(name, doc_items)
  }

  -- Sort priority: PK columns first (1), then FK (2), then regular (3)
  local priority = 3
  if is_pk then
    priority = 1
  elseif is_fk then
    priority = 2
  end

  return {
    label = name,
    kind = Utils.CompletionItemKind.Field,
    detail = detail,
    documentation = documentation,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(priority, string.format("%04d_%s", ordinal, name)),
    data = {
      type = "column",
      name = name,
      data_type = data_type,
      is_primary_key = is_pk,
      is_foreign_key = is_fk,
    }
  }
end

---Format a stored procedure/function as an LSP CompletionItem
---@param proc_obj table Procedure object { name: string, type?: string, return_type?: string, schema?: string }
---@param opts table? Options { show_schema: boolean? }
---@return table completion_item LSP CompletionItem
function Utils.format_procedure(proc_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true

  local name = proc_obj.name or proc_obj.procedure_name or proc_obj.function_name
  local schema = proc_obj.schema or proc_obj.schema_name
  local obj_type = proc_obj.type or proc_obj.object_type or "PROCEDURE"
  local return_type = proc_obj.return_type

  -- Detail shows schema.proc (TYPE) or schema.func → return_type
  local detail
  if show_schema and schema then
    if return_type and obj_type == "FUNCTION" then
      detail = string.format("%s.%s → %s", schema, name, return_type)
    else
      detail = string.format("%s.%s (%s)", schema, name, obj_type)
    end
  else
    if return_type and obj_type == "FUNCTION" then
      detail = string.format("%s → %s", name, return_type)
    else
      detail = string.format("%s (%s)", name, obj_type)
    end
  end

  -- Build documentation
  local doc_items = {
    Type = obj_type,
  }

  if return_type then
    doc_items["Return Type"] = string.format("`%s`", return_type)
  end

  if schema then
    doc_items.Schema = schema
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(name, doc_items)
  }

  -- Sort priority: procedures/functions = 2
  local priority = 2

  return {
    label = name,
    kind = Utils.CompletionItemKind.Function,
    detail = detail,
    documentation = documentation,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(priority, name),
    data = {
      type = "procedure",
      name = name,
      schema = schema,
      object_type = obj_type,
      return_type = return_type,
    }
  }
end

---Format a SQL keyword as an LSP CompletionItem
---@param keyword string The SQL keyword (e.g., "SELECT", "JOIN")
---@param opts table? Options { priority: number? }
---@return table completion_item LSP CompletionItem
function Utils.format_keyword(keyword, opts)
  opts = opts or {}
  local priority = opts.priority or 9 -- Keywords have lowest priority by default

  return {
    label = keyword,
    kind = Utils.CompletionItemKind.Keyword,
    detail = "SQL Keyword",
    documentation = nil,
    insertText = keyword,
    filterText = keyword,
    sortText = Utils.generate_sort_text(priority, keyword),
    data = {
      type = "keyword",
    }
  }
end

---Format a database as an LSP CompletionItem
---@param db_obj table Database object { name: string, server?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_database(db_obj, opts)
  opts = opts or {}

  local name = db_obj.name or db_obj.db_name or db_obj.database_name
  local server = db_obj.server or db_obj.server_name

  local detail = server and string.format("Database on %s", server) or "Database"

  return {
    label = name,
    kind = Utils.CompletionItemKind.Folder,
    detail = detail,
    documentation = nil,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(1, name),
    data = {
      type = "database",
      name = name,
      server = server,
    }
  }
end

---Format a schema as an LSP CompletionItem
---@param schema_obj table Schema object { name: string, database?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_schema(schema_obj, opts)
  opts = opts or {}

  local name = schema_obj.name or schema_obj.schema_name
  local database = schema_obj.database or schema_obj.database_name

  local detail = database and string.format("Schema in %s", database) or "Schema"

  return {
    label = name,
    kind = Utils.CompletionItemKind.Module,
    detail = detail,
    documentation = nil,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(1, name),
    data = {
      type = "schema",
      name = name,
      database = database,
    }
  }
end

---Format a parameter as an LSP CompletionItem
---@param param_obj table Parameter object { name: string, data_type: string, is_output?: boolean, default_value?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_parameter(param_obj, opts)
  opts = opts or {}

  local name = param_obj.name or param_obj.parameter_name
  local data_type = param_obj.data_type or param_obj.type or "unknown"
  local is_output = param_obj.is_output or param_obj.is_out
  local default_value = param_obj.default_value

  -- Detail shows type and OUTPUT if applicable
  local detail_parts = { data_type }
  if is_output then
    table.insert(detail_parts, "OUTPUT")
  end
  local detail = table.concat(detail_parts, " ")

  -- Documentation
  local doc_items = {
    Type = string.format("`%s`", data_type),
    Mode = is_output and "OUTPUT" or "INPUT",
  }

  if default_value then
    doc_items.Default = string.format("`%s`", default_value)
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(name, doc_items)
  }

  return {
    label = name,
    kind = Utils.CompletionItemKind.Variable,
    detail = detail,
    documentation = documentation,
    insertText = string.format("%s = ", name), -- Auto-add = for parameter assignment
    filterText = name,
    sortText = Utils.generate_sort_text(2, name),
    data = {
      type = "parameter",
      name = name,
      data_type = data_type,
      is_output = is_output,
    }
  }
end

return Utils
