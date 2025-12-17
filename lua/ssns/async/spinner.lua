---Virtual text spinner with runtime display for async operations
---@class SpinnerModule
local Spinner = {}

---Spinner animation frames
local FRAMES = {
  braille = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  dots = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  line = { "-", "\\", "|", "/" },
  bounce = { "⠁", "⠂", "⠄", "⠂" },
  arc = { "◜", "◠", "◝", "◞", "◡", "◟" },
}

---Active spinners indexed by ID
---@type table<string, SpinnerInstance>
local active_spinners = {}

---Namespace for virtual text
local ns_id = vim.api.nvim_create_namespace("ssns_async_spinner")

---Generate unique spinner ID
---@return string
local function generate_id()
  return string.format("spinner_%s_%d", os.time(), math.random(10000, 99999))
end

---Format runtime as HH:MM:SS or MM:SS
---@param elapsed_ms number Elapsed time in milliseconds
---@return string formatted Runtime string
local function format_runtime(elapsed_ms)
  local total_seconds = math.floor(elapsed_ms / 1000)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor((total_seconds % 3600) / 60)
  local seconds = total_seconds % 60

  if hours > 0 then
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
  else
    return string.format("%02d:%02d", minutes, seconds)
  end
end

---@class SpinnerInstance
---@field id string Unique identifier
---@field bufnr number Buffer number
---@field line number Line number (0-indexed)
---@field text string Display text
---@field style string Animation style
---@field show_runtime boolean Whether to show runtime
---@field start_time number Start time (vim.loop.hrtime)
---@field frame_idx number Current animation frame index
---@field timer userdata|nil Libuv timer handle
---@field extmark_id number|nil Extmark ID for virtual text

---@class SpinnerOpts
---@field text string? Display text (default: "Loading...")
---@field style string? Animation style: "braille"|"dots"|"line"|"bounce"|"arc"
---@field show_runtime boolean? Show elapsed runtime (default: true)
---@field line number? Line number to display on (0-indexed, default: 0)
---@field hl_group string? Highlight group (default: "Comment")

