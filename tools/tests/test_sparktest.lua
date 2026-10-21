-- /ticky sparktest runs its variants on a test bar, prints a line for each, and puts things back.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
db.overlaySpark = false
M.printed = {}
SlashCmdList.TICKY("sparktest")
check(db.overlaySpark == true, "the test shows the spark while it runs")
local bar
for _, f in ipairs(M.frames) do if f.tickyOwned and f.w == 600 then bar = f end end
check(bar and bar:IsShown(), "test bar shown")
local hiddenAtReset, shownAtTick = false, false
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == bar then holder = f end end
check(holder ~= nil, "test shading found")
for _ = 1, 2 do M.update(1 / 60) end
hiddenAtReset = holder and not holder:IsShown()
for _ = 1, 40 do M.update(1 / 60) end
shownAtTick = holder and holder:IsShown()
check(hiddenAtReset and shownAtTick, "the shading is hidden while it goes back to the start, shown for the tick")
for _ = 1, 1200 do M.update(1 / 60) end
local lines = 0
for _, l in ipairs(M.printed) do if l:find("^.-%d%) ") then lines = lines + 1 end end
check(lines == 6, "a line per variant: " .. lines)
check(db.overlaySpark == false, "spark setting restored")
check(bar and not bar:IsShown(), "test bar hidden afterwards")
M.printed = {}
SlashCmdList.TICKY("sparktest")
check(bar:IsShown(), "runs again")
