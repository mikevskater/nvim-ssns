-- Test 4375: ON clause - mixed JOIN types

return {
  number = 4375,
  description = "ON clause - mixed JOIN types",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p ON p.ProjectID = e.EmployeeID
RIGHT JOIN Orders o ON █o.]],
  expected = {
    items = {
      includes = {
        "Id",
        "OrderId",
        "CustomerId",
      },
    },
    type = "column",
  },
}
