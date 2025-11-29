-- Test 4459: Temp table - UPDATE temp table

return {
  number = 4459,
  description = "Temp table - UPDATE temp table",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
UPDATE █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
        "Employees",
      },
    },
    type = "table",
  },
}
