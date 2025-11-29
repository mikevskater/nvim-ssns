-- Test 4474: Temp table - with computed column

return {
  number = 4474,
  description = "Temp table - with computed column",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (FirstName VARCHAR(50), LastName VARCHAR(50), FullName AS FirstName + ' ' + LastName)
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
        "FullName",
      },
    },
    type = "column",
  },
}
