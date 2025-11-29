-- Test 4648: MERGE - DEFAULT VALUES in INSERT

return {
  number = 4648,
  description = "MERGE - DEFAULT VALUES in INSERT",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT (EmployeeID, ,█ LastName) VALUES (source.EmployeeID, DEFAULT, source.LastName)]],
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
