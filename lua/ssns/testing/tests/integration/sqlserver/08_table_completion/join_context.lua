-- Integration Tests: Table Completion - JOIN Context
-- Test IDs: 4061-4080
-- Tests table completion in JOIN clauses

return {
  -- ============================================================================
  -- 4061-4070: Basic JOIN table completion
  -- ============================================================================
  {
    number = 4061,
    description = "JOIN - basic table completion after JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
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
  {
    number = 4062,
    description = "JOIN - INNER JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e INNER JOIN ]],
    cursor = { line = 0, col = 38 },
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
    number = 4063,
    description = "JOIN - LEFT JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT JOIN ]],
    cursor = { line = 0, col = 37 },
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
    number = 4064,
    description = "JOIN - RIGHT JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e RIGHT JOIN ]],
    cursor = { line = 0, col = 38 },
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
    number = 4065,
    description = "JOIN - FULL OUTER JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e FULL OUTER JOIN ]],
    cursor = { line = 0, col = 42 },
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
    number = 4066,
    description = "JOIN - LEFT OUTER JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT OUTER JOIN ]],
    cursor = { line = 0, col = 42 },
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
    number = 4067,
    description = "JOIN - CROSS JOIN table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e CROSS JOIN ]],
    cursor = { line = 0, col = 38 },
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
    number = 4068,
    description = "JOIN - multiline JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN ]],
    cursor = { line = 2, col = 5 },
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
    number = 4069,
    description = "JOIN - second JOIN in chain",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DeptID = d.ID JOIN ]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
        },
      },
    },
  },
  {
    number = 4070,
    description = "JOIN - third JOIN in chain",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DeptID = d.ID
JOIN Projects p ON p.DeptID = d.ID
JOIN ]],
    cursor = { line = 4, col = 5 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Customers",
          "Orders",
        },
      },
    },
  },

  -- ============================================================================
  -- 4071-4080: JOIN with FK-based suggestions
  -- ============================================================================
  {
    number = 4071,
    description = "JOIN - FK suggestion from Employees (DepartmentID FK)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Departments should be suggested with high priority due to FK
        includes = {
          "Departments",
        },
        -- Should include ON clause suggestion
        has_on_clause = true,
      },
    },
  },
  {
    number = 4072,
    description = "JOIN - FK suggestion from Orders (CustomerID, EmployeeID FKs)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Customers",
          "Employees",
        },
      },
    },
  },
  {
    number = 4073,
    description = "JOIN - FK chain: Customers -> Countries (via FK)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",
        },
      },
    },
  },
  {
    number = 4074,
    description = "JOIN - multi-hop FK: Orders -> Customers -> Countries",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerID = c.CustomerID JOIN ]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",  -- Via Customers FK
          "Employees",  -- Via Orders FK
        },
      },
    },
  },
  {
    number = 4075,
    description = "JOIN - schema-qualified FK suggestion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN dbo.]],
    cursor = { line = 0, col = 39 },
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
    number = 4076,
    description = "JOIN - views in JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN vw_]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "table",
      items = {
        includes = {
          "vw_ActiveEmployees",
          "vw_DepartmentSummary",
        },
      },
    },
  },
  {
    number = 4077,
    description = "JOIN - synonyms in JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN syn_]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "table",
      items = {
        includes = {
          "syn_Depts",
          "syn_Employees",
        },
      },
    },
  },
  {
    number = 4078,
    description = "JOIN - after ON clause complete, new JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT JOIN ]],
    cursor = { line = 3, col = 10 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
        },
      },
    },
  },
  {
    number = 4079,
    description = "JOIN - prefix filter in JOIN context",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Dep]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
        excludes = {
          "Employees",
          "Projects",
        },
      },
    },
  },
  {
    number = 4080,
    description = "JOIN - cross-database in JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN TEST.dbo.]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "TestTable",
        },
      },
    },
  },
}
