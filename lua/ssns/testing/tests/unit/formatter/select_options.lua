-- Test file: select_options.lua
-- IDs: 8451-84595
-- Tests: SELECT clause options - DISTINCT, TOP, INTO, list_style

return {
    -- SELECT clause options
    {
        id = 8451,
        type = "formatter",
        name = "select_distinct_newline true",
        input = "SELECT DISTINCT name, email FROM users",
        opts = { select_distinct_newline = true },
        expected = {
            matches = { "SELECT\n.-DISTINCT" }
        }
    },
    {
        id = 8452,
        type = "formatter",
        name = "select_distinct_newline false (default)",
        input = "SELECT DISTINCT name FROM users",
        opts = { select_distinct_newline = false },
        expected = {
            contains = { "SELECT DISTINCT" }  -- On same line
        }
    },
    {
        id = 8453,
        type = "formatter",
        name = "select_top_newline true",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = true },
        expected = {
            matches = { "SELECT\n.-TOP 10" }
        }
    },
    {
        id = 8454,
        type = "formatter",
        name = "select_top_newline false (default)",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = false },
        expected = {
            contains = { "SELECT TOP 10" }  -- On same line
        }
    },
    {
        id = 8455,
        type = "formatter",
        name = "select_into_newline true",
        input = "SELECT * INTO #temp FROM users",
        opts = { select_into_newline = true },
        expected = {
            matches = { "SELECT %*\n.-INTO" }
        }
    },

    -- select_list_style tests
    {
        id = 8456,
        type = "formatter",
        name = "select_list_style stacked - each column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT id,\n.-name,\n.-email" }
        }
    },
    {
        id = 8457,
        type = "formatter",
        name = "select_list_style inline - all columns on one line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "inline" },
        expected = {
            contains = { "SELECT id, name, email" }
        }
    },
    {
        id = 8458,
        type = "formatter",
        name = "select_list_style stacked with aliases",
        input = "SELECT u.id AS user_id, u.name AS user_name FROM users u",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT u.id AS user_id,\n.-u.name AS user_name" }
        }
    },
    {
        id = 8459,
        type = "formatter",
        name = "select_list_style stacked - function calls stay on same line",
        input = "SELECT COUNT(*), SUM(amount), MAX(created_at) FROM orders",
        opts = { select_list_style = "stacked" },
        expected = {
            -- Function arguments should not trigger newlines (paren_depth > 0)
            contains = { "COUNT(*)", "SUM(amount)", "MAX(created_at)" },
            matches = { "SELECT COUNT%(%*%),\n.-SUM%(amount%),\n.-MAX%(created_at%)" }
        }
    },
    {
        id = 84591,
        type = "formatter",
        name = "select_list_style stacked_indent - first column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- First column should be on new line after SELECT
            matches = { "SELECT\n.-id,\n.-name,\n.-email" }
        }
    },
    {
        id = 84592,
        type = "formatter",
        name = "select_list_style stacked_indent - indented properly",
        input = "SELECT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- Columns should be indented (4 spaces default)
            matches = { "SELECT\n    id,\n    name" }
        }
    },
    {
        id = 84593,
        type = "formatter",
        name = "select_list_style stacked vs stacked_indent comparison",
        input = "SELECT a, b FROM t",
        opts = { select_list_style = "stacked" },
        expected = {
            -- stacked: first column on same line as SELECT
            contains = { "SELECT a," }
        }
    },
    {
        id = 84594,
        type = "formatter",
        name = "select_list_style stacked_indent with DISTINCT - DISTINCT stays on SELECT line",
        input = "SELECT DISTINCT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- DISTINCT should stay on same line as SELECT, columns on new lines
            contains = { "SELECT DISTINCT" },
            matches = { "SELECT DISTINCT\n    id,\n    name" }
        }
    },
    {
        id = 84595,
        type = "formatter",
        name = "select_list_style stacked_indent with TOP - TOP stays on SELECT line",
        input = "SELECT TOP 10 id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- TOP 10 should stay on same line as SELECT, columns on new lines
            contains = { "SELECT TOP 10" },
            matches = { "SELECT TOP 10\n    id,\n    name" }
        }
    },
}
