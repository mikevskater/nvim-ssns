-- Test 4470: Temp table - alias-qualified columns

return {
  number = 4470,
  description = "Temp table - alias-qualified columns",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT te.ID, te.█ FROM #TempEmployees te]],
  expected = {
    items = {
      includes = {
        "Name",
      },
    },
    type = "column",
  },
}
