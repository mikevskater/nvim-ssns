-- Test 4499: Temp table - sp_rename temp table column

return {
  number = 4499,
  description = "Temp table - sp_rename temp table column",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #TempEmployees (OldName INT)
EXEC sp_rename '#TempEmployees.OldName', 'NewName', 'COLUMN'
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes_any = {
        "NewName",
        "OldName",
      },
    },
    type = "column",
  },
}
