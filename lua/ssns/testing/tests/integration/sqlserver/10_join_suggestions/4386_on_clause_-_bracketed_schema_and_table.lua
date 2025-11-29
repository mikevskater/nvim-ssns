-- Test 4386: ON clause - bracketed schema and table

return {
  number = 4386,
  description = "ON clause - bracketed schema and table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [dbo].[Employees] e JOIN [dbo].[Departments] d ON █e.",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
