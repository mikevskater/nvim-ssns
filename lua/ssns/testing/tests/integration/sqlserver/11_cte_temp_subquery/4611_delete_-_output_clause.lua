-- Test 4611: DELETE - OUTPUT clause

return {
  number = 4611,
  description = "DELETE - OUTPUT clause",
  database = "vim_dadbod_test",
  query = [[DELETE FROM Employees
OUTPUT deleted.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
