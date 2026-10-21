-- The shading's far end (the spark) holds still as DoT ticks land: the health end and the shading
-- are set in the same moment once the tick is counted (on a health message in a later frame than
-- the hit, or a moment after the hit), with routine redraws in between, and the bars' range isn't
-- touched on every redraw.
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
check(hp() ~= hA and seg.value == sA - 5, "health message: both ends move in the same moment")

-- A health message in the hit's own frame can carry the old health (seen in game): it doesn't
-- count the tick; the next one, a few frames later, does.
while M.now < 1000 + 5.98 do M.update(0.02) end
local hB, sB = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.fire("UNIT_HEALTH", "target")
check(hp() == hB and seg.value == sB, "same-frame health message: nothing moves")
for _ = 1, 3 do M.update(0.02) end
check(hp() == hB and seg.value == sB, "same-frame health message: still held a few frames on")
M.fire("UNIT_HEALTH", "target")
check(hp() ~= hB and seg.value == sB - 5, "next health message: both ends move in the same moment")
local tr = ns.TickTrace()
check(tr and tr.health and tr.health > tr.hit and tr.counted == tr.health,
  "trace: health and counting at the later health message")

-- Health message first, hit a few frames later, no health message after: held, then both move
-- together once the hit is PENDING_MAX old.
while M.now < 1000 + 8.94 do M.update(0.02) end
local hC, sC = hp(), seg.value
M.fire("UNIT_HEALTH", "target")
M.update(0.02); M.update(0.02)
check(hp() == hC and seg.value == sC, "health first: the health end waits for the hit")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.update(0.02); M.update(0.02)
check(hp() == hC and seg.value == sC, "health first: still held just after the hit")
for _ = 1, 15 do M.update(0.02) end
check(hp() ~= hC and seg.value == sC - 5, "health first: both ends move together after the wait")

-- A tick never seen: both release together when its grace runs out.
while M.now < 1000 + 11.98 do M.update(0.02) end
local hD, sD = hp(), seg.value
M.update(0.3)
check(hp() == hD and seg.value == sD, "unseen tick: still holding just after it was due")
for _ = 1, 20 do M.update(0.02) end
check(hp() ~= hD and seg.value == sD - 5, "unseen tick: both ends release together")

-- A tick landing 0.3s early: still held, then both move together on the next health message, and
-- the next tick is expected where this one really landed.
while M.now < 1000 + 14.68 do M.update(0.02) end
local hE, sE = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.fire("UNIT_HEALTH", "target")
M.update(0.02); M.update(0.02)
check(hp() == hE and seg.value == sE, "early tick: held")
M.fire("UNIT_HEALTH", "target")
check(hp() ~= hE and seg.value == sE - 5, "early tick: both ends move together")
tr = ns.TickTrace()
check(tr and tr.off < -0.2 and tr.counted and tr.drawn, "trace: early hit, counted and drawn")
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Last tick") then line = l end end
check(line and line:find("earlier"), "debug shows the last tick's timing: " .. tostring(line))

-- The range (0 to max health) isn't set again on ordinary redraws, only for a new mob or a change.
local setCount = 0
local realSet = mirror.SetMinMaxValues
mirror.SetMinMaxValues = function(self, a, b) setCount = setCount + 1; return realSet(self, a, b) end
for _ = 1, 10 do M.update(0.11) end
check(setCount == 0, "ordinary redraws leave the range alone: " .. setCount)
M.fire("UNIT_MAXHEALTH", "target"); M.update(0.11)
check(setCount == 1, "max health changed: set once: " .. setCount)
mirror.SetMinMaxValues = nil

-- A new target is drawn at once, health included.
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
local hF = hp()
M.cast(589, "T"); M.update(0.11); M.update(0.11)
check(hp() ~= hF, "new mob: its health is drawn straight away")
