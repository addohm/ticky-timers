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
