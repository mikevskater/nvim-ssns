-- Test 4372: ON clause - four table join with alias

return {
  number = 4372,
  description = "ON clause - four table join with alias",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.ProjectID = e.EmployeeID
JOIN Customers c ON c█.]],
  expected = {
    items = {
      includes = {
        "Id",
        "CustomerId",
      },
    },
    type = "column",
  },
}
