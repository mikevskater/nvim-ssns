-- Test 4560: INSERT - OUTPUT clause columns

return {
  number = 4560,
  description = "INSERT - OUTPUT clause columns",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Employees (FirstName, LastName)
OUTPUT inserted.█
VALUES ('John', 'Doe')]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
