---@class HighlightUtils
---Shared utilities for applying token highlights to buffers
---Handles multi-line tokens (block comments, strings) by splitting across lines
local M = {}

---Apply a highlight for a single token, handling multi-line tokens correctly
---
---Multi-line tokens (block comments, strings) store only their start position.
---Using `col_start + #token.text` for col_end overflows the line length on the
---start line, causing the bounds check to fail and the highlight to be skipped.
---This function splits multi-line tokens into per-line segments.
---
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
---@param token_line number 1-indexed line number (from tokenizer)
---@param token_col number 1-indexed column number (from tokenizer)
---@param token_text string Token text (may contain newlines)
---@param hl_group string Highlight group name
---@param lines string[] Current buffer lines (must be fresh, not stale)
---@param opts? { priority?: number, use_add_highlight?: boolean }
function M.apply_token_highlight(bufnr, ns_id, token_line, token_col, token_text, hl_group, lines, opts)
  opts = opts or {}
  local line = token_line - 1   -- 0-indexed
  local col_start = token_col - 1 -- 0-indexed

  -- Fast path: single-line token (vast majority of cases)
  if not token_text:find('\n') then
    local col_end = col_start + #token_text

    if line >= 0 and line < #lines then
      local line_len = #lines[line + 1]
      if col_start >= 0 and col_end <= line_len then
        if opts.use_add_highlight then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
        else
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col_start, {
            end_col = col_end,
            hl_group = hl_group,
            priority = opts.priority or 200,
          })
        end
      end
    end
    return
  end

  -- Multi-line token: split into per-line fragments
  local fragments = {}
  local start_pos = 1
  while true do
    local nl_pos = token_text:find('\n', start_pos, true)
    if nl_pos then
      table.insert(fragments, token_text:sub(start_pos, nl_pos - 1))
      start_pos = nl_pos + 1
    else
      table.insert(fragments, token_text:sub(start_pos))
      break
    end
  end

  for frag_idx, fragment in ipairs(fragments) do
    local buf_line = line + (frag_idx - 1)

    if buf_line < 0 or buf_line >= #lines then
      goto continue
    end

    local line_len = #lines[buf_line + 1]
    local frag_col_start, frag_col_end

    if frag_idx == 1 then
      -- First line: from token start to end of fragment (or end of line)
      frag_col_start = col_start
      frag_col_end = math.min(col_start + #fragment, line_len)
    else
      -- Subsequent lines: from column 0 to end of fragment (or end of line)
      frag_col_start = 0
      -- Strip \r from fragment length if present (Windows line endings)
      local clean_len = #fragment
      if fragment:sub(-1) == '\r' then
        clean_len = clean_len - 1
      end
      frag_col_end = math.min(clean_len, line_len)
    end

    if frag_col_start >= 0 and frag_col_end > frag_col_start and frag_col_end <= line_len then
      if opts.use_add_highlight then
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, buf_line, frag_col_start, frag_col_end)
      else
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, buf_line, frag_col_start, {
          end_col = frag_col_end,
          hl_group = hl_group,
          priority = opts.priority or 200,
        })
      end
    end

    ::continue::
  end
end

return M
