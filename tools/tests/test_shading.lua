-- Health bar shading, the owner's model: when a DoT goes on, the spark goes at the mob's health at
-- that moment minus the DoT's total (its tooltip's amount); each further DoT moves it by its own
-- total; ticks and other hits don't move it; the shading is the part between the health now and
-- the spark. Also: misses, refreshes, the end, per-spell segments, HoTs, unit frame addons'
-- bars, nameplates.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db, cdb = ns.DB(), ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207) -- tooltip: 30 over 18 sec, 6 ticks
ns.Track(2944, "Devouring Plague", 252997) -- tooltip: 152 over 24 sec
ns.Track(139, "Renew", 135953)             -- tooltip: heals 45 over 15 sec
db.overlayDamage, db.overlayHeal, db.locked = true, true, true
local function holderOn(bar)
  for _, f in ipairs(M.frames) do
    if f.tickyOwned and f.points[1] and f.points[1][2] == bar and f.points[2] then return f end
  end
end
local function shown(parent)
  local out = {}
  for _, c in ipairs(parent.children) do
    if c.kind == "StatusBar" and c.shown then out[#out + 1] = c end
  end
  return out
end

M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
local start = M.now
M.cast(589, "S"); M.update(0.15); M.frame()
local h = holderOn(M.healthBar)
local mirror, frozen, dclip, hclip = h.children[1], h.children[2], h.children[3], h.children[4]
local seg = shown(dclip)[1]
check(seg and seg.value == 30, "SW:P on: the shading is its total, 30: " .. tostring(seg and seg.value))
check(seg.points[1][2] == frozen._fill and seg.points[1][3] == "TOPRIGHT", "pinned to the health when it went on")
check(seg.reverse == true and seg.w == 126, "grows left from there, as wide as the bar")
check(type(seg.max) == "table", "scaled to the (secret) max health")
check(dclip.points[2][2] == mirror._fill and dclip.points[2][3] == "BOTTOMRIGHT",
  "shown only up to the health now")
local frozenAt = frozen.value
check(type(frozenAt) == "table" and frozenAt.__secret, "the health at the cast (secret)")
local top = h.children[#h.children]
local spark
for _, t in ipairs(top.children) do if t.texture and t.texture:find("Spark") and t.shown then spark = t end end
check(spark and spark.points[1][2] == seg._fill and spark.points[1][3] == "LEFT", "spark at the far end")

M.update(1.35)
M.cast(2944, "S"); M.update(0.15); M.frame()
check(seg.value == 30 + 152 and frozen.value == frozenAt, "DP on: the spark moves another 152, from the same health")

-- Ticks, other hits and health changes move only the health end.
local sets = 0
for _, f in ipairs({ seg, frozen }) do
  local real = f.SetValue
  f.SetValue = function(...) sets = sets + 1; return real(...) end
end
local h0 = mirror.value
for k = 1, 2 do
  while M.now < start + 3 * k do M.update(0.05) end
  M.fire("UNIT_COMBAT", "target", "WOUND", "", 25, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
  M.update(0.4)
  M.fire("UNIT_COMBAT", "target", "WOUND", "", 61, 1); M.fire("UNIT_HEALTH", "target"); M.frame() -- someone else
end
check(sets == 0 and seg.value == 182 and frozen.value == frozenAt, "ticks and other hits don't move the spark: "
  .. sets .. " sets")
check(mirror.value ~= h0, "the health end follows the health")
seg.SetValue, frozen.SetValue = nil, nil
check(cdb.tickSizes[589] == 25, "tick sizes are still learned (for /ticky debug): " .. tostring(cdb.tickSizes[589]))

-- Per-spell segments, in bar order.
db.overlayColors = "each"; M.update(0.15); M.frame()
local dmg = shown(dclip)
check(#dmg == 2 and dmg[1].value == 152 and dmg[2].value == 30, "per-spell segments (DP, SW:P)")
check(dmg[2].points[1][2] == dmg[1]._fill and dmg[2].points[1][3] == "TOPLEFT", "second chained to the first's end")
db.overlayColors = "single"; M.update(0.15); M.frame()

-- A refresh that misses takes its amount back; one that lands adds its total less what the old
-- one still had to do (SW:P recast at 9s of 18: half its ticks to come, 15 of 30).
while M.now < start + 9.05 do M.update(0.05) end
M.cast(589, "S"); M.update(0.1); M.fire("UNIT_COMBAT", "target", "MISS", "", 0, 1); M.update(0.1); M.frame()
check(seg.value == 182, "a missed refresh: no change: " .. tostring(seg.value))
M.update(0.5)
M.cast(589, "S"); M.update(0.15); M.frame()
check(math.abs(seg.value - (182 + 15)) < 0.01, "a refresh halfway: +15: " .. tostring(seg.value))
M.printed = {}
SlashCmdList.TICKY("log")
check((M.printed[1] or ""):find("SWP missed: spark back 15") and (M.printed[1] or ""):find("SWP on: spark %-15"),
  "/ticky log shows it: " .. tostring(M.printed[1]))

-- Another mob has its own plan; back on the first, its spark is where it was.
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(2944, "T"); M.update(0.15); M.frame()
check(seg.value == 152 and frozen.value ~= frozenAt, "another mob: its own spark")
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.update(0.15); M.frame()
check(math.abs(seg.value - 197) < 0.01 and frozen.value == frozenAt, "back on the first: the same spark")

-- It ends a moment after the last spell does.
while M.now < start + 1.5 + 24 + 0.3 do M.update(0.1) end -- DP ends at 25.5; SW:P (recast) at 27.7
check(h.shown, "still up while one is left")
while M.now < start + 9.75 + 18 + 0.7 do M.update(0.1) end
check(not h.shown, "gone after the last one ends")

-- HoT on a friend: from the health when it went on, growing right, shown beyond the health now.
M.units.target = { guid = "Player-2", name = "Friend", exists = true, canAssist = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(139, "Friend"); M.update(0.15); M.frame()
local heal = shown(hclip)
check(#heal == 1 and heal[1].value == 45 and heal[1].reverse == false, "Renew 45, growing right")
check(hclip.points[1][2] == mirror._fill and hclip.points[1][3] == "TOPRIGHT", "shown from the health now on")
check(#shown(dclip) == 0, "no damage shading on a friend")

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
M.units.target = A; M.fire("PLAYER_TARGET_CHANGED"); M.cast(589, "A"); M.update(0.15); M.frame()
local pA = M.plates.nameplate1
local oA = holderOn(pA.hb)
check(oA and oA.shown and oA.parent == pA, "nameplate shaded on its own health bar")
db.overlayDamage, db.overlayHeal = false, false; M.update(0.15); M.frame()
check(not oA.shown and not h.shown, "off: hidden")
