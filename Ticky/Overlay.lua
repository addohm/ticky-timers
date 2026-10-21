-- Ticky health bar overlay: on your target's health bar (and, if chosen, every nameplate's), the
-- part your DoTs will still take off (ending at the current health) and the part your HoTs will
-- still heal (starting there).
--
-- Target health is secret on Forever, so Lua can't work out where on the bar that is, but a
-- StatusBar can: Blizzard's API accepts secret values. Over the unit frame's health bar sits an
-- invisible "mirror" StatusBar of our own, fed the unit's (secret) health. Each spell gets a
-- StatusBar as wide as the health bar, scaled to the unit's max health and filled to that spell's
-- (plain) amount; the first is pinned to the end of the mirror's fill, each next one to the far end
-- of the previous one's fill. The mirror and the segments are all ours and change together (eased
-- the same way), so the far end, where the health should end up, holds still as ticks land,
-- whatever animation the unit frame's own bar has. A clipping frame cuts off what runs past.
local ADDON, ns = ...

local ipairs, pairs, pcall, type, floor = ipairs, pairs, pcall, type, math.floor

local db
local MAX_SEGMENTS = 8
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

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

-- A frame's path as the game names it ("SomeAddon_Target.Health"), or nil.
local function PathOf(f)
  local ok, name = pcall(f.GetDebugName, f, true)
  if ok and type(name) == "string" and not Secret(name) then return name end
end
ns.FramePath = PathOf

-- Unit frames hold more full-size status bars than the health bar: missing-health backgrounds,
-- absorb shields and incoming heals often fill from the other side. Names tell them apart.
local NOT_HEALTH = { "absorb", "shield", "loss", "missing", "predict", "incoming", "power", "mana",
  "energy", "rage", "cast", "background", "bg" }

local function Score(f)
  local name = (PathOf(f) or ""):lower()
  local last = name:match("([^%.]+)$") or name -- its own key, not its parents'
  for _, word in ipairs(NOT_HEALTH) do
    if last:find(word, 1, true) then return -1 end
  end
  if last:find("health", 1, true) or last == "hp" or last:find("hpbar", 1, true) then return 2 end
  return 1
end

-- The health bar inside a unit frame or nameplate: of the visible status bars inside `frame`, the
-- best-named one (see Score), then the largest. `depth` levels of child frames; frames we made
-- ourselves are skipped.
function ns.HealthBarIn(frame, depth)
  local best, bestScore, bestArea
  local function visit(f, d)
    if rawget(f, "tickyOwned") then return end
    if IsBar(f) and Visible(f) then
      local ok, w, h = pcall(function() return f:GetWidth(), f:GetHeight() end)
      if ok and not Secret(w) and not Secret(h) and w and h and w > 0 and h > 0 then
        local score, area = Score(f), w * h
        if not best or score > bestScore or (score == bestScore and area > bestArea) then
          best, bestScore, bestArea = f, score, area
        end
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
  if best and bestScore >= 0 then return best end
end
local LargestBar = ns.HealthBarIn

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
    -- Any frame will do: the shading only uses its area (health comes from the mirror bar).
    local f = Resolve(custom)
    if type(f) == "table" and type(f.GetWidth) == "function" then return f, custom end
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

-- The spark and outline of a chain, drawn on the overlay's top layer.
local function NewTrim(top)
  local t = { lines = {} }
  t.spark = top:CreateTexture(nil, "OVERLAY")
  t.spark:SetTexture(SPARK)
  t.spark:SetBlendMode("ADD")
  t.spark:Hide()
  for i = 1, 4 do
    t.lines[i] = top:CreateTexture(nil, "OVERLAY", nil, -1)
    t.lines[i]:Hide()
  end
  return t
end

-- An overlay: a clipping holder (child of `parent`) with a damage and a heal chain, and a layer
-- above them for the sparks and outlines.
local function NewOverlay(parent)
  local o = { layerAt = 0 }
  o.holder = CreateFrame("Frame", nil, parent)
  o.holder.tickyOwned = true -- not a health bar to anchor to (see Plates.lua's search)
  o.holder:SetClipsChildren(true)
  o.holder:Hide()
  o.mirror = CreateFrame("StatusBar", nil, o.holder)
  o.mirror:SetAllPoints(o.holder)
  o.mirror:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  o.mirror:SetStatusBarColor(0, 0, 0, 0)
  o.mirror:SetMinMaxValues(0, 1)
  o.damage = NewChain(o.holder)
  o.heal = NewChain(o.holder)
  o.top = CreateFrame("Frame", nil, o.holder)
  o.top:SetAllPoints(o.holder)
  o.damage.trim = NewTrim(o.top)
  o.heal.trim = NewTrim(o.top)
  return o
end

-- Lay a chain out from the health fill's `edge` side, growing left or right: bar 1 is pinned to
-- the edge, each next bar to the far end of the previous bar's fill.
local function LayChain(c, fill, edge, growLeft, width)
  local near = growLeft and "RIGHT" or "LEFT" -- the side of each bar that's pinned
  local far = growLeft and "LEFT" or "RIGHT"  -- the side its fill grows toward
  c.near, c.far, c.trimmed = near, far, nil
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
-- How much bigger the bar is drawn than the holder's parent: unit frame addons often scale their
-- frames. The holder takes the bar's scale, so the segment widths (in the bar's units) match it.
local function ScaleOf(o, bar)
  local ok, barScale, parentScale = pcall(function()
    return bar:GetEffectiveScale(), o.holder:GetParent():GetEffectiveScale()
  end)
  if ok and not Secret(barScale) and not Secret(parentScale) and barScale and parentScale and parentScale > 0 then
    return floor(barScale / parentScale * 1000 + 0.5) / 1000
  end
  return 1
