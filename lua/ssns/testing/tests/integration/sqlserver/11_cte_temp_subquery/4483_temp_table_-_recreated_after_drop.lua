-- Test 4483: Temp table - recreated after DROP

return {
  number = 4483,
  description = "Temp table - recreated after DROP",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT)
DROP TABLE #TempEmployees
CREATE TABLE #TempEmployees (NewID INT, NewName VARCHAR(100))
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      excludes = {
        "ID",
      },
      includes = {
        "NewID",
        "NewName",
      },
    },
    type = "column",
  },
}
