---@module ssns.ui.panels.theme_preview_sql
---Preview SQL with pre-defined highlighting for theme picker
---Uses ContentBuilder for consistent styling throughout the plugin

local M = {}

local ContentBuilder = require('ssns.ui.core.content_builder')

-- Add SQL-specific style mappings to extend ContentBuilder
-- These map to the actual SSNS highlight groups
local SQL_STYLES = {
  -- SQL Keywords
  statement = "SsnsKeywordStatement",  -- SELECT, INSERT, CREATE, etc.
  clause = "SsnsKeywordClause",        -- FROM, WHERE, JOIN, etc.
  sql_operator = "SsnsKeywordOperator",    -- AND, OR, NOT, IN, BETWEEN, etc.
  sql_function = "SsnsKeywordFunction",    -- COUNT, SUM, GETDATE, etc.
  datatype = "SsnsKeywordDatatype",    -- INT, VARCHAR, DATETIME, etc.
  constraint = "SsnsKeywordConstraint", -- PRIMARY, FOREIGN, KEY, etc.
  modifier = "SsnsKeywordModifier",    -- ASC, DESC, NOLOCK, etc.
  sysproc = "SsnsKeywordSystemProcedure",
  globalvar = "SsnsKeywordGlobalVariable",
  -- SQL Objects
  sql_column = "SsnsColumn",
  sql_table = "SsnsTable",
  sql_schema = "SsnsSchema",
  sql_database = "SsnsDatabase",
  sql_procedure = "SsnsProcedure",
  sql_parameter = "SsnsParameter",
  sql_alias = "SsnsAlias",
  sql_index = "SsnsIndex",
  unresolved = "SsnsUnresolved",
  -- Literals (reuse existing ContentBuilder mappings)
  sql_string = "SsnsString",
  sql_number = "SsnsNumber",
  sql_comment = "SsnsComment",
}

