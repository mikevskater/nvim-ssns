-- Test 4390: ON clause - fully qualified with brackets

return {
  number = 4390,
  description = "ON clause - fully qualified with brackets",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM [vim_dadbod_test].[dbo].[Employees] e
JOIN [vim_dadbod_test].[dbo].[Departments] d ON █e.]],
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
