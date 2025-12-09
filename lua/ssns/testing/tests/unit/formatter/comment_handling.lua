-- Test file: comment_handling.lua
-- IDs: 8201-8250
-- Tests: Comment preservation and formatting

return {
    -- Line comment preservation
    {
        id = 8201,
        type = "formatter",
        name = "Preserve single line comment",
        input = "-- This is a comment\nSELECT * FROM users",
        expected = {
            contains = { "-- This is a comment" }
        }
    },
    {
        id = 8202,
        type = "formatter",
        name = "Preserve inline comment",
        input = "SELECT * FROM users -- get all users",
        expected = {
            contains = { "-- get all users" }
        }
    },
    {
        id = 8203,
        type = "formatter",
        name = "Multiple line comments",
        input = "-- Comment 1\n-- Comment 2\nSELECT * FROM users",
        expected = {
            contains = { "-- Comment 1", "-- Comment 2" }
        }
    },
    {
        id = 8204,
        type = "formatter",
        name = "Comment between clauses",
        input = "SELECT * FROM users\n-- Filter active users only\nWHERE active = 1",
        expected = {
            contains = { "-- Filter active users only" }
        }
    },
    {
        id = 8205,
        type = "formatter",
        name = "Comment at end of query",
        input = "SELECT * FROM users WHERE id = 1\n-- TODO: Add pagination",
        expected = {
            contains = { "-- TODO: Add pagination" }
        }
    },
    {
        id = 8206,
        type = "formatter",
        name = "Comment with special characters",
        input = "-- @param: user_id (int)\nSELECT * FROM users WHERE id = @user_id",
        expected = {
            contains = { "-- @param: user_id (int)" }
        }
    },

    -- Block comment preservation
    {
        id = 8210,
        type = "formatter",
        name = "Preserve block comment",
        input = "/* This is a block comment */\nSELECT * FROM users",
        expected = {
            contains = { "/* This is a block comment */" }
        }
    },
    {
        id = 8211,
        type = "formatter",
        name = "Inline block comment",
        input = "SELECT /* hint: force index */ * FROM users",
        expected = {
            contains = { "/* hint: force index */" }
        }
    },
    {
        id = 8212,
        type = "formatter",
        name = "Multi-line block comment",
        input = "/*\n * This is a\n * multi-line comment\n */\nSELECT * FROM users",
        expected = {
            contains = { "/*", "multi-line comment", "*/" }
        }
    },
    {
        id = 8213,
        type = "formatter",
        name = "Block comment between keywords",
        input = "SELECT * /* table: users */ FROM users",
        expected = {
            contains = { "/* table: users */" }
        }
    },
    {
        id = 8214,
        type = "formatter",
        name = "Nested-style block comment markers",
        input = "/* outer /* not nested */ comment */\nSELECT * FROM t",
        expected = {
            contains = { "/* outer /* not nested */" }
        }
    },

    -- Comment position preservation
    {
        id = 8220,
        type = "formatter",
        name = "Comment after SELECT keyword",
        input = "SELECT -- important columns\n    id, name FROM users",
        expected = {
            contains = { "-- important columns" }
        }
    },
    {
        id = 8221,
        type = "formatter",
        name = "Comment after column",
        input = "SELECT id, -- primary key\n    name FROM users",
        expected = {
            contains = { "-- primary key" }
        }
    },
    {
        id = 8222,
        type = "formatter",
        name = "Comment in JOIN clause",
        input = "SELECT * FROM users u\n-- Join with orders table\nJOIN orders o ON u.id = o.user_id",
        expected = {
            contains = { "-- Join with orders table" }
        }
    },
    {
        id = 8223,
        type = "formatter",
        name = "Comment in WHERE clause",
        input = "SELECT * FROM users WHERE\n    -- Active users only\n    active = 1",
        expected = {
            contains = { "-- Active users only" }
        }
    },

    -- SQL Server specific comments
    {
        id = 8230,
        type = "formatter",
        name = "Query hint comment",
        input = "SELECT * FROM users WITH (NOLOCK) /* use nolock for read */",
        expected = {
            contains = { "/* use nolock for read */" }
        }
    },
    {
        id = 8231,
        type = "formatter",
        name = "Execution plan hint",
        input = "/* OPTION (RECOMPILE) */\nSELECT * FROM users WHERE name = @name",
        expected = {
            contains = { "/* OPTION (RECOMPILE) */" }
        }
    },

    -- Comments with keywords inside
    {
        id = 8235,
        type = "formatter",
        name = "Comment containing SELECT keyword",
        input = "-- SELECT should be uppercase\nselect * from users",
        expected = {
            -- Comment content unchanged, query keywords uppercase
            contains = { "-- SELECT should be uppercase", "SELECT *" }
        }
    },
    {
        id = 8236,
        type = "formatter",
        name = "Block comment with SQL inside",
        input = "/* Old query: SELECT id FROM old_users */\nSELECT * FROM users",
        expected = {
            contains = { "/* Old query: SELECT id FROM old_users */" }
        }
    },

    -- Empty and edge case comments
    {
        id = 8240,
        type = "formatter",
        name = "Empty line comment",
        input = "--\nSELECT * FROM users",
        expected = {
            contains = { "--" }
        }
    },
    {
        id = 8241,
        type = "formatter",
        name = "Empty block comment",
        input = "/**/SELECT * FROM users",
        expected = {
            contains = { "/**/" }
        }
    },
    {
        id = 8242,
        type = "formatter",
        name = "Comment with only whitespace",
        input = "--   \nSELECT * FROM users",
        expected = {
            contains = { "--" }
        }
    },

    -- Multiple comment types mixed
    {
        id = 8245,
        type = "formatter",
        name = "Mixed line and block comments",
        input = "-- Line comment\n/* Block comment */\nSELECT * FROM users\n-- Another line comment",
        expected = {
            contains = { "-- Line comment", "/* Block comment */", "-- Another line comment" }
        }
    },
    {
        id = 8246,
        type = "formatter",
        name = "Comments throughout query",
        input = "-- Get users\nSELECT id, /* user id */ name /* user name */\nFROM users -- main table\nWHERE active = 1 -- filter",
        expected = {
            contains = { "-- Get users", "/* user id */", "/* user name */", "-- main table", "-- filter" }
        }
    },

    -- Header comments (common pattern)
    {
        id = 8248,
        type = "formatter",
        name = "Procedure header comment",
        input = "/***********************\n * Get Active Users\n * Author: John Doe\n * Date: 2024-01-01\n ***********************/\nSELECT * FROM users WHERE active = 1",
        expected = {
            contains = { "/***********************", "Get Active Users", "***********************/" }
        }
    },
    {
        id = 8249,
        type = "formatter",
        name = "Section divider comment",
        input = "-- ================================\n-- User Queries\n-- ================================\nSELECT * FROM users",
        expected = {
            contains = { "-- ================================", "-- User Queries" }
        }
    },
    {
        id = 8250,
        type = "formatter",
        name = "Inline documentation comment",
        input = "SELECT\n    id,           -- Primary key\n    name,         -- User's full name\n    email         -- Contact email\nFROM users",
        expected = {
            contains = { "-- Primary key", "-- User's full name", "-- Contact email" }
        }
    },

    -- =========================================================================
    -- Inline Comment Alignment (IDs: 8900-8915)
    -- =========================================================================

    -- Basic inline comment alignment
    {
        id = 8900,
        type = "formatter",
        name = "Align inline comments - basic SELECT columns",
        input = "SELECT\n    id, -- Primary key\n    name, -- User name\n    email -- Contact\nFROM users",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- All comments should align to the same column
            -- id is 2 chars, name is 4 chars, email is 5 chars
            -- Comments should align after longest item (email,)
            pattern = "id,%s+-- Primary key"
        }
    },
    {
        id = 8901,
        type = "formatter",
        name = "Align inline comments - disabled by default",
        input = "SELECT\n    id, -- Primary key\n    name, -- User name\n    email -- Contact\nFROM users",
        config = {
            inline_comment_align = false,
            select_list_style = "stacked"
        },
        expected = {
            -- Comments should NOT be aligned when disabled
            contains = { "-- Primary key", "-- User name", "-- Contact" }
        }
    },
    {
        id = 8902,
        type = "formatter",
        name = "Align inline comments - varying column lengths",
        input = "SELECT\n    a, -- Short\n    very_long_column_name, -- Long column\n    b -- Another short\nFROM t",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Comments should align after longest column (very_long_column_name,)
            pattern = "a,%s+-- Short"
        }
    },
    {
        id = 8903,
        type = "formatter",
        name = "Align inline comments - SET clause",
        input = "UPDATE users SET\n    id = 1, -- PK\n    name = 'test', -- Name value\n    email = 'a@b.com' -- Email\nWHERE x = 1",
        config = {
            inline_comment_align = true,
            update_set_style = "stacked"
        },
        expected = {
            -- Comments in SET clause should align
            pattern = "id = 1,%s+-- PK"
        }
    },
    {
        id = 8904,
        type = "formatter",
        name = "Align inline comments - mixed with non-commented lines",
        input = "SELECT\n    id, -- Has comment\n    name,\n    email, -- Also has comment\n    status\nFROM users",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Only lines with comments participate in alignment
            contains = { "-- Has comment", "-- Also has comment" }
        }
    },
    {
        id = 8905,
        type = "formatter",
        name = "Align inline comments - FROM clause with aliases",
        input = "SELECT * FROM users u -- Users table\nJOIN orders o -- Orders table\n    ON u.id = o.user_id",
        config = {
            inline_comment_align = true
        },
        expected = {
            -- Comments after table aliases should align
            contains = { "-- Users table", "-- Orders table" }
        }
    },
    {
        id = 8906,
        type = "formatter",
        name = "Align inline comments - block comments ignored",
        input = "SELECT\n    id, /* block */ -- line comment\n    name -- another\nFROM users",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Only line comments (--) should be aligned
            contains = { "/* block */", "-- line comment", "-- another" }
        }
    },
    {
        id = 8907,
        type = "formatter",
        name = "Align inline comments - preserves comment content",
        input = "SELECT\n    x, -- Comment with @param and special chars!?\n    y -- Normal\nFROM t",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Comment content should be preserved exactly
            contains = { "-- Comment with @param and special chars!?", "-- Normal" }
        }
    },
    {
        id = 8908,
        type = "formatter",
        name = "Align inline comments - minimum padding added",
        input = "SELECT\n    short, -- A\n    x -- B\nFROM t",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Shorter line (x) should have padding, longer line (short) should have minimal space
            pattern = "x,%s+-- B"
        }
    },
    {
        id = 8909,
        type = "formatter",
        name = "Align inline comments - single comment no change",
        input = "SELECT id, -- Only comment\n    name\nFROM users",
        config = {
            inline_comment_align = true,
            select_list_style = "stacked"
        },
        expected = {
            -- Single inline comment should still work (nothing to align with)
            contains = { "-- Only comment" }
        }
    },

    -- Edge cases
    {
        id = 8910,
        type = "formatter",
        name = "Align inline comments - empty input",
        input = "SELECT * FROM users",
        config = {
            inline_comment_align = true
        },
        expected = {
            -- No comments = no alignment needed
            not_contains = { "--" }
        }
    },
    {
        id = 8911,
        type = "formatter",
        name = "Align inline comments - only standalone comments",
        input = "-- Standalone comment\nSELECT * FROM users\n-- Another standalone",
        config = {
            inline_comment_align = true
        },
        expected = {
            -- Standalone comments (on their own line) should not be aligned
            contains = { "-- Standalone comment", "-- Another standalone" }
        }
    },
    {
        id = 8912,
        type = "formatter",
        name = "Align inline comments - WHERE conditions",
        input = "SELECT * FROM users\nWHERE id = 1 -- Filter by ID\n    AND name = 'test' -- Filter by name\n    AND active = 1 -- Only active",
        config = {
            inline_comment_align = true,
            where_condition_style = "stacked"
        },
        expected = {
            -- Comments on WHERE conditions should align
            contains = { "-- Filter by ID", "-- Filter by name", "-- Only active" }
        }
    },
    {
        id = 8913,
        type = "formatter",
        name = "Align inline comments - multiple statements",
        input = "SELECT id -- First\nFROM t1;\n\nSELECT name -- Second\nFROM t2",
        config = {
            inline_comment_align = true
        },
        expected = {
            -- Comments in separate statements should be independent
            contains = { "-- First", "-- Second" }
        }
    },
    {
        id = 8914,
        type = "formatter",
        name = "Align inline comments - CTE",
        input = "WITH cte AS ( -- CTE definition\n    SELECT id -- Column\n    FROM t\n)\nSELECT * FROM cte",
        config = {
            inline_comment_align = true
        },
        expected = {
            -- Comments in CTE should be preserved
            contains = { "-- CTE definition", "-- Column" }
        }
    },
    {
        id = 8915,
        type = "formatter",
        name = "Align inline comments - INSERT columns",
        input = "INSERT INTO users (id, -- PK\n    name, -- Name\n    email) -- Email\nVALUES (1, 'x', 'y')",
        config = {
            inline_comment_align = true,
            insert_columns_style = "stacked"
        },
        expected = {
            -- Comments in INSERT column list should align
            contains = { "-- PK", "-- Name", "-- Email" }
        }
    },
}
