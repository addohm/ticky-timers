-- Ticky health bar overlay: on your target's health bar (and, if chosen, every nameplate's), the
-- part your DoTs will still take off (ending at the current health) and the part your HoTs will
-- still heal (starting there).
--
-- Target health is secret on Forever, so Lua can't work out where on the bar that is, but a
-- StatusBar can: Blizzard's API accepts secret min/max values. Each spell gets a StatusBar as wide
-- as the health bar, scaled to the target's max health and filled to that spell's (plain) amount.
-- The first is pinned to the edge of the health fill; each next one is pinned to the far end of
-- the previous one's fill, so they chain away from the health edge. A clipping frame over the
-- health bar cuts off whatever runs past its ends.
local ADDON, ns = ...

local ipairs, pairs, pcall, type = ipairs, pairs, pcall, type

local db
local MAX_SEGMENTS = 8

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

local function Visible(f)
  local ok, v = pcall(f.IsVisible, f)
  return ok and not Secret(v) and v == true
end

-- The health bar of a unit frame: of the visible status bars inside it, the one with the most
-- area (health bars are at least as wide as power bars and usually taller).
local function LargestBar(frame, depth)
  local best, bestArea
  local function visit(f, d)
    if IsBar(f) and Visible(f) then
      local ok, w, h = pcall(function() return f:GetWidth(), f:GetHeight() end)
      if ok and not Secret(w) and not Secret(h) and w and h and w * h > (bestArea or 0) then
        best, bestArea = f, w * h
      end
    end
    if d < depth then
      local ok, kids = pcall(function() return { f:GetChildren() } end)
      if ok then
        for _, k in ipairs(kids) do visit(k, d + 1) end
      end
    end
  end
  visit(frame, 0)
  return best
end

-- Blizzard's target frame bar (from Forever's TargetFrame.xml).
local function BlizzardBar()
  return Resolve("TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar")
end

-- Another addon's target frame: a visible frame other than Blizzard's whose "unit" attribute is
-- "target" (unit frame addons build theirs on SecureUnitButtonTemplate). Searched at most every
-- two seconds, the answer kept while it stays visible.
local found, searchedAt = nil, -10
local function AddonBar(now)
  if found and Visible(found) then return found end
  if now - searchedAt < 2 then return end
  searchedAt = now
  found = nil
  local function visit(f, d)
    if found then return end
    if f ~= TargetFrame and type(f.GetAttribute) == "function" and Visible(f) then
      local ok, unit = pcall(f.GetAttribute, f, "unit")
      if ok and unit == "target" then
        found = LargestBar(f, 4)
        if found then return end
      end
    end
    if d < 3 then
      local ok, kids = pcall(function() return { f:GetChildren() } end)
      if ok then
        for _, k in ipairs(kids) do visit(k, d + 1) end
      end
    end
  end
  visit(UIParent, 0)
  return found
end

-- The health bar to draw on and a description of it.
function ns.FindHealthBar()
  local custom = db.overlayFrame
  if custom and custom ~= "" then
    local f = Resolve(custom)
    if IsBar(f) then return f, custom end
  end
  local addon = AddonBar(GetTime())
  if addon then return addon, "another addon's target frame" end
  local blizzard = BlizzardBar()
  if IsBar(blizzard) then return blizzard, "Blizzard's target frame" end
end

---------------------------------------------------------------------------
-- Overlays: one for the target frame's health bar, one per nameplate
---------------------------------------------------------------------------

local function NewChain(holder)
  local c = { segs = {} }
  for i = 1, MAX_SEGMENTS do
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    local divider = bar:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(0, 0, 0, 0.8)
    divider:SetWidth(1)
    c.segs[i] = { bar = bar, divider = divider }
  end
  return c
end

