-- The shading's far end (the spark) holds still as DoT ticks land: the health end moves once the
-- tick is counted (whichever of the hit and the health message comes first, with routine redraws in
-- between), and the shading follows on the very next frame, when its position has caught up.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207)
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S")
M.update(0.15); M.frame()
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar then holder = f end end
check(holder ~= nil, "target overlay exists")
local mirror, seg = holder.children[1], holder.children[2]
local function hp() return mirror.value and mirror.value.n end

local h0 = hp(); M.update(0.11); M.update(0.11)
check(hp() ~= h0, "between ticks the health end follows health on every redraw")

-- Hit first, health message a few frames later.
while M.now < 1000 + 2.96 do M.update(0.02) end
local hA, sA = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
for _ = 1, 4 do M.update(0.02) end
check(hp() == hA and seg.value == sA, "after the hit, neither end moves before the health message")
M.fire("UNIT_HEALTH", "target")
local hA2 = hp()
check(hA2 ~= hA and seg.value == sA, "health message: the health end moves, the shading waits a frame")
M.frame()
check(seg.value == sA - 5 and hp() == hA2, "next frame: the shading follows, the health end stays")

-- Health message first, hit a few frames later.
while M.now < 1000 + 5.98 do M.update(0.02) end
local hB, sB = hp(), seg.value
M.fire("UNIT_HEALTH", "target")
M.update(0.02); M.update(0.02)
check(hp() == hB and seg.value == sB, "health first: the health end waits for the hit")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
check(hp() ~= hB and seg.value == sB, "hit arrives: the health end moves")
M.frame()
check(seg.value == sB - 5, "next frame: the shading follows")

-- A tick never seen: both release together when its grace runs out.
while M.now < 1000 + 8.98 do M.update(0.02) end
local hC, sC = hp(), seg.value
M.update(0.1)
check(hp() == hC and seg.value == sC, "unseen tick: still holding just after it was due")
for _ = 1, 12 do M.update(0.02) end
M.frame()
check(hp() ~= hC and seg.value == sC - 5, "unseen tick: both ends release (a frame apart)")

-- A new target is drawn at once, health included.
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
local hD = hp()
M.cast(589, "T"); M.update(0.11); M.update(0.11)
check(hp() ~= hD, "new mob: its health is drawn straight away")
