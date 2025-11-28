return {
  number = 5,
  description = [[Autocomplete for tables in schemas in different database (cross-db handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM TEST.dbo.]],
  cursor = {
    line = 0,
    col = 23
  },
  expected = {
    type = [[table]],
    items = {
      includes = {
        "Records" -- TEST.dbo only has one table: Records
      },
      excludes = {
        -- Tables from vim_dadbod_test should not appear
        "Employees",
        "Departments",
        "Customers",
        "Orders",
        "Products",
        "Benefits",
        -- Tables from Branch_Prod should not appear
        "central_division",
        "eastern_division",
        "western_division",
        "division_metrics",
        -- Views should not appear
        "vw_ActiveEmployees",
        "vw_all_divisions"
      }
    }
  }
}