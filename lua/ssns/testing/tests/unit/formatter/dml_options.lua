-- Test file: dml_options.lua
-- IDs: 8800-8850
-- Tests: Phase 2 DML options - INSERT, UPDATE, DELETE, MERGE specific formatting

return {
    -- INSERT multi-row style
    {
        id = 8800,
        type = "formatter",
        name = "insert_multi_row_style stacked (default)",
        input = "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane'), (3, 'Bob')",
        opts = { insert_multi_row_style = "stacked" },
        expected = {
            matches = { "%(1, 'John'%),\n.-%( ?2, 'Jane'%),\n.-%( ?3, 'Bob'%)" }
        }
    },
    {
        id = 8801,
        type = "formatter",
        name = "insert_multi_row_style inline",
        input = "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane')",
        opts = { insert_multi_row_style = "inline" },
        expected = {
            contains = { "(1, 'John'), (2, 'Jane')" }  -- Same line
        }
    },

    -- UPDATE SET style
    {
        id = 8810,
        type = "formatter",
        name = "update_set_style stacked",
        input = "UPDATE users SET name = 'John', email = 'john@example.com', updated_at = GETDATE() WHERE id = 1",
        opts = { update_set_style = "stacked" },
        expected = {
            matches = { "SET name = 'John',\n.-email = 'john@example.com',\n.-updated_at = GETDATE%(%)" }
        }
    },
    {
        id = 8811,
        type = "formatter",
        name = "update_set_style inline",
        input = "UPDATE users SET name = 'John', email = 'john@example.com' WHERE id = 1",
        opts = { update_set_style = "inline" },
        expected = {
            contains = { "SET name = 'John', email = 'john@example.com'" }
        }
    },
    {
        id = 8812,
        type = "formatter",
        name = "update_set_align true - equals aligned",
        input = "UPDATE users SET name = 'John', email = 'john@example.com' WHERE id = 1",
        opts = { update_set_style = "stacked", update_set_align = true },
        expected = {
            -- With alignment: name and email should have equals at same column
            -- name  = 'John',
            -- email = 'john@example.com'
            -- The = should align - email is 5 chars, name is 4 chars, so name gets 1 space padding
            contains = { "name  =", "email =" }
        }
    },
    {
        id = 8813,
        type = "formatter",
        name = "update_set_align true - multiple columns",
        input = "UPDATE users SET a = 1, bb = 2, ccc = 3 WHERE id = 1",
        opts = { update_set_style = "stacked", update_set_align = true },
        expected = {
            -- Longest column is 'ccc' (3 chars), so:
            -- a   = 1,
            -- bb  = 2,
            -- ccc = 3
            contains = { "a   =", "bb  =", "ccc =" }
        }
    },
    {
        id = 8814,
        type = "formatter",
        name = "update_set_align false - no alignment",
        input = "UPDATE users SET a = 1, bb = 2, ccc = 3 WHERE id = 1",
        opts = { update_set_style = "stacked", update_set_align = false },
        expected = {
            -- Without alignment, standard spacing (one space around =)
            contains = { "a = 1", "bb = 2", "ccc = 3" }
        }
    },
    {
        id = 8815,
        type = "formatter",
        name = "update_set_align with qualified column names",
        input = "UPDATE u SET u.name = 'John', u.email = 'john@example.com' FROM users u WHERE u.id = 1",
        opts = { update_set_style = "stacked", update_set_align = true },
        expected = {
            -- Qualified names: u.name (6 chars) and u.email (7 chars)
            contains = { "u.name  =", "u.email =" }
        }
    },

    -- OUTPUT clause
    {
        id = 8820,
        type = "formatter",
        name = "output_clause_newline true (default)",
        input = "INSERT INTO users (name) OUTPUT INSERTED.id VALUES ('John')",
        opts = { output_clause_newline = true },
        expected = {
            matches = { "users%(name%)\n.-OUTPUT" }  -- No space before ( after identifier
        }
    },
    {
        id = 8821,
        type = "formatter",
        name = "output_clause_newline false",
        input = "INSERT INTO users (name) OUTPUT INSERTED.id VALUES ('John')",
        opts = { output_clause_newline = false },
        expected = {
            contains = { "users(name) OUTPUT" }  -- No space before (, OUTPUT on same line
        }
    },
    {
        id = 8822,
        type = "formatter",
        name = "OUTPUT in DELETE statement",
        input = "DELETE FROM users OUTPUT DELETED.* WHERE id = 1",
        opts = { output_clause_newline = true, delete_from_newline = false },
        expected = {
            matches = { "DELETE FROM users\n.-OUTPUT DELETED" }
        }
    },
    {
        id = 8823,
        type = "formatter",
        name = "OUTPUT in UPDATE statement",
        input = "UPDATE users SET status = 'deleted' OUTPUT DELETED.id, INSERTED.status WHERE id = 1",
        opts = { output_clause_newline = true },
        expected = {
            -- OUTPUT columns follow trailing comma style
            contains = { "OUTPUT DELETED.id,", "INSERTED.status" }
        }
    },

    -- MERGE statement
    {
        id = 8830,
        type = "formatter",
        name = "merge_when_newline true (default)",
        input = "MERGE INTO target t USING source s ON t.id = s.id WHEN MATCHED THEN UPDATE SET t.name = s.name WHEN NOT MATCHED THEN INSERT (id, name) VALUES (s.id, s.name)",
        opts = { merge_when_newline = true },
        expected = {
            matches = { "\nWHEN MATCHED", "\nWHEN NOT MATCHED" }
        }
    },
    {
        id = 8831,
        type = "formatter",
        name = "merge_when_newline false",
        input = "MERGE INTO target t USING source s ON t.id = s.id WHEN MATCHED THEN UPDATE SET t.name = s.name",
        opts = { merge_when_newline = false },
        expected = {
            -- WHEN stays inline with previous content
            not_contains = { "\nWHEN MATCHED" }
        }
    },
    {
        id = 8832,
        type = "formatter",
        name = "MERGE with multiple WHEN clauses",
        input = "MERGE t USING s ON t.id = s.id WHEN MATCHED AND s.deleted = 1 THEN DELETE WHEN MATCHED THEN UPDATE SET t.name = s.name WHEN NOT MATCHED BY TARGET THEN INSERT (id) VALUES (s.id) WHEN NOT MATCHED BY SOURCE THEN DELETE",
        opts = { merge_when_newline = true },
        expected = {
            -- WHEN clauses start on new lines; THEN action may be on separate line
            contains = { "WHEN MATCHED AND", "WHEN MATCHED THEN", "WHEN NOT MATCHED BY TARGET", "WHEN NOT MATCHED BY SOURCE" }
        }
    },

    -- DELETE statement
    {
        id = 8840,
        type = "formatter",
        name = "DELETE basic formatting",
        input = "DELETE FROM users WHERE status = 'deleted' AND deleted_at < '2020-01-01'",
        opts = { and_or_position = "leading", delete_from_newline = false },
        expected = {
            matches = { "DELETE FROM users\nWHERE status = 'deleted'\n.-AND deleted_at" }
        }
    },
    {
        id = 8841,
        type = "formatter",
        name = "DELETE TOP",
        input = "DELETE TOP (100) FROM logs WHERE created_at < '2020-01-01'",
        opts = { delete_from_newline = false },
        expected = {
            contains = { "DELETE TOP (100) FROM logs" }
        }
    },

    -- Combined DML tests
    {
        id = 8845,
        type = "formatter",
        name = "Complex INSERT with all options",
        input = "INSERT INTO users (id, name, email, status) OUTPUT INSERTED.id VALUES (1, 'John', 'john@example.com', 'active'), (2, 'Jane', 'jane@example.com', 'active')",
        opts = {
            insert_columns_style = "stacked",
            insert_multi_row_style = "stacked",
            output_clause_newline = true
        },
        expected = {
            contains = { "INSERT INTO users", "OUTPUT INSERTED.id", "VALUES" }
        }
    },
    {
        id = 8846,
        type = "formatter",
        name = "Complex UPDATE with all options",
        input = "UPDATE users SET name = 'Updated', email = 'new@example.com', updated_at = GETDATE() OUTPUT DELETED.name, INSERTED.name WHERE id = 1 AND status = 'active'",
        opts = {
            update_set_style = "stacked",
            output_clause_newline = true,
            and_or_position = "leading"
        },
        expected = {
            matches = { "SET name = 'Updated',\n", "OUTPUT DELETED", "WHERE id = 1\n.-AND status" }
        }
    },
    {
        id = 8847,
        type = "formatter",
        name = "INSERT...SELECT formatting",
        input = "INSERT INTO archive (id, name) SELECT id, name FROM users WHERE deleted = 1",
        expected = {
            -- No space between table name and column list in INSERT
            contains = { "INSERT INTO archive(id, name)", "SELECT id,", "FROM users", "WHERE deleted = 1" }
        }
    },
    {
        id = 8848,
        type = "formatter",
        name = "UPDATE with FROM clause (SQL Server)",
        input = "UPDATE u SET u.status = 'verified' FROM users u INNER JOIN verified v ON u.id = v.user_id WHERE v.verified_at IS NOT NULL",
        opts = { update_set_style = "stacked" },
        expected = {
            contains = { "UPDATE u", "SET u.status = 'verified'", "FROM users u", "INNER JOIN verified v" }
        }
    },
    {
        id = 8849,
        type = "formatter",
        name = "DELETE with JOIN (SQL Server)",
        input = "DELETE u FROM users u INNER JOIN banned b ON u.id = b.user_id WHERE b.banned_at < '2020-01-01'",
        expected = {
            contains = { "DELETE u", "FROM users u", "INNER JOIN banned b" }
        }
    },
    {
        id = 8850,
        type = "formatter",
        name = "TRUNCATE TABLE formatting",
        input = "TRUNCATE TABLE logs",
        expected = {
            contains = { "TRUNCATE TABLE logs" }
        }
    },
}
