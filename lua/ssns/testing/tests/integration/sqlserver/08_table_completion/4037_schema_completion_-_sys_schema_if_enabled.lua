-- Test 4037: Schema completion - sys schema (if enabled)

return {
  number = 4037,
  description = "Schema completion - sys schema (if enabled)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM sys.█",
  expected = {
    items = {
      includes_any = {
        "objects",
        "tables",
        "columns",
      },
    },
    type = "table",
  },
}
