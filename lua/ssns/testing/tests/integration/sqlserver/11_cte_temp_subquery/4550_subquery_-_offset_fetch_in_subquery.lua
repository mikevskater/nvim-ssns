-- Test 4550: Subquery - OFFSET FETCH in subquery

return {
  number = 4550,
  description = "Subquery - OFFSET FETCH in subquery",
  database = "vim_dadbod_test",
  query = "SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees ORDER BY EmployeeID OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY) sub",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
