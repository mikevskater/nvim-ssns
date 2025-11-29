-- Test 4395: ON clause - whitespace handling

return {
  number = 4395,
  description = "ON clause - whitespace handling",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON   e   .  █ ",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
