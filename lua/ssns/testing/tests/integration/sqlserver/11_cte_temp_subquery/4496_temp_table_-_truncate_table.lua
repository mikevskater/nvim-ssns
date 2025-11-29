-- Test 4496: Temp table - TRUNCATE TABLE

return {
  number = 4496,
  description = "Temp table - TRUNCATE TABLE",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
TRUNCATE TABLE █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
