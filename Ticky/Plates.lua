-- Ticky nameplates: the same timer bars, smaller, on each mob's nameplate, for the tracked buffs
-- and debuffs Ticky knows are on that mob (from your casts, or read from its auras).
--
-- The bars always span the nameplate's health bar: a holder frame is anchored to both of its
-- edges, and each plate's bars are laid out to the holder's width, with the height a set share
-- of it. The holder is parented to the plate (or to EllesmereUI's own plate frame), so the bars
-- move, scale, fade and hide with it. Finding the health bar follows Does It Die (MIT): EllesmereUI's
-- plate, then Blizzard's bar, then a search of other nameplate addons' frames for a "health" bar.
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
local function PlateValue(k)
  if k == "growUp" then return db.plateAnchor == "TOP" end -- stack away from the plate
  local pk = PLATE_KEYS[k]
  if pk then return db[pk] end
  return db[k]
end

function ns.LayoutPlates() layoutVersion = layoutVersion + 1 end

---------------------------------------------------------------------------
-- Finding the nameplate's health bar
---------------------------------------------------------------------------

local function Get(t, k)
  local ok, v = pcall(function() return t[k] end)
  if ok and type(v) == "table" and not Secret(v) then return v end
end

local function IsBar(f) return type(f) == "table" and type(f.GetStatusBarTexture) == "function" end

local function Shown(f)
  local ok, v = pcall(f.IsShown, f)
  return ok and not Secret(v) and v == true
end

local function IsUnder(frame, plate)
  local current = frame
  for _ = 1, 12 do
    local ok, parent = pcall(current.GetParent, current)
    if not ok or parent == nil then return false end
    if parent == plate then return true end
    current = parent
  end
  return false
end

-- Other nameplate addons (Plater, KUI, ...) hang their frames on the plate and keep the bar under a
-- key like "health". Breadth-first, a few levels deep, Blizzard's own UnitFrame skipped.
local function SearchBar(plate)
  local queue, seen, head = { plate }, { [plate] = true }, 1
  local depth = { [plate] = 0 }
  local unitFrame = Get(plate, "UnitFrame")
  while queue[head] do
    local frame = queue[head]
    head = head + 1
    local ok, fields = pcall(function()
      local out = {}
      for k, v in pairs(frame) do
        if type(k) == "string" and type(v) == "table" then out[#out + 1] = { k, v } end
      end
      return out
    end)
    if ok then
      table.sort(fields, function(a, b) return a[1] < b[1] end)
      for _, f in ipairs(fields) do
        if f[1]:lower():find("health", 1, true) and IsBar(f[2]) and IsUnder(f[2], plate) and Shown(f[2]) then
          return f[2]
        end
      end
      if depth[frame] < 3 then
        for _, f in ipairs(fields) do
          local v = f[2]
          if not seen[v] and v ~= unitFrame and type(v.GetObjectType) == "function" and not IsBar(v)
            and IsUnder(v, plate) then
            seen[v] = true
            depth[v] = depth[frame] + 1
            queue[#queue + 1] = v
          end
        end
      end
    end
  end
end

local searched = {} -- [plate] = { bar, at }: the search is slow, so its answer is kept a while

-- The health bar the plate shows and the frame our bars should hang from.
local function PlateBar(plate, unit)
  local eui = type(EllesmereNameplates_NS) == "table" and Get(EllesmereNameplates_NS, "plates")
  local euiPlate = eui and Get(eui, unit)
  if euiPlate and Get(euiPlate, "nameplate") == plate and IsBar(Get(euiPlate, "health")) then
    return euiPlate.health, euiPlate
  end
  local uf = Get(plate, "UnitFrame")
  local blizzard = uf and ((Get(uf, "HealthBarsContainer") and Get(uf.HealthBarsContainer, "healthBar"))
    or Get(uf, "healthBar") or Get(uf, "HealthBar"))
  if IsBar(blizzard) and Shown(blizzard) then return blizzard, plate end
  local s = searched[plate]
  local now = GetTime()
  if not (s and (s.bar and Shown(s.bar) or now - s.at < 1)) then
    local ok, found = pcall(SearchBar, plate)
    s = { bar = ok and found or nil, at = now }
    searched[plate] = s
  end
  if s.bar then return s.bar, plate end
  return nil, plate
end

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

-- Hang the holder on the plate (or EllesmereUI's plate) across the health bar's full width.
local function Anchor(h, host, bar, plate)
  if h.host ~= host then
    h.host = host
    if not h.frame then h.frame = CreateFrame("Frame", nil, host) else h.frame:SetParent(host) end
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
  -- Above the plate's art; a plate addon's bar may sit in a strata of its own.
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
  if not db.plateEnabled or (db.hideOutOfCombat and not ns.InCombat())
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
        local bar, host = PlateBar(plate, unit)
        if h.host ~= host or h.bar ~= bar or h.version ~= layoutVersion then Anchor(h, host, bar, plate) end
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
