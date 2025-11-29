-- Test 4642: MERGE - table variable as source

return {
  number = 4642,
  description = "MERGE - table variable as source",
  database = "vim_dadbod_test",
  query = [[DECLARE @Staging TABLE (ID INT, Name VARCHAR(100))
MERGE INTO Employees AS target
USING @Staging AS source
ON target.EmployeeID = source.█]],
  expected = {
    items = {
      includes = {
        "ID",
      },
    },
    type = "column",
  },
}
