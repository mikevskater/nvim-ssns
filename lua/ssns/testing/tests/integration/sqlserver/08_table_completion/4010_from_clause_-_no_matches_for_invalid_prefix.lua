-- Test 4010: FROM clause - no matches for invalid prefix

return {
  number = 4010,
  description = "FROM clause - no matches for invalid prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM xyz_nonexistent█",
  expected = {
    items = {
      count = 0,
    },
    type = "table",
  },
}
