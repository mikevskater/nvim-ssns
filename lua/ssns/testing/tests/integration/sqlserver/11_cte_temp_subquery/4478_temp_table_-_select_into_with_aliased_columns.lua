-- Test 4478: Temp table - SELECT INTO with aliased columns

return {
  number = 4478,
  description = "Temp table - SELECT INTO with aliased columns",
  database = "vim_dadbod_test",
  query = [[SELECT EmployeeID AS ID, FirstName AS Name INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
        "FirstName",
      },
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
