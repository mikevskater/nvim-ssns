-- Test 4593: UPDATE - SET with scalar function

return {
  number = 4593,
  description = "UPDATE - SET with scalar function",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET FullName = dbo.fn_GetFullN█ame()",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
