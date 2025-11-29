-- Test 4558: INSERT - EXEC procedure completion

return {
  number = 4558,
  description = "INSERT - EXEC procedure completion",
  database = "vim_dadbod_test",
  query = "INSERT INTO Projects EXEC █",
  expected = {
    items = {
      includes_any = {
        "usp_GetEmployeesByDepartment",
        "usp_InsertEmployee",
      },
    },
    type = "procedure",
  },
}
