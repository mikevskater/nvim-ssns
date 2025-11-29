-- Test 4493: Temp table - name with numbers

return {
  number = 4493,
  description = "Temp table - name with numbers",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE #Temp123 (ID INT)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#Temp123",
      },
    },
    type = "table",
  },
}