---Build preview SQL content with highlights using ContentBuilder
---@return string[] lines, table[] highlights
function M.build()
  local cb = ContentBuilder.new()

  -- Helper to create spans with SQL-specific styles
  local function sql(text, style)
    return { text = text, style = style, hl_group = SQL_STYLES[style] }
  end

  -- Helper for raw highlight group (bypass ContentBuilder mapping)
  local function raw(text, hl_group)
    return { text = text, hl_group = hl_group }
  end

  -- ============================================
  -- Header comments
  -- ============================================
  cb:styled("-- ============================================", "comment")
  cb:styled("-- SSNS Theme Preview", "comment")
  cb:styled("-- This query showcases all highlight groups", "comment")
  cb:styled("-- ============================================", "comment")
  cb:blank()

  -- ============================================
  -- Database & Schema References
  -- ============================================
  cb:styled("-- Database & Schema References", "comment")
  cb:spans({
    raw("USE", SQL_STYLES.statement), { text = " " },
    raw("master", SQL_STYLES.sql_database), { text = ";" },
  })
  cb:spans({ raw("GO", SQL_STYLES.statement) })
  cb:blank()

  -- ============================================
  -- SELECT Statement
  -- ============================================
  cb:styled("-- Statement Keywords (SELECT, INSERT, CREATE, etc.)", "comment")
  cb:spans({ raw("SELECT", SQL_STYLES.statement) })

  cb:styled("    -- Column References", "comment")
  cb:spans({
    { text = "    " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("id", SQL_STYLES.sql_column), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("username", SQL_STYLES.sql_column), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("email", SQL_STYLES.sql_column), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("created_at", SQL_STYLES.sql_column), { text = "," },
  })

  cb:styled("    -- Alias References", "comment")
  cb:spans({
    { text = "    " },
    raw("o", SQL_STYLES.sql_alias), { text = "." },
    raw("order_total", SQL_STYLES.sql_column), { text = " " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("total", SQL_STYLES.sql_alias), { text = "," },
  })

  cb:styled("    -- Function Keywords (COUNT, SUM, GETDATE, etc.)", "comment")
  cb:spans({
    { text = "    " },
    raw("COUNT", SQL_STYLES.sql_function), { text = "(*) " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("order_count", SQL_STYLES.sql_alias), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("SUM", SQL_STYLES.sql_function), { text = "(" },
    raw("o", SQL_STYLES.sql_alias), { text = "." },
    raw("amount", SQL_STYLES.sql_column), { text = ") " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("total_amount", SQL_STYLES.sql_alias), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("GETDATE", SQL_STYLES.sql_function), { text = "() " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("current_date", SQL_STYLES.sql_alias), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("CAST", SQL_STYLES.sql_function), { text = "(" },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("balance", SQL_STYLES.sql_column), { text = " " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("DECIMAL", SQL_STYLES.datatype), { text = "(" },
    raw("10", SQL_STYLES.sql_number), { text = "," },
    raw("2", SQL_STYLES.sql_number), { text = ")) " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("balance", SQL_STYLES.sql_alias), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("COALESCE", SQL_STYLES.sql_function), { text = "(" },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("nickname", SQL_STYLES.sql_column), { text = ", " },
    raw("'N/A'", SQL_STYLES.sql_string), { text = ") " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("display_name", SQL_STYLES.sql_alias),
  })

  -- ============================================
  -- FROM clause with JOINs
  -- ============================================
  cb:styled("-- Clause Keywords (FROM, WHERE, JOIN, etc.)", "comment")
  cb:spans({
    raw("FROM", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Users", SQL_STYLES.sql_table), { text = " " },
    raw("u", SQL_STYLES.sql_alias),
  })

  cb:styled("-- Table & View References", "comment")
  cb:spans({
    raw("INNER JOIN", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Orders", SQL_STYLES.sql_table), { text = " " },
    raw("o", SQL_STYLES.sql_alias), { text = " " },
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("id", SQL_STYLES.sql_column), { text = " = " },
    raw("o", SQL_STYLES.sql_alias), { text = "." },
    raw("user_id", SQL_STYLES.sql_column),
  })
  cb:spans({
    raw("LEFT JOIN", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("UserProfiles", SQL_STYLES.sql_table), { text = " " },
    raw("up", SQL_STYLES.sql_alias), { text = " " },
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("id", SQL_STYLES.sql_column), { text = " = " },
    raw("up", SQL_STYLES.sql_alias), { text = "." },
    raw("user_id", SQL_STYLES.sql_column),
  })

  -- ============================================
  -- WHERE clause with operators
  -- ============================================
  cb:styled("-- Operator Keywords (AND, OR, NOT, IN, BETWEEN)", "comment")
  cb:spans({
    raw("WHERE", SQL_STYLES.clause), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("status", SQL_STYLES.sql_column), { text = " = " },
    raw("'active'", SQL_STYLES.sql_string),
  })
  cb:spans({
    { text = "    " },
    raw("AND", SQL_STYLES.sql_operator), { text = " " },
    raw("o", SQL_STYLES.sql_alias), { text = "." },
    raw("created_at", SQL_STYLES.sql_column), { text = " " },
    raw("BETWEEN", SQL_STYLES.sql_operator), { text = " " },
    raw("'2024-01-01'", SQL_STYLES.sql_string), { text = " " },
    raw("AND", SQL_STYLES.sql_operator), { text = " " },
    raw("'2024-12-31'", SQL_STYLES.sql_string),
  })
  cb:spans({
    { text = "    " },
    raw("AND", SQL_STYLES.sql_operator), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("role", SQL_STYLES.sql_column), { text = " " },
    raw("IN", SQL_STYLES.sql_operator), { text = " (" },
    raw("'admin'", SQL_STYLES.sql_string), { text = ", " },
    raw("'user'", SQL_STYLES.sql_string), { text = ", " },
    raw("'moderator'", SQL_STYLES.sql_string), { text = ")" },
  })
  cb:spans({
    { text = "    " },
    raw("OR", SQL_STYLES.sql_operator), { text = " " },
    raw("NOT", SQL_STYLES.sql_operator), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("is_deleted", SQL_STYLES.sql_column), { text = " = " },
    raw("1", SQL_STYLES.sql_number),
  })

  cb:styled("-- Modifier Keywords (ASC, DESC, NOLOCK, etc.)", "comment")
  cb:spans({
    raw("ORDER BY", SQL_STYLES.clause), { text = " " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("created_at", SQL_STYLES.sql_column), { text = " " },
    raw("DESC", SQL_STYLES.modifier), { text = ", " },
    raw("u", SQL_STYLES.sql_alias), { text = "." },
    raw("username", SQL_STYLES.sql_column), { text = " " },
    raw("ASC", SQL_STYLES.modifier), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Literals
  -- ============================================
  cb:styled("-- Number Literals", "comment")
  cb:spans({
    raw("SELECT", SQL_STYLES.statement), { text = " " },
    raw("42", SQL_STYLES.sql_number), { text = ", " },
    raw("3.14159", SQL_STYLES.sql_number), { text = ", " },
    raw("-100", SQL_STYLES.sql_number), { text = ", " },
    raw("0x1F", SQL_STYLES.sql_number), { text = ";" },
  })
  cb:blank()

  cb:styled("-- String Literals", "comment")
  cb:spans({
    raw("SELECT", SQL_STYLES.statement), { text = " " },
    raw("'Hello World'", SQL_STYLES.sql_string), { text = ", " },
    raw("N'Unicode String'", SQL_STYLES.sql_string), { text = ", " },
    raw("'It''s escaped'", SQL_STYLES.sql_string), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Parameters
  -- ============================================
  cb:styled("-- Parameter References (@params and @@system)", "comment")
  cb:spans({
    raw("DECLARE", SQL_STYLES.statement), { text = " " },
    raw("@UserId", SQL_STYLES.sql_parameter), { text = " " },
    raw("INT", SQL_STYLES.datatype), { text = " = " },
    raw("1", SQL_STYLES.sql_number), { text = ";" },
  })
  cb:spans({
    raw("DECLARE", SQL_STYLES.statement), { text = " " },
    raw("@SearchTerm", SQL_STYLES.sql_parameter), { text = " " },
    raw("NVARCHAR", SQL_STYLES.datatype), { text = "(" },
    raw("100", SQL_STYLES.sql_number), { text = ") = " },
    raw("'%test%'", SQL_STYLES.sql_string), { text = ";" },
  })
  cb:spans({
    raw("SELECT", SQL_STYLES.statement), { text = " " },
    raw("@@VERSION", SQL_STYLES.globalvar), { text = ", " },
    raw("@@ROWCOUNT", SQL_STYLES.globalvar), { text = ", " },
    raw("@@IDENTITY", SQL_STYLES.globalvar), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Procedures
  -- ============================================
  cb:styled("-- Procedure & Function Calls", "comment")
  cb:spans({
    raw("EXEC", SQL_STYLES.statement), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("GetUserById", SQL_STYLES.sql_procedure), { text = " " },
    raw("@UserId", SQL_STYLES.sql_parameter), { text = " = " },
    raw("@UserId", SQL_STYLES.sql_parameter), { text = ";" },
  })
  cb:spans({
    raw("EXEC", SQL_STYLES.statement), { text = " " },
    raw("sp_help", SQL_STYLES.sysproc), { text = " " },
    raw("'dbo.Users'", SQL_STYLES.sql_string), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- CREATE TABLE with datatypes
  -- ============================================
  cb:styled("-- Datatype Keywords (INT, VARCHAR, DATETIME, etc.)", "comment")
  cb:spans({
    raw("CREATE TABLE", SQL_STYLES.statement), { text = " " },
    raw("#TempUsers", SQL_STYLES.sql_table), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    raw("id", SQL_STYLES.sql_column), { text = " " },
    raw("INT", SQL_STYLES.datatype), { text = " " },
    raw("PRIMARY", SQL_STYLES.constraint), { text = " " },
    raw("KEY", SQL_STYLES.constraint), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("name", SQL_STYLES.sql_column), { text = " " },
    raw("VARCHAR", SQL_STYLES.datatype), { text = "(" },
    raw("100", SQL_STYLES.sql_number), { text = ") " },
    raw("NOT", SQL_STYLES.sql_operator), { text = " " },
    raw("NULL", SQL_STYLES.constraint), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("email", SQL_STYLES.sql_column), { text = " " },
    raw("NVARCHAR", SQL_STYLES.datatype), { text = "(" },
    raw("255", SQL_STYLES.sql_number), { text = ") " },
    raw("UNIQUE", SQL_STYLES.constraint), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("balance", SQL_STYLES.sql_column), { text = " " },
    raw("DECIMAL", SQL_STYLES.datatype), { text = "(" },
    raw("18", SQL_STYLES.sql_number), { text = "," },
    raw("2", SQL_STYLES.sql_number), { text = ") " },
    raw("DEFAULT", SQL_STYLES.constraint), { text = " " },
    raw("0.00", SQL_STYLES.sql_number), { text = "," },
  })
  cb:spans({
    { text = "    " },
    raw("created_at", SQL_STYLES.sql_column), { text = " " },
    raw("DATETIME", SQL_STYLES.datatype), { text = " " },
    raw("DEFAULT", SQL_STYLES.constraint), { text = " " },
    raw("GETDATE", SQL_STYLES.sql_function), { text = "()," },
  })
  cb:spans({
    { text = "    " },
    raw("metadata", SQL_STYLES.sql_column), { text = " " },
    raw("XML", SQL_STYLES.datatype), { text = " " },
    raw("NULL", SQL_STYLES.constraint),
  })
  cb:line(");")
  cb:blank()

  -- ============================================
  -- Constraints
  -- ============================================
  cb:styled("-- Constraint Keywords (PRIMARY, KEY, FOREIGN, etc.)", "comment")
  cb:spans({
    raw("ALTER TABLE", SQL_STYLES.statement), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Orders", SQL_STYLES.sql_table),
  })
  cb:spans({
    raw("ADD", SQL_STYLES.statement), { text = " " },
    raw("CONSTRAINT", SQL_STYLES.constraint), { text = " " },
    raw("FK_Orders_Users", SQL_STYLES.sql_index),
  })
  cb:spans({
    { text = "    " },
    raw("FOREIGN KEY", SQL_STYLES.constraint), { text = " (" },
    raw("user_id", SQL_STYLES.sql_column), { text = ") " },
    raw("REFERENCES", SQL_STYLES.constraint), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Users", SQL_STYLES.sql_table), { text = "(" },
    raw("id", SQL_STYLES.sql_column), { text = ")" },
  })
  cb:spans({
    { text = "    " },
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("DELETE", SQL_STYLES.statement), { text = " " },
    raw("CASCADE", SQL_STYLES.modifier),
  })
  cb:spans({
    { text = "    " },
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("UPDATE", SQL_STYLES.statement), { text = " " },
    raw("NO", SQL_STYLES.sql_operator), { text = " " },
    raw("ACTION", SQL_STYLES.modifier), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Index
  -- ============================================
  cb:styled("-- Index Reference", "comment")
  cb:spans({
    raw("CREATE", SQL_STYLES.statement), { text = " " },
    raw("NONCLUSTERED", SQL_STYLES.modifier), { text = " " },
    raw("INDEX", SQL_STYLES.statement), { text = " " },
    raw("IX_Users_Email", SQL_STYLES.sql_index),
  })
  cb:spans({
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Users", SQL_STYLES.sql_table), { text = " (" },
    raw("email", SQL_STYLES.sql_column), { text = ")" },
  })
  cb:spans({
    raw("INCLUDE", SQL_STYLES.clause), { text = " (" },
    raw("username", SQL_STYLES.sql_column), { text = ", " },
    raw("created_at", SQL_STYLES.sql_column), { text = ");" },
  })
  cb:blank()

  -- ============================================
  -- CTE
  -- ============================================
  cb:styled("-- CTE (Common Table Expression)", "comment")
  cb:spans({
    raw("WITH", SQL_STYLES.clause), { text = " " },
    raw("ActiveUsers", SQL_STYLES.sql_alias), { text = " " },
    raw("AS", SQL_STYLES.clause), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    raw("SELECT", SQL_STYLES.statement), { text = " " },
    raw("id", SQL_STYLES.sql_column), { text = ", " },
    raw("username", SQL_STYLES.sql_column), { text = ", " },
    raw("email", SQL_STYLES.sql_column),
  })
  cb:spans({
    { text = "    " },
    raw("FROM", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Users", SQL_STYLES.sql_table),
  })
  cb:spans({
    { text = "    " },
    raw("WHERE", SQL_STYLES.clause), { text = " " },
    raw("status", SQL_STYLES.sql_column), { text = " = " },
    raw("'active'", SQL_STYLES.sql_string),
  })
  cb:line("),")
  cb:spans({
    raw("RecentOrders", SQL_STYLES.sql_alias), { text = " " },
    raw("AS", SQL_STYLES.clause), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    raw("SELECT", SQL_STYLES.statement), { text = " " },
    raw("user_id", SQL_STYLES.sql_column), { text = ", " },
    raw("COUNT", SQL_STYLES.sql_function), { text = "(*) " },
    raw("AS", SQL_STYLES.clause), { text = " " },
    raw("cnt", SQL_STYLES.sql_alias),
  })
  cb:spans({
    { text = "    " },
    raw("FROM", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("Orders", SQL_STYLES.sql_table),
  })
  cb:spans({
    { text = "    " },
    raw("WHERE", SQL_STYLES.clause), { text = " " },
    raw("created_at", SQL_STYLES.sql_column), { text = " > " },
    raw("DATEADD", SQL_STYLES.sql_function), { text = "(" },
    raw("DAY", SQL_STYLES.modifier), { text = ", " },
    raw("-30", SQL_STYLES.sql_number), { text = ", " },
    raw("GETDATE", SQL_STYLES.sql_function), { text = "())" },
  })
  cb:spans({
    { text = "    " },
    raw("GROUP BY", SQL_STYLES.clause), { text = " " },
    raw("user_id", SQL_STYLES.sql_column),
  })
  cb:line(")")
  cb:spans({
    raw("SELECT", SQL_STYLES.statement), { text = " * " },
    raw("FROM", SQL_STYLES.clause), { text = " " },
    raw("ActiveUsers", SQL_STYLES.sql_table), { text = " " },
    raw("au", SQL_STYLES.sql_alias),
  })
  cb:spans({
    raw("JOIN", SQL_STYLES.clause), { text = " " },
    raw("RecentOrders", SQL_STYLES.sql_table), { text = " " },
    raw("ro", SQL_STYLES.sql_alias), { text = " " },
    raw("ON", SQL_STYLES.clause), { text = " " },
    raw("au", SQL_STYLES.sql_alias), { text = "." },
    raw("id", SQL_STYLES.sql_column), { text = " = " },
    raw("ro", SQL_STYLES.sql_alias), { text = "." },
    raw("user_id", SQL_STYLES.sql_column), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Unresolved (not in database)
  -- ============================================
  cb:styled("-- Unresolved (gray - not in database)", "comment")
  cb:spans({
    raw("SELECT", SQL_STYLES.statement), { text = " * " },
    raw("FROM", SQL_STYLES.clause), { text = " " },
    raw("dbo", SQL_STYLES.sql_schema), { text = "." },
    raw("UnknownTable", SQL_STYLES.unresolved), { text = " " },
    raw("WHERE", SQL_STYLES.clause), { text = " " },
    raw("unknown_col", SQL_STYLES.unresolved), { text = " = " },
    raw("1", SQL_STYLES.sql_number), { text = ";" },
  })

  return cb:build_lines(), cb:build_raw_highlights()
end

return M
