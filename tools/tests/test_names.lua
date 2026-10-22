-- Your spells on other units (the owner, 2026-10-22): with "Your spells on other units" on, the
-- main bars also show your HoTs and DoTs on anyone but your target, each with who it's on, so a
-- HoT kept on someone shows when it falls off. "Who it's on" also puts names on every bar or none;
-- nameplate bars never get them. A heal clicked on a party member's frame goes on them, not you.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.Track(139, "Renew", 135953)
db.locked = true
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
local GRAY = "|cff999999"

M.units.party1 = { guid = "Player-3", name = "Bob", exists = true, canAssist = true, auras = {} }
M.units.target = { guid = "Creature-1", name = "Spider", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.fire("PLAYER_REGEN_DISABLED"); M.auraLock = true
M.cast(589, "Spider")
M.cast(139, "Bob") -- clicked on Bob's party frame; your target is still the spider
M.update(0.15)
check(names() == "Shadow Word: Pain", "off by default: only your target's: " .. names())
check(#ns.UnitTimers("party1", M.now, {}) == 1, "the Renew is on Bob, not you")

db.showOthers = true; M.update(0.15)
check(names() == "Shadow Word: Pain | Renew " .. GRAY .. "(Bob)|r", "on: Bob's Renew after your target's, named: "
  .. names())

-- Switch target: the spider's DoT is now another unit's, named; Bob's Renew stays.
M.units.target = { guid = "Creature-2", name = "Wolf", exists = true, canAttack = true, auras = {} }
M.fire("PLAYER_TARGET_CHANGED"); M.update(0.15)
local list = names()
check(list:find("Shadow Word: Pain " .. GRAY .. "%(Spider%)") and list:find("Renew " .. GRAY .. "%(Bob%)"),
  "the spider's DoT and Bob's Renew, both named: " .. list)

-- "Who it's on": on every bar, or never.
M.cast(589, "Wolf"); M.update(0.15)
db.unitNameMode = "all"; M.update(0.15)
check(names():find("^Shadow Word: Pain " .. GRAY .. "%(Wolf%)"), "every bar: your target's too: " .. names())
db.unitNameMode = "none"; M.update(0.15)
check(not names():find("%("), "never: no names: " .. names())
db.unitNameMode = "others"

-- Nameplate bars never get names.
db.plateEnabled, db.plateWhich = true, "all"
M.units.nameplate1 = M.units.target
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); M.update(0.15)
local plateText
for _, f in ipairs(M.frames) do
  if f.kind == "StatusBar" and f.shown and f.name and f.parent and f.parent.parent == M.plates.nameplate1 then
    plateText = f.name.text
  end
end
db.unitNameMode = "all"; M.update(0.15)
for _, f in ipairs(M.frames) do
  if f.kind == "StatusBar" and f.shown and f.name and f.parent and f.parent.parent == M.plates.nameplate1 then
    plateText = f.name.text
  end
end
check(plateText and not plateText:find("%("), "nameplate bars: no names: " .. tostring(plateText))

-- The game can give a cast's target name with a realm ("Whoat-Beta"). A HoT on yourself is still
-- yours, and reading your buffs doesn't add a second bar for it (it did: two bars per HoT, two
-- timings, 2026-10-22). Same for a party member from another realm.
db.plateEnabled, db.unitNameMode = false, "others"
M.units.target = nil; M.fire("PLAYER_TARGET_CHANGED"); M.update(0.15)
local function count(text, word)
  local n = 0
  for _ in text:gmatch(word) do n = n + 1 end
  return n
end
M.cast(139, "Whoat-Beta"); M.update(0.15)
M.units.player.auras = { M.aura(139, 15, { harmful = false }) }
M.auraLock = false; M.fire("UNIT_AURA", "player"); M.update(0.15)
check(count(names(), "Renew") == 2 and not names():find("Whoat"),
  "your Renew once (the other is Bob's): " .. names())
M.units.party2 = { guid = "Player-4", name = "Carl", exists = true, canAssist = true, auras = {} }
M.cast(139, "Carl-Otherrealm"); M.update(0.15)
check(#ns.UnitTimers("party2", M.now, {}) == 1, "Carl from another realm: found in your group")

-- A friend Ticky couldn't see at the cast (kept under their name), read later as your target:
-- one bar, not two.
M.cast(139, "Dana"); M.update(0.15)
check(count(names(), "%(Dana%)") == 1, "Dana's Renew, by name: " .. names())
M.units.target = { guid = "Player-5", name = "Dana", exists = true, canAssist = true,
  auras = { M.aura(139, 15, { harmful = false }) } }
M.fire("PLAYER_TARGET_CHANGED"); M.update(0.15)
check(count(names(), "Renew") == 4 and names():find("^Renew |") and not names():find("%(Dana%)"),
  "targeted and read: her Renew once, as your target's: " .. names())
-- The game gave a cast's target as "Nit Pik" for a player UnitName calls "Nit" (in game,
-- 2026-10-22: two bars, "(Nit Pik, by name)" and "(Nit, GUID)"). Their nameplate is up: found at
-- the cast. Not up: kept as "Nit", and reading their buffs from their nameplate later takes it over.
M.units.target = nil; M.fire("PLAYER_TARGET_CHANGED"); M.update(0.15)
M.units.nameplate5 = { guid = "Player-6", name = "Nit", exists = true, canAssist = true,
  auras = { M.aura(139, 15, { harmful = false }) } }
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
M.cast(139, "Nit Pik"); M.update(0.15)
check(count(names(), "%(Nit") == 1 and names():find("Renew " .. GRAY .. "%(Nit%)"),
  "Nit Pik is Nit, whose nameplate is up: one bar, \"(Nit)\": " .. names())
M.units.nameplate6 = nil
M.cast(139, "Eve Longname"); M.update(0.15)
check(names():find("Renew " .. GRAY .. "%(Eve%)"), "not seen anywhere: kept as Eve: " .. names())
M.units.nameplate6 = { guid = "Player-7", name = "Eve", exists = true, canAssist = true,
  auras = { M.aura(139, 15, { harmful = false }) } }
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate6"); M.update(0.15)
check(count(names(), "%(Eve") == 1, "her nameplate read later: still one bar: " .. names())

M.printed = {}
SlashCmdList.TICKY("debug")
local line
for _, l in ipairs(M.printed) do if l:find("Elsewhere") then line = l end end
check(line and line:find("Renew %(Bob, GUID%)") and line:find("Renew %(%?, you%)"),
  "/ticky debug lists your spells on others and how they were found: " .. tostring(line))

-- The same spell on several people keeps its places: by who it's on (it swapped around: table.sort
-- isn't stable, and bars of one spell sorted equal, 2026-10-22).
db.sortMode = "custom"
for i, who in ipairs({ "Zed", "Amy", "Max", "Kim", "Lou" }) do
  M.units["raid" .. i] = { guid = "Player-R" .. i, name = who, exists = true, canAssist = true, auras = {} }
  M.cast(139, who)
end
local orders = {}
for _ = 1, 8 do
  M.update(0.15)
  local seq = {}
  for who in names():gmatch("Renew " .. GRAY .. "%((%a+)%)") do
    if ({ Zed = 1, Amy = 1, Max = 1, Kim = 1, Lou = 1 })[who] then seq[#seq + 1] = who end
  end
  orders[table.concat(seq, ",")] = true
end
local seen = {}
for k in pairs(orders) do seen[#seen + 1] = k end
check(#seen == 1 and seen[1] == "Amy,Kim,Lou,Max,Zed", "in name order, every redraw: " .. table.concat(seen, " / "))
