-- Test 4498: Temp table - columns after ALTER TABLE ADD

return {
  number = 4498,
  description = "Temp table - columns after ALTER TABLE ADD",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT)
ALTER TABLE #TempEmployees ADD NewCol VARCHAR(100)
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "ID",
        "NewCol",
      },
    },
    type = "column",
  },
}
