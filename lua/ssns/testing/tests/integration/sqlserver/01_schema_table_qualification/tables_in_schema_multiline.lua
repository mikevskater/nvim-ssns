return {
  number = 3,
  description = [[Autocomplete for tables in schema (Multi-line SELECT handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
* 
FROM
dbo.]],
  cursor = {
    line = 3,
    col = 4
  },
  expected = {
    type = [[table]],
    items = {
      includes = {
        -- Sample of tables from dbo schema
        "Departments",
        "Employees",
        "Projects",
        "Customers",
        "Orders",
        "Products",
        -- Sample of views from dbo schema
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        "CustomerOrders",
        "View_CustomerOrders",
        -- Sample of synonyms from dbo schema
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
        -- Sample of table-valued functions from dbo schema
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders",
        "GetOrderTotal"
      },
      excludes = {
        -- Tables from other schemas should not appear
        "Benefits", -- hr schema table
        -- Synonyms in Branch schema should not appear
        "AllDivisions",
        "CentralDivision",
        -- Objects from other databases
        "Records", -- TEST.dbo.Records
        "central_division", -- Branch_Prod.dbo
        "division_metrics" -- Branch_Prod.dbo
      }
    }
  }
}