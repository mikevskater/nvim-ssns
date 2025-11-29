-- Test 4393: ON clause - numeric alias

return {
  number = 4393,
  description = "ON clause - numeric alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees [1] JOIN Departments [2] ON [1]█.",
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
