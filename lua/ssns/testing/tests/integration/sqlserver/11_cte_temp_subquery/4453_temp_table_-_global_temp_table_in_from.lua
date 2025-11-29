-- Test 4453: Temp table - global temp table in FROM

return {
  number = 4453,
  description = "Temp table - global temp table in FROM",
  database = "vim_dadbod_test",
  query = [[CREATE TABLE ##GlobalTemp (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "##GlobalTemp",
        "Employees",
      },
    },
    type = "table",
  },
}
