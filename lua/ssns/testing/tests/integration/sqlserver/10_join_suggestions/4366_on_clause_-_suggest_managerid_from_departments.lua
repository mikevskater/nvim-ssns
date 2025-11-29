-- Test 4366: ON clause - suggest ManagerID from Departments

return {
  number = 4366,
  description = "ON clause - suggest ManagerID from Departments",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.EmployeeID =█ d.",
  expected = {
    items = {
      includes_any = {
        "ManagerID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
