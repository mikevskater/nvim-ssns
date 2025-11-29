-- Test 4616: DELETE - TOP clause

return {
  number = 4616,
  description = "DELETE - TOP clause",
  database = "vim_dadbod_test",
  query = "DELETE TOP (100) FROM Employees WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "IsActive",
      },
    },
    type = "column",
  },
}
