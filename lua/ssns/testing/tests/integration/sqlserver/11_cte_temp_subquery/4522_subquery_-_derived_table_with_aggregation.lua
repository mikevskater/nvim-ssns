-- Test 4522: Subquery - derived table with aggregation

return {
  number = 4522,
  description = "Subquery - derived table with aggregation",
  database = "vim_dadbod_test",
  query = "SELECT sub.█ FROM (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSal FROM Employees GROUP BY DepartmentID) sub",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmpCount",
        "AvgSal",
      },
    },
    type = "column",
  },
}
