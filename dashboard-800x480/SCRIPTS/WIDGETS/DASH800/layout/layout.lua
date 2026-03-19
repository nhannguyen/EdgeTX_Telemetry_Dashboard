-- Fixed layout for 800x480 (e.g. TX16S Mk3). Three card rows + timers.

local M = {}

local function rect(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local ZONE_W = 800
local ZONE_H = 480
local GAP = 2

local TOP_BAR_H = 44
local CARD_ROW_H = 126  -- 44 + 2 + 3*126 + 2*2 + 36 = 466 <= 480
local TIMERS_H = 36

function M.compute(zone)
  if not zone then return nil end
  local x = zone.x or 0
  local y = zone.y or 0
  local w = zone.w or ZONE_W
  local h = zone.h or ZONE_H
  if w <= 0 or h <= 0 then return nil end

  local topBarY = y
  local row1Y = topBarY + TOP_BAR_H + GAP
  local row2Y = row1Y + CARD_ROW_H + GAP
  local row3Y = row2Y + CARD_ROW_H + GAP
  local timersY = row3Y + CARD_ROW_H + GAP

  return {
    zone      = rect(x, y, w, h),
    gap       = GAP,
    topBar    = rect(x, topBarY, w, TOP_BAR_H),
    cardRow1  = rect(x, row1Y, w, CARD_ROW_H),
    cardRow2  = rect(x, row2Y, w, CARD_ROW_H),
    cardRow3  = rect(x, row3Y, w, CARD_ROW_H),
    timersRow = rect(x, timersY, w, TIMERS_H),
  }
end

return M
