-- Test 4336: ON clause generation - uses correct source alias

return {
  number = 4336,
  description = "ON clause generation - uses correct source alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees emp JOIN █",
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
