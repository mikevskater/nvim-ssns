-- Test 4388: ON clause - cross database join

return {
  number = 4388,
  description = "ON clause - cross database join",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN TEST.dbo.Records r ON e.EmployeeID = █r.",
  expected = {
    items = {
      includes_any = {
        "id",
        "name",
      },
    },
    type = "column",
  },
}
