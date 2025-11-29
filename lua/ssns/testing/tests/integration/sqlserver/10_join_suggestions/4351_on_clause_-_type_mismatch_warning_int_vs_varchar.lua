-- Test 4351: ON clause - type mismatch warning (int vs varchar)

return {
  number = 4351,
  description = "ON clause - type mismatch warning (int vs varchar)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentID█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "incompatible_types",
      },
    },
    type = "warning",
  },
}
