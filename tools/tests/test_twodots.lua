-- Two DoTs ticking close together: the first one's tick doesn't shrink the shading while the health
-- end still waits for the second; both ends move once, together, for both ticks.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(2944, "Devouring Plague", 252997)
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S")   -- ticks at 3, 6, ...
M.update(0.3)
M.cast(2944, "S")  -- ticks at 3.3, 6.3, ...
M.update(0.15); M.frame()
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar then holder = f end end
check(holder ~= nil, "target overlay exists")
local mirror, seg = holder.children[1], holder.children[2]
local function hp() return mirror.value and mirror.value.n end

while M.now < 1000 + 2.98 do M.update(0.02) end
local h0, s0 = hp(), seg.value
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(hp() == h0 and seg.value == s0, "first tick, the second due soon: both ends wait")
while M.now < 1000 + 3.28 do M.update(0.02) end
check(hp() == h0 and seg.value == s0, "both still waiting just before the second tick")
M.fire("UNIT_COMBAT", "target", "WOUND", "", 19, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(hp() ~= h0 and seg.value == s0 - 5 - 19, "second tick: both ends move together, for both ticks ("
  .. tostring(s0) .. " -> " .. tostring(seg.value) .. ")")
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Last tick") then line = l end end
check(line and line:find("19 hit, shading %-24"), "debug shows the hit and how much the shading shrank: " .. tostring(line))