-- An overlay: a clipping holder (child of `parent`) with a damage and a heal chain.
local function NewOverlay(parent)
  local o = { layerAt = 0 }
  o.holder = CreateFrame("Frame", nil, parent)
  o.holder.tickyOwned = true -- not a health bar to anchor to (see Plates.lua's search)
  o.holder:SetClipsChildren(true)
  o.holder:Hide()
  o.damage = NewChain(o.holder)
  o.heal = NewChain(o.holder)
  return o
end

-- Lay a chain out from the health fill's `edge` side, growing left or right: bar 1 is pinned to
-- the edge, each next bar to the far end of the previous bar's fill.
local function LayChain(c, fill, edge, growLeft, width)
  local near = growLeft and "RIGHT" or "LEFT" -- the side of each bar that's pinned
  local far = growLeft and "LEFT" or "RIGHT"  -- the side its fill grows toward
  local prev
  for _, seg in ipairs(c.segs) do
    local bar = seg.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOP" .. near, prev or fill, "TOP" .. (prev and far or edge))
    bar:SetPoint("BOTTOM" .. near, prev or fill, "BOTTOM" .. (prev and far or edge))
    bar:SetWidth(width)
    bar:SetReverseFill(growLeft)
    local own = bar:GetStatusBarTexture()
    seg.divider:ClearAllPoints()
    seg.divider:SetPoint("TOP", own, "TOP" .. far)
    seg.divider:SetPoint("BOTTOM", own, "BOTTOM" .. far)
    prev = own
  end
end

-- Anchor to a health bar (again only when it, its width or its fill direction changed: the
-- target frame may be protected, so we avoid re-anchoring more than needed).
local function Attach(o, bar)
  local ok, width = pcall(bar.GetWidth, bar)
  if not ok or Secret(width) or not width or width <= 0 then return false end
  local reverse = bar.GetReverseFill and bar:GetReverseFill()
  reverse = not Secret(reverse) and reverse == true
  if bar == o.bar and width == o.width and reverse == o.reverse then return true end
  o.bar, o.width, o.reverse = bar, width, reverse
  o.holder:ClearAllPoints()
  o.holder:SetAllPoints(bar)
  -- Health ends at the fill's right end (left end on a bar that fills from the right). Damage
  -- grows from there into the health, healing into the missing part.
  local fill = bar:GetStatusBarTexture()
  local edge = reverse and "LEFT" or "RIGHT"
  LayChain(o.damage, fill, edge, not reverse, width)
  LayChain(o.heal, fill, edge, reverse, width)
  o.layerAt = 0
  return true
end

-- Keep the overlay just above the health bar; frames can be re-layered at any time.
local function Layer(o, now)
  if now - o.layerAt < 1 then return end
  o.layerAt = now
  local bar = o.bar
  local ok, strata, level = pcall(function() return bar:GetFrameStrata(), bar:GetFrameLevel() end)
  if not ok or Secret(strata) or Secret(level) or not level then return end
  o.holder:SetFrameStrata(strata)
  o.holder:SetFrameLevel(level + 5)
end

local function HideOverlay(o)
  if o and o.holder:IsShown() then o.holder:Hide() end
end

-- Show a chain's entries ({ amount, color }), one bar each (or one bar with the total).
local function Fill(c, entries, enabled, single, color, maxHealth)
  local tex = ns.Lookup(ns.TEXTURES, db.overlayTexture)[2]
  local alpha = db.overlayAlpha
  local count = enabled and #entries or 0
  if single and count > 0 then count = 1 end
  local total = 0
  for _, e in ipairs(entries) do total = total + e.amount end
  for i, seg in ipairs(c.segs) do
    local bar = seg.bar
    if i <= count then
      local col, amount = color or entries[i].color, entries[i].amount
      -- Single color, or spells past the last bar: the last shown bar carries the rest.
      if single then
        amount = total
      elseif i == MAX_SEGMENTS then
        for j = i + 1, #entries do amount = amount + entries[j].amount end
      end
      bar:SetMinMaxValues(0, maxHealth)
      bar:SetValue(amount)
      bar:SetStatusBarTexture(tex)
      bar:SetStatusBarColor(col[1], col[2], col[3], alpha)
      seg.divider:SetShown(db.overlayDividers and not single and i < count)
      bar:Show()
    else
      bar:Hide()
    end
  end
  return count > 0
end

-- Draw what your DoTs and HoTs on `unit` will still do onto `bar` (its health bar).
local function Draw(o, bar, unit, now)
  local damage, heal = ns.UnitAmounts(unit, now)
  if not damage or (#damage == 0 and #heal == 0) or not Visible(bar) then return HideOverlay(o) end
  if not Attach(o, bar) then return HideOverlay(o) end
  Layer(o, now)
  local single = db.overlayColors == "single"
  local drawn = false
  local ok = pcall(function()
    local maxHealth = UnitHealthMax(unit)
    drawn = Fill(o.damage, damage, db.overlayDamage, single, single and db.overlayDamageColor, maxHealth)
    drawn = Fill(o.heal, heal, db.overlayHeal, single, single and db.overlayHealColor, maxHealth) or drawn
  end)
  if not ok or not drawn then return HideOverlay(o) end
  o.holder:Show()
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------

local targetOverlay
local plateOverlays = {} -- [nameplate frame] = overlay, parented to the plate

local function UpdatePlateOverlays(now, on)
  local used = {}
  if on and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    for unit in pairs(ns.plateUnits) do
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
      local bar = ok and type(plate) == "table" and not Secret(plate) and ns.PlateHealthBar(plate)
      if bar then
        local o = plateOverlays[plate]
        if not o then
          o = NewOverlay(plate)
          plateOverlays[plate] = o
        end
        used[plate] = true
        Draw(o, bar, unit, now)
      end
    end
  end
  for plate, o in pairs(plateOverlays) do
    if not used[plate] then HideOverlay(o) end
  end
end

function ns.UpdateOverlay(now)
  if not db then return end
  local on = db.overlayDamage or db.overlayHeal
  UpdatePlateOverlays(now, on and db.overlayPlates)
  local bar = on and ns.HasTarget() and ns.FindHealthBar()
  if not bar then return HideOverlay(targetOverlay) end
  if not targetOverlay then targetOverlay = NewOverlay(UIParent) end
  Draw(targetOverlay, bar, "target", now)
end

function ns.CreateOverlay()
  db = ns.DB()
end
