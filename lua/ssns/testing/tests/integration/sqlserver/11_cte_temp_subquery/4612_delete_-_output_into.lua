-- Test 4612: DELETE - OUTPUT INTO

return {
  number = 4612,
  description = "DELETE - OUTPUT INTO",
  database = "vim_dadbod_test",
  query = [[DELETE FROM Employees
OUTPUT deleted.* INTO █]],
  expected = {
    items = {
      includes_any = {
        "DeleteLog",
        "#Deleted",
      },
    },
    type = "table",
  },
}
