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
    description = "Type compatibility - uniqueidentifier = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE RowGUID = FirstName]],
    cursor = { line = 0, col = 47 },
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
    description = "Type compatibility - smallint = int (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE SmallCol = EmployeeID]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4664,
    description = "Type compatibility - binary = varbinary (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Documents WHERE BinaryData = VarBinaryData]],
    cursor = { line = 0, col = 54 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4665,
    description = "Type compatibility - binary = int (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Documents WHERE BinaryData = DocID]],
    cursor = { line = 0, col = 47 },
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
    description = "Type compatibility - xml = varchar (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Documents WHERE XmlData = DocName]],
    cursor = { line = 0, col = 46 },
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
    description = "Type compatibility - geography = geometry (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Locations WHERE GeoPoint = GeomShape]],
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
    number = 4668,
    description = "Type compatibility - hierarchyid comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM OrgChart WHERE NodePath = ParentPath]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4669,
    description = "Type compatibility - money = decimal (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary = Bonus]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4670,
    description = "Type compatibility - timestamp/rowversion (special)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE RowVersion = @version]],
    cursor = { line = 0, col = 50 },
    expected = {
      -- Rowversion has special handling
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
    query = [[SELECT * FROM Employees e JOIN StringIDs s ON e.EmployeeID = s.StringID]],
    cursor = { line = 0, col = 70 },
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
    query = [[SELECT * FROM Employees e JOIN TimeEntries t ON e.HireDate = t.EntryDateTime]],
    cursor = { line = 0, col = 75 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4674,
    description = "JOIN ON - nullable = non-nullable (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Employees m ON e.ManagerID = m.EmployeeID]],
    cursor = { line = 0, col = 70 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4675,
    description = "JOIN ON - char(10) = varchar(50) (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Codes c ON e.DeptCode = c.CodeValue]],
    cursor = { line = 0, col = 65 },
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
    description = "JOIN ON - composite key all compatible",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM OrderDetails od JOIN Products p ON od.ProductID = p.ProductID AND od.OrderID = p.OrderID]],
    cursor = { line = 0, col = 100 },
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
    query = [[SELECT * FROM Employees e JOIN StringIDs s ON CAST(e.EmployeeID AS VARCHAR(10)) = s.StringID]],
    cursor = { line = 0, col = 92 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4680,
    description = "JOIN ON - collation difference (warning)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN LatinTable l ON e.FirstName COLLATE Latin1_General_CI_AS = l.LatinName]],
    cursor = { line = 0, col = 101 },
    expected = {
      -- Explicit collation should resolve
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4681,
    description = "JOIN ON - cross-database type consistency",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e JOIN vim_dadbod_second.dbo.ExtEmployees x ON e.EmployeeID = x.ExtID]],
    cursor = { line = 0, col = 114 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4682,
    description = "JOIN ON - computed column type",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ComputedTable c ON e.EmployeeID = c.ComputedID]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4683,
    description = "JOIN ON - user-defined type",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM CustomTypes c1 JOIN CustomTypes c2 ON c1.CustomCol = c2.CustomCol]],
    cursor = { line = 0, col = 78 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4684,
    description = "JOIN ON - sql_variant comparison",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM VariantTable v1 JOIN VariantTable v2 ON v1.VariantCol = v2.VariantCol]],
    cursor = { line = 0, col = 82 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4685,
    description = "JOIN ON - numeric precision difference (compatible)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Precise1 p1 JOIN Precise2 p2 ON p1.Decimal_18_2 = p2.Decimal_10_4]],
    cursor = { line = 0, col = 77 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4686,
    description = "JOIN ON - datetimeoffset vs datetime2",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TimeTable1 t1 JOIN TimeTable2 t2 ON t1.DateTimeOffset = t2.DateTime2Col]],
    cursor = { line = 0, col = 84 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "precision_loss",
          "implicit_conversion",
        },
      },
    },
  },
  {
    number = 4687,
    description = "JOIN ON - time vs datetime",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TimeTable t JOIN DateTimeTable dt ON t.TimeCol = dt.DateTimeCol]],
    cursor = { line = 0, col = 77 },
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
    number = 4688,
    description = "JOIN ON - nchar vs char (compatible with potential data loss)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM NCharTable n JOIN CharTable c ON n.NCharCol = c.CharCol]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4689,
    description = "JOIN ON - image vs varbinary(max)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM LegacyTable l JOIN ModernTable m ON l.ImageCol = m.VarBinaryMax]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4690,
    description = "JOIN ON - text vs varchar(max)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM LegacyTable l JOIN ModernTable m ON l.TextCol = m.VarCharMax]],
    cursor = { line = 0, col = 73 },
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
    query = [[SELECT Salary + Bonus FROM Employees]],
    cursor = { line = 0, col = 22 },
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
    query = [[SELECT COALESCE(ManagerID, FirstName) FROM Employees]],
    cursor = { line = 0, col = 38 },
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
    query = [[UPDATE Employees SET DepartmentID = ManagerID]],
    cursor = { line = 0, col = 45 },
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
    query = [[MERGE INTO Employees AS t USING Staging AS s ON t.ID = s.ID WHEN MATCHED THEN UPDATE SET t.Salary = s.Name]],
    cursor = { line = 0, col = 106 },
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
