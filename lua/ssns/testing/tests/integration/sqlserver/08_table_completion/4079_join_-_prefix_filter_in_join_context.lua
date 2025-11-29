-- Test 4079: JOIN - prefix filter in JOIN context

return {
  number = 4079,
  description = "JOIN - prefix filter in JOIN context",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Dep█",
  expected = {
    items = {
      excludes = {
        "Employees",
        "Projects",
      },
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
