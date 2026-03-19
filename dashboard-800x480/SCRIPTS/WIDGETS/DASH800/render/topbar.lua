-- Top bar: model name | FM icon, Arm color, Antenna | TX bat, link, clock.

local M = {}

local WIDGET_PATH = "DASH800"
local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _RED = (type(RED) == "number") and RED or 0xF800
-- Icon size tokens (consistent with cards/timers).
local ICON_TOPBAR_SMALL = 20
local ICON_TOPBAR_LARGE = 24
local ICON_TOPBAR_FM = 22
local LINK_ICON_W, LINK_ICON_H = ICON_TOPBAR_LARGE, ICON_TOPBAR_LARGE
local BATTERY_ICON_W = ICON_TOPBAR_SMALL
local FM_ICON_W = ICON_TOPBAR_FM

local _TEXT_COLOR = _WHITE
local _TEXT_SHADOW = _BLACK

local _iconLinkOn, _iconLinkOff, _iconTxBattery, _iconAntenna
local _iconFm = {}
local ANTENNA_ICON_W, ANTENNA_ICON_H = ICON_TOPBAR_SMALL, ICON_TOPBAR_SMALL
local _iconsLoaded = false
local _loadedTheme = nil

local function drawShadowText(x, y, text, size, color)
  if not lcd or type(lcd.drawText) ~= "function" then return end
  local c = (type(color) == "number") and color or _WHITE
  local sh = _TEXT_SHADOW
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, sh)
    lcd.drawText(x + 1, y + 1, text, size + CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR, c)
    lcd.drawText(x, y, text, size + CUSTOM_COLOR)
    return
  end
  pcall(lcd.drawText, x + 1, y + 1, text, size, sh)
  pcall(lcd.drawText, x, y, text, size, c)
end

local function truncate(text, maxW, cw)
  cw = cw or 5
  local n = math.max(1, math.floor(maxW / cw))
  if #text <= n then return text end
  if n <= 3 then return string.sub(text, 1, n) end
  return string.sub(text, 1, n - 3) .. "..."
end

local function droneName(telemetry)
  if telemetry and telemetry.available and telemetry.available.droneName and type(telemetry.droneName) == "string" and #telemetry.droneName > 0 then
    return telemetry.droneName
  end
  if model and model.getInfo then
    local info = model.getInfo()
    if info and type(info.name) == "string" and info.name ~= "" then return info.name end
  end
  return "MODEL"
end

local function readTxVoltage()
  if not getValue then return nil end
  for _, n in ipairs({ "tx-voltage", "TxBt", "A1" }) do
    local v = getValue(n)
    if type(v) == "number" and v >= 0 then return v end
  end
  return nil
end

local function readClock()
  if getDateTime then
    local dt = getDateTime()
    if dt and dt.hour ~= nil and dt.min ~= nil then
      return string.format("%02d:%02d", dt.hour, dt.min)
    end
  end
  return "--:--"
