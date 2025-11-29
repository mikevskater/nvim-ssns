-- Test 4515: Subquery - derived table column with alias

return {
  number = 4515,
  description = "Subquery - derived table column with alias",
  database = "vim_dadbod_test",
  query = "SELECT sub.█ FROM (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees) sub",
  expected = {
    items = {
      excludes = {
        "EmployeeID",
        "FirstName",
      },
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
