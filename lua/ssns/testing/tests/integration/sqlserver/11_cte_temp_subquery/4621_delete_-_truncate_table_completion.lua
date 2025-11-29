-- Test 4621: DELETE - TRUNCATE TABLE completion

return {
  number = 4621,
  description = "DELETE - TRUNCATE TABLE completion",
  database = "vim_dadbod_test",
  query = "TRUNCATE TABLE █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Projects",
      },
    },
    type = "table",
  },
}
