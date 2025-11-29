-- Test 4580: UPDATE - FROM join ON clause

return {
  number = 4580,
  description = "UPDATE - FROM join ON clause",
  database = "vim_dadbod_test",
  query = "UPDATE e SET e.DepartmentID = d.DepartmentID FROM Employees e JOIN Departments d ON █e.",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
