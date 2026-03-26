---@class UiHighlights
---Highlight group setup for SSNS UI
---Note: Per-line highlighting is handled by ContentBuilder via render_to_buffer().
---This module only manages theme setup and filetype detection.
local UiHighlights = {}

---Setup highlight groups
---Delegates to ThemeManager for actual highlight setup
function UiHighlights.setup()
  local ThemeManager = require('nvim-ssns.ui.theme_manager')
  ThemeManager.setup()
end

---Setup filetype detection
function UiHighlights.setup_filetype()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ssns",
    callback = function()
      UiHighlights.setup()
    end,
  })
end

return UiHighlights
