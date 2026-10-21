-- Ticky health bar overlay: on your target's health bar, the part your DoTs will still take off
-- (ending at the current health) and the part your HoTs will still heal (starting there).
--
-- Target health is secret on Forever, so Lua can't work out where on the bar that is. StatusBars
-- can: each overlay bar is as wide as the health bar, anchored to the edge of its fill, scaled to
-- the target's (secret) max health and filled to our own (plain) amounts. A clipping frame over
-- the health bar cuts off anything past its ends. Same trick as Does It Die's damage marker.
local ADDON, ns = ...

local ipairs, floor = ipairs, math.floor

local db
local MAX_SEGMENTS = 8
local WHITE = "Interface\\Buttons\\WHITE8X8"

local holder        -- clips to the health bar
local groups = {}   -- damage and heal, each { area, segs }
local attached      -- the health bar we're anchored to
local attachedWidth, attachedReverse
local layerCheckedAt = 0

local function Secret(v) return ns.Secret(v) end

---------------------------------------------------------------------------
-- Finding the target frame's health bar
---------------------------------------------------------------------------

-- "GlobalName.key.key" to the frame it names, or nil.
local function Resolve(path)
  if type(path) ~= "string" then return end
  path = strtrim(path)
  if path == "" then return end
  local obj
  for part in path:gmatch("[^%.]+") do
    if obj == nil then obj = _G[part] else obj = type(obj) == "table" and obj[part] or nil end
    if type(obj) ~= "table" then return end
  end
  return obj
end

local function IsBar(f) return type(f) == "table" and type(f.GetStatusBarTexture) == "function" end

-- Paths tried in order after the player's own: EllesmereUI's target frame (only there while it
-- draws one), then Blizzard's (Forever's Mainline target frame), then the old global name.
local KNOWN = {
  { "EllesmereUIUnitFrames_Target.Health", "EllesmereUI's target frame" },
  { "TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar", "Blizzard's target frame" },
  { "TargetFrameHealthBar", "Blizzard's target frame" },
}

-- The health bar to draw on and a description of it.
function ns.FindHealthBar()
  local custom = db.overlayFrame
  if custom and custom ~= "" then
    local f = Resolve(custom)
    if IsBar(f) then return f, custom end
  end
  for _, k in ipairs(KNOWN) do
    local f = Resolve(k[1])
    if IsBar(f) then return f, k[2] end
  end
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

-- A group of running-total bars: segment i covers from bar i-1's fill end to bar i's, so each
-- spell gets its own share of the (secret) health scale, in its own color.
local function MakeGroup()
  local area = CreateFrame("Frame", nil, holder)
  local g = { area = area, segs = {} }
  for i = 1, MAX_SEGMENTS do
    local bar = CreateFrame("StatusBar", nil, area)
    bar:SetAllPoints(area)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    g.segs[i] = { bar = bar, fill = bar:GetStatusBarTexture() }
  end
  -- Painted on a layer above the (invisible) bars.
  g.paint = CreateFrame("Frame", nil, area)
  g.paint:SetAllPoints(area)
  for _, seg in ipairs(g.segs) do
    seg.tex = g.paint:CreateTexture(nil, "ARTWORK")
    seg.divider = g.paint:CreateTexture(nil, "OVERLAY")
    seg.divider:SetColorTexture(0, 0, 0, 0.8)
    seg.divider:SetWidth(1)
  end
  return g
end

-- Point the segments the right way: damage grows away from the health edge into the health,
-- healing grows away from it into the missing part.
local function LayoutGroup(g, growLeft)
  for i, seg in ipairs(g.segs) do
    seg.bar:SetReverseFill(growLeft)
    local prev = g.segs[i - 1]
    seg.tex:ClearAllPoints()
    seg.divider:ClearAllPoints()
    if growLeft then
      seg.tex:SetPoint("TOPRIGHT", prev and prev.fill or g.area, prev and "TOPLEFT" or "TOPRIGHT")
      seg.tex:SetPoint("BOTTOMLEFT", seg.fill, "BOTTOMLEFT")
      seg.divider:SetPoint("TOP", seg.fill, "TOPLEFT")
      seg.divider:SetPoint("BOTTOM", seg.fill, "BOTTOMLEFT")
    else
      seg.tex:SetPoint("TOPLEFT", prev and prev.fill or g.area, prev and "TOPRIGHT" or "TOPLEFT")
      seg.tex:SetPoint("BOTTOMRIGHT", seg.fill, "BOTTOMRIGHT")
      seg.divider:SetPoint("TOP", seg.fill, "TOPRIGHT")
      seg.divider:SetPoint("BOTTOM", seg.fill, "BOTTOMRIGHT")
    end
  end
end

local function Build()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetClipsChildren(true)
  holder:Hide()
  groups.damage = MakeGroup()
  groups.heal = MakeGroup()
