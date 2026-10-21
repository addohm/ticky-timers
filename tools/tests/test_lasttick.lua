-- A DoT's last tick, due at its expiry, can land a little late. It still counts as that DoT's tick
-- (it used to find the timer gone: "hit N (not a tick)", the health dropped with nothing to match),
-- and the shading shrinks by it in the same moment.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(2944, "Devouring Plague", 252997)
db.overlayDamage, db.locked = true, true
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "S")   -- ticks at 3, 6, ... 18 (its expiry)
M.update(1.5)
M.cast(2944, "S")  -- ticks at 4.5, 7.5, ... 25.5
M.update(0.15); M.frame()
local holder
for _, f in ipairs(M.frames) do if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar then holder = f end end
local seg = holder.children[2]
local function Tick(at, amount)
  while M.now < 1000 + at do M.update(0.02) end
  M.fire("UNIT_COMBAT", "target", "WOUND", "", amount, 32); M.fire("UNIT_HEALTH", "target"); M.frame()
end
for k = 1, 5 do
  Tick(3 * k, 5)
  if 3 * k + 1.5 < 18 then Tick(3 * k + 1.5, 19) end
end
Tick(18.08, 5) -- the last Shadow Word: Pain tick, 0.08s after its expiry
local before = seg.value
M.printed = {}
SlashCmdList.TICKY("log")
local log = M.printed[1] or ""
check(log:find("hit 5 SWP") and not log:find("not a tick"), "the late last tick is Shadow Word: Pain's: " .. log)
-- That tick was 0.08s after expiry, and the draws around it: the shading lost exactly it.
local trace = ns.TickTrace()
check(trace and trace.name == "Shadow Word: Pain" and trace.shrink and math.abs(trace.shrink - 5) < 0.01,
  "shading shrank by the late tick: " .. tostring(trace and trace.shrink))
for _ = 1, 40 do M.update(0.05) end
M.printed = {}
SlashCmdList.TICKY("log")
check((M.printed[1] or ""):find("ended SWP"), "then the timer is let go")
check(holder:IsShown() and seg.value > 0, "Devouring Plague's shading stays")
