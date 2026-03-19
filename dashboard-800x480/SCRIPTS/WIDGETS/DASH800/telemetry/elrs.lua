-- ELRS firmware version and device name via CRSF device-info (0x29).
-- Maps device name to antenna mode: Single 2.4, Single 900, Diversity 2.4, Diversity 900, Gemini Xrossband.

local M = {}

local function fieldGetString(data, off)
  local startOff = off
  while off <= #data and data[off] ~= 0 do
    data[off] = string.char(data[off])
    off = off + 1
  end
  return table.concat(data, nil, startOff, off - 1), off + 1
end

local function parseDeviceInfo(state, data)
  if not data or data[2] ~= 0xEE then return false end
  local name, off = fieldGetString(data, 3)
  state.name = (name and #name > 0) and name or "ELRS"
  local vMaj = data[off + 9]
  local vMin = data[off + 10]
  local vRev = data[off + 11]
  if type(vMaj) ~= "number" or type(vMin) ~= "number" or type(vRev) ~= "number" then
    state.vStr = state.name
    return true
  end
  state.vStr = string.format("%s %d.%d.%d", state.name, vMaj, vMin, vRev)
  return true
end

-- Map ELRS device name to antenna mode label.
function M.deviceNameToAntennaMode(name)
  if type(name) ~= "string" or #name == 0 then return nil end
  local n = name:lower()
  if n:find("gemini") then return "Gemini Xrossband" end
  if n:find("diversity") then
    if n:find("900") then return "Diversity 900" end
    return "Diversity 2.4"
  end
  if n:find("900") then return "Single 900" end
  return "Single 2.4"
end

function M.init()
  return { name = nil, vStr = nil, lastUpd = 0, done = false }
end

function M.update(state)
  if not state or state.done then return end
  if type(crossfireTelemetryPop) ~= "function" or type(crossfireTelemetryPush) ~= "function" then return end
  local command, data = crossfireTelemetryPop()
  if command == 0x29 then
    if parseDeviceInfo(state, data) then state.done = true end
    return
  end
  local now = getTime()
  if (state.lastUpd or 0) + 100 < now then
    crossfireTelemetryPush(0x28, { 0x00, 0xEA })
    state.lastUpd = now
  end
end

function M.getString(state)
  return (state and type(state.vStr) == "string" and #state.vStr > 0) and state.vStr or "ELRS"
end

function M.getDeviceName(state)
  return (state and type(state.name) == "string" and #state.name > 0) and state.name or nil
end

return M
