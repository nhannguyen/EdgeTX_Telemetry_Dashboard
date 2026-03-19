-- Primary grid: 4 composite cards (Link, Battery, GPS, Temps) for 800x480.

local M = {}

local WIDGET_PATH = "DASH800"
-- Icon size tokens: ICON_TITLE for card title icons (consistent with topbar/timers naming).
local ICON_TITLE = 16
local ICON_SIZE = ICON_TITLE
local ICON_GAP = 8
local BAR_H = 4       -- thin progress bar at bottom
local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _GREEN = (type(GREEN) == "number") and GREEN or 0x07E0
local _YELLOW = (type(YELLOW) == "number") and YELLOW or 0xFFE0
local _RED = (type(RED) == "number") and RED or 0xF800

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
  icons.battery = openBitmap(roots, { "battery.png" })
  icons.signal = openBitmap(roots, { "signal.png" })
  icons.current = openBitmap(roots, { "current.png" })
  icons.sat = openBitmap(roots, { "sat.png" })
  icons.antenna = openBitmap(roots, { "antenna.png" })
  _iconsLoaded = true
end

local function setColor(c)
  if lcd and lcd.setColor and type(CUSTOM_COLOR) == "number" and type(c) == "number" then
    lcd.setColor(CUSTOM_COLOR, c)
  end
end

local function drawBar(rect, frac)
  if not rect or not lcd then return end
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local barY = y + h - CARD_PAD - BAR_H
  if lcd.drawFilledRectangle then
    lcd.drawFilledRectangle(x, barY, w, BAR_H, _BLACK)
    local fillW = math.floor(w * math.max(0, math.min(1, frac)) + 0.5)
    if fillW > 0 then
      local c = _GREEN
      if frac < 0.25 then c = _RED elseif frac < 0.5 then c = _YELLOW end
      setColor(c)
      lcd.drawFilledRectangle(x, barY, fillW, BAR_H, CUSTOM_COLOR or c)
    end
  end
end

local function drawShadowText(x, y, text, size, color)
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

-- Single padding constant for top/bottom/left/right (8px rhythm per UI/UX plan).
local CARD_PAD = 8
local TITLE_TO_BODY_GAP = 8
local TITLE_H = 12   -- MIDSIZE font height per lua-reference fonts.md
local SMLSIZE_H = 6  -- SMLSIZE font height for vertical spread
local BAR_RESERVE = BAR_H + CARD_PAD  -- pixels reserved at bottom when showBar (bar + padding)

local function drawCardBorder(rect, color)
  if not rect or not lcd or not lcd.drawLine then return end
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local c = (type(color) == "number") and color or _WHITE
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, c)
    c = CUSTOM_COLOR
  end
  local solid = (type(SOLID) == "number") and SOLID or 0
  lcd.drawLine(x, y, x + w - 1, y, solid, c)
  lcd.drawLine(x, y + h - 1, x + w - 1, y + h - 1, solid, c)
  lcd.drawLine(x, y, x, y + h - 1, solid, c)
  lcd.drawLine(x + w - 1, y, x + w - 1, y + h - 1, solid, c)
end

local function drawCompositeCard(rect, icon, title, lines, showBar, frac, theme)
  if not rect or not lcd then return end
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local left = x + CARD_PAD
  local titleY = y + CARD_PAD
  -- Align icon vertical center with title line
  local iconY = titleY + math.floor(TITLE_H / 2) - math.floor(ICON_SIZE / 2)
  iconY = math.max(y, iconY)
  if icon and lcd.drawBitmap then
    lcd.drawBitmap(icon, left, iconY)
    left = left + ICON_SIZE + ICON_GAP
  end
  local maxContentW = w - 2 * CARD_PAD
  local textColor = theme and theme.textColor or _WHITE
  drawShadowText(left, titleY, title or "", MIDSIZE, textColor)
  local bodyY = titleY + TITLE_H + TITLE_TO_BODY_GAP
  local bodyBottom = y + h - CARD_PAD - (showBar and BAR_RESERVE or 0)
  -- Spread body lines evenly in card body (equal gap above, between, below)
  local n = #lines
  if n > 0 then
    local bodyHeight = bodyBottom - bodyY
    local lineH = SMLSIZE_H
    local totalLineH = n * lineH
    local gap = (bodyHeight - totalLineH) / (n + 1)
    for i = 1, n do
      local yy = bodyY + math.floor(gap + (i - 1) * (lineH + gap))
      local text = string.sub(lines[i] or "--", 1, 28)
      drawShadowText(left, yy, text, SMLSIZE, textColor)
    end
  end
  if showBar and frac then drawBar(rect, frac) end
  -- 1px border consistent with stick panels (SOLID lines per lua-reference-guide drawLine)
  local borderColor = theme and (theme.borderColor or theme.textColor) or _WHITE
  drawCardBorder(rect, borderColor)
end

