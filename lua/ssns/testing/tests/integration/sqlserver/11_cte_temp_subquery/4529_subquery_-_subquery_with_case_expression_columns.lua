-- Test 4529: Subquery - subquery with CASE expression columns

return {
  number = 4529,
  description = "Subquery - subquery with CASE expression columns",
  database = "vim_dadbod_test",
  query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    CASE WHEN Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryLevel
  FROM Employees
) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "SalaryLevel",
      },
    },
    type = "column",
  },
}
