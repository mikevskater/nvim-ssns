-- Test 4619: DELETE - table variable

return {
  number = 4619,
  description = "DELETE - table variable",
  database = "vim_dadbod_test",
  query = [[DECLARE @Emp TABLE (ID INT, Name VARCHAR(100))
DELETE FROM @Emp WHERE █]],
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
