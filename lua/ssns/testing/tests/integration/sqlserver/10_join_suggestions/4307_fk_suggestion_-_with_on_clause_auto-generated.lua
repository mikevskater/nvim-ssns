-- Test 4307: FK suggestion - with ON clause auto-generated

return {
  number = 4307,
  description = "FK suggestion - with ON clause auto-generated",
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
