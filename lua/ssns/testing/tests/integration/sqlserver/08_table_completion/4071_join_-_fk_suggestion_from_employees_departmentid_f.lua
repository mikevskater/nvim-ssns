-- Test 4071: JOIN - FK suggestion from Employees (DepartmentID FK)

return {
  number = 4071,
  description = "JOIN - FK suggestion from Employees (DepartmentID FK)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      has_on_clause = true,
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
