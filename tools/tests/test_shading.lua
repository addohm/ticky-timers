-- Health bar shading: it hangs from the health end and is as long as what your DoTs still have to
-- do (each one's tooltip total over its ticks, times the ticks not yet done). So anything that
-- moves the health moves the spark (other players' damage, healing on the mob), and each of your
-- ticks shrinks it by one tick, in the same draw as its health change, so the spark stays put.
-- Also: misses, refreshes, late last ticks, the end, per-spell segments, HoTs, unit frame
-- addons' bars, nameplates.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207) -- tooltip: 30 over 18 sec: 6 ticks of 5
ns.Track(2944, "Devouring Plague", 252997) -- tooltip: 152 over 24 sec: 8 ticks of 19
ns.Track(139, "Renew", 135953)             -- tooltip: heals 45 over 15 sec: 5 ticks of 9
db.overlayDamage, db.overlayHeal, db.locked = true, true, true
local function holderOn(bar)
  for _, f in ipairs(M.frames) do
    if f.tickyOwned and f.points[1] and f.points[1][2] == bar and f.points[2] then return f end
  end
end
local function shown(h, from, to)
  local out = {}
  for i = from, to do
    local c = h.children[i]
    if c and c.kind == "StatusBar" and c.shown then out[#out + 1] = c end
  end
  return out
end

M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
local start = M.now
M.cast(589, "S"); M.update(0.15); M.frame()
local h = holderOn(M.healthBar)
local mirror = h.children[1]
local seg = shown(h, 2, 9)[1]
check(seg and seg.value == 30, "SW:P on: the shading is its total, 30: " .. tostring(seg and seg.value))
check(seg.points[1][2] == mirror._fill and seg.points[1][3] == "TOPRIGHT", "pinned to the health end")
check(seg.reverse == true and seg.w == 126, "grows left from there, as wide as the bar")
check(type(seg.max) == "table", "scaled to the (secret) max health")
local top = h.children[#h.children]
local spark
for _, t in ipairs(top.children) do if t.texture and t.texture:find("Spark") and t.shown then spark = t end end
check(spark and spark.points[1][2] == seg._fill and spark.points[1][3] == "LEFT", "spark at the far end")

M.update(1.35)
M.cast(2944, "S"); M.update(0.15); M.frame()
check(seg.value == 30 + 152, "DP on: another 152")

-- Your tick: the shading shrinks by one tick in the same draw as the health end moves.
while M.now < start + 3 do M.update(0.05) end
local h0, s0 = mirror.value, seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32); M.fire("UNIT_HEALTH", "target")
check(mirror.value == h0 and seg.value == s0, "nothing moves inside the events")
M.frame()
check(mirror.value ~= h0 and seg.value == s0 - 5, "next frame: health end and shading together")
-- Someone else's hit: only the health end moves (so the spark moves with it).
M.update(0.4)
h0, s0 = mirror.value, seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 61, 1); M.fire("UNIT_HEALTH", "target"); M.frame()
check(mirror.value ~= h0 and seg.value == s0, "other damage: the health end moves, the shading doesn't")
-- Damage the game doesn't report at all, too.
h0 = mirror.value
M.fire("UNIT_HEALTH", "target"); M.frame()
check(mirror.value ~= h0 and seg.value == s0, "an unreported health change moves it as well")
-- An unseen tick (DP's at 4.5) counts half a second after its time.
while M.now < start + 4.9 do M.update(0.05) end
check(seg.value == s0, "DP's tick not seen yet: still there")
M.update(0.2)
check(seg.value == s0 - 19, "half a second after its time: counted: " .. tostring(seg.value))

-- Per-spell segments, in bar order.
db.overlayColors = "each"; M.update(0.15); M.frame()
local dmg = shown(h, 2, 9)
check(#dmg == 2 and dmg[1].value == 133 and dmg[2].value == 25, "per-spell segments (DP 133, SW:P 25): "
  .. tostring(dmg[1] and dmg[1].value) .. ", " .. tostring(dmg[2] and dmg[2].value))
check(dmg[2].points[1][2] == dmg[1]._fill and dmg[2].points[1][3] == "TOPLEFT", "second chained to the first's end")
db.overlayColors = "single"; M.update(0.15); M.frame()

-- A refresh that misses changes nothing; one that lands puts SW:P back at its full 30 (it had 3
-- of 6 ticks, 15, still to come at 9s).
while M.now < start + 9.05 do M.update(0.05) end
local before = seg.value
M.cast(589, "S"); M.update(0.1); M.fire("UNIT_COMBAT", "target", "MISS", "", 0, 1); M.update(0.1); M.frame()
check(seg.value == before, "a missed refresh: no change")
M.update(0.5)
local beforeRefresh = seg.value
M.cast(589, "S"); M.update(0.15); M.frame()
check(seg.value - beforeRefresh == 30 - 15, "a refresh halfway: SW:P's 15 still to come become 30: "
  .. tostring(beforeRefresh) .. " -> " .. tostring(seg.value))

-- Another mob has its own; back on the first, the same.
local first = seg.value
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(2944, "T"); M.update(0.15); M.frame()
check(seg.value == 152, "another mob: its own")
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.update(0.1); M.frame()
check(seg.value <= first and seg.value >= first - 19, "back on the first: the same (less any tick since)")

-- Devouring Plague's last tick, due at its expiry, lands 0.2s late (after Ticky ended it): still
-- its tick, taken off with its health change, not before.
while M.now < start + 1.5 + 24 + 0.2 do M.update(0.02) end
local beforeLast = seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 19, 32); M.fire("UNIT_HEALTH", "target")
check(seg.value == beforeLast, "the last tick's part is still there when it lands late")
M.frame()
check(seg.value == beforeLast - 19, "and goes with its health change: " .. tostring(seg.value))

-- It ends when the last spell does.
while M.now < start + 9.75 + 18 + 0.7 do M.update(0.1) end
check(not h.shown, "gone after the last one ends")

-- HoT on a friend: from the health end, growing right; damage on them moves only the health end.
M.units.target = { guid = "Player-2", name = "Friend", exists = true, canAssist = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(139, "Friend"); M.update(0.15); M.frame()
local heal = shown(h, 10, 17)
check(#heal == 1 and heal[1].value == 45 and heal[1].reverse == false, "Renew 45, growing right")
check(#shown(h, 2, 9) == 0, "no damage shading on a friend")
local hh = mirror.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 10, 1); M.fire("UNIT_HEALTH", "target"); M.frame()
check(heal[1].value == 45 and mirror.value ~= hh, "a hit on your friend moves the health end, not Renew's part")

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
