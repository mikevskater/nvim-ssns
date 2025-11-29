-- Test 4589: UPDATE - table variable

return {
  number = 4589,
  description = "UPDATE - table variable",
  database = "vim_dadbod_test",
  query = [[DECLARE @Emp TABLE (ID INT, Name VARCHAR(100))
UPDATE @Emp SET █]],
  expected = {
    items = {
      includes = {
        "Name",
      },
    },
    type = "column",
  },
}
