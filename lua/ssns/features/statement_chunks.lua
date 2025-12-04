---@class StatementChunksViewer
---View parsed statement chunks in a floating window
---Displays the internal parse result for debugging and understanding
---@module ssns.features.statement_chunks
local StatementChunksViewer = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local StatementParser = require('ssns.completion.statement_parser')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function StatementChunksViewer.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View statement chunks for the current buffer
---Parses the buffer content and displays parsed chunks in a floating window
function StatementChunksViewer.view_statement_chunks()
  -- Close any existing float
  StatementChunksViewer.close_current_float()

  -- Get current buffer content
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text == "" then
    vim.notify("SSNS: Buffer is empty", vim.log.levels.WARN)
    return
  end

  -- Parse the SQL
  local parse_result = StatementParser.parse(text)

  if not parse_result then
    vim.notify("SSNS: Failed to parse buffer content", vim.log.levels.ERROR)
    return
  end

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Statement Parser Results")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Summary section
  table.insert(display_lines, "Summary")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Chunks: %d", #(parse_result.chunks or {})))
  table.insert(display_lines, string.format("  Temp Tables: %d", vim.tbl_count(parse_result.temp_tables or {})))
  table.insert(display_lines, "")

  -- Temp tables section
  if parse_result.temp_tables and vim.tbl_count(parse_result.temp_tables) > 0 then
    table.insert(display_lines, "Temp Tables")
    table.insert(display_lines, string.rep("-", 30))
    for name, info in pairs(parse_result.temp_tables) do
      table.insert(display_lines, string.format("  %s (batch %d):", name, info.created_in_batch or 0))
      if info.columns and #info.columns > 0 then
        for _, col in ipairs(info.columns) do
          table.insert(display_lines, string.format("    - %s", col.name or col))
        end
      end
    end
    table.insert(display_lines, "")
  end

  -- Statement chunks section
  if parse_result.chunks and #parse_result.chunks > 0 then
    for i, chunk in ipairs(parse_result.chunks) do
      table.insert(display_lines, string.format("Chunk #%d: %s", i, chunk.statement_type or "UNKNOWN"))
      table.insert(display_lines, string.rep("-", 30))

      -- Location info
      table.insert(display_lines, string.format("  Lines: %d-%d (batch %d)",
        chunk.start_line or 0,
        chunk.end_line or 0,
        chunk.go_batch_index or 1
      ))
      table.insert(display_lines, "")

      -- Tables
      if chunk.tables and #chunk.tables > 0 then
        table.insert(display_lines, "  Tables:")
        for _, tbl in ipairs(chunk.tables) do
          local tbl_str = tbl.name or "?"
          if tbl.schema then
            tbl_str = tbl.schema .. "." .. tbl_str
          end
          if tbl.alias then
            tbl_str = tbl_str .. " AS " .. tbl.alias
          end
          table.insert(display_lines, "    - " .. tbl_str)
        end
        table.insert(display_lines, "")
      end

      -- Columns (for SELECT)
      if chunk.columns and #chunk.columns > 0 then
        table.insert(display_lines, "  Columns:")
        for _, col in ipairs(chunk.columns) do
          local col_str = col.name or "*"
          if col.source_table then
            col_str = col.source_table .. "." .. col_str
          end
          if col.is_star then
            col_str = col_str .. " (star)"
          end
          table.insert(display_lines, "    - " .. col_str)
        end
        table.insert(display_lines, "")
      end

      -- CTEs
      if chunk.ctes and #chunk.ctes > 0 then
        table.insert(display_lines, "  CTEs:")
        for _, cte in ipairs(chunk.ctes) do
          table.insert(display_lines, "    - " .. (cte.name or "?"))
        end
        table.insert(display_lines, "")
      end

      -- Subqueries
      if chunk.subqueries and #chunk.subqueries > 0 then
        table.insert(display_lines, "  Subqueries:")
        for j, sq in ipairs(chunk.subqueries) do
          table.insert(display_lines, string.format("    [%d] alias=%s, tables=%d, columns=%d",
            j,
            sq.alias or "(none)",
            sq.tables and #sq.tables or 0,
            sq.columns and #sq.columns or 0
          ))
        end
        table.insert(display_lines, "")
      end

      -- Clause positions
      if chunk.clause_positions and next(chunk.clause_positions) then
        table.insert(display_lines, "  Clause Positions:")
        local sorted_clauses = {}
        for clause_name in pairs(chunk.clause_positions) do
          table.insert(sorted_clauses, clause_name)
        end
        table.sort(sorted_clauses)
        for _, clause_name in ipairs(sorted_clauses) do
          local pos = chunk.clause_positions[clause_name]
          table.insert(display_lines, string.format("    %s: L%d:%d - L%d:%d",
            clause_name,
            pos.start_line or 0,
            pos.start_col or 0,
            pos.end_line or 0,
            pos.end_col or 0
          ))
        end
        table.insert(display_lines, "")
      end

      table.insert(display_lines, "")
    end
  else
    table.insert(display_lines, "(No statement chunks parsed)")
  end

  -- Add JSON section for full parse result
  table.insert(display_lines, "")
  table.insert(display_lines, "Full JSON Output")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Prettify the full parse result
  local json_lines = JsonUtils.prettify_lines(parse_result)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Statement Chunks",
    border = "rounded",
    filetype = "json",
    min_width = 60,
    max_width = 120,
    max_height = 40,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh: reparse and update content
        StatementChunksViewer.view_statement_chunks()
      end,
    },
    footer = "q/Esc: close | r: refresh",
  })
end

return StatementChunksViewer
