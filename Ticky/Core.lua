-- Ticky core: settings, reading auras and channels, expiry alerts, events, slash commands.
-- Written for World of Warcraft: Forever (Mainline addon API, interface 16001).
--
-- Where the timing comes from:
--   * Duration and start/end come from the aura itself, so talents (e.g. Improved
--     Shadow Word: Pain making it 24s), rank and gear are already included.
--   * The tick period comes from the game's spell data (Data.lua), scaled by spell
--     haste for spells the data marks as haste-affected.
--   * Channels spread the data's tick count across the client's channel time.
--   * The game keeps each unit's auras, so switching targets just re-reads them.
-- The combat log is not available to addons on Forever, and some values can be
-- "secret" (drawable but not readable); anything secret is skipped, never read.
local ADDON, ns = ...

local GetTime, ipairs, pairs, wipe, tonumber, floor, abs = GetTime, ipairs, pairs, wipe, tonumber, math.floor, math.abs

local DB_VERSION = 4

-- Account-wide look and behaviour. Spell choices are per character (TickyCharDB).
ns.DEFAULTS = {
  version = DB_VERSION,
  point = { "CENTER", 0, -160 },
  locked = false,
  -- Bars
  width = 220, height = 18, spacing = 3, scale = 1, growUp = false,
  texture = "Blizzard", bgAlpha = 0.55, fillMode = "drain", sortMode = "name",
  showIcon = true, iconSide = "LEFT",
  lowEnabled = false, lowSeconds = 3, lowColor = { 1, 0.25, 0.25 },
  -- Text & ticks
  showName = true, showTime = true, showTickCount = true,
  font = "Friz Quadrata", fontSize = 11, outline = "OUTLINE",
  tickColor = { 1, 1, 1 }, tickWidth = 2, pastTicks = "dim",
  highlightNext = true, nextColor = { 1, 0.85, 0.2 },
  -- Alerts
  expireSound = "NONE", warnSound = "NONE", warnSeconds = 0, warnFlash = true,
  soundChannel = "Master", alertOtherTargets = true, alertOnlyInCombat = false,
  -- General
  showChannel = true, showSelf = true, hideOutOfCombat = false,
  alpha = 1, oocAlpha = 1, showAll = false, previewInOptions = true,
}

ns.CHAR_DEFAULTS = {
  spells = {}, -- [lower-case name] = { name, id, icon, color, order, label, expireSound, warnSound, isChannel }
  nextOrder = 1,
}

