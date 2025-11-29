-- Test 4494: Temp table - name with underscores

return {
  number = 4494,
  description = "Temp table - name with underscores",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #Temp_Table_Name (ID INT)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#Temp_Table_Name",
      },
    },
    type = "table",
  },
}