function M.draw(layout, slots, telemetry, state, theme)
  if not layout or not slots or not slots.primary then return end
  ensureIcons(theme)
  local t = telemetry
  local av = t and t.available or {}

  local function card(id, iconKey, title, lines, showBar, frac)
    local slot = slots.primary[id]
    if not slot then return end
    drawCompositeCard(slot, icons[iconKey], title, lines, showBar, frac, theme)
  end

  -- P2: Battery — Title "Battery {V}", Line 1 current A, Line 2 consumed mAh
  local bat = t and t.battery or 0
  local batStr = (av.battery and bat > 0) and string.format("%.2fV", bat) or "--"
  local cur = t and t.current or 0
  local curStr = (av.current and cur >= 0) and string.format("%.1f A", cur) or "--"
  local cap = t and t.capacity or 0
  local capStr = (av.capacity and cap >= 0) and (tostring(math.floor(cap + 0.5)) .. " mAh") or "-- mAh"
  card("P2", "battery", "Battery " .. batStr, { curStr, capStr }, true, (av.battery and bat > 0) and math.min(1, bat / 12.6) or 0)

  -- P4: Link — Title "LQ xx%"; Line 1 TxP / SNR (fixed label width); Line 2 RSS or 1RSS/2RSS
  local lq = t and t.linkQuality or 0
  local lqStr = av.linkQuality and (math.floor(lq + 0.5) .. "%") or "--%"
  local tpwr = t and t.txPower or 0
  local tpStr = (av.txPower and tpwr > 0) and (math.floor(tpwr + 0.5) .. "mW") or "--"
  local rsnr = t and t.rsnr
  local snrStr = (av.rsnr and rsnr ~= nil) and tostring(math.floor(rsnr + 0.5)) or "--"
  local line1Link = "TxP  " .. tpStr .. "   SNR " .. snrStr
  local r1 = t and t.rssi1 or 0
  local r1Str = (av.rssi1 and r1 ~= 0) and (math.floor(r1 + 0.5) .. "dBm") or "--"
  local r2 = t and t.rssi2 or 0
  local r2Str = (av.rssi2 and r2 ~= 0) and (math.floor(r2 + 0.5) .. "dBm") or "--"
  local rssi = t and t.rssi or 0
  local rssiStr = (av.rssi and rssi ~= 0) and (math.floor(rssi + 0.5) .. "dBm") or "--"
  local line2Link
  if av.rssi1 and av.rssi2 then
    line2Link = "1RSS " .. r1Str .. "   2RSS " .. r2Str
  else
    line2Link = "RSS  " .. rssiStr
  end
  card("P4", "signal", "LQ " .. lqStr, { line1Link, line2Link }, true, lq / 100)

  -- P5: Temperature — Title "Temperature"; Line 1 FC / ESC, Line 2 VTX / M (fixed spacing)
  local fcStr = (av.tempFC and t.tempFC ~= nil) and (math.floor(t.tempFC + 0.5) .. "°") or "--"
  local escStr = (av.tempESC and t.tempESC ~= nil) and (math.floor(t.tempESC + 0.5) .. "°") or "--"
  local vtxStr = (av.tempVTX and t.tempVTX ~= nil) and (math.floor(t.tempVTX + 0.5) .. "°") or "--"
  local mStr = (av.tempMotor and t.tempMotor ~= nil) and (math.floor(t.tempMotor + 0.5) .. "°") or "--"
  local line1Temp = "FC   " .. fcStr .. "   ESC " .. escStr
  local line2Temp = "VTX  " .. vtxStr .. "   M   " .. mStr
  card("P5", "current", "Temperature", { line1Temp, line2Temp }, false, nil)

  -- P6: Drone GPS — Title "Drone Sat: {n}", Line 1 Lat, Line 2 Long
  local sats = t and (t.sats or t.satellites) or 0
  local satsStr = (av.satellites and sats ~= nil) and tostring(math.floor(sats + 0.5)) or "--"
  local latStr = (av.gpsPosition and t.gpsLat ~= nil) and string.format("%.5f", t.gpsLat) or "--"
  local lonStr = (av.gpsPosition and t.gpsLon ~= nil) and string.format("%.5f", t.gpsLon) or "--"
  card("P6", "sat", "Drone Sat: " .. satsStr, { "Lat " .. latStr, "Long " .. lonStr }, false, nil)

  -- P7: Pilot GPS — Title "Pilot Sat: {n}", Line 1 Lat, Line 2 Long
  local pilotSats = t and t.pilotSats
  local pilotSatsStr = (av.pilotSats and pilotSats ~= nil) and tostring(math.floor(pilotSats + 0.5)) or (av.pilotPosition and "--") or "--"
  local pilotLatStr = (av.pilotPosition and t.pilotLat ~= nil) and string.format("%.5f", t.pilotLat) or "--"
  local pilotLonStr = (av.pilotPosition and t.pilotLon ~= nil) and string.format("%.5f", t.pilotLon) or "--"
  card("P7", "sat", "Pilot Sat: " .. pilotSatsStr, { "Lat " .. pilotLatStr, "Long " .. pilotLonStr }, false, nil)
end

return M