---Start a spinner in a buffer with virtual text
---@param bufnr number Buffer number
---@param opts SpinnerOpts? Options
---@return string spinner_id ID to reference this spinner
function Spinner.start_in_buffer(bufnr, opts)
  opts = opts or {}

  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    error("Invalid buffer: " .. tostring(bufnr), 2)
  end

  local id = generate_id()
  local style = opts.style or "braille"
  local frames = FRAMES[style] or FRAMES.braille

  ---@type SpinnerInstance
  local spinner = {
    id = id,
    bufnr = bufnr,
    line = opts.line or 0,
    text = opts.text or "Loading...",
    style = style,
    show_runtime = opts.show_runtime ~= false, -- Default true
    start_time = vim.loop.hrtime(),
    frame_idx = 1,
    timer = nil,
    extmark_id = nil,
    hl_group = opts.hl_group or "Comment",
    frames = frames,
  }

  active_spinners[id] = spinner

  -- Initial render
  Spinner._render(spinner)

  -- Start animation timer (80ms interval for smooth animation)
  spinner.timer = vim.loop.new_timer()
  spinner.timer:start(0, 80, vim.schedule_wrap(function()
    if not active_spinners[id] then
      return -- Spinner was stopped
    end

    -- Advance frame
    spinner.frame_idx = (spinner.frame_idx % #spinner.frames) + 1

    -- Re-render
    Spinner._render(spinner)
  end))

  return id
end

---Render spinner virtual text
---@param spinner SpinnerInstance
function Spinner._render(spinner)
  if not vim.api.nvim_buf_is_valid(spinner.bufnr) then
    Spinner.stop(spinner.id)
    return
  end

  -- Build display text
  local frame = spinner.frames[spinner.frame_idx]
  local display = spinner.text .. " " .. frame

  if spinner.show_runtime then
    local elapsed_ms = (vim.loop.hrtime() - spinner.start_time) / 1e6
    display = display .. " Runtime: " .. format_runtime(elapsed_ms)
  end

  -- Clear previous extmark if exists
  if spinner.extmark_id then
    pcall(vim.api.nvim_buf_del_extmark, spinner.bufnr, ns_id, spinner.extmark_id)
  end

  -- Ensure buffer has enough lines
  local line_count = vim.api.nvim_buf_line_count(spinner.bufnr)
  if spinner.line >= line_count then
    -- Add empty lines if needed
    local lines_to_add = spinner.line - line_count + 1
    local empty_lines = {}
    for _ = 1, lines_to_add do
      table.insert(empty_lines, "")
    end
    pcall(vim.api.nvim_buf_set_lines, spinner.bufnr, line_count, line_count, false, empty_lines)
  end

  -- Set virtual text as line content (replaces line content visually)
  spinner.extmark_id = vim.api.nvim_buf_set_extmark(spinner.bufnr, ns_id, spinner.line, 0, {
    virt_text = { { display, spinner.hl_group } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

---Update spinner text
---@param id string Spinner ID
---@param text string New display text
function Spinner.update(id, text)
  local spinner = active_spinners[id]
  if spinner then
    spinner.text = text
    Spinner._render(spinner)
  end
end

---Update spinner line position
---@param id string Spinner ID
---@param line number New line number (0-indexed)
function Spinner.set_line(id, line)
  local spinner = active_spinners[id]
  if spinner then
    spinner.line = line
    Spinner._render(spinner)
  end
end

---Stop and remove a spinner
---@param id string Spinner ID
function Spinner.stop(id)
  local spinner = active_spinners[id]
  if not spinner then
    return
  end

  -- Stop timer
  if spinner.timer then
    spinner.timer:stop()
    spinner.timer:close()
    spinner.timer = nil
  end

  -- Remove virtual text
  if spinner.extmark_id and vim.api.nvim_buf_is_valid(spinner.bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, spinner.bufnr, ns_id, spinner.extmark_id)
  end

  active_spinners[id] = nil
end

---Stop all spinners in a buffer
---@param bufnr number Buffer number
function Spinner.stop_all_in_buffer(bufnr)
  for id, spinner in pairs(active_spinners) do
    if spinner.bufnr == bufnr then
      Spinner.stop(id)
    end
  end
end

---Get elapsed time for a spinner
---@param id string Spinner ID
---@return number? elapsed_ms Elapsed time in milliseconds, or nil if not found
function Spinner.get_elapsed(id)
  local spinner = active_spinners[id]
  if spinner then
    return (vim.loop.hrtime() - spinner.start_time) / 1e6
  end
  return nil
end

---Check if a spinner is active
---@param id string Spinner ID
---@return boolean is_active
function Spinner.is_active(id)
  return active_spinners[id] ~= nil
end

---Get all active spinner IDs
---@return string[] ids
function Spinner.get_active_ids()
  local ids = {}
  for id, _ in pairs(active_spinners) do
    table.insert(ids, id)
  end
  return ids
end

---Write content to buffer, clearing spinner first
---This is a helper for the common pattern of showing spinner then replacing with results
---@param id string Spinner ID
---@param lines string[] Lines to write to buffer
---@param opts { start_line: number?, end_line: number? }? Options
function Spinner.replace_with_content(id, lines, opts)
  local spinner = active_spinners[id]
  if not spinner then
    return
  end

  opts = opts or {}
  local bufnr = spinner.bufnr
  local start_line = opts.start_line or spinner.line
  local end_line = opts.end_line or (start_line + 1)

  -- Stop spinner first
  Spinner.stop(id)

  -- Write content to buffer
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)
  end
end

---Clear all virtual text from namespace in a buffer
---@param bufnr number Buffer number
function Spinner.clear_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

return Spinner
