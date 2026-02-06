---@class SsnsHealth
---Health check for SSNS plugin
local M = {}

local health = vim.health

function M.check()
  health.start("SSNS")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    health.ok("Neovim version >= 0.9")
  else
    health.error("Neovim 0.9+ required")
  end

  -- Check if node is available
  local node_path = vim.fn.exepath("node")
  if node_path ~= "" then
    local node_version = vim.fn.system("node --version"):gsub("%s+", "")
    health.ok("Node.js found: " .. node_path .. " (" .. node_version .. ")")
  else
    health.error("Node.js not found in PATH", {
      "Install Node.js 16+ from https://nodejs.org/",
    })
  end

  -- Check global neovim package
  local neovim_check = vim.fn.system("npm list -g neovim 2>&1")
  if neovim_check:match("neovim@") then
    local version = neovim_check:match("neovim@([%d%.]+)")
    health.ok("Global neovim npm package installed: " .. (version or "unknown version"))
  else
    health.error("Global neovim npm package not found", {
      "Run: npm install -g neovim",
      "This is required for Neovim's node-host to work",
    })
  end

  -- Check if plugin is in runtimepath
  local rtp = vim.o.runtimepath
  local ssns_in_rtp = rtp:match("nvim%-ssns") or rtp:match("ssns")
  if ssns_in_rtp then
    health.ok("SSNS plugin found in runtimepath")
  else
    health.warn("SSNS plugin may not be in runtimepath")
  end

  -- Find the rplugin directory
  local rplugin_paths = vim.api.nvim_get_runtime_file("rplugin/node/ssns-db/index.js", false)
  if #rplugin_paths > 0 then
    health.ok("Node remote plugin found: " .. rplugin_paths[1])

    -- Check if node_modules exists
    local rplugin_dir = rplugin_paths[1]:gsub("index%.js$", "")
    local node_modules = rplugin_dir .. "node_modules"
    if vim.fn.isdirectory(node_modules) == 1 then
      health.ok("Node modules installed")
    else
      health.error("Node modules not installed", {
        "Run: cd " .. rplugin_dir .. " && npm install",
      })
    end
  else
    health.error("Node remote plugin not found in runtimepath", {
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
      health.ok("Remote plugin registered in manifest")
    else
      health.warn("Remote plugin NOT registered in manifest", {
        "Run :UpdateRemotePlugins and restart Neovim",
      })
    end
  else
    health.warn("rplugin.vim manifest not found", {
      "Run :UpdateRemotePlugins",
    })
  end

  -- Check nvim-float dependency
  local nvim_float_ok = pcall(require, "nvim-float")
  if nvim_float_ok then
    health.ok("nvim-float dependency found")
  else
    health.error("nvim-float dependency not found", {
      "Install nvim-float as a dependency",
    })
  end
end

return M
