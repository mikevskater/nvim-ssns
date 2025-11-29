-- Test 4481: Temp table - defined in earlier batch

return {
  number = 4481,
  description = "Temp table - defined in earlier batch",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
GO
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
