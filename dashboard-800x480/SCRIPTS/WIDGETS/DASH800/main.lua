-- FPVDash 800x480 (TX16S Mk3). Three card rows: sticks+battery, link+temps, drone GPS+pilot GPS.

local WIDGET_NAME = "DASH800"
local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/" .. WIDGET_NAME .. "/",
  "/WIDGETS/" .. WIDGET_NAME .. "/",
  "SCRIPTS/WIDGETS/" .. WIDGET_NAME .. "/",
  "WIDGETS/" .. WIDGET_NAME .. "/",
  "dashboard-800x480/SCRIPTS/WIDGETS/" .. WIDGET_NAME .. "/",
  "",
}

local function loadModule(relativePath)
  if not loadScript then return nil end
  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then return chunk() end
  end
  return nil
end

local layoutModule   = loadModule("layout/layout.lua")
local slotsModule    = loadModule("layout/slots.lua")
local telemetryRead  = loadModule("telemetry/read.lua")
local telemetryState = loadModule("telemetry/state.lua")
local elrsModule     = loadModule("telemetry/elrs.lua")
local topbarRenderer = loadModule("render/topbar.lua")
local sticksRenderer = loadModule("render/sticks.lua")
local cardsRenderer  = loadModule("render/cards.lua")
local contextRenderer = loadModule("render/context.lua")
local timersRenderer = loadModule("render/timers.lua")
local footerRenderer = loadModule("render/footer.lua")

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _RED = (type(RED) == "number") and RED or 0xF800
local _GREEN = (type(GREEN) == "number") and GREEN or 0x07E0
local _YELLOW = (type(YELLOW) == "number") and YELLOW or 0xFFE0

local TRANSP_VALUES = { 6, 8, 10, 12 }
local OPTION_COMBO = (type(COMBO) == "number" and COMBO) or (type(CHOICE) == "number" and CHOICE)
local WIDGET_OPTIONS = OPTION_COMBO and
  { { "darkTheme", BOOL, 1 }, { "transpLevel", OPTION_COMBO, 1, { "1","2","3","4" } } } or
  { { "darkTheme", BOOL, 1 }, { "transpLevel", VALUE, 1, 0, 3 } }

local function resolveTransparencyValue(raw)
  local v = raw
  if type(v) == "table" then v = v.value or v.val end
  if type(v) == "string" then v = tonumber(v) end
  if type(v) ~= "number" then return 8 end
  local n = math.floor(v + 0.5)
  if n >= 1 and n <= 4 then return TRANSP_VALUES[n] end
  if n >= 0 and n <= 3 then return TRANSP_VALUES[n + 1] end
  return 8
end

local function resolveTheme(options)
  local isDark = not (options and (options.darkTheme == 0 or options.darkTheme == false))
  local transparency_value = resolveTransparencyValue(options and options.transpLevel or 1)
  return {
    isLight = not isDark,
    bgColor = isDark and _BLACK or _WHITE,
    textColor = isDark and _WHITE or 0x9CF3,
    iconFolder = isDark and "dark" or "light",
    transparency = transparency_value,
  }
end

local function topBarColorFromArmState(telemetry)
  if not telemetry or not telemetry.armState or type(telemetry.armState) ~= "string" then return nil end
  local s = telemetry.armState:upper()
  if s:find("ARMED") and not s:find("PRE") then return _GREEN end
  if s:find("PREARMED") then return _YELLOW end
  if s:find("DISARMED") or s:find("DIS") then return _RED end
  return nil
end

local function drawSectionWash(rect, theme, colorOverride)
  if not rect or not lcd.drawFilledRectangle then return end
  local fillColor = (colorOverride ~= nil) and colorOverride or theme.bgColor
  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, fillColor)
    pcall(lcd.drawFilledRectangle, rect.x, rect.y, rect.w, rect.h, CUSTOM_COLOR, theme.transparency)
  end
end

local function zoneChanged(widget)
  local z = widget.zone
  local c = widget.cachedZone
  if not c then return true end
  return z.x ~= c.x or z.y ~= c.y or z.w ~= c.w or z.h ~= c.h
end

local function recomputeLayout(widget)
  if not layoutModule or not slotsModule then
    widget.layout = nil
    widget.slots = nil
    return
  end
  widget.layout = layoutModule.compute(widget.zone)
  widget.slots = slotsModule.compute(widget.layout)
  widget.cachedZone = { x = widget.zone.x, y = widget.zone.y, w = widget.zone.w, h = widget.zone.h }
end

local function create(zone, options)
  local theme = resolveTheme(options)
  return {
    zone = zone,
    options = options,
    telemetry = nil,
    state = nil,
    layout = nil,
    slots = nil,
    cachedZone = nil,
    theme = theme,
    elrsState = elrsModule and elrsModule.init() or nil,
    powerOnStart = nil,
    powerOnLastTime = nil,
    flightTimeSec = 0,
    lastArmed = false,
    lastArmTime = nil,
    criticalPlayed = false,
    criticalCooldownUntil = 0,
  }
end

local function update(widget, options)
  widget.options = options
  widget.theme = resolveTheme(options)
  if zoneChanged(widget) then recomputeLayout(widget) end
end

local function background(widget) end

local function isArmed(telemetry)
  if not telemetry or not telemetry.available or not telemetry.available.armState then return false end
  local a = telemetry.armState
  if type(a) == "string" and a:lower():find("arm") and not a:lower():find("dis") then return true end
  return false
