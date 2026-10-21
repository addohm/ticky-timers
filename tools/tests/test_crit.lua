-- A DoT tick that crits moves the spark by what it did beyond a normal tick (the plan's total over
-- its ticks); a normal tick doesn't move it. (The owner, 2026-10-21.)
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207) -- tooltip: 30 over 18 sec: 6 ticks of 5
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
local start = M.now
M.cast(589, "S"); M.update(0.15); M.frame()
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar and f.points[2] then holder = f end end
local dclip = holder.children[3]
local seg
for _, c in ipairs(dclip.children) do if c.kind == "StatusBar" and c.shown then seg = c end end
check(seg and seg.value == 30, "starts at the total, 30")
while M.now < start + 3 do M.update(0.05) end
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(seg.value == 30, "a normal tick doesn't move the spark")
while M.now < start + 6 do M.update(0.05) end
M.fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 8, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
check(seg.value == 33, "a crit for 8 (normal 5) moves it 3: " .. tostring(seg.value))
M.printed = {}
SlashCmdList.TICKY("log")
check((M.printed[1] or ""):find("SWP crit: spark %-3"), "/ticky log shows it: " .. tostring(M.printed[1]))
