-- Test 4486: Temp table - in stored procedure body

return {
  number = 4486,
  description = "Temp table - in stored procedure body",
  database = "vim_dadbod_test",
  query = [[CREATE PROCEDURE sp_Test AS
BEGIN
  CREATE TABLE #LocalTemp (ID INT, Value VARCHAR(100))
  SELECT * FROM█
END]],
  expected = {
    items = {
      includes = {
        "#LocalTemp",
        "Employees",
      },
    },
    type = "table",
  },
}
