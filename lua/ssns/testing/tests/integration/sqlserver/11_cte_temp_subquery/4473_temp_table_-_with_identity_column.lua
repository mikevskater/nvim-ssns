-- Test 4473: Temp table - with IDENTITY column

return {
  number = 4473,
  description = "Temp table - with IDENTITY column",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT IDENTITY(1,1), Name VARCHAR(100))
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
