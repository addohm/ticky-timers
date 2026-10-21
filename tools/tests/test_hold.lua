-- The shading's far end (the spark) holds still as DoT ticks land: the health end and the shading
-- are set in the same moment once the tick is counted (on its health message, or a moment after the
-- hit), drawn in the next frame update, and the bars' values, range, texture, color and layer are
-- set only when they change (re-setting them seems to end or restart their easing).
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

-- Between ticks the health end follows health messages (in the next frame), and plain redraws
-- set neither value again.
local sets = 0
for _, f in ipairs({ mirror, seg }) do
  local real = f.SetValue
  f.SetValue = function(...) sets = sets + 1; return real(...) end
end
M.update(0.11); M.update(0.11)
check(sets == 0, "plain redraws set neither value again: " .. sets)
local h0 = hp()
M.fire("UNIT_HEALTH", "target")
check(hp() == h0, "a health message is drawn in the next frame, not inside the event")
M.frame()
check(hp() ~= h0 and sets == 1, "next frame: the health end follows it (" .. sets .. " set)")
mirror.SetValue, seg.SetValue = nil, nil

-- Hit first, health message a few frames later.
while M.now < 1000 + 2.96 do M.update(0.02) end
local hA, sA = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
for _ = 1, 4 do M.update(0.02) end
check(hp() == hA and seg.value == sA, "after the hit, neither end moves before the health message")
M.fire("UNIT_HEALTH", "target"); M.frame()
check(hp() ~= hA and seg.value == sA - 5, "health message: both ends move in the same moment")

-- Hit and health message in the same frame (what the game does), either order: both ends move
-- at once, and nothing else is set on the bars that could cut their easing short.
local calls = {}
local function Count(f, name)
  local real = f[name]
  f[name] = function(...) calls[#calls + 1] = name; return real(...) end
end
for _, f in ipairs({ seg, mirror }) do
  Count(f, "SetStatusBarTexture"); Count(f, "SetStatusBarColor"); Count(f, "SetMinMaxValues")
end
Count(holder, "SetFrameLevel"); Count(holder, "SetFrameStrata")
while M.now < 1000 + 5.98 do M.update(0.02) end
local hB, sB = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.fire("UNIT_HEALTH", "target"); M.frame()
check(hp() ~= hB and seg.value == sB - 5, "hit, then health in the same frame: both move at once")
local tr = ns.TickTrace()
check(tr and tr.health == tr.hit and tr.counted == tr.hit, "trace: health and counting in the hit's frame")
while M.now < 1000 + 8.98 do M.update(0.02) end -- the next tick, seen with health first
local hB2, sB2 = hp(), seg.value
M.fire("UNIT_HEALTH", "target")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32); M.frame()
check(hp() ~= hB2 and seg.value == sB2 - 5, "health, then hit in the same frame: both move at once")
for _ = 1, 30 do M.update(0.05) end
check(#calls == 0, "redraws and ticks leave texture, color, range and layer alone: "
  .. table.concat(calls, ", "))
M.fire("UNIT_MAXHEALTH", "target"); M.update(0.11)
check(#calls == 2 and calls[1] == "SetMinMaxValues", "max health changed: range set once (mirror, segment): "
  .. table.concat(calls, ", "))
for _, f in ipairs({ seg, mirror, holder }) do
  for _, name in ipairs({ "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetFrameLevel",
    "SetFrameStrata" }) do
    if rawget(f, name) then f[name] = nil end
  end
end

-- Health message first, hit a few frames later, no health message after: held, then both move
-- together once the hit is PENDING_MAX old.
while M.now < 1000 + 11.94 do M.update(0.02) end
local hC, sC = hp(), seg.value
M.fire("UNIT_HEALTH", "target")
M.update(0.02); M.update(0.02)
check(hp() == hC and seg.value == sC, "health first: the health end waits for the hit")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.update(0.02); M.update(0.02)
check(hp() == hC and seg.value == sC, "health first: still held just after the hit")
for _ = 1, 15 do M.update(0.02) end
check(hp() ~= hC and seg.value == sC - 5, "health first: both ends move together after the wait")

-- Recast (ticks now from 12.32 on: 15.32, 18.32, ...). A tick never seen: both release together
-- when its grace runs out.
M.cast(589, "S")
while M.now < 1000 + 15.30 do M.update(0.02) end
local hD, sD = hp(), seg.value
M.update(0.04); M.fire("UNIT_HEALTH", "target") -- its health message; the hit itself unseen
M.update(0.3)
check(hp() == hD and seg.value == sD, "unseen tick: still holding just after it was due")
for _ = 1, 20 do M.update(0.02) end
check(hp() ~= hD and seg.value == sD - 5, "unseen tick: both ends release together")

-- A tick landing 0.3s early: held until it comes, then both move together, and the next tick is
-- expected where this one really landed.
while M.now < 1000 + 17.98 do M.update(0.02) end
local hE, sE = hp(), seg.value
M.update(0.02); M.update(0.02)
check(hp() == hE and seg.value == sE, "early tick: held while it's nearly due")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32)
M.fire("UNIT_HEALTH", "target"); M.frame()
check(hp() ~= hE and seg.value == sE - 5, "early tick: both ends move together")
tr = ns.TickTrace()
check(tr and tr.off < -0.2 and tr.counted and tr.drawn, "trace: early hit, counted and drawn")
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Last tick") then line = l end end
check(line and line:find("earlier"), "debug shows the last tick's timing: " .. tostring(line))

-- A new target is drawn at once, health included.
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
local hF = hp()
M.cast(589, "T"); M.update(0.11); M.update(0.11)
check(hp() ~= hF, "new mob: its health is drawn straight away")