ns.TEXTURES = {
  { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
  { "Flat", "Interface\\Buttons\\WHITE8X8" },
  { "Smooth", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
  { "Skills", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

ns.FONTS = {
  { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
  { "Arial Narrow", "Fonts\\ARIALN.TTF" },
  { "Morpheus", "Fonts\\MORPHEUS.TTF" },
  { "Skurri", "Fonts\\skurri.ttf" },
}

ns.OUTLINES = { { "", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }

-- SOUNDKIT names from the Forever client; the numbers are fallbacks if a name is missing.
ns.SOUNDS = {
  { "NONE", "None" },
  { "RAID_WARNING", "Raid Warning", 8959 },
  { "READY_CHECK", "Ready Check", 8960 },
  { "ALARM_CLOCK_WARNING_1", "Alarm 1", 18871 },
  { "ALARM_CLOCK_WARNING_2", "Alarm 2", 12867 },
  { "ALARM_CLOCK_WARNING_3", "Alarm 3", 12889 },
  { "UI_RAID_BOSS_WHISPER_WARNING", "Boss Whisper", 37666 },
  { "RAID_BOSS_EMOTE_WARNING", "Boss Emote", 12197 },
  { "MAP_PING", "Map Ping", 3175 },
  { "TELL_MESSAGE", "Whisper", 3081 },
  { "IG_QUEST_LIST_COMPLETE", "Quest Complete", 878 },
  { "IG_PLAYER_INVITE", "Invite", 880 },
  { "UI_BNET_TOAST", "Toast", 18019 },
  { "PVP_THROUGH_QUEUE", "Queue Pop", 8459 },
}

ns.CHANNELS = { { "Master", "Master" }, { "SFX", "Effects" }, { "Dialog", "Dialog" }, { "Ambience", "Ambience" } }

local PALETTE = {
  { 0.80, 0.35, 1.00 }, { 0.30, 0.55, 1.00 }, { 0.30, 0.85, 0.40 }, { 0.95, 0.75, 0.25 },
  { 1.00, 0.40, 0.40 }, { 0.40, 0.90, 0.90 }, { 1.00, 0.55, 0.85 }, { 0.75, 0.75, 0.75 },
}

-- All auras are read; each is kept if you cast it, or if its spell is set to "from anyone".
local AURA_FILTERS = { "HARMFUL", "HELPFUL" }

local db, cdb
local targetTimers = {}   -- tracked auras on your target
local selfTimers = {}     -- tracked auras on you
local channel            -- the player's current tracked channel
local watch = {}         -- [unitGUID][key] = timer, for expiry alerts on every unit we've seen
local playerGUID
local inCombat = false

local TB = CreateFrame("Frame")
ns.TB = TB

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Secret(v)
  return (issecretvalue and issecretvalue(v)) or (issecrettable and type(v) == "table" and issecrettable(v)) or false
end
ns.Secret = Secret

function ns.Lookup(list, key)
  for _, e in ipairs(list) do
    if e[1] == key then return e end
  end
  return list[1]
end

local function SpellInfo(spell)
  local info = C_Spell.GetSpellInfo(spell)
  if info and not Secret(info.name) then return info.name, info.iconID, info.spellID end
end
ns.SpellInfo = SpellInfo

local function GuidOf(unit)
  local g = UnitGUID(unit)
  if g and not Secret(g) then return g end
end

-- Last readable haste; haste can be secret in restricted content and rarely changes mid-fight.
local haste = 1
local function HasteMult()
  local h = UnitSpellHaste("player")
  if h and not Secret(h) then haste = 1 + h / 100 end
  return haste
end

-- Tooltip fallback for spells missing from Data.lua: "every N sec", "for N sec".
local descCache = {}
local function DescriptionInfo(id)
  if not id then return end
  local c = descCache[id]
  if c then return c end
  local d = C_Spell.GetSpellDescription(id)
  if not d or Secret(d) or d == "" then
    C_Spell.RequestLoadSpellData(id) -- SPELL_DATA_LOAD_RESULT refreshes the options list
    return
  end
  d = d:lower()
  local every = tonumber(d:match("every ([%d%.]+) sec")) or ((d:find("every sec") or d:find("per sec")) and 1) or nil
  local periodic = every ~= nil or d:find("over [%d%.]+ sec") ~= nil or d:find("over [%d%.]+ min") ~= nil
  c = {
    every = every,
    periodic = periodic,
    timed = periodic or d:find("for [%d%.]+ sec") ~= nil or d:find("for [%d%.]+ min") ~= nil
      or d:find("lasts [%d%.]+ sec") ~= nil or d:find("lasts [%d%.]+ min") ~= nil,
  }
  descCache[id] = c
  return c
end

-- Seconds between ticks for an aura, or nil if it doesn't tick (or we don't know).
local function AuraPeriod(id)
  local d = ns.Data[id]
  if d then
    if not d.p then return end
    local p = d.p / 1000
    return d.h and p / HasteMult() or p
  end
  local info = DescriptionInfo(id)
  return info and info.every
end
ns.AuraPeriod = AuraPeriod

-- Seconds between ticks for a channel lasting `span` seconds (already hasted by the client).
local function ChannelPeriod(id, span)
  local d = ns.Data[id]
  if d and d.p and d.d then return span * d.p / d.d end
  return AuraPeriod(id)
end

function ns.SpellCfg(key) return cdb and cdb.spells[key] end
function ns.DB() return db end
function ns.CharDB() return cdb end
function ns.InCombat() return inCombat end

---------------------------------------------------------------------------
-- Reading auras and channels
---------------------------------------------------------------------------

local function FromMe(aura)
  local mine, source = aura.isFromPlayerOrPlayerPet, aura.sourceUnit
  if mine ~= nil and not Secret(mine) then return mine end
  return source ~= nil and not Secret(source) and (source == "player" or source == "pet")
end

local function TimerFromAura(aura)
  if Secret(aura) then return end
  local id, duration, expires = aura.spellId, aura.duration, aura.expirationTime
  if Secret(id) or Secret(duration) or Secret(expires) or not id or not duration or duration <= 0 then return end
  local name, icon = SpellInfo(id)
  if not name then return end
  local key = name:lower()
  local cfg = cdb.spells[key]
  if not cfg or cfg.isChannel then return end
  if not cfg.anyCaster and not FromMe(aura) then return end
  return {
    key = key, name = name, icon = icon or cfg.icon,
    start = expires - duration, expires = expires, interval = AuraPeriod(id),
  }
end

-- Tracked auras on a unit, or nil if they couldn't be read (secret, restricted, etc.).
local function ScanUnit(unit)
  local out = {}
  local ok = pcall(function()
    for _, filter in ipairs(AURA_FILTERS) do
      for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if aura == nil then break end
        local t = TimerFromAura(aura)
        if t then out[#out + 1] = t end
      end
    end
  end)
  if ok then return out end
end

local function HasTarget()
  local exists = UnitExists("target")
  return Secret(exists) or exists and true or false
end

-- Is the target you? Then its bars are your own and only shown once.
local function TargetIsMe()
  local same = UnitIsUnit("target", "player")
  return not Secret(same) and same == true
end

-- Alerts -----------------------------------------------------------------

local function SoundFor(t, which)
  local cfg = cdb.spells[t.key]
  local own = cfg and cfg[which]
  if own and own ~= "DEFAULT" then return own end
  return db[which]
end

function ns.PlaySound(key)
  if not key or key == "NONE" then return end
  local e = ns.Lookup(ns.SOUNDS, key)
  local id = (SOUNDKIT and SOUNDKIT[key]) or e[3]
  if id then PlaySound(id, db.soundChannel) end
end

local function AlertAllowed(t)
  if db.alertOnlyInCombat and not inCombat then return false end
  if t.guid ~= GuidOf("target") and t.guid ~= playerGUID then
    if not db.alertOtherTargets then return false end
    -- Don't announce DoTs falling off something that died.
    local token = UnitTokenFromGUID and UnitTokenFromGUID(t.guid)
    if token and not Secret(token) then
      local dead = UnitIsDeadOrGhost(token)
      if not Secret(dead) and dead then return false end
    end
  end
  return true
end

local function Expire(t)
  if t.expired then return end
  t.expired = true
  if AlertAllowed(t) then ns.PlaySound(SoundFor(t, "expireSound")) end
end

local function Warn(t)
  t.warned = true
  if AlertAllowed(t) then ns.PlaySound(SoundFor(t, "warnSound")) end
end

-- Record a unit's current timers. Anything that vanished well before its expiry was
-- dispelled or overwritten, so it doesn't alert; anything vanishing right at expiry does.
local function Remember(unit, list)
  local guid = GuidOf(unit)
  if not guid then return end
  local now, old, new = GetTime(), watch[guid], {}
  for _, t in ipairs(list) do
    local prev = old and old[t.key]
    if prev and abs(prev.expires - t.expires) < 0.1 then t.warned, t.expired = prev.warned, prev.expired end
    t.guid = guid
    new[t.key] = t
  end
  if old then
    for key, prev in pairs(old) do
      if not new[key] and prev.expires - now < 0.5 then Expire(prev) end
    end
  end
  watch[guid] = next(new) and new or nil
end

local function CheckAlerts(now)
  for guid, timers in pairs(watch) do
    for key, t in pairs(timers) do
      if now >= t.expires then
        Expire(t)
        timers[key] = nil
      elseif not t.warned and db.warnSeconds > 0 and t.expires - now <= db.warnSeconds then
        Warn(t)
      end
    end
    if not next(timers) then watch[guid] = nil end
  end
end

-- Refreshing ----------------------------------------------------------------

local function sortKey(e)
  if db.sortMode == "remaining" then return e.expires end
  if db.sortMode == "added" then
    local cfg = cdb.spells[e.key]
    return cfg and cfg.order or 0
  end
  return e.key
end
local function byMode(a, b)
  local ka, kb = sortKey(a), sortKey(b)
  if ka == kb then return a.key < b.key end
  return ka < kb
end

local function Refresh(unit)
  local list = ScanUnit(unit)
  if list then Remember(unit, list) end
  if unit == "target" then
    targetTimers = list or {}
  elseif unit == "player" then
    selfTimers = list or {}
    for _, t in ipairs(selfTimers) do t.onSelf = true end
  end
end

local function RefreshDisplay()
  if HasTarget() then Refresh("target") else targetTimers = {} end
  Refresh("player")
end
ns.RefreshDisplay = RefreshDisplay

local function ReadChannel()
  local name, _, icon, startMS, endMS, _, _, spellID = UnitChannelInfo("player")
  if not name or Secret(name) or Secret(startMS) or Secret(endMS) or Secret(spellID) then return end
  local key = name:lower()
  local cfg = cdb.spells[key]
  if not cfg then return end
  if not cfg.isChannel then
    cfg.isChannel = true -- some channels also leave a debuff; show them once, as a channel
    RefreshDisplay()
  end
  local start, finish = startMS / 1000, endMS / 1000
  return {
    key = key, name = name, icon = icon, channel = true,
    start = start, expires = finish, interval = ChannelPeriod(spellID, finish - start),
  }
end

-- What the bars should show right now: your channel, your target's auras, then your own.
local active, group = {}, {}
local function AddGroup(list, now, youTag)
  wipe(group)
  for _, e in ipairs(list) do
    if e.expires > now then
      e.youTag = youTag
      group[#group + 1] = e
    end
  end
  table.sort(group, byMode)
  for _, e in ipairs(group) do active[#active + 1] = e end
end

function ns.ActiveTimers(now)
  wipe(active)
  if channel then
    if channel.expires <= now then channel = nil elseif db.showChannel then active[1] = channel end
  end
  local hasTarget = HasTarget()
  AddGroup(targetTimers, now, false)
  if db.showSelf and not (hasTarget and TargetIsMe()) then AddGroup(selfTimers, now, hasTarget) end
  return active
end

---------------------------------------------------------------------------
-- Tick math
---------------------------------------------------------------------------

-- Tick positions as fractions (0..1) of the timer's span. Ticks land every period
-- from the start; a last tick cut short by expiry lands at the end.
function ns.ComputeTicks(e, out)
  wipe(out)
  local span, iv = e.expires - e.start, e.interval
  if span <= 0 or not iv or iv < 0.1 then return out end
  local t = e.start + iv
  while t < e.expires - 0.05 do
    out[#out + 1] = (t - e.start) / span
    t = t + iv
  end
  out[#out + 1] = 1
  return out
end

---------------------------------------------------------------------------
-- Spell selection (used by Options.lua and slash commands)
---------------------------------------------------------------------------

-- Does this spell leave a timed buff or debuff? Game data first, tooltip wording as a fallback.
local function IsTimedAura(id)
  if ns.Data[id] then return true end
  local info = DescriptionInfo(id)
  return info and info.timed
end

-- Spells in the current spec's spellbook; only ones that leave a buff or debuff unless `all`.
function ns.SpellbookSpells(all)
  local out, byKey = {}, {}
  local bank = Enum.SpellBookSpellBank.Player
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if info and not info.shouldHide and not info.offSpecID then
      for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        local id = item and item.spellID
        if id and not item.isPassive and not item.isOffSpec and item.itemType == Enum.SpellBookItemType.Spell
          and (all or IsTimedAura(id)) then
          local name, icon = SpellInfo(id)
          if name then
            local key = name:lower()
            local row = byKey[key]
            if not row then
              row = { key = key }
              byKey[key] = row
              out[#out + 1] = row
            end
            row.id, row.name, row.icon = id, name, icon -- the highest rank wins
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out, byKey
end

function ns.IsTracked(key) return cdb.spells[key] ~= nil end

function ns.Track(id, name, icon)
  local key = name:lower()
  if cdb.spells[key] then return end
  local n = 0
  for _ in pairs(cdb.spells) do n = n + 1 end
  local c = PALETTE[n % #PALETTE + 1]
  local d = id and ns.Data[id]
  cdb.spells[key] = {
    name = name, id = id, icon = icon, color = { c[1], c[2], c[3] }, order = cdb.nextOrder,
    isChannel = d and d.d and true or nil,
  }
  cdb.nextOrder = cdb.nextOrder + 1
  RefreshDisplay()
end

function ns.Untrack(key)
  key = key:lower()
  local cfg = cdb.spells[key]
  if not cfg then return false, "Not tracking \"" .. key .. "\"." end
  cdb.spells[key] = nil
  if channel and channel.key == key then channel = nil end
  for _, timers in pairs(watch) do timers[key] = nil end
  RefreshDisplay()
  return true, "Stopped tracking " .. cfg.name .. "."
end

-- Add by name, spell ID, or spell link (for spells outside your spellbook).
function ns.AddSpell(input)
  input = input and strtrim(input) or ""
  if input == "" then return false, "Enter a spell name or ID." end
  local id = input:match("|Hspell:(%d+)") or input:match("^(%d+)$")
  local name, icon, spellID = SpellInfo(id and tonumber(id) or input)
  if not name then
    return false, "Unknown spell \"" .. input .. "\". Try its spell ID or shift-click it from your spellbook."
  end
  ns.Track(spellID or tonumber(id), name, icon)
  return true, "Tracking " .. name .. "."
end

-- One line describing a spell's ticks, for the options list.
function ns.Describe(key, id)
  local cfg = cdb.spells[key]
  id = id or (cfg and cfg.id)
  local who = cfg and cfg.anyCaster and " (anyone's)" or ""
  local d = id and ns.Data[id]
  if d then
    if d.p and d.d then
      return ("channel, %d ticks%s"):format(floor(d.d / d.p + 0.5), who)
    elseif d.p then
      return ("ticks every %gs%s%s"):format(d.p / 1000, d.h and ", faster with haste" or "", who)
    end
    return "timer, no ticks" .. who
  end
  local info = DescriptionInfo(id)
  if info and info.every then return ("ticks every %gs (from tooltip)%s"):format(info.every, who) end
  return "timer, no tick data" .. who
end

function ns.ResetSettings()
  local keep = { point = db.point }
  wipe(db)
  for k, v in pairs(ns.CopyDefaults(ns.DEFAULTS, {})) do db[k] = v end
  db.point = keep.point
  ns.ApplyStyle()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

TB:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
TB:RegisterEvent("ADDON_LOADED")
TB:RegisterEvent("PLAYER_LOGIN")

function ns.CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = type(v) == "table" and ns.CopyDefaults(v, {}) or v
    end
  end
  return dst
end

function TB:ADDON_LOADED(name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  TickyDB = TickyDB or {}
  TickyCharDB = ns.CopyDefaults(ns.CHAR_DEFAULTS, TickyCharDB or {})
  if TickyDB.version ~= DB_VERSION then
    -- Older versions kept spells account-wide; move them to this character once.
    if TickyDB.spells and not next(TickyCharDB.spells) then
      TickyCharDB.spells = TickyDB.spells
      for _, cfg in pairs(TickyCharDB.spells) do
        cfg.order = TickyCharDB.nextOrder
        TickyCharDB.nextOrder = TickyCharDB.nextOrder + 1
      end
    end
    TickyDB.spells, TickyDB.learned, TickyDB.learnedTicks = nil, nil, nil
    TickyDB.version = DB_VERSION
  end
  db = ns.CopyDefaults(ns.DEFAULTS, TickyDB)
  cdb = TickyCharDB

  ns.CreateBars()

  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("SPELLS_CHANGED")
  self:RegisterEvent("SPELL_DATA_LOAD_RESULT")
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  self:RegisterEvent("UNIT_AURA")
  self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

  local elapsedSinceCheck = 0
  self:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    ns.UpdateBars(now)
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    if elapsedSinceCheck > 0.1 then
      elapsedSinceCheck = 0
      CheckAlerts(now)
    end
  end)
end

function TB:PLAYER_LOGIN()
  playerGUID = GuidOf("player")
  local c = UnitAffectingCombat("player")
  inCombat = not Secret(c) and c or false
  RefreshDisplay()
  if not next(cdb.spells) then
    print("|cff99ccffTicky|r: type /ticky to choose which spells to track.")
  end
end

function TB:PLAYER_TARGET_CHANGED() RefreshDisplay() end
function TB:PLAYER_REGEN_DISABLED() inCombat = true end
function TB:PLAYER_REGEN_ENABLED() inCombat = false end

function TB:UNIT_AURA(unit)
  if unit == "target" or unit == "player" or unit:find("^nameplate%d") then Refresh(unit) end
end

function TB:NAME_PLATE_UNIT_ADDED(unit) Refresh(unit) end

function TB:SPELLS_CHANGED()
  wipe(descCache)
  if ns.RefreshOptions then ns.RefreshOptions(true) end
end

function TB:SPELL_DATA_LOAD_RESULT()
  if ns.RefreshOptions then ns.RefreshOptions(true) end
end

function TB:UNIT_SPELLCAST_CHANNEL_START() channel = ReadChannel() end
function TB:UNIT_SPELLCAST_CHANNEL_UPDATE() if channel then channel = ReadChannel() end end
function TB:UNIT_SPELLCAST_CHANNEL_STOP() channel = nil end

---------------------------------------------------------------------------
-- Slash commands and the addon compartment (minimap) entry
---------------------------------------------------------------------------

local function Print(msg) print("|cff99ccffTicky|r: " .. msg) end

function Ticky_OnAddonCompartmentClick() ns.ToggleOptions() end

SLASH_TICKY1 = "/ticky"
SlashCmdList.TICKY = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" or cmd == "config" or cmd == "options" then
    ns.ToggleOptions()
  elseif cmd == "lock" or cmd == "unlock" then
    db.locked = cmd == "lock"
    ns.ApplyStyle()
    Print(db.locked and "Locked." or "Unlocked - drag the blue bar to move.")
  elseif cmd == "add" then
    local _, m = ns.AddSpell(rest)
    Print(m)
  elseif cmd == "remove" then
    local _, m = ns.Untrack(rest)
    Print(m)
  elseif cmd == "list" then
    for key, cfg in pairs(cdb.spells) do Print(" - " .. cfg.name .. ": " .. ns.Describe(key)) end
  elseif cmd == "preview" then
    ns.SetPreview(not ns.preview)
    Print(ns.preview and "Preview on." or "Preview off.")
  elseif cmd == "reset" then
    ns.ResetSettings()
    Print("Appearance and alert settings reset. Your spells are unchanged.")
  else
    Print("/ticky [options | lock | unlock | add <spell> | remove <spell> | list | preview | reset]")
  end
end
