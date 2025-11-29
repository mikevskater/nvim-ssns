-- Test 4472: Temp table - with DEFAULT values

return {
  number = 4472,
  description = "Temp table - with DEFAULT values",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100) DEFAULT 'Unknown', CreatedDate DATETIME DEFAULT GETDATE())
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
        "CreatedDate",
      },
    },
    type = "column",
  },
}
