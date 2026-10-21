-- Inside a raid, Ticky puts nothing on nameplates by default (the owner, 2026-10-22): no timer
-- bars, no health shading. Your target's shading and the main bars still work; with "Hide on
-- nameplates in raids" off, the nameplates get theirs again. Dungeons and the open world: as before.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
check(ns.DEFAULTS.plateHideInRaid == true, "on by default")
ns.Track(589, "Shadow Word: Pain", 136207)
db.plateEnabled, db.plateWhich, db.overlayDamage, db.overlayPlates, db.locked = true, "all", true, true, true
local A = { guid = "Creature-A", name = "A", exists = true, canAttack = true, auras = {} }
M.units.nameplate1 = A
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
M.units.target = A
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "A"); M.update(0.15); M.frame()
local plate = M.plates.nameplate1
-- On the plate: the timer bars' holder hangs off the health bar's top or bottom edge; the
-- shading's covers it (TOPLEFT to TOPLEFT).
local function onPlate()
  local bars, shading
  for _, f in ipairs(M.frames) do
    if f.tickyOwned and f.parent == plate and f.points[1] and f.points[1][2] == plate.hb then
      if f.points[1][1] == "TOPLEFT" and f.points[1][3] == "TOPLEFT" then shading = f else bars = f end
    end
  end
  return bars and bars:IsShown(), shading and shading:IsShown()
end
local function targetShading()
  for _, f in ipairs(M.frames) do
    if f.tickyOwned and f.points[1] and f.points[1][2] == M.healthBar and f.points[2] then return f:IsShown() end
  end
end
local bars, shading = onPlate()
check(bars and shading, "open world: bars and shading on the nameplate")

M.instanceType = "party"; M.update(1.1); M.frame()
bars, shading = onPlate()
check(bars and shading, "a dungeon: still there")

M.instanceType = "raid"; M.update(1.1); M.frame()
bars, shading = onPlate()
check(not bars and not shading, "a raid: nothing on the nameplate")
check(targetShading(), "your target's health bar shading still shows")

db.plateHideInRaid = false; M.update(0.15); M.frame()
bars, shading = onPlate()
check(bars and shading, "the setting off: back on the nameplate in the raid")
