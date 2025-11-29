-- Test 4385: ON clause - bracketed identifiers

return {
  number = 4385,
  description = "ON clause - bracketed identifiers",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Employees] e JOIN [Departments] d ON e.[DepartmentID] = █d.",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
