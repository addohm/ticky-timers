-- Ticky nameplates: the same timer bars, smaller, on each mob's nameplate, for the tracked buffs
-- and debuffs Ticky knows are on that mob (from your casts, or read from its auras).
--
-- The bars always span the nameplate's health bar: a holder frame is parented to the plate and
-- anchored to both edges of that bar, and each plate's bars are laid out to the holder's width,
-- with the height a set share of it. The health bar is the largest visible status bar inside the
-- plate, which covers Blizzard's plates and nameplate addons that build theirs on top of them.
local ADDON, ns = ...

local ipairs, pairs, pcall, type, floor, max = ipairs, pairs, pcall, type, math.floor, math.max

local db
local holders = {} -- [nameplate frame] = { frame, bars, style, bar, width, version, used }
local layoutVersion = 0
local scratch = {}

local function Secret(v) return ns.Secret(v) end

-- Nameplate settings that stand in for the main ones; everything else (colors, texture, ticks,
-- fonts, icon side) comes from the main bars. Width and height are per plate (see Size).
local PLATE_KEYS = {
  spacing = "plateSpacing", showIcon = "plateShowIcon", fontSize = "plateFontSize",
  showName = "plateShowName", showTime = "plateShowTime", showTickCount = "plateShowTickCount",
}
-- With "Their own look" on, these come from the Nameplates tab too.
local PLATE_LOOK = {
  texture = "plateTexture", bgColor = "plateBgColor", bgAlpha = "plateBgAlpha",
  borderSize = "plateBorderSize", borderColor = "plateBorderColor", fillMode = "plateFillMode",
  spark = "plateSpark", tickColor = "plateTickColor", font = "plateFont", outline = "plateOutline",
}
local function PlateValue(k)
  if k == "growUp" then return db.plateAnchor == "TOP" end -- stack away from the plate
  local pk = PLATE_KEYS[k] or (db.plateOwnLook and PLATE_LOOK[k])
  if pk then return db[pk] end
  return db[k]
end

function ns.LayoutPlates() layoutVersion = layoutVersion + 1 end

---------------------------------------------------------------------------
-- Finding the nameplate's health bar
---------------------------------------------------------------------------

local function Visible(f)
  local ok, v = pcall(f.IsVisible, f)
  return ok and not Secret(v) and v == true
end

-- Our own frames (holders, overlays) are marked tickyOwned and left out of the search.

-- The plate's health bar, picked by name and size (Overlay.lua's ns.HealthBarIn).
local function LargestBar(plate) return ns.HealthBarIn(plate, 5) end

-- Is `frame` inside `plate`? Blizzard pools the frames inside nameplates (the health bar
-- included) and moves them between plates as mobs come and go, so a bar found on one plate can
-- later belong to another.
local function IsUnder(frame, plate)
  local f = frame
  for _ = 1, 8 do
    local ok, parent = pcall(f.GetParent, f)
    if not ok or parent == nil or Secret(parent) then return false end
    if parent == plate then return true end
    f = parent
  end
  return false
end

local searched = {} -- [plate] = { bar, at }: kept while the bar is still visible on this plate

-- The health bar the plate shows (nil: use the whole plate).
local function PlateBar(plate)
  local s = searched[plate]
  local now = GetTime()
  if s and s.bar and Visible(s.bar) and IsUnder(s.bar, plate) then return s.bar end
  if s and not s.bar and now - s.at < 1 then return end
  local ok, bar = pcall(LargestBar, plate)
  s = { bar = ok and bar or nil, at = now }
  searched[plate] = s
  return s.bar
end

-- For Overlay.lua: the plate's health bar, for the DoT/HoT shading on nameplates.
ns.PlateHealthBar = PlateBar

---------------------------------------------------------------------------
-- Holders
---------------------------------------------------------------------------

