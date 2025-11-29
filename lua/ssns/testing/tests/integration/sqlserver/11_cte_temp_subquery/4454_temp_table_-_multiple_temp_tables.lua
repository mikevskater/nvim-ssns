-- Test 4454: Temp table - multiple temp tables

return {
  number = 4454,
  description = "Temp table - multiple temp tables",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #Temp1 (ID INT)
CREATE TABLE #Temp2 (Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#Temp1",
        "#Temp2",
      },
    },
    type = "table",
  },
}
