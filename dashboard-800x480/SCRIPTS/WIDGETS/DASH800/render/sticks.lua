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

local INPUT_SOURCES = {
  roll = { "ail", "Ail" }, pitch = { "ele", "Ele" },
  throttle = { "thr", "Thr" }, yaw = { "rud", "Rud" },
}

local function toNum(v)
  if type(v) == "number" then return v end
  if type(v) == "table" then
    if type(v.value) == "number" then return v.value end
    if type(v.val) == "number" then return v.val end
  end
  if type(v) == "string" then local n = tonumber(string.match(v, "%-?%d+%.?%d*")) if n then return n end end
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

local function drawText(x, y, text, size, color)
  if not lcd or not lcd.drawText then return end
  local c = (type(color) == "number") and color or _WHITE
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, _BLACK)
    lcd.drawText(x + 1, y + 1, text, size + CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR, c)
    lcd.drawText(x, y, text, size + CUSTOM_COLOR)
  else
    lcd.drawText(x, y, text, size)
  end
end

local DOT_SIZE = 5
local function drawDot(cx, cy, color)
  if not lcd or not lcd.drawFilledRectangle then return end
  local c = (type(color) == "number") and color or _GREEN
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, c)
    lcd.drawFilledRectangle(cx - DOT_SIZE, cy - DOT_SIZE, DOT_SIZE * 2, DOT_SIZE * 2, CUSTOM_COLOR)
  else
    lcd.drawFilledRectangle(cx - DOT_SIZE, cy - DOT_SIZE, DOT_SIZE * 2, DOT_SIZE * 2, c)
  end
end

local function drawStickBox(rect, xVal, yVal, drawPosition, placeholderLabel, theme)
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
  -- Placeholder when no telemetry: larger letter (MIDSIZE) + "Stick" label for visibility
  if placeholderLabel and lcd and lcd.drawText then
    local textColor = (theme and theme.textColor) or _WHITE
    local letterW, letterH = 8, 12   -- MIDSIZE approx
    local labelW, labelH = 24, 6    -- "Stick" SMLSIZE
    local totalH = letterH + 2 + labelH
    local startY = y + math.floor((h - totalH) / 2)
    local txLetter = x + math.floor((w - letterW) / 2)
    drawText(txLetter, startY, placeholderLabel, MIDSIZE, textColor)
    local txLabel = x + math.floor((w - labelW) / 2)
    drawText(txLabel, startY + letterH + 2, "Stick", SMLSIZE, textColor)
  end
  -- Only draw position dot when stick input is available; otherwise avoid stray black square
  if drawPosition and lcd and lcd.drawFilledRectangle then
    local cx = x + math.floor(w / 2)
    local cy = y + math.floor(h / 2)
    local minX, maxX = x + 4, x + w - 5
    local minY, maxY = y + 4, y + h - 5
    local px = mapAxis(xVal, minX, maxX, false)
    local py = mapAxis(yVal, minY, maxY, true)
    drawDot(px, py, _BLACK)
  end
end

function M.drawLeftStick(rect, theme, telemetry)
  if not rect then return end
  ensureIcons(theme)
  local hasInput = type(getValue) == "function"
  local yaw = readInput(INPUT_SOURCES.yaw)
  local throttle = readInput(INPUT_SOURCES.throttle)
  local showPlaceholder = not (telemetry and telemetry.connected) and not hasInput
  drawStickBox(rect, yaw, throttle, hasInput, showPlaceholder and "L" or nil, theme)
end

function M.drawRightStick(rect, theme, telemetry)
  if not rect then return end
  ensureIcons(theme)
  local hasInput = type(getValue) == "function"
  local roll = readInput(INPUT_SOURCES.roll)
  local pitch = readInput(INPUT_SOURCES.pitch)
  local showPlaceholder = not (telemetry and telemetry.connected) and not hasInput
  drawStickBox(rect, roll, pitch, hasInput, showPlaceholder and "R" or nil, theme)
end

return M
