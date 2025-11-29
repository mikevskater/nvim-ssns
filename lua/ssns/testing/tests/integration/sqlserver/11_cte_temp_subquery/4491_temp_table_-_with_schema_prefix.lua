-- Test 4491: Temp table - with schema prefix

return {
  number = 4491,
  description = "Temp table - with schema prefix",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM dbo.█]],
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
