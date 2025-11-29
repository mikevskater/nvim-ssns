-- Test 4484: Temp table - IF EXISTS scope

return {
  number = 4484,
  description = "Temp table - IF EXISTS scope",
  database = "vim_dadbod_test",
  query = [[IF OBJECT_ID('tempdb..#TempEmployees') IS NOT NULL DROP TABLE #TempEmployees
CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
