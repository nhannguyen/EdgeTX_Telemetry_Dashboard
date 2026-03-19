-- Footer: ELRS version, EdgeTX version.

local M = {}

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _edgeTxCached

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

local function edgeTxVersion()
  if _edgeTxCached then return _edgeTxCached end
  if type(getVersion) == "function" then
    local ok, _, _, major, minor, rev, osname = pcall(getVersion)
    if ok and type(major) == "number" then
      local name = (type(osname) == "string" and #osname > 0) and osname or "EdgeTX"
      _edgeTxCached = string.format("%s %d.%d.%d", name, major, minor, rev)
      return _edgeTxCached
    end
  end
  _edgeTxCached = "EdgeTX"
  return _edgeTxCached
end

function M.draw(rect, telemetry, state, theme)
  if not rect then return end
  local textColor = (theme and theme.textColor) or _WHITE
  local elrsStr = (telemetry and type(telemetry.elrsVersion) == "string" and #telemetry.elrsVersion > 0)
    and telemetry.elrsVersion or "ELRS"
  drawText(rect.x + 4, rect.y - 1, elrsStr, SMLSIZE, textColor)
  local et = edgeTxVersion()
  drawText(rect.x + rect.w - #et * 6 - 4, rect.y - 1, et, SMLSIZE, textColor)
end

return M
