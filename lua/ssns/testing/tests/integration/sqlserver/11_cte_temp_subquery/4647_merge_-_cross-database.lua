-- Test 4647: MERGE - cross-database

return {
  number = 4647,
  description = "MERGE - cross-database",
  database = "vim_dadbod_test",
  query = [[MERGE INTO vim_dadbod_test.dbo.Employees AS target
USING TEST.dbo.█ AS source
ON target.EmployeeID = source.EmployeeID]],
  expected = {
    items = {
      includes_any = {
        "Records",
        "TestTable",
      },
    },
    type = "table",
  },
}
