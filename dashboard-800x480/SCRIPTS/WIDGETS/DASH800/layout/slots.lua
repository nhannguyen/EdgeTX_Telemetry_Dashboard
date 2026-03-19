-- Slot geometry for 800x480 dashboard: 7 card slots (3+2+2) + timers.

local M = {}

local function rect(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local function withSlot(id, metric, r)
  return { id = id, metric = metric, x = r.x, y = r.y, w = r.w, h = r.h }
end

local function splitColumns(area, columns, gap)
  local cells = {}
  local innerW = area.w - ((columns - 1) * gap)
  local baseW = math.floor(innerW / columns)
  local x = area.x
  for i = 1, columns do
    local cellW = (i == columns) and ((area.x + area.w) - x) or baseW
    cells[i] = rect(x, area.y, cellW, area.h)
    x = x + cellW + gap
  end
  return cells
end

function M.compute(layout)
  if not layout then return nil end
  local gap = layout.gap or 2
  local slots = { primary = {}, timers = {}, byId = {} }

  -- Row 1: 3 slots -> P1 LeftStick, P2 Battery, P3 RightStick
  local row1 = splitColumns(layout.cardRow1, 3, gap)
  slots.primary.P1 = withSlot("P1", "leftStick", row1[1])
  slots.primary.P2 = withSlot("P2", "battery", row1[2])
  slots.primary.P3 = withSlot("P3", "rightStick", row1[3])

  -- Row 2: 2 slots -> P4 Link, P5 Temps
  local row2 = splitColumns(layout.cardRow2, 2, gap)
  slots.primary.P4 = withSlot("P4", "link", row2[1])
  slots.primary.P5 = withSlot("P5", "temps", row2[2])

  -- Row 3: 2 slots -> P6 DroneGPS, P7 PilotGPS
  local row3 = splitColumns(layout.cardRow3, 2, gap)
  slots.primary.P6 = withSlot("P6", "droneGps", row3[1])
  slots.primary.P7 = withSlot("P7", "pilotGps", row3[2])

  local timersCols = splitColumns(layout.timersRow, 2, gap)
  slots.timers.T1 = withSlot("T1", "powerOn", timersCols[1])
  slots.timers.T2 = withSlot("T2", "flightTime", timersCols[2])

  for k, v in pairs(slots.primary) do slots.byId[k] = v end
  for k, v in pairs(slots.timers) do slots.byId[k] = v end

  return slots
end

return M