end

local function refresh(widget, event, touchState)
  if elrsModule and widget.elrsState then
    elrsModule.update(widget.elrsState)
  end

  if telemetryRead and telemetryRead.snapshot then
    widget.telemetry = telemetryRead.snapshot()
  else
    widget.telemetry = nil
  end

  if widget.telemetry and elrsModule then
    widget.telemetry.elrsVersion = elrsModule.getString(widget.elrsState)
    local devName = elrsModule.getDeviceName(widget.elrsState)
    if devName and telemetryRead.setDroneName then
      telemetryRead.setDroneName(devName)
    end
    if devName and telemetryRead.setAntennaMode then
      local mode = elrsModule.deviceNameToAntennaMode(devName)
      telemetryRead.setAntennaMode(mode or "")
    end
  end

  if telemetryState and telemetryState.evaluate then
    widget.state = telemetryState.evaluate(widget.telemetry)
  else
    widget.state = nil
  end

  local now = getTime and getTime() or 0
  local t = widget.telemetry
  if t then
    if t.connected and widget.powerOnStart == nil then
      widget.powerOnStart = now
    end
    if t.linkLost and widget.powerOnStart then
      widget.powerOnLastTime = now
    end
    local armed = isArmed(t)
    if armed then
      if not widget.lastArmed then
        widget.lastArmTime = now
      end
      widget.lastArmed = true
      local elapsed = (now - (widget.lastArmTime or now)) / 100
      widget.flightTimeSec = math.floor(elapsed + 0.5)
    else
      if widget.lastArmed then
        local elapsed = (now - (widget.lastArmTime or now)) / 100
        widget.flightTimeSec = math.floor(elapsed + 0.5)
      end
      widget.lastArmed = false
    end
  end

  if telemetryState and telemetryState.isCritical and widget.telemetry and widget.state then
    if telemetryState.isCritical(widget.telemetry, widget.state) then
      if not widget.criticalPlayed and (widget.criticalCooldownUntil == nil or now > widget.criticalCooldownUntil) then
        if type(playFile) == "function" then
          pcall(playFile, "lowbatt.wav")
        end
        widget.criticalPlayed = true
        widget.criticalCooldownUntil = now + 500
      end
    else
      widget.criticalPlayed = false
    end
  end

  if zoneChanged(widget) or not widget.layout or not widget.slots then
    recomputeLayout(widget)
  end

  if not widget.layout then
    if lcd and lcd.drawText then
      lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "Layout unavailable", SMLSIZE)
    end
    return
  end

  local theme = resolveTheme(widget.options)
  widget.theme = theme

  if topbarRenderer and topbarRenderer.draw then
    local topBarColor = topBarColorFromArmState(widget.telemetry) or theme.bgColor
    drawSectionWash(widget.layout.topBar, theme, topBarColor)
    topbarRenderer.draw(widget.layout.topBar, widget.telemetry, widget.state, theme)
  end

  local slots = widget.slots
  if slots and slots.byId then
    -- Row 1: wash each card area, then left stick (P1), cards draw (P2,P4,P5,P6,P7), right stick (P3)
    local p1 = slots.byId.P1
    local p2 = slots.byId.P2
    local p3 = slots.byId.P3
    local p4 = slots.byId.P4
    local p5 = slots.byId.P5
    local p6 = slots.byId.P6
    local p7 = slots.byId.P7
    if p1 then drawSectionWash(p1, theme) end
    if p2 then drawSectionWash(p2, theme) end
    if p3 then drawSectionWash(p3, theme) end
    if p4 then drawSectionWash(p4, theme) end
    if p5 then drawSectionWash(p5, theme) end
    if p6 then drawSectionWash(p6, theme) end
    if p7 then drawSectionWash(p7, theme) end

    if sticksRenderer and sticksRenderer.drawLeftStick and p1 then
      sticksRenderer.drawLeftStick(p1, theme)
    end
    if cardsRenderer and cardsRenderer.draw then
      cardsRenderer.draw(widget.layout, widget.slots, widget.telemetry, widget.state, theme)
    end
    if sticksRenderer and sticksRenderer.drawRightStick and p3 then
      sticksRenderer.drawRightStick(p3, theme)
    end
  end

  if widget.layout.timersRow then
    drawSectionWash(widget.layout.timersRow, theme)
    if timersRenderer and timersRenderer.draw then
      timersRenderer.draw(widget.layout.timersRow, widget.telemetry, widget.state, theme, widget)
    end
  end

  if widget.layout.footerRow then
    drawSectionWash(widget.layout.footerRow, theme)
    if footerRenderer and footerRenderer.draw then
      footerRenderer.draw(widget.layout.footerRow, widget.telemetry, widget.state, theme)
    end
  end

  if widget.telemetry and widget.telemetry.linkLost and lcd and lcd.drawFilledRectangle and lcd.drawText then
    local z = widget.zone
    if type(CUSTOM_COLOR) == "number" and lcd.setColor then
      lcd.setColor(CUSTOM_COLOR, _RED)
      lcd.drawFilledRectangle(z.x, z.y + 44, z.w, 18, CUSTOM_COLOR)
    end
    lcd.drawText(z.x + 8, z.y + 48, "LINK LOST - last values shown", MIDSIZE)
  end
end

return {
  name = "FPVDash",
  options = WIDGET_OPTIONS,
  create = create,
  update = update,
  refresh = refresh,
  background = background,
}
