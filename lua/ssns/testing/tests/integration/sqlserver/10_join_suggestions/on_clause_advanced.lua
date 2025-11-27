-- Integration Tests: JOIN Suggestions - ON Clause Advanced
-- Test IDs: 4351-4400
-- Tests advanced ON clause completion, type warnings, and fuzzy matching

return {
  -- ============================================================================
  -- 4351-4360: ON clause type warnings
  -- ============================================================================
  {
    number = 4351,
    description = "ON clause - type mismatch warning (int vs varchar)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentID]],
    cursor = { line = 0, col = 79 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4352,
    description = "ON clause - no warning for compatible types (int = int)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 82 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4353,
    description = "ON clause - warning for date vs numeric",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.ProjectID]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4354,
    description = "ON clause - compatible varchar types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentName]],
    cursor = { line = 0, col = 79 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4355,
    description = "ON clause - compatible numeric types (int vs bigint)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.OrderID]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4356,
    description = "ON clause - compatible date types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDate]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4357,
    description = "ON clause - warning for bit vs varchar",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.IsActive = d.DepartmentName]],
    cursor = { line = 0, col = 75 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4358,
    description = "ON clause - compatible decimal types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budget]],
    cursor = { line = 0, col = 62 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4359,
    description = "ON clause - warning for uniqueidentifier vs int",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Customers c ON e.EmployeeID = c.CustomerGUID]],
    cursor = { line = 0, col = 74 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4360,
    description = "ON clause - compatible nullable columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.ManagerID = d.ManagerID]],
    cursor = { line = 0, col = 72 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },

  -- ============================================================================
  -- 4361-4370: Fuzzy column name matching in ON clause
  -- ============================================================================
  {
    number = 4361,
    description = "ON clause - fuzzy match DeptID to DepartmentID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DeptID = d.]],
    cursor = { line = 0, col = 60 },
    expected = {
      type = "column",
      items = {
        -- Should prioritize DepartmentID due to fuzzy match with DeptID
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4362,
    description = "ON clause - fuzzy match EmpID to EmployeeID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON o.EmpID = e.]],
    cursor = { line = 0, col = 52 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4363,
    description = "ON clause - fuzzy match CustID to CustomerID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustID = c.]],
    cursor = { line = 0, col = 54 },
    expected = {
      type = "column",
      items = {
        includes = {
          "CustomerID",
        },
      },
    },
  },
  {
    number = 4364,
    description = "ON clause - fuzzy match ProjID to ProjectID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Tasks t JOIN Projects p ON t.ProjID = p.]],
    cursor = { line = 0, col = 52 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4365,
    description = "ON clause - fuzzy match with underscore (Dept_ID to DepartmentID)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.Dept_ID = d.]],
    cursor = { line = 0, col = 61 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
          "Dept_ID",
        },
      },
    },
  },
  {
    number = 4366,
    description = "ON clause - fuzzy match Manager to ManagerID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Employees m ON e.Manager = m.]],
    cursor = { line = 0, col = 58 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ManagerID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4367,
    description = "ON clause - exact match preferred over fuzzy",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- DepartmentID should be first due to exact name match
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4368,
    description = "ON clause - fuzzy match with camelCase variation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.departmentId = d.]],
    cursor = { line = 0, col = 67 },
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
    number = 4369,
    description = "ON clause - fuzzy match location columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Locations l ON e.LocID = l.]],
    cursor = { line = 0, col = 55 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "LocationID",
          "LocID",
        },
      },
    },
  },
  {
    number = 4370,
    description = "ON clause - no fuzzy match for unrelated columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        -- Should suggest string columns, not ID columns
        includes_any = {
          "DepartmentName",
        },
        excludes = {
          "DepartmentID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4371-4380: Complex multi-table ON clauses
  -- ============================================================================
  {
    number = 4371,
    description = "ON clause - three table join, third table ON",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON ]],
    cursor = { line = 2, col = 18 },
    expected = {
      type = "column",
      items = {
        -- Should offer columns from all three tables
        includes_any = {
          "ProjectID",
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4372,
    description = "ON clause - four table join with alias",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.DepartmentID = d.DepartmentID
JOIN Customers c ON c.]],
    cursor = { line = 4, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "CustomerID",
        },
      },
    },
  },
  {
    number = 4373,
    description = "ON clause - self-join with different aliases",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e1
JOIN Employees e2 ON e1.ManagerID = e2.]],
    cursor = { line = 1, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4374,
    description = "ON clause - hierarchical self-join (three levels)",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e1
JOIN Employees e2 ON e1.ManagerID = e2.EmployeeID
JOIN Employees e3 ON e2.ManagerID = e3.]],
    cursor = { line = 3, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4375,
    description = "ON clause - mixed JOIN types",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p ON p.DepartmentID = d.DepartmentID
RIGHT JOIN Orders o ON o.]],
    cursor = { line = 4, col = 23 },
    expected = {
      type = "column",
      items = {
        includes = {
          "OrderID",
          "CustomerID",
        },
      },
    },
  },
  {
    number = 4376,
    description = "ON clause - compound condition with AND",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.LocationID = d.]],
    cursor = { line = 1, col = 72 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "LocationID",
        },
      },
    },
  },
  {
    number = 4377,
    description = "ON clause - compound condition with OR",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID OR e.ManagerID = d.]],
    cursor = { line = 1, col = 69 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ManagerID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4378,
    description = "ON clause - parenthesized conditions",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON (e.DepartmentID = d.DepartmentID) AND (e.LocationID = d.]],
    cursor = { line = 1, col = 76 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "LocationID",
        },
      },
    },
  },
  {
    number = 4379,
    description = "ON clause - with BETWEEN operator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN SalaryRanges sr ON e.Salary BETWEEN sr.]],
    cursor = { line = 1, col = 43 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "MinSalary",
          "MaxSalary",
        },
      },
    },
  },
  {
    number = 4380,
    description = "ON clause - with IN subquery placeholder",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID IN (SELECT  FROM Departments)]],
    cursor = { line = 1, col = 54 },
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
  -- 4381-4390: Cross-database and schema-qualified ON clauses
  -- ============================================================================
  {
    number = 4381,
    description = "ON clause - schema-qualified tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.]],
    cursor = { line = 0, col = 56 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4382,
    description = "ON clause - cross-database join",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN vim_dadbod_second.dbo.ExtDepartments ed ON e.DepartmentID = ed.]],
    cursor = { line = 1, col = 66 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
          "ExtDeptID",
        },
      },
    },
  },
  {
    number = 4383,
    description = "ON clause - mixed schema qualification",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN hr.Benefits b ON e.EmployeeID = b.]],
    cursor = { line = 0, col = 63 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "BenefitID",
        },
      },
    },
  },
  {
    number = 4384,
    description = "ON clause - three-part name tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN vim_dadbod_test.dbo.Departments d ON e.DepartmentID = d.]],
    cursor = { line = 1, col = 59 },
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
    number = 4385,
    description = "ON clause - bracketed identifiers",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Employees] e JOIN [Departments] d ON e.[DepartmentID] = d.]],
    cursor = { line = 0, col = 71 },
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
    number = 4386,
    description = "ON clause - bracketed schema and table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [dbo].[Employees] e JOIN [dbo].[Departments] d ON e.]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4387,
    description = "ON clause - cross-schema in same database",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN sales.Orders o ON e.EmployeeID = o.]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "SalesRepID",
        },
      },
    },
  },
  {
    number = 4388,
    description = "ON clause - linked server simulation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN RemoteDB.dbo.RemoteTable r ON e.EmployeeID = r.]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "RemoteID",
        },
      },
    },
  },
  {
    number = 4389,
    description = "ON clause - mixed bracketed and unbracketed",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN [Special Table] st ON e.EmployeeID = st.]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "SpecialID",
        },
      },
    },
  },
  {
    number = 4390,
    description = "ON clause - fully qualified with brackets",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [vim_dadbod_test].[dbo].[Employees] e
JOIN [vim_dadbod_test].[dbo].[Departments] d ON e.]],
    cursor = { line = 1, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4391-4400: Edge cases and special scenarios
  -- ============================================================================
  {
    number = 4391,
    description = "ON clause - table alias same as column name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees EmployeeID JOIN Departments d ON EmployeeID.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- Alias EmployeeID refers to Employees table
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4392,
    description = "ON clause - reserved word as alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees [select] JOIN Departments d ON [select].]],
    cursor = { line = 0, col = 64 },
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
  {
    number = 4393,
    description = "ON clause - numeric alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees [1] JOIN Departments [2] ON [1].]],
    cursor = { line = 0, col = 55 },
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
  {
    number = 4394,
    description = "ON clause - empty alias after dot (edge case)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4395,
    description = "ON clause - whitespace handling",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON   e   .   ]],
    cursor = { line = 0, col = 57 },
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
  {
    number = 4396,
    description = "ON clause - tab characters",
    database = "vim_dadbod_test",
    query = "SELECT * FROM Employees e JOIN Departments d ON\te.",
    cursor = { line = 0, col = 49 },
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
  {
    number = 4397,
    description = "ON clause - case sensitivity (lowercase)",
    database = "vim_dadbod_test",
    query = [[select * from employees e join departments d on e.]],
    cursor = { line = 0, col = 48 },
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
  {
    number = 4398,
    description = "ON clause - mixed case",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees E JOIN Departments D ON E.departmentid = D.]],
    cursor = { line = 0, col = 65 },
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
    number = 4399,
    description = "ON clause - Unicode table/column names",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN [Départements] d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
          "DépartementID",
        },
      },
    },
  },
  {
    number = 4400,
    description = "ON clause - extremely long query",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, e.FirstName, e.LastName, e.Email, e.Phone, e.Address, e.City, e.State, e.Zip, d.DepartmentID, d.DepartmentName, d.Budget, d.ManagerID FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 209 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
}
