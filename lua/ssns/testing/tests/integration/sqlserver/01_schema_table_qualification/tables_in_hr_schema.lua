return {
  number = 2,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM hr.]],
  cursor = {
    line = 0,
    col = 17
  },
  expected = {
    type = [[table]],
    items = {
      includes = {
        "Benefits", -- hr.Benefits table
        "fn_GetTotalBenefitCost" -- hr.fn_GetTotalBenefitCost scalar function
      },
      excludes = {
        -- Tables from dbo schema should not appear
        "Employees",
        "Departments",
        "Projects",
        "Customers",
        "Orders",
        "Products",
        -- Views from dbo schema
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        -- Synonyms from dbo schema
        "syn_Employees",
        "syn_Depts",
        "syn_HRBenefits", -- This is a synonym in dbo pointing to hr.Benefits
        -- Synonyms from Branch schema
        "AllDivisions",
        "CentralDivision"
      }
    }
  }
}