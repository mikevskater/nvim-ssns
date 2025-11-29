-- Test 4614: DELETE - CTE WHERE clause

return {
  number = 4614,
  description = "DELETE - CTE WHERE clause",
  database = "vim_dadbod_test",
  query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE IsActive = 0)
DELETE FROM Employees WHERE EmployeeID IN (SELECT  FROM█ ToDelete)]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
