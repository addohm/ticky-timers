-- Health bar shading: one segment with the total by default, pinned to the mirror's fill end,
-- per-spell segments as an option, spark, scale, unit frame addons' bars, nameplates.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db, cdb = ns.DB(), ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(2944, "Devouring Plague", 252997)
ns.Track(139, "Renew", 135953)
db.overlayDamage, db.overlayHeal, db.locked = true, true, true
local function holderOn(bar)
  for _, f in ipairs(M.frames) do
    if f.tickyOwned and f.points[1] and f.points[1][2] == bar and f.points[2] then return f end
  end
end
local function shownSegs(h, from, to)
  local out = {}
  for i = from, to do
    local c = h.children[i]
    if c and c.kind == "StatusBar" and c.shown then out[#out + 1] = c end
  end
  return out
end

M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S"); M.update(1.5); M.cast(2944, "S"); M.update(0.15)
local h = holderOn(M.healthBar)
local mirror = h.children[1]
local dmg = shownSegs(h, 2, 9)
check(#dmg == 1 and dmg[1].value == 30 + 152, "one segment with both DoTs' total: " .. tostring(dmg[1] and dmg[1].value))
check(dmg[1].points[1][2] == mirror._fill and dmg[1].points[1][3] == "TOPRIGHT", "pinned to the mirror's fill end")
check(dmg[1].reverse == true and dmg[1].w == 126, "grows left from the health end, as wide as the bar")
check(type(dmg[1].max) == "table", "scaled to the (secret) max health")
local top = h.children[#h.children]
local spark
for _, t in ipairs(top.children) do if t.texture and t.texture:find("Spark") and t.shown then spark = t end end
check(spark and spark.points[1][2] == dmg[1]._fill and spark.points[1][3] == "LEFT", "spark at the far end")

db.overlayColors = "each"; M.update(0.15)
dmg = shownSegs(h, 2, 9)
check(#dmg == 2 and dmg[1].value == 152 and dmg[2].value == 30, "per-spell segments, in bar order (DP, SW:P)")
check(dmg[2].points[1][2] == dmg[1]._fill and dmg[2].points[1][3] == "TOPLEFT", "second chained to the first's end")
db.overlayColors = "single"

-- A tick seen with its health change teaches the tick size.
while M.now < 1000 + 3.0 do M.update(0.05) end
M.fire("UNIT_COMBAT", "target", "WOUND", "", 25, 32); M.fire("UNIT_HEALTH", "target")
check(cdb.tickSizes[589] == 25, "learned SW:P tick 25: " .. tostring(cdb.tickSizes[589]))
M.fire("UNIT_COMBAT", "target", "WOUND", "", 80, 1)
check(cdb.tickSizes[2944] == nil, "a Physical hit isn't taken for a Shadow tick")

-- HoT on a friend: green from the health end, growing right.
M.units.target = { guid = "Player-2", name = "Friend", exists = true, canAssist = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(139, "Friend"); M.update(0.15)
local heal = shownSegs(h, 10, 17)
check(#heal == 1 and heal[1].value == 45 and heal[1].reverse == false, "Renew 45 from the health end, growing right")
check(#shownSegs(h, 2, 9) == 0, "no damage shading on a friend")

-- A unit frame addon's target frame: its health bar, not a reversed missing-health bar.
local uf = CreateFrame("Button", "OtherUF_Target", UIParent)
uf:SetAttribute("unit", "target")
local loss = CreateFrame("StatusBar", nil, uf); loss:SetSize(200, 20); loss.debugName = "OtherUF_Target.HealthLoss"
local health = CreateFrame("StatusBar", nil, uf); health:SetSize(200, 20); health.debugName = "OtherUF_Target.Health"
local power = CreateFrame("StatusBar", nil, uf); power:SetSize(200, 8); power.debugName = "OtherUF_Target.Power"
uf:SetScale(1.25)
M.update(2.1)
check(ns.FindHealthBar() == health, "picks the bar named for health")
local h2 = holderOn(health)
check(h2 and h2.scale == 1.25, "shading takes the unit frame's scale: " .. tostring(h2 and h2.scale))
uf:Hide(); M.update(2.1)
check(ns.FindHealthBar() == M.healthBar, "back to Blizzard's when it's hidden")

-- Nameplates.
db.overlayPlates = true
local A = { guid = "Creature-A", name = "A", exists = true, canAttack = true, auras = {} }
M.units.nameplate1 = A
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
M.units.target = A; M.fire("PLAYER_TARGET_CHANGED"); M.cast(589, "A"); M.update(0.15)
local pA = M.plates.nameplate1
local oA = holderOn(pA.hb)
check(oA and oA.shown and oA.parent == pA, "nameplate shaded on its own health bar")
db.overlayDamage, db.overlayHeal = false, false; M.update(0.15)
check(not oA.shown and not h.shown, "off: hidden")
