-- Test 4485: Temp table - multiple temp tables different batches

return {
  number = 4485,
  description = "Temp table - multiple temp tables different batches",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #Temp1 (Col1 INT)
GO
CREATE TABLE #Temp2 (Col2 VARCHAR(100))
GO
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
