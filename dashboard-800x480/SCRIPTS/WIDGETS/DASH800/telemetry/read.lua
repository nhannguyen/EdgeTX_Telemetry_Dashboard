-- Telemetry read and normalization for 800x480 dashboard.
-- Single snapshot per frame; when disconnected retains last values and sets linkLost.

local M = {}

local EMPTY_TEXT = "--"

local SOURCE_ID_CACHE = {}
local RESCAN_INTERVAL = 90
local frameCount = 0

local FIELD_SENSORS = {
  battery       = { "VFAS", "RxBt", "Bat", "BATT", "A4" },
  rssi          = { "1RSS", "2RSS", "TRSS" },
  linkQuality   = { "RQly", "LQ", "TQly" },
  packetRate    = { "RFMD" },
  current       = { "Curr", "CUR" },
  satellites    = { "Sats", "SATS", "SAT" },
  txPower       = { "TPWR", "TxPw" },
  flightMode    = { "FM", "FMODE" },
  rssi1         = { "1RSS" },
  rssi2         = { "2RSS" },
  capacity      = { "Capa", "CAP" },
  activeAntenna = { "ANT" },
  remaining     = { "Remaining", "Fuel", "Rema" },
  rsnr          = { "RSNR", "SNR" },
  armState      = { "Arm", "ARM", "Tmp1" },
  pilotSats     = { "RxSats", "PilotSats", "Pilot Sats" },
  tempFC        = { "T1", "Temp", "FC Temp", "FC" },
  tempESC       = { "T2", "ESC", "ESC Temp" },
  tempVTX       = { "T3", "VTX", "VTX Temp" },
  tempMotor     = { "T4", "Motor", "Motors", "M1", "M2" },
}

local PACKET_RATE_FROM_RFMD = {
  [1] = 25, [2] = 50, [3] = 100, [4] = 150, [5] = 250, [6] = 500, [7] = 1000,
  [8] = 333, [9] = 500, [10] = 50, [11] = 100, [12] = 150, [13] = 200,
  [14] = 250, [15] = 333, [16] = 500, [25] = 50, [26] = 100, [27] = 150,
  [28] = 250, [29] = 500, [30] = 250, [31] = 500, [32] = 500,
}

local snapshot = {
  battery = 0,
  rssi = 0,
  linkQuality = 0,
  packetRate = 0,
  current = 0,
  satellites = 0,
  sats = 0,
  txPower = 0,
  flightMode = EMPTY_TEXT,
  rssi1 = 0,
  rssi2 = 0,
  capacity = 0,
  activeAntenna = 0,
  remaining = nil,
  rsnr = nil,
  armState = EMPTY_TEXT,
  pilotSats = nil,
  gpsLat = nil,
  gpsLon = nil,
  pilotLat = nil,
  pilotLon = nil,
  tempFC = nil,
  tempESC = nil,
  tempVTX = nil,
  tempMotor = nil,
  droneName = nil,
  antennaMode = nil,
  connected = false,
  linkLost = false,
  available = {
    battery = false, rssi = false, linkQuality = false, packetRate = false,
    current = false, satellites = false, sats = false, txPower = false,
    flightMode = false, rssi1 = false, rssi2 = false, capacity = false,
    activeAntenna = false, remaining = false, rsnr = false, armState = false,
    pilotSats = false, gpsPosition = false, pilotPosition = false,
    tempFC = false, tempESC = false, tempVTX = false, tempMotor = false,
    droneName = false, antennaMode = false,
  },
}

local function validValue(v)
  if v == nil or v == "" then return false end
  return true
end

local function clearNegativeCache()
  for k, v in pairs(SOURCE_ID_CACHE) do
    if v == false then SOURCE_ID_CACHE[k] = nil end
  end
end

local function resolveId(name)
  local cached = SOURCE_ID_CACHE[name]
  if cached ~= nil then return cached end
  if getFieldInfo then
    local info = getFieldInfo(name)
    if info and info.id then
      SOURCE_ID_CACHE[name] = info.id
      return info.id
    end
  end
  SOURCE_ID_CACHE[name] = false
  return false
end

local function readFirst(names)
  if not getValue then return nil end
  for i = 1, #names do
    local id = resolveId(names[i])
    if id ~= false then
      local value = getValue(id)
      if validValue(value) then return value end
    end
  end
  return nil
end

local function toNumber(v)
  if type(v) == "number" then return v end
  if type(v) == "table" then
    if type(v.value) == "number" then return v.value end
    if type(v.val) == "number" then return v.val end
  end
  if type(v) == "string" then
    local n = tonumber(string.match(v, "%-?%d+%.?%d*"))
    if n then return n end
  end
  return nil
end

local function resolvePacketRateFromRfmd(rfmd)
  if rfmd == nil or rfmd == 0 then return nil end
  return PACKET_RATE_FROM_RFMD[rfmd]
end

