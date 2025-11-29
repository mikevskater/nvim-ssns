-- Test 4464: Temp table - columns in WHERE clause

return {
  number = 4464,
  description = "Temp table - columns in WHERE clause",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
SELECT * FROM #TempEmployees WHERE █]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
        "Salary",
      },
    },
    type = "column",
  },
}
