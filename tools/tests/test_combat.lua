-- Timers from casts in combat, tab-dotting, misses and resists, deaths, combat ending.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db, cdb = ns.DB(), ns.CharDB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(2944, "Devouring Plague", 252997)
ns.Track(772, "Rend", 132155)
ns.Track(139, "Renew", 135953)
db.locked, db.alertOtherTargets = true, false
cdb.spells["shadow word: pain"].applySound = "RAID_WARNING"
local function names()
  local t = {}
  for _, b in ipairs(TickyAnchor.children) do
    if b.kind == "StatusBar" and b.shown then t[#t + 1] = { y = b.points[1][5], n = b.name.text } end
  end
  table.sort(t, function(a, b) return a.y > b.y end)
  local out = {}
  for _, e in ipairs(t) do out[#out + 1] = e.n end
  return table.concat(out, " | ")
end
local function timeLeft()
  for _, b in ipairs(TickyAnchor.children) do
    if b.kind == "StatusBar" and b.shown then return tonumber(b.time.text:match("([%d%.]+)$")) end
  end
end

M.units.target = { guid = "Creature-1", name = "Spider", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
local n0 = #M.sounds
M.cast(589, "Spider"); M.update(0.05)
check(names() == "Shadow Word: Pain", "bar from the cast in combat: " .. names())
check(#M.sounds == n0 + 1 and M.sounds[#M.sounds][1] == 8959, "apply sound")
check(timeLeft() and timeLeft() >= 17, "18s from the tooltip")

-- Tab-dot: aimed at A, target switches before the cast lands.
local A = M.units.target
M.fire("UNIT_SPELLCAST_SENT", "player", "Spider", "TD", 2944)
M.units.target = { guid = "Creature-2", name = "Wolf", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "TD", 2944); M.update(0.05)
check(names() == "", "the new target has nothing")
M.units.target = A; M.fire("PLAYER_TARGET_CHANGED"); M.update(0.05)
check(names():find("Devouring Plague") ~= nil, "DP landed on the mob it was aimed at: " .. names())

-- A missed recast keeps the old timer; misses reported before the cast count too.
for _ = 1, 80 do M.update(0.1) end
M.fire("UNIT_SPELLCAST_SENT", "player", "Spider", "MR", 589)
M.fire("UNIT_COMBAT", "target", "MISS", "", 0, 1)
M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "MR", 589); M.update(0.05)
local swp
for _, b in ipairs(TickyAnchor.children) do
  if b.kind == "StatusBar" and b.shown and b.name.text == "Shadow Word: Pain" then swp = tonumber(b.time.text:match("([%d%.]+)$")) end
end
check(swp and swp < 11, "missed recast: old SW:P timer keeps running: " .. tostring(swp))
-- A miss half a second after a cast is someone else's.
M.cast(589, "Spider"); M.update(0.5); M.fire("UNIT_COMBAT", "target", "MISS", "", 0, 1); M.update(0.05)
check(names():find("Shadow Word: Pain") ~= nil, "a late miss doesn't cancel")
-- Dodges never cancel spells, but do cancel Rend.
M.units.target = { guid = "Creature-3", name = "Bear", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED")
M.cast(589, "Bear"); M.fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1); M.update(0.05)
check(names() == "Shadow Word: Pain", "a dodge doesn't cancel a spell")
M.cast(772, "Bear"); M.fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1); M.update(0.05)
check(names() == "Shadow Word: Pain", "a dodge cancels Rend")
M.cast(2944, "Bear"); M.fire("UNIT_COMBAT", "target", "RESIST", "", 0, 32); M.update(0.05)
check(names() == "Shadow Word: Pain", "a resist cancels DP")
M.fire("UNIT_COMBAT", "player", "MISS", "", 0, 1)
check(true, "a miss on you is ignored")

-- The target dies: its bars go without a sound.
n0 = #M.sounds
M.units.target.dead = true; M.update(0.2); M.update(0.2)
check(names() == "" and #M.sounds == n0, "dead target cleared silently")

-- Combat ends: unseen mobs' debuffs dropped, buffs kept.
M.units.target = { guid = "Player-9", name = "Friend", exists = true, canAssist = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(139, "Friend"); M.update(0.05)
M.units.target = { guid = "Creature-4", name = "Bat", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.cast(589, "Bat"); M.update(0.05)
M.units.target = nil; M.fire("PLAYER_TARGET_CHANGED")
M.auraLock = false; M.fire("PLAYER_REGEN_ENABLED")
db.expireSound, db.alertOtherTargets = "MAP_PING", true
n0 = #M.sounds
for _ = 1, 250 do M.update(0.1) end
local pings = 0
for i = n0 + 1, #M.sounds do if M.sounds[i][1] == 3175 then pings = pings + 1 end end
check(pings == 1, "after combat only the buff (Renew) ends with a sound: " .. pings)

-- Out of combat, a readable aura teaches the real length.
M.units.target = { guid = "Creature-5", name = "Crab", exists = true, canAttack = true,
  auras = { M.aura(589, 24, { start = M.now }) } }
M.fire("PLAYER_TARGET_CHANGED"); M.update(0.1)
check(cdb.durations[589] == 24, "learned SW:P lasts 24s: " .. tostring(cdb.durations[589]))