end

local function Attach(o, bar)
  local ok, width = pcall(bar.GetWidth, bar)
  if not ok or Secret(width) or not width or width <= 0 then return false end
  local reverse = bar.GetReverseFill and bar:GetReverseFill()
  reverse = not Secret(reverse) and reverse == true
  local scale = ScaleOf(o, bar)
  if bar == o.bar and width == o.width and reverse == o.reverse and scale == o.scale then return true end
  o.bar, o.width, o.reverse, o.scale = bar, width, reverse, scale
  o.attaches = (o.attaches or 0) + 1
  o.holder:SetScale(scale)
  o.holder:ClearAllPoints()
  o.holder:SetAllPoints(bar)
  o.mirror:SetReverseFill(reverse)
  -- Health ends at the mirror's fill's right end (left end on a bar that fills from the right).
  -- Damage grows from there into the health, healing into the missing part.
  local fill = o.mirror:GetStatusBarTexture()
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
  o.top:SetFrameLevel(level + 10)
end

-- The spark where the shading ends (the health that should be left once your DoTs are done, or
-- the health your HoTs will bring) and an outline around it. Anchored only to our own bars.
local function Trim(c, count, height)
  local t = c.trim
  local last = count > 0 and c.segs[count].bar:GetStatusBarTexture()
  if count > 0 and c.trimmed ~= count then
    c.trimmed = count
    local first = c.segs[1].bar
    t.spark:ClearAllPoints()
    t.spark:SetPoint("CENTER", last, c.far)
    local l = t.lines
    for _, line in ipairs(l) do line:ClearAllPoints() end
    l[1]:SetPoint("TOP" .. c.far, last, "TOP" .. c.far)       -- top
    l[1]:SetPoint("TOP" .. c.near, first, "TOP" .. c.near)
    l[2]:SetPoint("BOTTOM" .. c.far, last, "BOTTOM" .. c.far) -- bottom
    l[2]:SetPoint("BOTTOM" .. c.near, first, "BOTTOM" .. c.near)
    l[3]:SetPoint("TOP" .. c.far, last, "TOP" .. c.far)       -- the far end
    l[3]:SetPoint("BOTTOM" .. c.far, last, "BOTTOM" .. c.far)
    l[4]:SetPoint("TOP" .. c.near, first, "TOP" .. c.near)    -- the health edge
    l[4]:SetPoint("BOTTOM" .. c.near, first, "BOTTOM" .. c.near)
  end
  local spark = count > 0 and db.overlaySpark
  if spark then
    local sc = db.overlaySparkColor
    t.spark:SetSize(12, height * 2)
    t.spark:SetVertexColor(sc[1], sc[2], sc[3], 1)
  end
  t.spark:SetShown(spark and true or false)
  local size = count > 0 and db.overlayOutline or 0
  local oc = db.overlayOutlineColor
  for i, line in ipairs(t.lines) do
    if size > 0 then
      line:SetColorTexture(oc[1], oc[2], oc[3], 1)
      if i <= 2 then line:SetHeight(size) else line:SetWidth(size) end
    end
    line:SetShown(size > 0)
  end
end

local function HideOverlay(o)
  if o and o.holder:IsShown() then o.holder:Hide() end
end

-- Show a chain's entries ({ amount, color }), one bar each (or one bar with the total). `smooth`:
-- ease toward the new values like a smooth health bar does, so the far end holds still.
local function Fill(c, entries, enabled, single, color, maxHealth, smooth, height)
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
      bar:SetValue(amount, smooth)
      bar:SetStatusBarTexture(tex)
      bar:SetStatusBarColor(col[1], col[2], col[3], alpha)
      seg.divider:SetShown(db.overlayDividers and not single and i < count)
      bar:Show()
    else
      bar:Hide()
    end
  end
  Trim(c, count, height)
  return count > 0
end

-- Draw what your DoTs and HoTs on `unit` will still do onto `bar` (its health bar).
local function Draw(o, bar, unit, now)
  local damage, heal = ns.UnitAmounts(unit, now)
  if not damage or (#damage == 0 and #heal == 0) or not Visible(bar) then return HideOverlay(o) end
  if not Attach(o, bar) then return HideOverlay(o) end
  Layer(o, now)
  local single = db.overlayColors == "single"
  -- Ease only while it's the same mob; a new one is drawn at once.
  local mob = ns.MobKey(unit)
  local interp = Enum.StatusBarInterpolation
  local smooth = interp and (db.overlaySmooth and mob == o.mob and interp.ExponentialEaseOut or interp.Immediate)
  o.mob = mob
  local hok, height = pcall(bar.GetHeight, bar)
  height = hok and not Secret(height) and height or 12
  local drawn = false
  local ok = pcall(function()
    local maxHealth = UnitHealthMax(unit)
    o.mirror:SetMinMaxValues(0, maxHealth)
    o.mirror:SetValue(UnitHealth(unit), smooth)
    drawn = Fill(o.damage, damage, db.overlayDamage, single, single and db.overlayDamageColor, maxHealth, smooth, height)
    drawn = Fill(o.heal, heal, db.overlayHeal, single, single and db.overlayHealColor, maxHealth, smooth, height)
      or drawn
  end)
  if not ok or not drawn then return HideOverlay(o) end
  o.holder:Show()
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------

local targetOverlay

-- For /ticky debug: how often the target shading had to be re-anchored (a count that keeps
-- climbing means the bar it follows keeps changing size), and the size it last used.
function ns.OverlayInfo()
  if targetOverlay then return targetOverlay.attaches or 0, targetOverlay.width, targetOverlay.scale end
end
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
