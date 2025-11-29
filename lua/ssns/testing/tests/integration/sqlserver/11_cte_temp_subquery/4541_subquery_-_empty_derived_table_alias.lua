-- Test 4541: Subquery - empty derived table alias

return {
  number = 4541,
  description = "Subquery - empty derived table alias",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM (SELECT * FROM Employees)",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
