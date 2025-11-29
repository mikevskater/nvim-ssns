-- Test 4583: UPDATE - OUTPUT inserted columns

return {
  number = 4583,
  description = "UPDATE - OUTPUT inserted columns",
  database = "vim_dadbod_test",
  query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.█]],
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
