-- Test 4582: UPDATE - OUTPUT clause

return {
  number = 4582,
  description = "UPDATE - OUTPUT clause",
  database = "vim_dadbod_test",
  query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.█, inserted.Salary]],
  expected = {
    items = {
      includes = {
        "Salary",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
