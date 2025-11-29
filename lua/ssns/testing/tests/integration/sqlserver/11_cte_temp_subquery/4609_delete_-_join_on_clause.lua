-- Test 4609: DELETE - JOIN ON clause

return {
  number = 4609,
  description = "DELETE - JOIN ON clause",
  database = "vim_dadbod_test",
  query = "DELETE e FROM Employees e JOIN Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
