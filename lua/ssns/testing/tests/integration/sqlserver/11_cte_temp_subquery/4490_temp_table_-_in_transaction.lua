-- Test 4490: Temp table - in transaction

return {
  number = 4490,
  description = "Temp table - in transaction",
  database = "vim_dadbod_test",
  query = [[BEGIN TRANSACTION
CREATE TABLE #TranTemp (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TranTemp",
      },
    },
    type = "table",
  },
}
