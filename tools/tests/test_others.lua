-- Another player's spells aren't yours: their auras (same spells as yours) don't make bars, play
-- your sounds or teach durations, unless the spell is set to track "from anyone". Only the aura's
-- caster tells (isFromPlayerOrPlayerPet is true for any player's aura). In game, 2026-10-21.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db, cdb = ns.DB(), ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(139, "Renew", 135953)
db.applySound, db.refreshSound, db.expireSound = "RAID_WARNING", "RAID_WARNING", "RAID_WARNING"
M.units.party1 = { guid = "Player-2", name = "Otherpriest", exists = true, canAssist = true, auras = {} }

-- Out of combat, another priest's Shadow Word: Pain goes on your target.
M.units.target = { guid = "Creature-1", name = "S", exists = true, canAttack = true,
  auras = { M.aura(589, 18, { mine = false }) } }
M.sounds = {}
M.fire("PLAYER_TARGET_CHANGED"); M.fire("UNIT_AURA", "target"); M.update(0.15)
check(#ns.UnitTimers("target", M.now, {}) == 0, "their Shadow Word: Pain makes no bar")
check(#M.sounds == 0, "and no sound: " .. #M.sounds)
check(cdb.durations[589] == nil, "and teaches no length: " .. tostring(cdb.durations[589]))

-- Their Renew on you.
M.units.player.auras = { M.aura(139, 15, { mine = false, harmful = false }) }
M.fire("UNIT_AURA", "player"); M.update(0.15)
local list = ns.ActiveTimers(M.now)
local renew
for _, e in ipairs(list) do if e.key == "renew" and not e.missing then renew = e end end
check(not renew and #M.sounds == 0, "their Renew on you isn't yours")

-- "From anyone" on: theirs counts.
ns.SpellCfg("renew").anyCaster = true
M.fire("UNIT_AURA", "player"); M.update(0.15)
renew = nil
for _, e in ipairs(ns.ActiveTimers(M.now)) do if e.key == "renew" and not e.missing then renew = e end end
check(renew ~= nil, "with \"from anyone\", theirs shows")

-- Yours still counts.
M.units.target.auras = { M.aura(589, 24, { start = M.now }) }
M.fire("UNIT_AURA", "target"); M.update(0.15)
check(#ns.UnitTimers("target", M.now, {}) == 1 and cdb.durations[589] == 24, "your own Shadow Word: Pain does")
