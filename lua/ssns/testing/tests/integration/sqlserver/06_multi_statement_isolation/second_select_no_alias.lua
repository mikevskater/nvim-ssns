return {
  number = 27,
  description = [[Autocomplete for columns in second select with multiple select statements in query]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.Employees
SELECT  FROM dbo.Departments]],
  cursor = {
    line = 1,
    col = 7
  },
  expected = {
    type = [[column]],
    includes = {
      -- From Departments (current statement)
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    },
    excludes = {
      -- From Employees (different statement - should be isolated)
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "HireDate",
      "Salary",
      "IsActive",
      -- From other tables (not in query at all)
      "OrderId",
      "OrderDate",
      "Total",
      "Status",
      "CustomerId",
      "CompanyId",
      "Country",
      "CountryID",
      "ProductId",
      "CategoryId",
      "Price",
      "ProjectID",
      "ProjectName"
    }
  }
}