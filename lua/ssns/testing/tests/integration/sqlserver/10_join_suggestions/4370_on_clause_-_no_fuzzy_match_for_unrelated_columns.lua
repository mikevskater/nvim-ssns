-- Test 4370: ON clause - no fuzzy match for unrelated columns

return {
  number = 4370,
  description = "ON clause - no fuzzy match for unrelated columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.█",
  expected = {
    items = {
      excludes = {
        "DepartmentID",
      },
      includes_any = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
