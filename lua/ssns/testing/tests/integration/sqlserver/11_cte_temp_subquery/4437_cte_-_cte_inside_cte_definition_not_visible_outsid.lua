-- Test 4437: CTE - CTE inside CTE definition not visible outside

return {
  number = 4437,
  description = "CTE - CTE inside CTE definition not visible outside",
  database = "vim_dadbod_test",
  query = [[WITH Outer AS (
  SELECT * FROM Employees
)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "Outer",
      },
    },
    type = "table",
  },
}
