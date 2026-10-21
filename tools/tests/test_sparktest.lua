-- /ticky sparktest runs its variants on a test bar, prints a line for each, and puts things back.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
db.overlaySpark = false
M.printed = {}
SlashCmdList.TICKY("sparktest")
check(db.overlaySpark == true, "the test shows the spark while it runs")
local bar
for _, f in ipairs(M.frames) do if f.tickyOwned and f.strata == "DIALOG" and f.kind == "StatusBar" then bar = f end end
check(bar and bar:IsShown(), "test bar shown")
local hiddenAtReset, shownAtTick = false, false
local holder
for _, f in ipairs(M.frames) do
  if not holder and f.tickyOwned and f.points[1] and f.points[1][2] == bar then holder = f end
end
check(holder ~= nil, "test shading found")
for _ = 1, 2 do M.update(1 / 60) end
hiddenAtReset = holder and not holder:IsShown()
for _ = 1, 40 do M.update(1 / 60) end
shownAtTick = holder and holder:IsShown()
check(hiddenAtReset and shownAtTick, "the shading is hidden while it goes back to the start, shown for the tick")
for _ = 1, 2000 do M.update(1 / 60) end
local lines = 0
for _, l in ipairs(M.printed) do if l:find("^.-%d%) ") then lines = lines + 1 end end
check(lines == 6, "a line per variant: " .. lines)
check(db.overlaySpark == false, "spark setting restored")
check(bar and not bar:IsShown(), "test bar hidden afterwards")
local hiddenLine
for _, l in ipairs(M.printed) do if l:find("5%) ") then hiddenLine = l end end
check(hiddenLine and hiddenLine:find("only watched") and not hiddenLine:find("didn't hide"),
  "hidden-value tests ran with hidden values: " .. tostring(hiddenLine))
M.printed = {}
SlashCmdList.TICKY("sparktest")
local again
for _, f in ipairs(M.frames) do
  if f.tickyOwned and f.strata == "DIALOG" and f.kind == "StatusBar" and f ~= bar and f:IsShown() then again = f end
end
check(again ~= nil, "runs again, on a fresh bar")

-- /ticky sparktest copy: a copy of the target's shading on a plain bar, drawn with the real one.
for _ = 1, 2000 do M.update(1 / 60) end -- let the second run finish
ns.Track(589, "Shadow Word: Pain", 136207)
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.printed = {}
SlashCmdList.TICKY("sparktest copy")
local copyBar
for _, f in ipairs(M.frames) do
  if f.tickyOwned and f.kind == "StatusBar" and f.strata ~= "DIALOG" and f:IsShown() and f.parent == UIParent then copyBar = f end
end
check(copyBar ~= nil, "copy bar shown")
local castAt = M.now
M.cast(589, "S")
M.update(0.15); M.frame()
local copyHolder, realHolder
for _, f in ipairs(M.frames) do
  if f.tickyOwned and f.points[1] and f.points[1][2] == copyBar then copyHolder = f end
  if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar then realHolder = f end
end
check(copyHolder and copyHolder:IsShown() and realHolder and realHolder:IsShown(), "copy and real shading both drawn")
local cseg, rseg = copyHolder.children[2], realHolder.children[2]
check(cseg.value == rseg.value, "copy shows the same amount: " .. tostring(cseg.value) .. " / " .. tostring(rseg.value))
while M.now < castAt + 2.98 do M.update(0.02) end
M.fire("UNIT_COMBAT", "target", "WOUND", "", 5, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
local tr = ns.TickTrace()
check(cseg.value == rseg.value and tr and tr.shrink == 5, "after a tick: same amount, and the trace follows the real one ("
  .. tostring(tr and tr.shrink) .. ")")
SlashCmdList.TICKY("sparktest copy")
check(not copyBar:IsShown() and not copyHolder:IsShown(), "copy hidden again")
