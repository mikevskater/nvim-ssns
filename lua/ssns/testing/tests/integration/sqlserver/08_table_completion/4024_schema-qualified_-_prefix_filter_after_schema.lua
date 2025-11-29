-- Test 4024: Schema-qualified - prefix filter after schema

return {
  number = 4024,
  description = "Schema-qualified - prefix filter after schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Emp█",
  expected = {
    items = {
      excludes = {
        "Departments",
      },
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
