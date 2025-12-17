---Column completion provider for SSNS IntelliSense
---Provides context-aware column completions with alias resolution
---Entry point that routes to specialized handlers
---@class ColumnsProvider
local ColumnsProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

-- Lazy-loaded submodules
local qualified = nil
local unqualified = nil
local special = nil

---Get the qualified columns submodule
---@return table
local function get_qualified()
  if not qualified then
    qualified = require('ssns.completion.providers.columns.qualified')
  end
  return qualified
end

---Get the unqualified columns submodule
---@return table
local function get_unqualified()
  if not unqualified then
    unqualified = require('ssns.completion.providers.columns.unqualified')
  end
  return unqualified
end

---Get the special columns submodule
---@return table
local function get_special()
  if not special then
    special = require('ssns.completion.providers.columns.special')
  end
  return special
end

-- Use BaseProvider.create_safe_wrapper for standardized error handling
ColumnsProvider.get_completions = BaseProvider.create_safe_wrapper(ColumnsProvider, "Columns", false)

---Resolve table reference to full path for weight lookup
---@param table_ref string Table reference (could be alias, name, etc.)
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@param resolved_scope table? Pre-resolved scope from source
---@return string? path Full path (e.g., "dbo.Employees") or nil
function ColumnsProvider.resolve_table_path(table_ref, connection, context, resolved_scope)
  if not table_ref then
    return nil
  end

  -- Try to resolve via Resolver
  local success, result = pcall(function()
    local Resolver = require('ssns.completion.metadata.resolver')

    -- Try pre-resolved scope first
    local table_obj = nil
    if resolved_scope then
      table_obj = Resolver.get_resolved(resolved_scope, table_ref)
    end
    if not table_obj then
      table_obj = Resolver.resolve_table(table_ref, connection, context)
    end

    if table_obj then
      local schema = table_obj.schema or table_obj.schema_name
      local name = table_obj.name or table_obj.table_name

      if schema and name then
        return string.format("%s.%s", schema, name)
      elseif name then
        return name
      end
    end

    return nil
  end)

  if success and result then
    return result
  end

  -- Fallback: assume it's already a qualified name
  return table_ref
end

---Internal implementation of column completion
---Routes to appropriate handler based on context mode
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ColumnsProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Route based on context mode
  -- Note: "qualified" modes can work without connection for CTE/subquery columns
  -- Other modes require database connection for column lookups
  if sql_context.mode == "qualified" or
     sql_context.mode == "select_qualified" or
     sql_context.mode == "where_qualified" then
    -- Pattern: table.| or alias.|
    -- Can work without connection for CTE/subquery columns
    local Debug = require('ssns.debug')
    Debug.log(string.format("[COLUMNS] Routing mode '%s' to _get_qualified_columns", sql_context.mode or "nil"))
    return get_qualified().get_qualified_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "on" then
    -- Pattern: JOIN table ON left.col = | (show columns from other tables with fuzzy matching)
    -- But if user typed table_ref. (e.g., d.), use qualified completion instead
    if sql_context.table_ref then
      return get_qualified().get_qualified_columns(sql_context, connection, sql_context)
    end
    -- ON clause without table_ref needs database connection
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_on_clause_columns(connection, sql_context)

  elseif sql_context.mode == "where" then
    -- Pattern: WHERE col = | (show columns with type compatibility warnings)
    if not connection or not connection.database then
      return {}
    end
    return get_unqualified().get_where_clause_columns(connection, sql_context)

  elseif sql_context.mode == "select" or
         sql_context.mode == "order_by" or sql_context.mode == "group_by" or
         sql_context.mode == "having" or sql_context.mode == "set" then
    -- Pattern: SELECT | or ORDER BY | or GROUP BY | or HAVING | or UPDATE SET | (show columns from all tables in query)
    if not connection or not connection.database then
      return {}
    end
    return get_unqualified().get_all_columns_from_query(connection, sql_context)

  elseif sql_context.mode == "qualified_bracket" then
    -- Pattern: [schema].[table].| or [database].|
    -- Can work without connection for CTE columns
    return get_qualified().get_qualified_bracket_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "insert_columns" then
    -- Pattern: INSERT INTO table (| - show columns from target table
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_insert_columns(connection, sql_context)

  elseif sql_context.mode == "merge_insert_columns" then
    -- Pattern: MERGE ... WHEN NOT MATCHED THEN INSERT (| - show columns from MERGE target table
    -- MERGE target table is also chunk.tables[1], same as regular INSERT
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_insert_columns(connection, sql_context)

  elseif sql_context.mode == "values" then
    -- Pattern: INSERT INTO table (col1, col2) VALUES (|val1, val2)
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_values_completions(connection, sql_context)

  elseif sql_context.mode == "output" then
    -- Pattern: OUTPUT inserted.| or OUTPUT deleted.| (show columns from DML target table)
    if sql_context.table_ref and (sql_context.table_ref:lower() == "inserted" or sql_context.table_ref:lower() == "deleted") then
      -- Get columns from the DML target table
      return get_special().get_output_pseudo_table_columns(connection, sql_context)
    else
      -- Just "OUTPUT |" - suggest all columns from target or return empty
      if not connection or not connection.database then
        return {}
      end
      return get_unqualified().get_all_columns_from_query(connection, sql_context)
    end

  else
    return {}
  end
end

return ColumnsProvider
