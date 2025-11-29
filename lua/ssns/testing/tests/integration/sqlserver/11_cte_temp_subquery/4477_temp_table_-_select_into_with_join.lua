-- Test 4477: Temp table - SELECT INTO with JOIN

return {
  number = 4477,
  description = "Temp table - SELECT INTO with JOIN",
  database = "vim_dadbod_test",
  query = [[SELECT e.EmployeeID, e.FirstName, d.DepartmentName
INTO #EmpDept
FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID
SELECT █ FROM #EmpDept]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
