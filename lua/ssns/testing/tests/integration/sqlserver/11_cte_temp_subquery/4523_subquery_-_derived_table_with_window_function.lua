-- Test 4523: Subquery - derived table with window function

return {
  number = 4523,
  description = "Subquery - derived table with window function",
  database = "vim_dadbod_test",
  query = "SELECT sub.█ FROM (SELECT EmployeeID, Salary, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Rank FROM Employees) sub",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "Salary",
        "Rank",
      },
    },
    type = "column",
  },
}
