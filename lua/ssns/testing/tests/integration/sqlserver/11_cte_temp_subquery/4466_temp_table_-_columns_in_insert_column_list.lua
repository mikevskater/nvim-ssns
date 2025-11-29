-- Test 4466: Temp table - columns in INSERT column list

return {
  number = 4466,
  description = "Temp table - columns in INSERT column list",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
INSERT INTO #TempEmployees (█) VALUES (1, 'Test', 50000)]],
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
