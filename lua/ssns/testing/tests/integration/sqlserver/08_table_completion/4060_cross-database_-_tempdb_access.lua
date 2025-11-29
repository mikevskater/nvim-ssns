-- Test 4060: Cross-database - tempdb access

return {
  number = 4060,
  description = "Cross-database - tempdb access",
  database = "vim_dadbod_test",
  query = "SELECT * FROM tempdb.sys.█",
  expected = {
    items = {
      includes_any = {
        "objects",
        "tables",
      },
    },
    type = "table",
  },
}
