-- Test 4492: Temp table - long temp table name

return {
  number = 4492,
  description = "Temp table - long temp table name",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #VeryLongTempTableNameForTestingPurposes (ID INT)
SELECT * FROM #Very█]],
  expected = {
    items = {
      includes = {
        "#VeryLongTempTableNameForTestingPurposes",
      },
    },
    type = "table",
  },
}
