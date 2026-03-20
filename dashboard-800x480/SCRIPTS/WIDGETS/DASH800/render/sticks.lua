-- Stick monitor: LQ and RX battery with icons; two stick boxes.

local M = {}

local WIDGET_PATH = "DASH800"
local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _GREEN = (type(GREEN) == "number") and GREEN or 0x07E0
local LQ_ICON_W, LQ_ICON_H = 28, 28
local BATTERY_ICON_W, BATTERY_ICON_H = 20, 28

local icons = {}
local _iconsLoaded = false
local _loadedTheme = nil

local function openBitmap(roots, names)
  if not Bitmap or type(Bitmap.open) ~= "function" then return nil end
  for i = 1, #names do
    for j = 1, #roots do
      local bm = Bitmap.open(roots[j] .. names[i])
      if bm then return bm end
    end
  end
  return nil
end

local function ensureIcons(theme)
  if _iconsLoaded and _loadedTheme == (theme and theme.iconFolder or "dark") then return end
  _loadedTheme = (theme and theme.iconFolder) or "dark"
  local folder = _loadedTheme
  local roots = {}
  for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/" .. folder .. "/"
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/"
  end
  icons.link = openBitmap(roots, { "link.png" })
  icons.link_off = openBitmap(roots, { "link_off.png" })
  icons.battery = openBitmap(roots, { "battery.png" })
  local batRoots = {}
  for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
    batRoots[#batRoots + 1] = p .. WIDGET_PATH .. "/icons/battery/"
  end
  icons.batteryOk = openBitmap(batRoots, { "battery-ok.png", "battery-full.png" })
  icons.batteryWarn = openBitmap(batRoots, { "battery-warn.png", "battery-ok.png" })
  icons.batteryLow = openBitmap(batRoots, { "battery-low.png", "battery-dead.png" })
  local linkRoots = {}
  for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
    linkRoots[#linkRoots + 1] = p .. WIDGET_PATH .. "/icons/link/"
  end
  icons.connOk = openBitmap(linkRoots, { "connection-ok.png" })
  icons.connWarn = openBitmap(linkRoots, { "connection-warn.png", "connection-ok.png" })
  icons.connLow = openBitmap(linkRoots, { "connection-low.png", "connection-dead.png" })
  _iconsLoaded = true
end

-- Mode 2: Left stick  = Thr (Y, up/down) + Rud (X, left/right)
--         Right stick = Ele (Y, up/down) + Ail (X, left/right)
local INPUT_SOURCES = {
  left_x  = { "rud", "Rud", "RUD" },  -- left stick horizontal
  left_y  = { "thr", "Thr", "THR" },  -- left stick vertical
  right_x = { "ail", "Ail", "AIL" },  -- right stick horizontal
  right_y = { "ele", "Ele", "ELE" },  -- right stick vertical
}

local function toNum(v)
  if type(v) == "number" then return v end
  if type(v) == "table" then
    if type(v.value) == "number" then return v.value end
    if type(v.val)   == "number" then return v.val   end
  end
  if type(v) == "string" then
    local n = tonumber(string.match(v, "%-?%d+%.?%d*"))
    if n then return n end
  end
  return nil
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function readInput(names)
  if not getValue then return 0 end
  for i = 1, #names do
    local n = toNum(getValue(names[i]))
    if n ~= nil then
      local norm = clamp((n * 100) / 1024, -100, 100)
      if math.abs(norm) < 0.8 then norm = 0 end
      return norm
    end
  end
  return 0
end

local function mapAxis(value, minP, maxP, invert)
  local t = (value + 100) / 200
  if invert then t = 1 - t end
  return math.floor(minP + t * (maxP - minP) + 0.5)
end

local RING_R = 8   -- outer guide ring radius
local DOT_R  = 4   -- filled position dot radius

local function drawCircleColor(cx, cy, r, color, filled)
  if not lcd then return end
  local c = (type(color) == "number") and color or _WHITE
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, c)
    c = CUSTOM_COLOR
  end
  if filled and type(lcd.drawFilledCircle) == "function" then
    lcd.drawFilledCircle(cx, cy, r, c)
  elseif type(lcd.drawCircle) == "function" then
    lcd.drawCircle(cx, cy, r, c)
  end
end

local function drawStickBox(rect, xVal, yVal, drawPosition, theme)
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  if lcd.drawLine then
    local c = (theme and (theme.borderColor or theme.textColor)) or _WHITE
    if type(CUSTOM_COLOR) == "number" and lcd.setColor then lcd.setColor(CUSTOM_COLOR, c) c = CUSTOM_COLOR end
    local solid = (type(SOLID) == "number") and SOLID or 0
    lcd.drawLine(x, y, x + w - 1, y, solid, c)
    lcd.drawLine(x, y + h - 1, x + w - 1, y + h - 1, solid, c)
    lcd.drawLine(x, y, x, y + h - 1, solid, c)
    lcd.drawLine(x + w - 1, y, x + w - 1, y + h - 1, solid, c)
  end
  local cx = x + math.floor(w / 2)
  local cy = y + math.floor(h / 2)
  local ringColor = (theme and theme.textColor) or _WHITE
  -- Draw outer guide ring (always visible as reference circle)
  drawCircleColor(cx, cy, RING_R, ringColor, false)
  if drawPosition then
    -- Dot tracks actual stick position
    local minX, maxX = x + DOT_R + 2, x + w - DOT_R - 3
    local minY, maxY = y + DOT_R + 2, y + h - DOT_R - 3
    local px = mapAxis(xVal, minX, maxX, false)
    local py = mapAxis(yVal, minY, maxY, true)
    drawCircleColor(px, py, DOT_R, _GREEN, true)
  else
    -- No telemetry: filled dot at center inside the ring
    drawCircleColor(cx, cy, DOT_R, ringColor, true)
  end
end

function M.drawLeftStick(rect, theme, telemetry)
  if not rect then return end
  ensureIcons(theme)
  local x = readInput(INPUT_SOURCES.left_x)
  local y = readInput(INPUT_SOURCES.left_y)
  drawStickBox(rect, x, y, type(getValue) == "function", theme)
end

function M.drawRightStick(rect, theme, telemetry)
  if not rect then return end
  ensureIcons(theme)
  local x = readInput(INPUT_SOURCES.right_x)
  local y = readInput(INPUT_SOURCES.right_y)
  drawStickBox(rect, x, y, type(getValue) == "function", theme)
end

return M
