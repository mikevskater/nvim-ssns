---Debug logger that writes to file immediately
local Debug = {}

-- Log file path
local log_file = vim.fn.stdpath('data') .. '/ssns_debug.log'

-- Initialize log file (truncate on first load)
local function init_log()
  local f = io.open(log_file, 'w')
  if f then
    f:write("=== SSNS Debug Log ===\n")
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    f:close()
  end
end

init_log()

---Write debug message to log file
---@param message string The debug message
function Debug.log(message)
  local f = io.open(log_file, 'a')
  if f then
    f:write(os.date("%H:%M:%S") .. " | " .. message .. "\n")
    f:flush()  -- Force write immediately
    f:close()
  end
end

---Get log file path
---@return string
function Debug.get_log_path()
  return log_file
end

return Debug
