-- Test 4335: ON clause generation - single column FK

return {
  number = 4335,
  description = "ON clause generation - single column FK",
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
