-- Test 4595: UPDATE - OUTPUT INTO

return {
  number = 4595,
  description = "UPDATE - OUTPUT INTO",
  database = "vim_dadbod_test",
  query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.Salary INTO █]],
  expected = {
    items = {
      includes_any = {
        "SalaryLog",
        "#SalaryChanges",
      },
    },
    type = "table",
  },
}
