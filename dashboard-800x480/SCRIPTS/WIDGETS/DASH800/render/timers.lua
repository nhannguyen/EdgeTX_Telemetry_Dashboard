-- Timers row: clock icon + power-on time, clock icon + flight time.

local M = {}

local WIDGET_PATH = "DASH800"
-- Icon size token (clock icon; consistent with topbar ICON_TOPBAR_LARGE).
local ICON_TIMER = 24
local ICON_SIZE = ICON_TIMER
local ICON_GAP = 8
local SMLSIZE_H = 6  -- SMLSIZE font height for vertical centering
local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000

local _iconClock = nil
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
  local folder = (theme and theme.iconFolder) or "dark"
  if _iconsLoaded and _loadedTheme == folder then return end
  _loadedTheme = folder
  local roots = {}
  for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/" .. folder .. "/"
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/"
  end
  _iconClock = openBitmap(roots, { "clock.png" })
  _iconsLoaded = true
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

local function formatMMSS(ticks)
  if type(ticks) ~= "number" or ticks < 0 then return "--:--" end
  local s = math.floor(ticks / 100)
  local m = math.floor(s / 60)
  s = s % 60
  return string.format("%02d:%02d", m, s)
end

local function drawTimerCell(x, y, w, h, icon, label, valueStr, textColor)
  local textY = y + math.floor((h - SMLSIZE_H) / 2)
  local left = x + 4
  if icon and lcd.drawBitmap then
    -- Center clock icon vertically with the text line
    local iconY = textY + math.floor(SMLSIZE_H / 2) - math.floor(ICON_SIZE / 2)
    lcd.drawBitmap(icon, left, iconY)
    left = left + ICON_SIZE + ICON_GAP
  end
  drawText(left, textY, label .. " " .. valueStr, SMLSIZE, textColor)
end

function M.draw(rect, telemetry, state, theme, widgetState)
  if not rect then return end
  ensureIcons(theme)
  local textColor = (theme and theme.textColor) or _WHITE
  local w = widgetState or {}
  local now = getTime and getTime() or 0

  local powerOnStr = "--:--"
  if w.powerOnStart and telemetry and telemetry.connected then
    powerOnStr = formatMMSS(now - w.powerOnStart)
  elseif w.powerOnStart and telemetry and telemetry.linkLost then
    powerOnStr = formatMMSS((w.powerOnLastTime or now) - w.powerOnStart)
  end

  local flightStr = "--:--"
  if w.flightTimeSec then
    flightStr = formatMMSS(w.flightTimeSec * 100)
  end

  local colW = math.floor(rect.w / 2)
  drawTimerCell(rect.x, rect.y, colW, rect.h, _iconClock, "Power-on:", powerOnStr, textColor)
  drawTimerCell(rect.x + colW, rect.y, rect.w - colW, rect.h, _iconClock, "Flight:", flightStr, textColor)
end

return M
