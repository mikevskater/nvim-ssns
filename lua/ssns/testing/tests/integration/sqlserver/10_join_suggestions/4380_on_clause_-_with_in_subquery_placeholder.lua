-- Test 4380: ON clause - with IN subquery placeholder

return {
  number = 4380,
  description = "ON clause - with IN subquery placeholder",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID IN (SELECT  FROM █Departments)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
