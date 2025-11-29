-- Test 4497: Temp table - ALTER TABLE

return {
  number = 4497,
  description = "Temp table - ALTER TABLE",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT)
ALTER TABLE █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
