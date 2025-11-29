-- Test 4562: INSERT - temp table columns

return {
  number = 4562,
  description = "INSERT - temp table columns",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100))
INSERT INTO #TempEmp (█) VALUES (1, 'Test')]],
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
