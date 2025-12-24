---@class ColorUtils
---Color conversion and manipulation utilities
local M = {}

-- ============================================================================
-- Hex <-> RGB Conversions
-- ============================================================================

---Parse hex color string to RGB components
---@param hex string Hex color like "#FF5500" or "FF5500"
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
function M.hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  if #hex ~= 6 then
    return 128, 128, 128 -- fallback gray
  end
  local r = tonumber(hex:sub(1, 2), 16) or 128
  local g = tonumber(hex:sub(3, 4), 16) or 128
  local b = tonumber(hex:sub(5, 6), 16) or 128
  return r, g, b
end

---Convert RGB components to hex string
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return string hex Hex color like "#FF5500"
function M.rgb_to_hex(r, g, b)
  r = math.max(0, math.min(255, math.floor(r + 0.5)))
  g = math.max(0, math.min(255, math.floor(g + 0.5)))
  b = math.max(0, math.min(255, math.floor(b + 0.5)))
  return string.format("#%02X%02X%02X", r, g, b)
end

-- ============================================================================
-- RGB <-> HSL Conversions
-- ============================================================================

---Convert RGB to HSL
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return number h Hue (0-360)
---@return number s Saturation (0-100)
---@return number l Lightness (0-100)
function M.rgb_to_hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255

  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s, l

  l = (max + min) / 2

  if max == min then
    h, s = 0, 0 -- achromatic
  else
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)

    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end

    h = h / 6
  end

  return h * 360, s * 100, l * 100
end

---Helper for HSL to RGB conversion
---@param p number
---@param q number
---@param t number
---@return number
local function hue_to_rgb(p, q, t)
  if t < 0 then t = t + 1 end
  if t > 1 then t = t - 1 end
  if t < 1/6 then return p + (q - p) * 6 * t end
  if t < 1/2 then return q end
  if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
  return p
end

---Convert HSL to RGB
---@param h number Hue (0-360)
---@param s number Saturation (0-100)
---@param l number Lightness (0-100)
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
function M.hsl_to_rgb(h, s, l)
  h, s, l = h / 360, s / 100, l / 100

  local r, g, b

  if s == 0 then
    r, g, b = l, l, l -- achromatic
  else
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r = hue_to_rgb(p, q, h + 1/3)
    g = hue_to_rgb(p, q, h)
    b = hue_to_rgb(p, q, h - 1/3)
  end

  return r * 255, g * 255, b * 255
end

-- ============================================================================
-- Hex <-> HSL Conversions (convenience)
-- ============================================================================

---Convert hex to HSL
---@param hex string Hex color
---@return number h Hue (0-360)
---@return number s Saturation (0-100)
---@return number l Lightness (0-100)
function M.hex_to_hsl(hex)
  local r, g, b = M.hex_to_rgb(hex)
  return M.rgb_to_hsl(r, g, b)
end

---Convert HSL to hex
---@param h number Hue (0-360)
---@param s number Saturation (0-100)
---@param l number Lightness (0-100)
---@return string hex
function M.hsl_to_hex(h, s, l)
  local r, g, b = M.hsl_to_rgb(h, s, l)
  return M.rgb_to_hex(r, g, b)
end

-- ============================================================================
-- Color Manipulation
-- ============================================================================

---Adjust hue of a color
---@param hex string Base hex color
---@param delta number Hue adjustment (-360 to 360)
---@return string hex New hex color
function M.adjust_hue(hex, delta)
  local h, s, l = M.hex_to_hsl(hex)
  h = (h + delta) % 360
  if h < 0 then h = h + 360 end
  return M.hsl_to_hex(h, s, l)
end

---Adjust saturation of a color
---@param hex string Base hex color
---@param delta number Saturation adjustment (-100 to 100)
---@return string hex New hex color
function M.adjust_saturation(hex, delta)
  local h, s, l = M.hex_to_hsl(hex)
  s = math.max(0, math.min(100, s + delta))
  return M.hsl_to_hex(h, s, l)
end

