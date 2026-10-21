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
for _ = 1, 1000 do M.update(1 / 60) end
local lines = 0
for _, l in ipairs(M.printed) do if l:find("^.-%d%) ") then lines = lines + 1 end end
check(lines == 5, "a line per variant: " .. lines)
check(db.overlaySpark == false, "spark setting restored")
check(bar and not bar:IsShown(), "test bar hidden afterwards")
M.printed = {}
SlashCmdList.TICKY("sparktest")
check(bar:IsShown(), "runs again")
