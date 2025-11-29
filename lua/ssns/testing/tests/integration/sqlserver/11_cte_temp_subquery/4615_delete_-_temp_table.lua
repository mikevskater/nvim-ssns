-- Test 4615: DELETE - temp table

return {
  number = 4615,
  description = "DELETE - temp table",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100))
DELETE FROM #TempEmp WHERE █]],
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
