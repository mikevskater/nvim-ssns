-- Test 4323: FK chain - skip already joined tables

return {
  number = 4323,
  description = "FK chain - skip already joined tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN █",
  expected = {
    items = {
      excludes = {
        "Customers",
      },
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
