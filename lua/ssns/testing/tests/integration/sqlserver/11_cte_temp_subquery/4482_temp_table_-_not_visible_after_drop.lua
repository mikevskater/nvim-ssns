-- Test 4482: Temp table - not visible after DROP

return {
  number = 4482,
  description = "Temp table - not visible after DROP",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
DROP TABLE #TempEmployees
SELECT * FROM █]],
  expected = {
    items = {
      excludes = {
        "#TempEmployees",
      },
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