local function normalizePacketRate(raw)
  local n = toNumber(raw)
  return n and resolvePacketRateFromRfmd(n) or nil
end

local function normalizeFlightMode(raw)
  if type(raw) == "string" and raw ~= "" then return raw end
  if getFlightMode then
    local mode = getFlightMode()
    if type(mode) == "string" and mode ~= "" then return mode end
  end
  return nil
end

local function normalizeArmState(raw)
  if type(raw) == "string" and raw ~= "" then
    local s = string.lower(raw)
    if string.find(s, "arm") and not string.find(s, "dis") and not string.find(s, "pre") then
      return "ARMED"
    end
    if string.find(s, "pre") then return "PREARMED" end
    if string.find(s, "dis") or string.find(s, "0") then return "DISARMED" end
    return raw
  end
  local n = toNumber(raw)
  if n and n ~= 0 then return "ARMED" end
  if n == 0 then return "DISARMED" end
  return nil
end

local function assignNumeric(field, normalizer)
  local raw = readFirst(FIELD_SENSORS[field])
  local value = normalizer and normalizer(raw) or toNumber(raw)
  if value == nil then
    snapshot[field] = 0
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

local function assignText(field, normalizer)
  local raw = readFirst(FIELD_SENSORS[field])
  local value = normalizer and normalizer(raw) or (type(raw) == "string" and raw)
  if value == nil then
    snapshot[field] = EMPTY_TEXT
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

local function assignOptionalNumeric(field, normalizer)
  local raw = readFirst(FIELD_SENSORS[field])
  local value = normalizer and normalizer(raw) or toNumber(raw)
  if value == nil then
    snapshot[field] = nil
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

local function readConnectionOnly()
  local lq = readFirst(FIELD_SENSORS.linkQuality)
  local lqN = toNumber(lq)
  local hasLQ = lqN and lqN > 0
  local tpwr = readFirst(FIELD_SENSORS.txPower)
  local tpwrN = toNumber(tpwr)
  local hasTxPower = tpwrN and tpwrN > 0
  local rfmd = readFirst(FIELD_SENSORS.packetRate)
  local rate = rfmd and resolvePacketRateFromRfmd(toNumber(rfmd))
  local hasPacketRate = rate and rate > 0
  return hasLQ or hasTxPower or hasPacketRate
end

local function readGpsAndPilot()
  if not getValue then return end
  local gps = getValue("GPS")
  if type(gps) ~= "table" then
    snapshot.available.gpsPosition = false
    snapshot.available.pilotPosition = false
    return
  end
  if type(gps.lat) == "number" and type(gps.lon) == "number" then
    snapshot.gpsLat = gps.lat
    snapshot.gpsLon = gps.lon
    snapshot.available.gpsPosition = true
  else
    snapshot.available.gpsPosition = false
  end
  local plat = gps["pilot-lat"]
  local plon = gps["pilot-lon"]
  if type(plat) == "number" and type(plon) == "number" then
    snapshot.pilotLat = plat
    snapshot.pilotLon = plon
    snapshot.available.pilotPosition = true
  else
    snapshot.available.pilotPosition = false
  end
end

function M.snapshot()
  frameCount = frameCount + 1
  if frameCount >= RESCAN_INTERVAL then
    frameCount = 0
    clearNegativeCache()
  end

  local connected = readConnectionOnly()
  snapshot.connected = connected
  snapshot.linkLost = not connected

  if not connected then
    return snapshot
  end

  assignNumeric("battery")
  assignNumeric("rssi")
  assignNumeric("linkQuality")
  assignNumeric("packetRate", normalizePacketRate)
  assignNumeric("current")
  assignNumeric("satellites")
  snapshot.sats = snapshot.satellites
  snapshot.available.sats = snapshot.available.satellites
  assignNumeric("txPower")
  assignText("flightMode", normalizeFlightMode)
  assignNumeric("rssi1")
  assignNumeric("rssi2")
  assignNumeric("capacity")
  assignNumeric("activeAntenna")
  assignOptionalNumeric("remaining")
  assignOptionalNumeric("rsnr")
  assignText("armState", normalizeArmState)
  assignOptionalNumeric("pilotSats")
  assignOptionalNumeric("tempFC")
  assignOptionalNumeric("tempESC")
  assignOptionalNumeric("tempVTX")
  assignOptionalNumeric("tempMotor")

  readGpsAndPilot()

  if not snapshot.available.packetRate then
    snapshot.packetRate = 0
  end

  return snapshot
end

function M.setDroneName(name)
  if type(name) == "string" and #name > 0 then
    snapshot.droneName = name
    snapshot.available.droneName = true
  else
    snapshot.droneName = nil
    snapshot.available.droneName = false
  end
end

function M.setAntennaMode(mode)
  if type(mode) == "string" and #mode > 0 then
    snapshot.antennaMode = mode
    snapshot.available.antennaMode = true
  else
    snapshot.antennaMode = nil
    snapshot.available.antennaMode = false
  end
end

return M
