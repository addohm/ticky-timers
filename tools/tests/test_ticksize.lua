-- The shading shrinks by exactly what each tick did, even as the learned tick size shifts: with a
-- learned 27 and real ticks of 25 and 26, re-estimating every remaining tick on each hit shrank it
-- by 31 for a 25 hit (in game, 2026-10-21), moving the far end.
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

local hits = { 25, 26, 25, 26 }
for k, hit in ipairs(hits) do
  while M.now < 1000 + 3 * k - 0.02 do M.update(0.02) end
  local before = seg.value
  M.fire("UNIT_COMBAT", "target", "WOUND", "", hit, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
  check(before - seg.value == hit, ("tick %d: the shading shrinks by the hit, %d: %s -> %s"):format(k, hit,
    tostring(before), tostring(seg.value)))
  for _ = 1, 10 do M.update(0.05) end
  check(before - seg.value == hit, ("tick %d: and stays there between ticks"):format(k))
end
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Last tick") then line = l end end
check(line and line:find("26 hit, shading %-26"), "debug: hit and shrink match: " .. tostring(line))

-- A same-school hit far bigger than this spell's ticks, near a tick (a Mind Blast): not taken as the
-- tick, so the shading doesn't shrink by it.
while M.now < 1000 + 15 - 0.02 do M.update(0.02) end
local before = seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 400, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(seg.value == before, "a 400 hit isn't a 26 tick")