---Adjust lightness of a color
---@param hex string Base hex color
---@param delta number Lightness adjustment (-100 to 100)
---@return string hex New hex color
function M.adjust_lightness(hex, delta)
  local h, s, l = M.hex_to_hsl(hex)
  l = math.max(0, math.min(100, l + delta))
  return M.hsl_to_hex(h, s, l)
end

---Get color at specific HSL offset from base color
---@param hex string Base hex color
---@param hue_offset number Hue offset
---@param lightness_offset number Lightness offset
---@param saturation_offset number Saturation offset
---@return string hex New hex color
function M.get_offset_color(hex, hue_offset, lightness_offset, saturation_offset)
  local h, s, l = M.hex_to_hsl(hex)

  h = (h + hue_offset) % 360
  if h < 0 then h = h + 360 end

  s = math.max(0, math.min(100, s + saturation_offset))
  l = math.max(0, math.min(100, l + lightness_offset))

  return M.hsl_to_hex(h, s, l)
end

-- ============================================================================
-- Contrast and Luminance
-- ============================================================================

---Calculate relative luminance of a color
---@param hex string Hex color
---@return number luminance (0-1)
function M.get_luminance(hex)
  local r, g, b = M.hex_to_rgb(hex)
  -- Relative luminance formula (WCAG)
  local function to_linear(c)
    c = c / 255
    return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * to_linear(r) + 0.7152 * to_linear(g) + 0.0722 * to_linear(b)
end

---Get contrasting color (black or white) for text on given background
---@param hex string Background hex color
---@return string hex Contrasting text color (#000000 or #FFFFFF)
function M.get_contrast_color(hex)
  local luminance = M.get_luminance(hex)
  return luminance > 0.179 and "#000000" or "#FFFFFF"
end

---Get inverted color
---@param hex string Hex color
---@return string hex Inverted color
function M.invert_color(hex)
  local r, g, b = M.hex_to_rgb(hex)
  return M.rgb_to_hex(255 - r, 255 - g, 255 - b)
end

-- ============================================================================
-- Validation
-- ============================================================================

---Check if string is a valid hex color
---@param hex string
---@return boolean
function M.is_valid_hex(hex)
  if type(hex) ~= "string" then return false end
  hex = hex:gsub("^#", "")
  return #hex == 6 and hex:match("^%x+$") ~= nil
end

---Normalize hex color (ensure # prefix and uppercase)
---@param hex string
---@return string
function M.normalize_hex(hex)
  if not M.is_valid_hex(hex) then
    return "#808080" -- fallback gray
  end
  hex = hex:gsub("^#", ""):upper()
  return "#" .. hex
end

-- ============================================================================
-- Color Steps for Grid
-- ============================================================================

---Default step sizes for color navigation
M.STEPS = {
  hue = 3,        -- degrees per step
  saturation = 2, -- percent per step
  lightness = 2,  -- percent per step
}

---Generate a row of colors varying by hue
---@param base_hex string Center color
---@param count number Total colors in row (should be odd)
---@param hue_step number Hue change per cell
---@param lightness_offset number Additional lightness offset for this row
---@param saturation_offset number Additional saturation offset
---@return string[] colors Array of hex colors
function M.generate_hue_row(base_hex, count, hue_step, lightness_offset, saturation_offset)
  local colors = {}
  local half = math.floor(count / 2)

  for i = 1, count do
    local hue_offset = (i - half - 1) * hue_step
    local color = M.get_offset_color(base_hex, hue_offset, lightness_offset, saturation_offset)
    table.insert(colors, color)
  end

  return colors
end

---Generate full color grid
---@param center_hex string Center color of grid
---@param width number Grid width (columns, should be odd)
---@param height number Grid height (rows, should be odd)
---@param hue_step number Hue change per horizontal cell
---@param lightness_step number Lightness change per vertical cell
---@return string[][] grid 2D array of hex colors [row][col]
function M.generate_color_grid(center_hex, width, height, hue_step, lightness_step)
  local grid = {}
  local half_height = math.floor(height / 2)

  for row = 1, height do
    local lightness_offset = (half_height + 1 - row) * lightness_step
    local row_colors = M.generate_hue_row(center_hex, width, hue_step, lightness_offset, 0)
    table.insert(grid, row_colors)
  end

  return grid
end

return M