end

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
  _iconLinkOn = openBitmap(roots, { "link.png" })
  _iconLinkOff = openBitmap(roots, { "link_off.png" })
  _iconTxBattery = openBitmap(roots, { "battery.png" })
  if not _iconTxBattery then
    local batRoots = {}
    for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
      batRoots[#batRoots + 1] = p .. WIDGET_PATH .. "/icons/battery/"
    end
    _iconTxBattery = openBitmap(batRoots, { "battery-ok.png", "battery-full.png" })
  end
  for _, key in ipairs({ "angle", "horizon", "acro", "rth", "waypoint", "unknown" }) do
    _iconFm[key] = openBitmap(roots, { "fm-" .. key .. ".png" })
  end
  _iconFm.drone = openBitmap(roots, { "drone.png" })
  _iconAntenna = openBitmap(roots, { "antenna.png" })
  _iconsLoaded = true
end

local function flightModeToIconKey(fm)
  if not fm or type(fm) ~= "string" or fm == "" or fm == "--" then return "unknown" end
  local s = string.gsub(string.lower(fm), "%s+", "")
  if string.find(s, "angle") then return "angle" end
  if string.find(s, "horizon") then return "horizon" end
  if string.find(s, "acro") or string.find(s, "rate") then return "acro" end
  if string.find(s, "rth") or string.find(s, "return") then return "rth" end
  if string.find(s, "waypoint") or string.find(s, "wp") then return "waypoint" end
  return "unknown"
end

local function truncateAntenna(text, maxChars)
  maxChars = maxChars or 10
  if not text or #text <= maxChars then return text or "" end
  return string.sub(text, 1, maxChars - 2) .. ".."
end

-- Top bar height (matches layout.lua TOP_BAR_H) for banner region when link lost.
local TOP_BAR_H = 44

local function anyAvailable(av)
  if not av or type(av) ~= "table" then return false end
  for _, v in pairs(av) do
    if v then return true end
  end
  return false
end

function M.draw(bounds, telemetry, state, theme)
  if not bounds then return end
  _TEXT_COLOR = (theme and theme.textColor) or _WHITE
  _TEXT_SHADOW = (theme and theme.isLight) and _WHITE or _BLACK
  ensureIcons(theme)

  local x, y, w, h = bounds.x, bounds.y, bounds.w, bounds.h

  -- Link-lost / no-telemetry banner inside top bar (no separate row, no overlap with cards).
  if telemetry and telemetry.linkLost and lcd and lcd.drawFilledRectangle then
    if type(CUSTOM_COLOR) == "number" and lcd.setColor then
      lcd.setColor(CUSTOM_COLOR, _RED)
      lcd.drawFilledRectangle(x, y, w, h, CUSTOM_COLOR)
    else
      lcd.drawFilledRectangle(x, y, w, h, _RED)
    end
    local msg = (telemetry.available and anyAvailable(telemetry.available))
      and "LINK LOST - last values shown"
      or "No telemetry"
    local inset = 8
    local maxW = w - 2 * inset
    local bannerText = truncate(msg, maxW, 4)  -- SMLSIZE ~4-5px per char
    local textY = y + math.floor((h - 6) / 2)  -- SMLSIZE ~6px height
    drawShadowText(x + inset, textY, bannerText, SMLSIZE, _WHITE)
    return
  end

  local nameW = math.floor(w * 0.28)
  local nameText = truncate(droneName(telemetry), nameW - 8, 6)
  drawShadowText(x + 8, y + math.floor((h - 12) / 2), nameText, MIDSIZE, _TEXT_COLOR)

  local centerX = x + nameW + 8

  local fmKey = flightModeToIconKey(telemetry and telemetry.flightMode)
  local fmIcon = _iconFm[fmKey] or _iconFm.unknown or _iconFm.drone
  if fmIcon and lcd.drawBitmap then
    lcd.drawBitmap(fmIcon, centerX, y + math.floor((h - FM_ICON_W) / 2))
    centerX = centerX + FM_ICON_W + 4
  end

  local antennaMode = telemetry and telemetry.available and telemetry.available.antennaMode and telemetry.antennaMode and #telemetry.antennaMode > 0
  if antennaMode then
    if _iconAntenna and lcd.drawBitmap then
      lcd.drawBitmap(_iconAntenna, centerX, y + math.floor((h - ANTENNA_ICON_H) / 2))
      centerX = centerX + ANTENNA_ICON_W + 4
    else
      local antStr = truncateAntenna(telemetry.antennaMode, 10)
      drawShadowText(centerX, y + math.floor((h - 8) / 2), antStr, SMLSIZE, _TEXT_COLOR)
      centerX = centerX + (#antStr * 6) + 6
    end
  end

  local rightStart = x + w - 90
  local txV = readTxVoltage()
  local txStr = txV and string.format("%.1fV", txV) or "--.-V"
  local txX = rightStart
  if _iconTxBattery and lcd.drawBitmap then
    lcd.drawBitmap(_iconTxBattery, txX, y + math.floor((h - 20) / 2))
    txX = txX + BATTERY_ICON_W + 4
  end
  drawShadowText(txX, y + math.floor((h - 10) / 2), txStr, SMLSIZE, _TEXT_COLOR)

  local connected = telemetry and telemetry.connected
  local linkX = x + w - 62
  if _iconLinkOn and connected then
    lcd.drawBitmap(_iconLinkOn, linkX, y + math.floor((h - LINK_ICON_H) / 2))
  elseif _iconLinkOff and not connected then
    lcd.drawBitmap(_iconLinkOff, linkX, y + math.floor((h - LINK_ICON_H) / 2))
  else
    drawShadowText(linkX, y + 2, connected and "LINK" or "NO", SMLSIZE, connected and _TEXT_COLOR or _RED)
  end

  local timeStr = readClock()
  drawShadowText(x + w - 46, y + math.floor((h - 8) / 2), timeStr, SMLSIZE, _TEXT_COLOR)
end

return M
