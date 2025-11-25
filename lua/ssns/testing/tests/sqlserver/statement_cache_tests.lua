-- Statement Cache System Test Cases
-- These test multi-statement isolation, subqueries, CTEs, and temp tables
-- Tests verify that the statement chunk cache correctly isolates context per SQL statement

return {
  -- ====================================================================================
  -- MULTI-STATEMENT ISOLATION TESTS
  -- ====================================================================================

  {
    number = 101,
    description = [[First SELECT in multi-statement query - should only see Employees context]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
SELECT * FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns only (NOT Departments)
    },
    notes = "Should return columns from Employees table only. Departments table from second statement should not leak into this context."
  },

  {
    number = 102,
    description = [[Second SELECT in multi-statement query - should only see Departments context]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
SELECT d. FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 1,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns only (NOT Employees)
    },
    notes = "Should return columns from Departments table only. Employees table from first statement should not leak into this context."
  },

  {
    number = 103,
    description = [[Third SELECT in multi-statement query - isolated Products context]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES
SELECT * FROM dbo.DEPARTMENTS
SELECT p. FROM dbo.PRODUCTS p]],
    cursor = {
      line = 2,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Products columns only
    },
    notes = "Should return columns from Products table only. Previous statements should have no effect on this statement's context."
  },

  {
    number = 104,
    description = [[Multi-statement with GO separator - first statement]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
GO
SELECT * FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns only
    },
    notes = "GO separator creates explicit batch boundary. Should only see Employees context before GO."
  },

  {
    number = 105,
    description = [[Multi-statement with GO separator - second statement after GO]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
GO
SELECT d. FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 2,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns only
    },
    notes = "GO separator creates explicit batch boundary. Should only see Departments context after GO."
  },

  -- ====================================================================================
  -- SUBQUERY TESTS
  -- ====================================================================================

  {
    number = 111,
    description = [[Subquery alias completion - should see subquery's projected columns]],
    database = [[vim_dadbod_test]],
    query = [[SELECT emp. FROM (SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES) emp]],
    cursor = {
      line = 0,
      col = 11
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName only (not all Employees columns)
    },
    notes = "Should return only the columns projected by the subquery (EmployeeID, FirstName), not all columns from Employees table."
  },

  {
    number = 112,
    description = [[Nested subquery - outer alias should see inner subquery columns]],
    database = [[vim_dadbod_test]],
    query = [[SELECT outer_alias. FROM (
    SELECT * FROM (SELECT ProductID, ProductName FROM dbo.PRODUCTS) inner_alias
) outer_alias]],
    cursor = {
      line = 0,
      col = 20
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: ProductID, ProductName (from inner subquery)
    },
    notes = "Nested subquery: outer_alias should see columns from the inner subquery's SELECT * which projects ProductID, ProductName."
  },

  {
    number = 113,
    description = [[Table reference inside subquery - should see base table columns]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM (SELECT e. FROM dbo.EMPLOYEES e) sub]],
    cursor = {
      line = 0,
      col = 30
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: All Employees columns
    },
    notes = "Inside the subquery, e. should resolve to all columns from Employees table."
  },

  {
    number = 114,
    description = [[Subquery in WHERE clause - should see subquery table columns]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
WHERE e.DepartmentID IN (SELECT d. FROM dbo.DEPARTMENTS d WHERE d.IsActive = 1)]],
    cursor = {
      line = 1,
      col = 35
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "Inside the WHERE subquery, d. should resolve to Departments columns, isolated from outer query's Employees context."
  },

  {
    number = 115,
    description = [[Correlated subquery - inner alias should see its own table]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
WHERE e.Salary > (SELECT AVG(e2.) FROM dbo.EMPLOYEES e2 WHERE e2.DepartmentID = e.DepartmentID)]],
    cursor = {
      line = 1,
      col = 33
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns (via e2 alias)
    },
    notes = "Correlated subquery: e2. should resolve to Employees columns. This tests that inner query can reference its own alias."
  },

  -- ====================================================================================
  -- CTE (Common Table Expression) TESTS
  -- ====================================================================================

  {
    number = 121,
    description = [[CTE reference completion - should see CTE's projected columns]],
    database = [[vim_dadbod_test]],
    query = [[WITH ActiveEmps AS (
    SELECT EmployeeID, FirstName, LastName FROM dbo.EMPLOYEES WHERE IsActive = 1
)
SELECT ae. FROM ActiveEmps ae]],
    cursor = {
      line = 3,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName, LastName (CTE columns only)
    },
    notes = "Should return only columns projected by the CTE (EmployeeID, FirstName, LastName), not all Employees columns."
  },

  {
    number = 122,
    description = [[Multiple CTEs - first CTE alias completion]],
    database = [[vim_dadbod_test]],
    query = [[WITH
    Emps AS (SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES),
    Depts AS (SELECT DepartmentID, DepartmentName FROM dbo.DEPARTMENTS)
SELECT e. FROM Emps e JOIN Depts d ON e.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 3,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName (from Emps CTE)
    },
    notes = "With multiple CTEs, e. should resolve to columns from Emps CTE only."
  },

  {
    number = 123,
    description = [[Multiple CTEs - second CTE alias completion]],
    database = [[vim_dadbod_test]],
    query = [[WITH
    Emps AS (SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES),
    Depts AS (SELECT DepartmentID, DepartmentName FROM dbo.DEPARTMENTS)
SELECT d. FROM Emps e JOIN Depts d ON e.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 3,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: DepartmentID, DepartmentName (from Depts CTE)
    },
    notes = "With multiple CTEs, d. should resolve to columns from Depts CTE only."
  },

  {
    number = 124,
    description = [[CTE with aliased columns - should see aliased names]],
    database = [[vim_dadbod_test]],
    query = [[WITH EmpNames AS (
    SELECT FirstName AS FName, LastName AS LName FROM dbo.EMPLOYEES
)
SELECT en. FROM EmpNames en]],
    cursor = {
      line = 3,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: FName, LName (aliased names, not FirstName/LastName)
    },
    notes = "Should return the aliased column names (FName, LName) from the CTE, not the original column names."
  },

  {
    number = 125,
    description = [[Nested CTE - inner CTE reference]],
    database = [[vim_dadbod_test]],
    query = [[WITH
    InnerCTE AS (SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES),
    OuterCTE AS (SELECT ic. FROM InnerCTE ic)
SELECT * FROM OuterCTE]],
    cursor = {
      line = 2,
      col = 25
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName (from InnerCTE)
    },
    notes = "Inside OuterCTE definition, ic. should resolve to InnerCTE's columns."
  },

  -- ====================================================================================
  -- JOIN TESTS
  -- ====================================================================================

  {
    number = 131,
    description = [[Two-table join - first table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "In JOIN query, e. should resolve to Employees columns."
  },

  {
    number = 132,
    description = [[Two-table join - second table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e.FirstName, d. FROM dbo.EMPLOYEES e
JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 0,
      col = 21
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "In JOIN query, d. should resolve to Departments columns."
  },

  {
    number = 133,
    description = [[Three-way join - first table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT p. FROM dbo.PRODUCTS p
JOIN dbo.CATEGORIES c ON p.CategoryID = c.CategoryID
JOIN dbo.SUPPLIERS s ON p.SupplierID = s.SupplierID]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Products columns
    },
    notes = "In three-way join, p. should resolve to Products columns."
  },

  {
    number = 134,
    description = [[Three-way join - second table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT p.ProductName, c. FROM dbo.PRODUCTS p
JOIN dbo.CATEGORIES c ON p.CategoryID = c.CategoryID
JOIN dbo.SUPPLIERS s ON p.SupplierID = s.SupplierID]],
    cursor = {
      line = 0,
      col = 25
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Categories columns
    },
    notes = "In three-way join, c. should resolve to Categories columns."
  },

  {
    number = 135,
    description = [[Three-way join - third table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT p.ProductName, c.CategoryName, s. FROM dbo.PRODUCTS p
JOIN dbo.CATEGORIES c ON p.CategoryID = c.CategoryID
JOIN dbo.SUPPLIERS s ON p.SupplierID = s.SupplierID]],
    cursor = {
      line = 0,
      col = 41
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Suppliers columns
    },
    notes = "In three-way join, s. should resolve to Suppliers columns."
  },

  {
    number = 136,
    description = [[JOIN with subquery - subquery alias completion]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e.FirstName, sub. FROM dbo.EMPLOYEES e
JOIN (SELECT DepartmentID, DepartmentName FROM dbo.DEPARTMENTS) sub ON e.DepartmentID = sub.DepartmentID]],
    cursor = {
      line = 0,
      col = 25
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: DepartmentID, DepartmentName (subquery columns)
    },
    notes = "In JOIN with subquery, sub. should resolve to the subquery's projected columns."
  },

  -- ====================================================================================
  -- WHERE CLAUSE TESTS
  -- ====================================================================================

  {
    number = 141,
    description = [[WHERE clause with alias - should see table columns]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e WHERE e. > 50000]],
    cursor = {
      line = 0,
      col = 41
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "In WHERE clause, e. should resolve to Employees columns."
  },

  {
    number = 142,
    description = [[WHERE in multi-statement - second statement isolation test]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
SELECT * FROM dbo.DEPARTMENTS d WHERE d.]],
    cursor = {
      line = 1,
      col = 41
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns (NOT Employees)
    },
    notes = "In second statement's WHERE clause, d. should resolve to Departments columns only. First statement's Employees context should not leak."
  },

  {
    number = 143,
    description = [[WHERE with JOIN - first table alias in WHERE]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID
WHERE e. = 'IT']],
    cursor = {
      line = 2,
      col = 8
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "In WHERE clause of JOIN query, e. should resolve to Employees columns."
  },

  {
    number = 144,
    description = [[WHERE with JOIN - second table alias in WHERE]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM dbo.EMPLOYEES e
JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID
WHERE d. = 'Active']],
    cursor = {
      line = 2,
      col = 8
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "In WHERE clause of JOIN query, d. should resolve to Departments columns."
  },

  -- ====================================================================================
  -- TEMP TABLE TESTS
  -- ====================================================================================

  {
    number = 151,
    description = [[Temp table from SELECT INTO - should infer columns from SELECT]],
    database = [[vim_dadbod_test]],
    query = [[SELECT EmployeeID, FirstName INTO #TempEmp FROM dbo.EMPLOYEES
SELECT te. FROM #TempEmp te]],
    cursor = {
      line = 1,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName (inferred from SELECT INTO)
    },
    notes = "Should infer temp table columns from the SELECT INTO statement (EmployeeID, FirstName)."
  },

  {
    number = 152,
    description = [[Global temp table survives GO separator]],
    database = [[vim_dadbod_test]],
    query = [[SELECT EmployeeID INTO ##GlobalTemp FROM dbo.EMPLOYEES
GO
SELECT gt. FROM ##GlobalTemp gt]],
    cursor = {
      line = 2,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID (global temp table persists across GO)
    },
    notes = "Global temp table (##) should persist across GO boundary and provide column completion."
  },

  {
    number = 153,
    description = [[Local temp table NOT visible after GO separator]],
    database = [[vim_dadbod_test]],
    query = [[SELECT EmployeeID INTO #LocalTemp FROM dbo.EMPLOYEES
GO
SELECT * FROM #LocalTemp WHERE ]],
    cursor = {
      line = 2,
      col = 34
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: NO columns (temp table out of scope after GO)
    },
    notes = "Local temp table (#) should NOT be visible after GO separator. Should return no columns or error."
  },

  {
    number = 154,
    description = [[Temp table with aliased columns in SELECT INTO]],
    database = [[vim_dadbod_test]],
    query = [[SELECT EmployeeID AS EmpID, FirstName AS FName INTO #TempAlias FROM dbo.EMPLOYEES
SELECT ta. FROM #TempAlias ta]],
    cursor = {
      line = 1,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmpID, FName (aliased names from SELECT INTO)
    },
    notes = "Should infer temp table columns using the aliased names from SELECT INTO."
  },

  -- ====================================================================================
  -- INSERT WITH SELECT (Single Statement Tests)
  -- ====================================================================================

  {
    number = 161,
    description = [[INSERT SELECT is single statement - SELECT part should resolve]],
    database = [[vim_dadbod_test]],
    query = [[INSERT INTO TargetTable
SELECT e. FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 1,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "INSERT SELECT is one statement. The SELECT portion should resolve e. to Employees columns."
  },

  {
    number = 162,
    description = [[INSERT SELECT with JOIN - first table alias]],
    database = [[vim_dadbod_test]],
    query = [[INSERT INTO TargetTable
SELECT e. FROM dbo.EMPLOYEES e
JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 1,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "INSERT SELECT with JOIN. Should resolve e. to Employees columns."
  },

  -- ====================================================================================
  -- COMPLEX SCENARIO TESTS
  -- ====================================================================================

  {
    number = 171,
    description = [[CTE with JOIN - CTE alias in main query]],
    database = [[vim_dadbod_test]],
    query = [[WITH ActiveEmps AS (
    SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES WHERE IsActive = 1
)
SELECT ae. FROM ActiveEmps ae
JOIN dbo.DEPARTMENTS d ON ae.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 3,
      col = 10
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: EmployeeID, FirstName (CTE columns)
    },
    notes = "CTE used in JOIN. ae. should resolve to CTE's projected columns."
  },

  {
    number = 172,
    description = [[CTE with JOIN - base table alias in main query]],
    database = [[vim_dadbod_test]],
    query = [[WITH ActiveEmps AS (
    SELECT EmployeeID, FirstName FROM dbo.EMPLOYEES WHERE IsActive = 1
)
SELECT ae.FirstName, d. FROM ActiveEmps ae
JOIN dbo.DEPARTMENTS d ON ae.DepartmentID = d.DepartmentID]],
    cursor = {
      line = 3,
      col = 24
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "CTE used in JOIN. d. should resolve to Departments columns."
  },

  {
    number = 173,
    description = [[CTE with subquery in WHERE]],
    database = [[vim_dadbod_test]],
    query = [[WITH TopDepts AS (SELECT TOP 5 DepartmentID FROM dbo.DEPARTMENTS ORDER BY Budget DESC)
SELECT e. FROM dbo.EMPLOYEES e
WHERE e.DepartmentID IN (SELECT DepartmentID FROM TopDepts)]],
    cursor = {
      line = 1,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "CTE with subquery in WHERE. e. in main SELECT should resolve to Employees columns."
  },

  {
    number = 174,
    description = [[Nested subqueries with multiple levels]],
    database = [[vim_dadbod_test]],
    query = [[SELECT * FROM (
    SELECT * FROM (
        SELECT e. FROM dbo.EMPLOYEES e
    ) level2
) level1]],
    cursor = {
      line = 2,
      col = 17
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Deeply nested subqueries. e. at innermost level should resolve to Employees columns."
  },

  {
    number = 175,
    description = [[UNION query - first SELECT]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
UNION
SELECT d. FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "UNION query: first SELECT should resolve e. to Employees columns only."
  },

  {
    number = 176,
    description = [[UNION query - second SELECT]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
UNION
SELECT d. FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 2,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "UNION query: second SELECT should resolve d. to Departments columns only."
  },

  -- ====================================================================================
  -- COMMENT HANDLING TESTS
  -- ====================================================================================

  {
    number = 181,
    description = [[Single-line comment before query - should not affect parsing]],
    database = [[vim_dadbod_test]],
    query = [[-- This is a comment about employees
SELECT e. FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 1,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Single-line comment should be ignored. e. should resolve to Employees columns."
  },

  {
    number = 182,
    description = [[Block comment before query - should not affect parsing]],
    database = [[vim_dadbod_test]],
    query = [[/* Get employee data
   from the main table */
SELECT e. FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 2,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Block comment should be ignored. e. should resolve to Employees columns."
  },

  {
    number = 183,
    description = [[Inline comment within query - should not affect parsing]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. /* employee columns */ FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Inline comment should be ignored. e. should resolve to Employees columns."
  },

  {
    number = 184,
    description = [[Comment between statements - should not affect statement isolation]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
-- This comment separates statements
SELECT d. FROM dbo.DEPARTMENTS d]],
    cursor = {
      line = 2,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "Comment between statements should not affect isolation. d. should resolve to Departments columns only."
  },

  -- ====================================================================================
  -- EDGE CASE TESTS
  -- ====================================================================================

  {
    number = 191,
    description = [[Schema-qualified table - should resolve normally]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Schema-qualified table (dbo.EMPLOYEES) should resolve e. to Employees columns."
  },

  {
    number = 192,
    description = [[Bracketed identifiers - should resolve normally]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM [dbo].[EMPLOYEES] e]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Bracketed identifiers should be handled. e. should resolve to Employees columns."
  },

  {
    number = 193,
    description = [[Table without alias - use table name for completion]],
    database = [[vim_dadbod_test]],
    query = [[SELECT EMPLOYEES. FROM dbo.EMPLOYEES]],
    cursor = {
      line = 0,
      col = 17
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Table without alias should allow completion using table name (EMPLOYEES.)."
  },

  {
    number = 194,
    description = [[Mixed aliases and no-alias tables]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e., DEPARTMENTS. FROM dbo.EMPLOYEES e, dbo.DEPARTMENTS]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Mixed aliased and non-aliased tables. e. should resolve to Employees columns."
  },

  {
    number = 195,
    description = [[Cross-database query - schema.table reference]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM OtherDatabase.dbo.EMPLOYEES e]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns from OtherDatabase
    },
    notes = "Cross-database query with database.schema.table. Should resolve e. to Employees columns."
  },

  {
    number = 196,
    description = [[CASE statement in SELECT - table alias should still resolve]],
    database = [[vim_dadbod_test]],
    query = [[SELECT
    CASE WHEN e.Salary > 50000 THEN 'High' ELSE 'Low' END,
    e.
FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 2,
      col = 6
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "CASE statement in SELECT should not interfere with alias resolution. e. should resolve to Employees columns."
  },

  {
    number = 197,
    description = [[Subquery in SELECT list - outer alias should resolve]],
    database = [[vim_dadbod_test]],
    query = [[SELECT
    e.,
    (SELECT COUNT(*) FROM dbo.DEPARTMENTS d WHERE d.DepartmentID = e.DepartmentID) AS DeptCount
FROM dbo.EMPLOYEES e]],
    cursor = {
      line = 1,
      col = 6
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "Subquery in SELECT list. Outer e. alias should resolve to Employees columns."
  },

  {
    number = 198,
    description = [[APPLY operator - first table alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e. FROM dbo.EMPLOYEES e
CROSS APPLY (SELECT TOP 1 * FROM dbo.DEPARTMENTS d WHERE d.DepartmentID = e.DepartmentID) dept]],
    cursor = {
      line = 0,
      col = 9
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Employees columns
    },
    notes = "CROSS APPLY query. e. should resolve to Employees columns."
  },

  {
    number = 199,
    description = [[APPLY operator - APPLY alias]],
    database = [[vim_dadbod_test]],
    query = [[SELECT e.FirstName, dept. FROM dbo.EMPLOYEES e
CROSS APPLY (SELECT TOP 1 * FROM dbo.DEPARTMENTS d WHERE d.DepartmentID = e.DepartmentID) dept]],
    cursor = {
      line = 0,
      col = 27
    },
    expected = {
      type = [[column]],
      items = {}  -- USER FILLS: Departments columns
    },
    notes = "CROSS APPLY query. dept. alias should resolve to Departments columns from the APPLY subquery."
  },
}
