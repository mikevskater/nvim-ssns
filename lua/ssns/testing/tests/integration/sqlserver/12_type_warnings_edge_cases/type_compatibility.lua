-- Integration Tests: Type Compatibility and Warnings
-- Test IDs: 4651-4720
-- Tests type compatibility checking and warning scenarios

return {
  -- ============================================================================
  -- 4651-4670: WHERE clause type compatibility
  -- ============================================================================
  {
    number = 4651,
    description = "Type compatibility - int = int (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = DepartmentID]],
    cursor = { line = 0, col = 52 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4652,
    description = "Type compatibility - varchar = varchar (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE FirstName = LastName]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4653,
    description = "Type compatibility - int = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = FirstName]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "implicit_conversion",
        },
      },
    },
  },
  {
    number = 4654,
    description = "Type compatibility - date = int (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE HireDate = EmployeeID]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4655,
    description = "Type compatibility - datetime = date (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDate]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4656,
    description = "Type compatibility - decimal = int (compatible with warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary = EmployeeID]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "no_warning",
      -- Int to decimal is implicit safe conversion
      valid = true,
    },
  },
  {
    number = 4657,
    description = "Type compatibility - bit = int (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE IsActive = 1]],
    cursor = { line = 0, col = 42 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4658,
    description = "Type compatibility - bit = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE IsActive = FirstName]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4659,
    description = "Type compatibility - varchar = varchar comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Email = FirstName]],
    cursor = { line = 0, col = 45 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4660,
    description = "Type compatibility - nvarchar = varchar (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentName]],
    cursor = { line = 0, col = 77 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4661,
    description = "Type compatibility - bigint = int (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Employees e ON o.OrderID = e.EmployeeID]],
    cursor = { line = 0, col = 65 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4662,
    description = "Type compatibility - float = decimal (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budget]],
    cursor = { line = 0, col = 63 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4663,
    description = "Type compatibility - int = int (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID = EmployeeID]],
    cursor = { line = 0, col = 52 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4664,
    description = "Type compatibility - decimal = decimal (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Projects WHERE Budget = Budget]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4665,
    description = "Type compatibility - date = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Projects WHERE StartDate = ProjectName]],
    cursor = { line = 0, col = 53 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4666,
    description = "Type compatibility - decimal = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Projects WHERE Budget = ProjectName]],
    cursor = { line = 0, col = 50 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4667,
    description = "Type compatibility - int = decimal (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments WHERE DepartmentID = Budget]],
    cursor = { line = 0, col = 55 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4668,
    description = "Type compatibility - varchar = varchar (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers WHERE Name = Email]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4669,
    description = "Type compatibility - decimal = decimal (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.Salary = d.Budget]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4670,
    description = "Type compatibility - date = date (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDate]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },

  -- ============================================================================
  -- 4671-4690: Implicit conversion warnings in JOIN ON
  -- ============================================================================
  {
    number = 4671,
    description = "JOIN ON - compatible FK types (int = int)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 78 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4672,
    description = "JOIN ON - varchar to int conversion (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Employees e ON o.OrderId = e.EmployeeID]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "implicit_conversion",
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4673,
    description = "JOIN ON - date to datetime (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Customers c ON e.HireDate = c.CreatedDate]],
    cursor = { line = 0, col = 73 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4674,
    description = "JOIN ON - self-join on int columns (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Employees m ON e.DepartmentID = m.EmployeeID]],
    cursor = { line = 0, col = 72 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4675,
    description = "JOIN ON - varchar = varchar (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN Countries co ON c.Country = co.CountryName]],
    cursor = { line = 0, col = 74 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4676,
    description = "JOIN ON - multiple conditions type check",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.FirstName = d.DepartmentID]],
    cursor = { line = 0, col = 111 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4677,
    description = "JOIN ON - multiple compatible conditions",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Products p ON o.Id = p.Id AND o.OrderId = p.ProductId]],
    cursor = { line = 0, col = 84 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4678,
    description = "JOIN ON - expression result type",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID + 0]],
    cursor = { line = 0, col = 82 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4679,
    description = "JOIN ON - CAST expression type",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON CAST(e.EmployeeID AS VARCHAR(10)) = o.OrderId]],
    cursor = { line = 0, col = 93 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4680,
    description = "JOIN ON - explicit collation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName COLLATE Latin1_General_CI_AS = d.DepartmentName]],
    cursor = { line = 0, col = 104 },
    expected = {
      -- Explicit collation should resolve
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4681,
    description = "JOIN ON - cross-schema type consistency",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.EmployeeID]],
    cursor = { line = 0, col = 80 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4682,
    description = "JOIN ON - bit to int comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.IsActive = d.DepartmentID]],
    cursor = { line = 0, col = 75 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4683,
    description = "JOIN ON - varchar length difference",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.Email = d.DepartmentName]],
    cursor = { line = 0, col = 75 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4684,
    description = "JOIN ON - int to int consistency",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c1 JOIN Customers c2 ON c1.CountryID = c2.CountryID]],
    cursor = { line = 0, col = 78 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4685,
    description = "JOIN ON - decimal precision compatible",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budget]],
    cursor = { line = 0, col = 63 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4686,
    description = "JOIN ON - date vs datetime",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.OrderDate = c.CreatedDate]],
    cursor = { line = 0, col = 72 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4687,
    description = "JOIN ON - date to date comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Projects p ON o.OrderDate = p.StartDate]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4688,
    description = "JOIN ON - varchar compatibility",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Customers c ON e.Email = c.Email]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4689,
    description = "JOIN ON - varchar id comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Products p ON o.OrderId = p.ProductId]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4690,
    description = "JOIN ON - varchar to varchar compatibility",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN Products p ON c.CustomerId = p.ProductId]],
    cursor = { line = 0, col = 74 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },

  -- ============================================================================
  -- 4691-4710: Type compatibility in expressions
  -- ============================================================================
  {
    number = 4691,
    description = "Expression - arithmetic on compatible types",
    database = "vim_dadbod_test",
    query = [[SELECT Salary + DepartmentID FROM Employees]],
    cursor = { line = 0, col = 29 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4692,
    description = "Expression - arithmetic on incompatible types",
    database = "vim_dadbod_test",
    query = [[SELECT Salary + FirstName FROM Employees]],
    cursor = { line = 0, col = 25 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "invalid_operation",
        },
      },
    },
  },
  {
    number = 4693,
    description = "Expression - string concatenation",
    database = "vim_dadbod_test",
    query = [[SELECT FirstName + ' ' + LastName FROM Employees]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4694,
    description = "Expression - CONCAT with mixed types",
    database = "vim_dadbod_test",
    query = [[SELECT CONCAT(FirstName, EmployeeID) FROM Employees]],
    cursor = { line = 0, col = 37 },
    expected = {
      -- CONCAT handles type conversion
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4695,
    description = "Expression - CASE result type consistency",
    database = "vim_dadbod_test",
    query = [[SELECT CASE WHEN IsActive = 1 THEN Salary ELSE 'N/A' END FROM Employees]],
    cursor = { line = 0, col = 57 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "case_type_inconsistency",
        },
      },
    },
  },
  {
    number = 4696,
    description = "Expression - COALESCE type consistency",
    database = "vim_dadbod_test",
    query = [[SELECT COALESCE(DepartmentID, FirstName) FROM Employees]],
    cursor = { line = 0, col = 42 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4697,
    description = "Expression - IIF type consistency",
    database = "vim_dadbod_test",
    query = [[SELECT IIF(IsActive = 1, Salary, 'None') FROM Employees]],
    cursor = { line = 0, col = 41 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4698,
    description = "Expression - NULLIF compatible types",
    database = "vim_dadbod_test",
    query = [[SELECT NULLIF(EmployeeID, DepartmentID) FROM Employees]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4699,
    description = "Expression - NULLIF incompatible types",
    database = "vim_dadbod_test",
    query = [[SELECT NULLIF(EmployeeID, FirstName) FROM Employees]],
    cursor = { line = 0, col = 37 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4700,
    description = "Expression - aggregate with valid type",
    database = "vim_dadbod_test",
    query = [[SELECT SUM(Salary) FROM Employees]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4701,
    description = "Expression - aggregate with invalid type",
    database = "vim_dadbod_test",
    query = [[SELECT SUM(FirstName) FROM Employees]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "invalid_aggregate",
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4702,
    description = "Expression - COUNT with any type",
    database = "vim_dadbod_test",
    query = [[SELECT COUNT(FirstName) FROM Employees]],
    cursor = { line = 0, col = 23 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4703,
    description = "Expression - AVG with numeric",
    database = "vim_dadbod_test",
    query = [[SELECT AVG(Salary) FROM Employees]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4704,
    description = "Expression - AVG with non-numeric",
    database = "vim_dadbod_test",
    query = [[SELECT AVG(FirstName) FROM Employees]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "invalid_aggregate",
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4705,
    description = "Expression - DATEADD with date column",
    database = "vim_dadbod_test",
    query = [[SELECT DATEADD(day, 30, HireDate) FROM Employees]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4706,
    description = "Expression - DATEADD with non-date column",
    database = "vim_dadbod_test",
    query = [[SELECT DATEADD(day, 30, FirstName) FROM Employees]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "invalid_argument",
        },
      },
    },
  },
  {
    number = 4707,
    description = "Expression - DATEDIFF with dates",
    database = "vim_dadbod_test",
    query = [[SELECT DATEDIFF(day, HireDate, GETDATE()) FROM Employees]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4708,
    description = "Expression - string function on non-string",
    database = "vim_dadbod_test",
    query = [[SELECT LEN(EmployeeID) FROM Employees]],
    cursor = { line = 0, col = 22 },
    expected = {
      -- LEN converts implicitly
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4709,
    description = "Expression - SUBSTRING on varchar",
    database = "vim_dadbod_test",
    query = [[SELECT SUBSTRING(FirstName, 1, 3) FROM Employees]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4710,
    description = "Expression - mathematical function on numeric",
    database = "vim_dadbod_test",
    query = [[SELECT SQRT(Salary) FROM Employees]],
    cursor = { line = 0, col = 19 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },

  -- ============================================================================
  -- 4711-4720: Assignment and INSERT type compatibility
  -- ============================================================================
  {
    number = 4711,
    description = "INSERT - compatible column types",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (EmployeeID, FirstName) VALUES (1, 'John')]],
    cursor = { line = 0, col = 62 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4712,
    description = "INSERT - int into varchar column (implicit convert)",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName) VALUES (123)]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "implicit_conversion",
        },
      },
    },
  },
  {
    number = 4713,
    description = "INSERT - varchar into int column (warning)",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (EmployeeID) VALUES ('abc')]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "conversion_error",
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4714,
    description = "UPDATE - SET compatible types",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = 50000]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4715,
    description = "UPDATE - SET incompatible types",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET EmployeeID = 'text']],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "conversion_error",
        },
      },
    },
  },
  {
    number = 4716,
    description = "UPDATE - SET from other column compatible",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET DepartmentID = EmployeeID]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4717,
    description = "UPDATE - SET from other column incompatible",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET EmployeeID = FirstName]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4718,
    description = "MERGE - matched SET type check",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS t USING (SELECT EmployeeID, FirstName FROM Employees) AS s ON t.EmployeeID = s.EmployeeID WHEN MATCHED THEN UPDATE SET t.Salary = s.FirstName]],
    cursor = { line = 0, col = 156 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
        },
      },
    },
  },
  {
    number = 4719,
    description = "Variable assignment - compatible",
    database = "vim_dadbod_test",
    query = [[DECLARE @id INT; SELECT @id = EmployeeID FROM Employees]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4720,
    description = "Variable assignment - incompatible",
    database = "vim_dadbod_test",
    query = [[DECLARE @id INT; SELECT @id = FirstName FROM Employees]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "implicit_conversion",
        },
      },
    },
  },
}
