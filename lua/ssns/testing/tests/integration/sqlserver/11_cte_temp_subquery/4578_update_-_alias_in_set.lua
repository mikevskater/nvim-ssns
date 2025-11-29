-- Test 4578: UPDATE - alias in SET

return {
  number = 4578,
  description = "UPDATE - alias in SET",
  database = "vim_dadbod_test",
  query = "UPDATE e SET e.█ = 'New' FROM Employees e",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
