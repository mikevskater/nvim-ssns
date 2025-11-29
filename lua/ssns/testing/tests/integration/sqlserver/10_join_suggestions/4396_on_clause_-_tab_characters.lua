-- Test 4396: ON clause - tab characters

return {
  number = 4396,
  description = "ON clause - tab characters",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON\9█e.",
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
