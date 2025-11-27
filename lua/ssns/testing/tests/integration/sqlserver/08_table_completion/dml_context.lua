-- Integration Tests: Table Completion - DML Context
-- Test IDs: 4081-4100
-- Tests table completion in INSERT, UPDATE, DELETE, MERGE statements

return {
  -- ============================================================================
  -- 4081-4087: INSERT INTO table completion
  -- ============================================================================
  {
    number = 4081,
    description = "INSERT INTO - basic table completion",
    database = "vim_dadbod_test",
    query = [[INSERT INTO ]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
          "Projects",
        },
        excludes = {
          -- Views and synonyms may be excluded from INSERT
          -- depending on implementation
        },
      },
    },
  },
  {
    number = 4082,
    description = "INSERT INTO - schema-qualified",
    database = "vim_dadbod_test",
    query = [[INSERT INTO dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4083,
    description = "INSERT INTO - prefix filter",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Emp]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4084,
    description = "INSERT INTO - bracketed table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO [Emp]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4085,
    description = "INSERT INTO - multiline",
    database = "vim_dadbod_test",
    query = [[INSERT INTO
  ]],
    cursor = { line = 1, col = 2 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4086,
    description = "INSERT INTO - cross-database",
    database = "vim_dadbod_test",
    query = [[INSERT INTO TEST.dbo.]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "TestTable",
        },
      },
    },
  },
  {
    number = 4087,
    description = "INSERT INTO - hr schema",
    database = "vim_dadbod_test",
    query = [[INSERT INTO hr.]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Benefits",
        },
      },
    },
  },

  -- ============================================================================
  -- 4088-4093: UPDATE table completion
  -- ============================================================================
  {
    number = 4088,
    description = "UPDATE - basic table completion",
    database = "vim_dadbod_test",
    query = [[UPDATE ]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4089,
    description = "UPDATE - schema-qualified",
    database = "vim_dadbod_test",
    query = [[UPDATE dbo.]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4090,
    description = "UPDATE - prefix filter",
    database = "vim_dadbod_test",
    query = [[UPDATE Emp]],
    cursor = { line = 0, col = 10 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4091,
    description = "UPDATE - with alias (FROM clause)",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET Name = 'Test' FROM ]],
    cursor = { line = 0, col = 33 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4092,
    description = "UPDATE - JOIN in UPDATE FROM",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET Name = 'Test' FROM Employees e JOIN ]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4093,
    description = "UPDATE - multiline UPDATE",
    database = "vim_dadbod_test",
    query = [[UPDATE
  ]],
    cursor = { line = 1, col = 2 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },

  -- ============================================================================
  -- 4094-4098: DELETE FROM table completion
  -- ============================================================================
  {
    number = 4094,
    description = "DELETE FROM - basic table completion",
    database = "vim_dadbod_test",
    query = [[DELETE FROM ]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4095,
    description = "DELETE FROM - schema-qualified",
    database = "vim_dadbod_test",
    query = [[DELETE FROM dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4096,
    description = "DELETE FROM - with alias",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM ]],
    cursor = { line = 0, col = 14 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4097,
    description = "DELETE - without FROM keyword",
    database = "vim_dadbod_test",
    query = [[DELETE ]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4098,
    description = "DELETE FROM - JOIN for filtering",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM Employees e JOIN ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },

  -- ============================================================================
  -- 4099-4100: MERGE statement table completion
  -- ============================================================================
  {
    number = 4099,
    description = "MERGE INTO - target table completion",
    database = "vim_dadbod_test",
    query = [[MERGE INTO ]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4100,
    description = "MERGE USING - source table completion",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING ]],
    cursor = { line = 1, col = 6 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
          "Projects",
        },
      },
    },
  },
}
