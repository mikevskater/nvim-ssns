-- Test 4021: Schema-qualified - tables in dbo schema

return {
  number = 4021,
  description = "Schema-qualified - tables in dbo schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.█",
  expected = {
    items = {
      excludes = {
        "Benefits",
        "usp_GetEmployeesByDepartment",
        "usp_InsertEmployee",
        "fn_CalculateYearsOfService",
        "fn_GetEmployeeFullName",
      },
      includes = {
        "Employees",
        "Departments",
        "Projects",
        "Customers",
        "Orders",
        "Products",
        "Regions",
        "Countries",
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders",
      },
    },
    type = "table",
  },
}
