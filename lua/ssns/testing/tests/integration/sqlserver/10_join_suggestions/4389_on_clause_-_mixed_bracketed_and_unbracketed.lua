-- Test 4389: ON clause - mixed bracketed and unbracketed

return {
  number = 4389,
  description = "ON clause - mixed bracketed and unbracketed",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN [Departments] d ON e.DepartmentID = d█.",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
