-- Test 4471: Temp table - with PRIMARY KEY

return {
  number = 4471,
  description = "Temp table - with PRIMARY KEY",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT PRIMARY KEY, Name VARCHAR(100) NOT NULL)
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
