-- Test 4521: Subquery - multiple derived tables

return {
  number = 4521,
  description = "Subquery - multiple derived tables",
  database = "vim_dadbod_test",
  query = [[SELECT e.EmpID, d.DeptName
FROM (SELECT EmployeeID AS EmpID, DepartmentID FROM Employees) e
JOIN (SELECT DepartmentID, DepartmentName AS DeptName FROM Departments) d
ON e.DepartmentID = d.█]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
