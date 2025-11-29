-- Test 4392: ON clause - reserved word as alias

return {
  number = 4392,
  description = "ON clause - reserved word as alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees [select] JOIN Departments d ON [select].█",
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
