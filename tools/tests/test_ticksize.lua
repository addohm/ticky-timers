-- The shading shrinks by exactly what each tick did as it lands, even as the learned tick size
-- shifts: with a learned 27 and real ticks of 25 and 26, re-estimating every remaining tick on each
-- hit shrank it by 31 for a 25 hit (in game, 2026-10-21), moving the far end. Afterwards the
-- difference from the estimate drifts out slowly (no jump at the tick or at the DoT's end).
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db, cdb = ns.DB(), ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207)
cdb.tickSizes[589] = 27
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S") -- 6 ticks of 3s
M.update(0.15); M.frame()
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar then holder = f end end
local seg = holder.children[2]
check(seg.value == 6 * 27, "starts at 6 ticks x 27: " .. tostring(seg.value))

local hits = { 25, 26, 25 }
for k, hit in ipairs(hits) do
  while M.now < 1000 + 3 * k - 0.02 do M.update(0.02) end
  local before = seg.value
  M.fire("UNIT_COMBAT", "target", "WOUND", "", hit, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
  check(math.abs(before - seg.value - hit) < 0.001, ("tick %d: the shading shrinks by the hit, %d: %s -> %s")
    :format(k, hit, tostring(before), tostring(seg.value)))
  M.update(0.25)
  check(math.abs(before - seg.value - hit) < 0.001, ("tick %d: and holds a moment"):format(k))
  M.update(0.8)
  local mid = seg.value
  local estimate = (6 - k) * 27
  check(mid > estimate and mid < before - hit, ("tick %d: then drifts toward the estimate: %s"):format(k, tostring(mid)))
  for _ = 1, 10 do M.update(0.1) end
  check(seg.value == estimate, ("tick %d: until it's there: %s"):format(k, tostring(seg.value)))
end
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Last tick") then line = l end end
check(line and line:find("25 hit, shading %-25"), "debug: hit and shrink match: " .. tostring(line))

-- A critical tick (DoT ticks can crit on Forever: "hit 38! SWP" in game, 2026-10-21) takes off what
-- it really did too.
while M.now < 1000 + 12 - 0.02 do M.update(0.02) end
local beforeCrit = seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 38, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(math.abs(beforeCrit - seg.value - 38) < 0.001, "a 38 crit shrinks the shading by 38: " .. tostring(beforeCrit) .. " -> "
  .. tostring(seg.value))

-- A same-school hit far bigger than this spell's ticks, near a tick (a Mind Blast): not taken as the
-- tick, so the shading doesn't shrink by it.
while M.now < 1000 + 15 - 0.02 do M.update(0.02) end
local before = seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 400, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(holder:IsShown() and seg.value == before, "a 400 hit isn't a 26 tick: " .. tostring(before) .. " -> "
  .. tostring(seg.value))

-- The learned size isn't rounded: rounded, an average of 25 never moved for ticks of 26.
cdb.tickSizes[589] = 25
M.units.target = { guid = "Creature-2", name = "T", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
local castAt = M.now
M.cast(589, "T")
for k = 1, 3 do
  while M.now < castAt + 3 * k - 0.02 do M.update(0.02) end
  M.fire("UNIT_COMBAT", "target", "WOUND", "", 26, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
end
check(cdb.tickSizes[589] > 25.7, "ticks of 26 move a learned 25 up: " .. tostring(cdb.tickSizes[589]))
