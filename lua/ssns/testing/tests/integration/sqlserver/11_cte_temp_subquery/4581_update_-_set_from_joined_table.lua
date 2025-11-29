-- Test 4581: UPDATE - SET from joined table

return {
  number = 4581,
  description = "UPDATE - SET from joined table",
  database = "vim_dadbod_test",
  query = "UPDATE e SET e.DeptName = d.█ FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
  expected = {
    items = {
      includes = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