local function NewHolder()
  local h = { bars = {} }
  -- Per-plate style: the plate settings, with this plate's width and height.
  h.style = setmetatable({}, {
    __index = function(_, k)
      if k == "width" then return h.barWidth end
      if k == "height" then return h.barHeight end
      return PlateValue(k)
    end,
  })
  return h
end

-- Hang the holder on the plate across the health bar's full width.
local function Anchor(h, plate, bar)
  if not h.frame then
    h.frame = CreateFrame("Frame", nil, plate)
    h.frame.tickyOwned = true
  end
  local f, to = h.frame, bar or plate
  f:ClearAllPoints()
  if db.plateAnchor == "TOP" then
    f:SetPoint("BOTTOMLEFT", to, "TOPLEFT", 0, db.plateOffsetY)
    f:SetPoint("BOTTOMRIGHT", to, "TOPRIGHT", 0, db.plateOffsetY)
  else
    f:SetPoint("TOPLEFT", to, "BOTTOMLEFT", 0, -db.plateOffsetY)
    f:SetPoint("TOPRIGHT", to, "BOTTOMRIGHT", 0, -db.plateOffsetY)
  end
  -- Above the bar's art; a nameplate addon's bar may sit in a strata of its own.
  local ok, strata, level = pcall(function() return to:GetFrameStrata(), to:GetFrameLevel() end)
  if ok and not Secret(strata) and not Secret(level) and level then
    f:SetFrameStrata(strata)
    f:SetFrameLevel(level + 20)
  end
  h.bar, h.version, h.width = bar, layoutVersion, nil
end

-- The holder's width (it spans the health bar), and the bars' size from it. Returns false until
-- the width can be read.
local function Size(h)
  local ok, w = pcall(h.frame.GetWidth, h.frame)
  if not ok or Secret(w) or not w or w <= 1 then
    ok, w = pcall(h.bar and h.bar.GetWidth or h.frame.GetWidth, h.bar or h.frame)
    if not ok or Secret(w) or not w or w <= 1 then return false end
  end
  w = floor(w + 0.5)
  if w == h.width then return true end
  h.width = w
  local height = max(2, floor(w * db.plateHeightPct + 0.5))
  h.barHeight = height
  h.barWidth = max(10, w - ((db.plateShowIcon and (height + 2)) or 0))
  h.frame:SetHeight(height)
  for _, b in ipairs(h.bars) do b.version = nil end -- lay the bars out again at the new size
  return true
end

local function HideAll()
  for _, h in pairs(holders) do
    if h.frame and h.frame:IsShown() then h.frame:Hide() end
  end
end

function ns.UpdatePlates(now)
  if not db then return end
  if not db.plateEnabled or ns.PlatesHiddenHere() or (db.hideOutOfCombat and not ns.InCombat())
    or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return HideAll()
  end
  local targetMob = ns.HasTarget() and ns.MobKey("target")
  for _, h in pairs(holders) do h.used = false end
  for unit in pairs(ns.plateUnits) do
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and type(plate) == "table" and not Secret(plate) then
      local list, mob = ns.UnitTimers(unit, now, scratch)
      local wanted = mob and #list > 0
        and (db.plateWhich == "all" or (db.plateWhich == "target") == (mob == targetMob))
      if wanted then
        local h = holders[plate]
        if not h then
          h = NewHolder()
          holders[plate] = h
        end
        local bar = PlateBar(plate)
        if not h.frame or h.bar ~= bar or h.version ~= layoutVersion then Anchor(h, plate, bar) end
        if Size(h) then
          h.used = true
          for i, e in ipairs(list) do ns.UpdateBar(ns.GetBar(h.bars, i, h.style, h.frame), e, now, h.style) end
          for i = #list + 1, #h.bars do h.bars[i]:Hide() end
          if not h.frame:IsShown() then h.frame:Show() end
        end
      end
    end
  end
  for _, h in pairs(holders) do
    if not h.used and h.frame and h.frame:IsShown() then h.frame:Hide() end
  end
end

function ns.CreatePlates()
  db = ns.DB()
end
