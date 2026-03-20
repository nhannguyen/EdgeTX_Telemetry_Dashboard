-- Fixed layout for 800x480 (e.g. TX16S Mk3). Three card rows + timers.

local M = {}

local function rect(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local ZONE_W = 800
local ZONE_H = 480
local GAP = 2

local TOP_BAR_H    = 44
local TIMERS_H     = 36
-- Reserve space at the bottom so timers clear the EdgeTX simulator's
-- virtual-stick overlay (approx 40px). On real hardware this is empty space.
local BOTTOM_SLACK = 44
-- Horizontal margins to avoid the TX16S Mk3 left/right slider+trimmer chrome
-- (~46px per side covers both sliders and trimmers in the simulator).
local LEFT_MARGIN  = 46
local RIGHT_MARGIN = 46
-- 4 gaps: topBar→row1, row1→row2, row2→row3, row3→timers.
local FIXED_H = TOP_BAR_H + 4 * GAP + TIMERS_H + BOTTOM_SLACK

function M.compute(zone)
  if not zone then return nil end
  local x = zone.x or 0
  local y = zone.y or 0
  local w = zone.w or ZONE_W
  local h = zone.h or ZONE_H
  if w <= 0 or h <= 0 then return nil end

  -- Content area: inset from left/right to clear slider/trimmer chrome.
  local cx = x + LEFT_MARGIN
  local cw = math.max(0, w - LEFT_MARGIN - RIGHT_MARGIN)

  -- Card row height adapts to whatever zone height EdgeTX provides.
  local cardRowH = math.max(40, math.floor((h - FIXED_H) / 3))

  local topBarY = y
  local row1Y   = topBarY + TOP_BAR_H + GAP
  local row2Y   = row1Y + cardRowH + GAP
  local row3Y   = row2Y + cardRowH + GAP
  local timersY = row3Y + cardRowH + GAP

  return {
    zone      = rect(x,  y,        w,  h),
    gap       = GAP,
    topBar    = rect(cx, topBarY,  cw, TOP_BAR_H),
    cardRow1  = rect(cx, row1Y,    cw, cardRowH),
    cardRow2  = rect(cx, row2Y,    cw, cardRowH),
    cardRow3  = rect(cx, row3Y,    cw, cardRowH),
    timersRow = rect(cx, timersY,  cw, TIMERS_H),
  }
end

return M