end

-- Anchor to a health bar (again only when it, its width or its fill direction changed: the
-- target frame may be protected, so we avoid re-anchoring more than needed).
local function Attach(bar)
  local width = bar:GetWidth()
  if Secret(width) or not width or width <= 0 then return false end
  local reverse = bar.GetReverseFill and bar:GetReverseFill()
  reverse = not Secret(reverse) and reverse == true
  if bar == attached and width == attachedWidth and reverse == attachedReverse then return true end
  attached, attachedWidth, attachedReverse = bar, width, reverse
  local fill = bar:GetStatusBarTexture()
  holder:ClearAllPoints()
  holder:SetAllPoints(bar)
  -- The health edge is the fill's right end (its left end on a bar that fills from the right).
  local edge = reverse and "LEFT" or "RIGHT"
  local d, h = groups.damage.area, groups.heal.area
  d:ClearAllPoints()
  h:ClearAllPoints()
  if reverse then
    d:SetPoint("TOPLEFT", fill, "TOP" .. edge)
    d:SetPoint("BOTTOMLEFT", fill, "BOTTOM" .. edge)
    h:SetPoint("TOPRIGHT", fill, "TOP" .. edge)
    h:SetPoint("BOTTOMRIGHT", fill, "BOTTOM" .. edge)
  else
    d:SetPoint("TOPRIGHT", fill, "TOP" .. edge)
    d:SetPoint("BOTTOMRIGHT", fill, "BOTTOM" .. edge)
    h:SetPoint("TOPLEFT", fill, "TOP" .. edge)
    h:SetPoint("BOTTOMLEFT", fill, "BOTTOM" .. edge)
  end
  d:SetWidth(width)
  h:SetWidth(width)
  LayoutGroup(groups.damage, not reverse)
  LayoutGroup(groups.heal, reverse)
  layerCheckedAt = 0
  return true
end

-- Keep the overlay just above the health bar; frames can be re-layered at any time.
local function Layer(bar, now)
  if now - layerCheckedAt < 1 then return end
  layerCheckedAt = now
  local ok, strata, level = pcall(function() return bar:GetFrameStrata(), bar:GetFrameLevel() end)
  if not ok or Secret(strata) or Secret(level) or not level then return end
  holder:SetFrameStrata(strata)
  holder:SetFrameLevel(level + 5)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function Hide()
  if holder and holder:IsShown() then holder:Hide() end
end

-- Fill a group with its entries ({ amount, color }), scaled to the target's max health.
local function Fill(g, entries, enabled, single, maxHealth)
  local tex = ns.Lookup(ns.TEXTURES, db.overlayTexture)[2]
  local alpha = db.overlayAlpha
  local count = enabled and entries and #entries or 0
  local running, total = 0, 0
  for _, e in ipairs(entries or {}) do total = total + e.amount end
  for i, seg in ipairs(g.segs) do
    seg.bar:SetMinMaxValues(0, maxHealth)
    local e = (not single or i == 1) and i <= count and entries[i]
    if e then
      running = running + e.amount
      -- The last segment also covers any spells past the eighth.
      local value = (single or i == MAX_SEGMENTS) and total or running
      seg.bar:SetValue(value)
      local c = single and (g == groups.heal and db.overlayHealColor or db.overlayDamageColor) or e.color
      seg.tex:SetTexture(tex)
      seg.tex:SetVertexColor(c[1], c[2], c[3], alpha)
      seg.tex:Show()
      seg.divider:SetShown(db.overlayDividers and not single and i < count and i < MAX_SEGMENTS)
    else
      seg.bar:SetValue(total)
      seg.tex:Hide()
      seg.divider:Hide()
    end
  end
  g.area:SetShown(count > 0)
  return count > 0
end

function ns.UpdateOverlay(now)
  if not db then return end
  if not (db.overlayDamage or db.overlayHeal) then return Hide() end
  local damage, heal = ns.TargetAmounts(now)
  if not damage or (#damage == 0 and #heal == 0) then return Hide() end
  local bar = ns.FindHealthBar()
  if not bar then return Hide() end
  local ok, visible = pcall(bar.IsVisible, bar)
  if not ok or (not Secret(visible) and not visible) then return Hide() end
  if not holder then Build() end
  if not Attach(bar) then return Hide() end
  Layer(bar, now)
  local single = db.overlayColors == "single"
  local drawn = false
  ok = pcall(function()
    local maxHealth = UnitHealthMax("target")
    drawn = Fill(groups.damage, damage, db.overlayDamage, single, maxHealth)
    drawn = Fill(groups.heal, heal, db.overlayHeal, single, maxHealth) or drawn
  end)
  if not ok or not drawn then return Hide() end
  holder:Show()
end

function ns.CreateOverlay()
  db = ns.DB()
end
