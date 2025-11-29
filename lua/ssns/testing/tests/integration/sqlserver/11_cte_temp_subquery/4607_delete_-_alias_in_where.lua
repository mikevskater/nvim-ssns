-- Test 4607: DELETE - alias in WHERE

return {
  number = 4607,
  description = "DELETE - alias in WHERE",
  database = "vim_dadbod_test",
  query = "DELETE e FROM Employees e WHERE e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
