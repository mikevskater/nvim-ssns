-- Test 4433: CTE - deeply nested CTEs (3 levels)

return {
  number = 4433,
  description = "CTE - deeply nested CTEs (3 levels)",
  database = "vim_dadbod_test",
  query = [[WITH
  L1 AS (SELECT * FROM Employees),
  L2 AS (SELECT * FROM L1 WHERE DepartmentID = 1),
  L3 AS (SELECT EmployeeID, FirstName FROM L2)
SELECT █ FROM L3]],
  expected = {
    items = {
      excludes = {
        "LastName",
        "DepartmentID",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
