-- Test 4488: Temp table - global temp visible

return {
  number = 4488,
  description = "Temp table - global temp visible",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE ##GlobalTemp (ID INT, Name VARCHAR(100))
GO
SELECT * FROM ##█]],
  expected = {
    items = {
      includes = {
        "##GlobalTemp",
      },
    },
    type = "table",
  },
}
