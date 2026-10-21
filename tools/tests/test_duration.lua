-- A cast lasts what its tooltip says (the client's current one, talents included), not a duration
-- learned from an older aura read: Shadow Word: Pain's tooltip said 24 sec while the learned one
-- said 18, so Ticky ended it 6s early (in game, 2026-10-21). "seconds"/"minutes" are understood too.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local cdb = ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207)
cdb.durations[589] = 18
M.spells[589].desc = "A word of darkness that causes 203 Shadow damage over 24 seconds."
M.fire("SPELLS_CHANGED")
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S")
M.update(0.15)
local list = ns.UnitTimers("target", M.now, {})
local t = list[1]
check(t and math.abs(t.expires - t.start - 24) < 0.01, "lasts the tooltip's 24 seconds: "
  .. tostring(t and (t.expires - t.start)))
M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Spells") then line = l end end
check(line and line:find("Shadow Word: Pain 24s %(read 18s%)"), "debug shows it and the stale read: " .. tostring(line))

-- With no duration in the tooltip, the learned one is used.
M.spells[589].desc = "A word of darkness."
M.fire("SPELLS_CHANGED")
M.cast(589, "S")
M.update(0.15)
t = ns.UnitTimers("target", M.now, {})[1]
check(t and math.abs(t.expires - t.start - 18) < 0.01, "no tooltip duration: the learned 18: "
  .. tostring(t and (t.expires - t.start)))
