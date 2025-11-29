-- Test 4530: Subquery - subquery with scalar subquery column

return {
  number = 4530,
  description = "Subquery - subquery with scalar subquery column",
  database = "vim_dadbod_test",
  query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    (SELECT DepartmentName FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName
  FROM Employees e
) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DeptName",
      },
    },
    type = "column",
  },
}
