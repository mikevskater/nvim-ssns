---@class SsnsHealth
---Health check for SSNS plugin
local M = {}

-- Compatibility for different Neovim versions
local health = vim.health or require("health")
local start_fn = health.start or health.report_start
local ok_fn = health.ok or health.report_ok
local warn_fn = health.warn or health.report_warn
local error_fn = health.error or health.report_error

function M.check()
  start_fn("SSNS")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    ok_fn("Neovim version >= 0.9")
  else
    error_fn("Neovim 0.9+ required")
  end

  -- Check if node is available
  local node_path = vim.fn.exepath("node")
  if node_path ~= "" then
    local node_version = vim.fn.system("node --version"):gsub("%s+", "")
    ok_fn("Node.js found: " .. node_path .. " (" .. node_version .. ")")
  else
    error_fn("Node.js not found in PATH", {
      "Install Node.js 16+ from https://nodejs.org/",
    })
  end

  -- Check global neovim package
  local neovim_check = vim.fn.system("npm list -g neovim 2>&1")
  if neovim_check:match("neovim@") then
    local version = neovim_check:match("neovim@([%d%.]+)")
    ok_fn("Global neovim npm package installed: " .. (version or "unknown version"))
  else
    error_fn("Global neovim npm package not found", {
      "Run: npm install -g neovim",
      "This is required for Neovim's node-host to work",
    })
  end

  -- Check if plugin is in runtimepath
  local rtp = vim.o.runtimepath
  local ssns_in_rtp = rtp:match("nvim%-ssns") or rtp:match("ssns")
  if ssns_in_rtp then
    ok_fn("SSNS plugin found in runtimepath")
  else
    warn_fn("SSNS plugin may not be in runtimepath")
  end

  -- Find the rplugin directory
  local rplugin_paths = vim.api.nvim_get_runtime_file("rplugin/node/ssns-db/index.js", false)
  if #rplugin_paths > 0 then
    ok_fn("Node remote plugin found: " .. rplugin_paths[1])

    -- Check if node_modules exists
    local rplugin_dir = rplugin_paths[1]:gsub("index%.js$", "")
    local node_modules = rplugin_dir .. "node_modules"
    if vim.fn.isdirectory(node_modules) == 1 then
      ok_fn("Node modules installed")
    else
      error_fn("Node modules not installed", {
        "Run: cd " .. rplugin_dir .. " && npm install",
      })
    end
  else
    error_fn("Node remote plugin not found in runtimepath", {
      "Ensure the plugin is installed correctly",
      "Check that rplugin/node/ssns-db/index.js exists",
    })
  end

  -- Check rplugin.vim manifest
  local manifest_path = vim.fn.stdpath("data") .. "/rplugin.vim"
  if vim.fn.filereadable(manifest_path) == 1 then
    local manifest = vim.fn.readfile(manifest_path)
    local manifest_content = table.concat(manifest, "\n")
    if manifest_content:match("SSNSExecuteQuery") then
      ok_fn("Remote plugin registered in manifest")
    else
      warn_fn("Remote plugin NOT registered in manifest", {
        "Run :UpdateRemotePlugins and restart Neovim",
      })
    end
  else
    warn_fn("rplugin.vim manifest not found", {
      "Run :UpdateRemotePlugins",
    })
  end

  -- Check nvim-float dependency
  local nvim_float_ok = pcall(require, "nvim-float")
  if nvim_float_ok then
    ok_fn("nvim-float dependency found")
  else
    error_fn("nvim-float dependency not found", {
      "Install nvim-float as a dependency",
    })
  end
end

return M
