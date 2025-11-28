-- Integration Tests: Column Completion - Other Clauses
-- Test IDs: 4191-4230
-- Tests column completion in ORDER BY, GROUP BY, HAVING, and other clauses

return {
  -- ============================================================================
  -- 4191-4200: ORDER BY clause
  -- ============================================================================
  {
    number = 4191,
    description = "ORDER BY - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4192,
    description = "ORDER BY - with prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY First█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4193,
    description = "ORDER BY - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e ORDER BY e.█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4194,
    description = "ORDER BY - second column after comma",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4195,
    description = "ORDER BY - after ASC",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName ASC, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4196,
    description = "ORDER BY - after DESC",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName DESC, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4197,
    description = "ORDER BY - multi-table JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4198,
    description = "ORDER BY - qualified from joined table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY d.█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4199,
    description = "ORDER BY - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees
ORDER BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4200,
    description = "ORDER BY - after WHERE clause",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID = 1 ORDER BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Salary",
        },
      },
    },
  },

  -- ============================================================================
  -- 4201-4210: GROUP BY clause
  -- ============================================================================
  {
    number = 4201,
    description = "GROUP BY - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4202,
    description = "GROUP BY - second column",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Email",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4203,
    description = "GROUP BY - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4204,
    description = "GROUP BY - multi-table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4205,
    description = "GROUP BY - qualified from specific table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4206,
    description = "GROUP BY - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4207,
    description = "GROUP BY - with WHERE",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees WHERE Salary > 50000 GROUP BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4208,
    description = "GROUP BY - multiple grouping columns",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, Email, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4209,
    description = "GROUP BY - with prefix filter",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY Dep█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4210,
    description = "GROUP BY - ROLLUP clause",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY ROLLUP()█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4211-4220: HAVING clause
  -- ============================================================================
  {
    number = 4211,
    description = "HAVING - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4212,
    description = "HAVING - after aggregate function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT()█ > 5]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4213,
    description = "HAVING - SUM function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, SUM(Salary) FROM Employees GROUP BY DepartmentID HAVING SUM(█) > 100000]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4214,
    description = "HAVING - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.DepartmentID HAVING e█.]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4215,
    description = "HAVING - multi-table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.DepartmentName HAVING █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4216,
    description = "HAVING - AND condition",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > 5 AND █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4217,
    description = "HAVING - complex aggregate",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING AVG() >█ 50000]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4218,
    description = "HAVING - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY DepartmentID
HAVING █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4219,
    description = "HAVING - MIN/MAX function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING MAX() <█ '2020-01-01']],
    expected = {
      type = "column",
      items = {
        includes = {
          "HireDate",
        },
      },
    },
  },
  {
    number = 4220,
    description = "HAVING - nested aggregate",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING COUNT(DISTINCT )█ > 1]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ManagerID",
          "FirstName",
        },
      },
    },
  },

  -- ============================================================================
  -- 4221-4230: UPDATE SET and INSERT clauses
  -- ============================================================================
  {
    number = 4221,
    description = "UPDATE SET - column list",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4222,
    description = "UPDATE SET - second column",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET FirstName = 'John', █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4223,
    description = "UPDATE SET - value side from same table",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary + █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4224,
    description = "UPDATE FROM - column from joined table",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.Salary = d.█ FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Budget",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4225,
    description = "INSERT columns - column list",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4226,
    description = "INSERT columns - second column",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName, █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4227,
    description = "INSERT columns - schema-qualified table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO dbo.Employees (█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4228,
    description = "INSERT SELECT - columns in subquery",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName, LastName) SELECT █ FROM Employees]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4229,
    description = "INSERT multiline - column list",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees
  (FirstName,
   █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4230,
    description = "DELETE WHERE - column completion",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
}
