-- Test 4543: Subquery - deeply nested (4 levels)

return {
  number = 4543,
  description = "Subquery - deeply nested (4 levels)",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM (
  SELECT * FROM (
    SELECT * FROM (
      SELECT EmployeeID FROM Employees
    ) l1
  ) l2
) l3 WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
