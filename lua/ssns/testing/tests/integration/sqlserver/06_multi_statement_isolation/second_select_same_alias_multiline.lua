return {
  number = 32,
  description = [[Autocomplete for columns in second select with multiple select statements in query with same aliases (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    *
FROM
    dbo.Employees e;
SELECT
    e.
FROM
    dbo.Departments e;]],
  cursor = {
    line = 5,
    col = 6
  },
  expected = {
    type = [[column]],
    includes = {
      -- From Departments (current statement with alias 'e')
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    },
    excludes = {
      -- From Employees (different statement - alias 'e' means different table there)
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