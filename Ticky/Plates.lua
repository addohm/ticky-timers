-- Ticky nameplates: the same timer bars, smaller, on each mob's nameplate, for the tracked buffs
-- and debuffs Ticky knows are on that mob (from your casts, or read from its auras).
--
-- Each nameplate frame (WoW recycles them between mobs) gets a holder frame parented to it, so the
-- bars move, scale and hide with the plate. The bars themselves are Bars.lua's, drawn with a
-- nameplate style: the main settings with the Nameplates tab's size and text swapped in.
local ADDON, ns = ...

local ipairs, pairs, pcall = ipairs, pairs, pcall

local db
local holders = {} -- [nameplate frame] = { frame, bars, version, used }
local layoutVersion = 0
local scratch = {}

-- Nameplate settings that stand in for the main ones; everything else (colors, texture, ticks,
-- fonts, icon side) comes from the main bars.
local PLATE_KEYS = {
  width = "plateWidth", height = "plateHeight", spacing = "plateSpacing", showIcon = "plateShowIcon",
  fontSize = "plateFontSize", showName = "plateShowName", showTime = "plateShowTime",
  showTickCount = "plateShowTickCount",
}
local style = setmetatable({}, {
  __index = function(_, k)
    if k == "growUp" then return db.plateAnchor == "TOP" end -- stack away from the plate
    local pk = PLATE_KEYS[k]
    if pk then return db[pk] end
    return db[k]
  end,
})

function ns.LayoutPlates() layoutVersion = layoutVersion + 1 end

local function Holder(plate)
  local h = holders[plate]
  if not h then
    h = { frame = CreateFrame("Frame", nil, plate), bars = {} }
    holders[plate] = h
  end
  if h.version ~= layoutVersion then
    h.version = layoutVersion
    local f = h.frame
    f:SetSize(style.width + ns.IconSpace(style), style.height)
    f:ClearAllPoints()
    if db.plateAnchor == "TOP" then
      f:SetPoint("BOTTOM", plate, "TOP", db.plateOffsetX, db.plateOffsetY)
    else
      f:SetPoint("TOP", plate, "BOTTOM", db.plateOffsetX, -db.plateOffsetY)
    end
    -- Above the plate's own art (nameplate addons draw on top of Blizzard's plate frame).
    local ok, level = pcall(plate.GetFrameLevel, plate)
    if ok and level and not ns.Secret(level) then f:SetFrameLevel(level + 20) end
  end
  return h
end

local function HideAll()
  for _, h in pairs(holders) do
    if h.frame:IsShown() then h.frame:Hide() end
  end
end

function ns.UpdatePlates(now)
  if not db then return end
  if not db.plateEnabled or (db.hideOutOfCombat and not ns.InCombat())
    or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return HideAll()
  end
  local targetMob = ns.HasTarget() and ns.MobKey("target")
  for _, h in pairs(holders) do h.used = false end
  for unit in pairs(ns.plateUnits) do
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and type(plate) == "table" and not ns.Secret(plate) then
      local list, mob = ns.UnitTimers(unit, now, scratch)
      local wanted = mob and #list > 0
        and (db.plateWhich == "all" or (db.plateWhich == "target") == (mob == targetMob))
      if wanted then
        local h = Holder(plate)
        h.used = true
        for i, e in ipairs(list) do ns.UpdateBar(ns.GetBar(h.bars, i, style, h.frame), e, now, style) end
        for i = #list + 1, #h.bars do h.bars[i]:Hide() end
        if not h.frame:IsShown() then h.frame:Show() end
      end
    end
  end
  for _, h in pairs(holders) do
    if not h.used and h.frame:IsShown() then h.frame:Hide() end
  end
end

function ns.CreatePlates()
  db = ns.DB()
end
