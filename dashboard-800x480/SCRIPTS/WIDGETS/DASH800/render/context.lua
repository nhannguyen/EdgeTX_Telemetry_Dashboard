-- Context row: RF rate, RSNR, Rem, temps; GPS coords. No Sats/FM/Arm/Antenna (in top bar / primary cards).

local M = {}

local WIDGET_PATH = "DASH800"
local ICON_SIZE = 22
local ICON_GAP = 4
local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000

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
  local folder = (theme and theme.iconFolder) or "dark"
  if _iconsLoaded and _loadedTheme == folder then return end
  _loadedTheme = folder
  local roots = {}
  for _, p in ipairs({ "/WIDGETS/", "/SCRIPTS/WIDGETS/", "WIDGETS/", "SCRIPTS/WIDGETS/" }) do
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/" .. folder .. "/"
    roots[#roots + 1] = p .. WIDGET_PATH .. "/icons/"
  end
  icons.rfmd = openBitmap(roots, { "rfmd.png", "rfmd-b.png" })
  icons.battery = openBitmap(roots, { "battery.png" })
  icons.current = openBitmap(roots, { "current.png" })
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

local function drawIconLabel(x, y, icon, text, color)
  local left = x
  if icon and lcd.drawBitmap then
    lcd.drawBitmap(icon, left, y)
    left = left + ICON_SIZE + ICON_GAP
  end
  drawText(left, y, text or "--", SMLSIZE, color)
end

local function formatCoord(lat, lon)
  if type(lat) ~= "number" or type(lon) ~= "number" then return nil end
  return string.format("%.5f,%.5f", lat, lon)
end

function M.draw(rect, telemetry, state, theme)
  if not rect then return end
  ensureIcons(theme)
  local t = telemetry
  local av = t and t.available or {}
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local textColor = (theme and theme.textColor) or _WHITE

  local row1Y = y + 2
  local row2Y = y + math.floor(h / 2) - 2

  -- Row 1: RF rate, RSNR, Rem (no Sats/FM/Arm/Antenna)
  local rateStr = (av.packetRate and t.packetRate and t.packetRate > 0) and (math.floor(t.packetRate + 0.5) .. "Hz") or "--"
  local rsnrStr = (av.rsnr and t.rsnr ~= nil) and tostring(math.floor(t.rsnr + 0.5)) or "--"
  local remStr = (av.remaining and t.remaining ~= nil) and tostring(math.floor(t.remaining + 0.5)) .. "mAh" or "--"
  drawIconLabel(x, row1Y, icons.rfmd, "RF:" .. rateStr .. " RSNR:" .. rsnrStr, textColor)
  drawIconLabel(x + math.floor(w / 2), row1Y, icons.battery, "Rem:" .. remStr, textColor)

  -- Row 2: temps
  local temps = {}
  if av.tempFC and t.tempFC ~= nil then temps[#temps + 1] = "FC:" .. math.floor(t.tempFC + 0.5) .. "°" end
  if av.tempESC and t.tempESC ~= nil then temps[#temps + 1] = "ESC:" .. math.floor(t.tempESC + 0.5) .. "°" end
  if av.tempVTX and t.tempVTX ~= nil then temps[#temps + 1] = "VTX:" .. math.floor(t.tempVTX + 0.5) .. "°" end
  if av.tempMotor and t.tempMotor ~= nil then temps[#temps + 1] = "M:" .. math.floor(t.tempMotor + 0.5) .. "°" end
  local tempStr = #temps > 0 and table.concat(temps, " ") or "--"
  if #tempStr > 40 then tempStr = string.sub(tempStr, 1, 37) .. ".." end
  drawIconLabel(x, row2Y, icons.current, tempStr, textColor)

  -- GPS coords line
  local droneCoord = (av.gpsPosition and t.gpsLat and t.gpsLon) and formatCoord(t.gpsLat, t.gpsLon) or nil
  local pilotCoord = (av.pilotPosition and t.pilotLat and t.pilotLon) and formatCoord(t.pilotLat, t.pilotLon) or nil
  if droneCoord or pilotCoord then
    local line = "D:" .. (droneCoord or "--") .. " P:" .. (pilotCoord or "--")
    if #line > 72 then line = string.sub(line, 1, 69) .. "..." end
    drawText(x, y + h - 10, line, SMLSIZE, textColor)
  end
end

return M
