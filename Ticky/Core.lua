-- Ticky core: settings, reading auras and channels, alerts, events, slash commands.
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

local GetTime, ipairs, pairs, wipe, tonumber, floor, abs, min = GetTime, ipairs, pairs, wipe, tonumber, math.floor, math.abs, math.min

local DB_VERSION = 7

ns.REPO_URL = "https://github.com/addohm/ticky-timers"
ns.ISSUES_URL = ns.REPO_URL .. "/issues"

-- Account-wide look and behaviour. Spell choices are per character (TickyCharDB).
ns.DEFAULTS = {
  version = DB_VERSION,
  point = { "CENTER", 0, -160 },
  locked = false,
  -- Bars
  width = 220, height = 18, scale = 1,
  texture = "Blizzard", bgColor = { 0, 0, 0 }, bgAlpha = 0.55, fillMode = "drain", reverse = false,
  borderSize = 0, borderColor = { 0, 0, 0 }, spark = false,
  showIcon = true, iconSide = "LEFT",
  lowEnabled = false, lowSeconds = 3, lowColor = { 1, 0.25, 0.25 },
  -- Layout
  spacing = 3, growUp = false, sortMode = "name",
  missingMode = "hide", missingAlpha = 0.5, missingColor = { 0.35, 0.35, 0.35 }, missingDesaturate = true,
  missingOnlyInCombat = false, missingMatchTarget = true,
  -- Text & ticks
  showName = true, showTime = true, showTickCount = true, showStacks = true,
  font = "Friz Quadrata", fontSize = 11, outline = "OUTLINE", shadow = false,
  nameColor = { 1, 1, 1 }, timeColor = { 1, 1, 1 }, timeSide = "RIGHT", decimals = 10,
  tickColor = { 1, 1, 1 }, tickWidth = 2, tickHeight = 1, pastTicks = "dim",
  highlightNext = true, nextColor = { 1, 0.85, 0.2 },
  -- Sounds and alerts
  applySound = "NONE", refreshSound = "NONE", tickSound = "NONE",
  warnSound = "NONE", expireSound = "NONE", removeSound = "NONE",
  warnSeconds = 0, warnFlash = true,
  soundChannel = "Master", alertOtherTargets = true, alertOnlyInCombat = false,
  msgWarn = false, msgExpire = false, msgRemove = false,
  customSounds = {}, -- sound file paths or file IDs the player added
  -- Health bar overlay
  overlayDamage = false, overlayHeal = false, overlayPlates = false, overlayColors = "single",
  overlayDamageColor = { 0.1, 0.1, 0.1 }, overlayHealColor = { 0.2, 1, 0.3 }, overlayAlpha = 0.6,
  overlayTexture = "Flat", overlayDividers = true, overlayFrame = "",
  overlaySmooth = true, overlaySpark = true, overlaySparkColor = { 1, 1, 1 },
  overlayOutline = 0, overlayOutlineColor = { 0, 0, 0 },
  -- Nameplates
  plateEnabled = false, plateWhich = "others", plateAnchor = "TOP", plateOffsetY = 4,
  plateHeightPct = 0.07, plateSpacing = 1, plateShowIcon = true, plateShowName = false,
  plateShowTime = true, plateShowTickCount = false, plateFontSize = 8,
  plateOwnLook = false, plateTexture = "Blizzard", plateBgColor = { 0, 0, 0 }, plateBgAlpha = 0.6,
  plateBorderSize = 1, plateBorderColor = { 0, 0, 0 }, plateFillMode = "drain", plateSpark = false,
  plateTickColor = { 1, 1, 1 }, plateFont = "Friz Quadrata", plateOutline = "OUTLINE",
  -- General
  hideMain = false, showChannel = true, showSelf = true, hideOutOfCombat = false, hideNoTarget = false,
  alpha = 1, oocAlpha = 1, showAll = false, previewInOptions = true,
}

ns.CHAR_DEFAULTS = {
  -- [lower-case name] = { name, id, icon, color, order, label, speech, missing, warnSeconds,
  --   anyCaster, noOverlay, noPlate, isChannel, applySound, refreshSound, tickSound, warnSound, expireSound, removeSound }
  spells = {},
  nextOrder = 1,
  durations = {}, -- [spellID] = seconds the aura lasted when last read (so talents are included)
  tickSizes = {}, -- [spellID] = average non-crit tick (damage or healing) seen on UNIT_COMBAT
}

-- The alert events a spell can play a sound for, in the order the options show them.
ns.SOUND_EVENTS = {
  { "applySound", "When you put it on", "%s" },
  { "refreshSound", "When you refresh it", "%s refreshed" },
  { "tickSound", "On every tick", "%s" },
  { "warnSound", "Warning before it ends", "%s ending" },
  { "expireSound", "When it ends", "%s down" },
  { "removeSound", "When it's removed early", "%s removed" },
}
local SPEECH = {}
for _, e in ipairs(ns.SOUND_EVENTS) do SPEECH[e[1]] = e[3] end

-- On-screen messages, keyed by the setting that turns them on.
local MESSAGES = { warnSound = { "msgWarn", "%s ends soon" }, expireSound = { "msgExpire", "%s has ended" },
  removeSound = { "msgRemove", "%s was removed" } }

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
  -- Sound files that come with Ticky (tools/make_sounds.py).
  { "F:Interface\\AddOns\\Ticky\\Sounds\\beep.ogg", "Ticky beep" },
  { "F:Interface\\AddOns\\Ticky\\Sounds\\chime.ogg", "Ticky chime" },
}

ns.CHANNELS = { { "Master", "Master" }, { "SFX", "Effects" }, { "Dialog", "Dialog" }, { "Ambience", "Ambience" } }

-- Every sound a cycle can offer: the stock list, text to speech, then the player's own files.
function ns.SoundChoices(withDefault)
  local out = {}
  if withDefault then out[1] = { "DEFAULT", "Use default (Sounds tab)" } end
  for _, e in ipairs(ns.SOUNDS) do out[#out + 1] = { e[1], e[2] } end
  out[#out + 1] = { "SPEAK", "Say it (text to speech)" }
  local db = ns.DB()
  for _, f in ipairs(db and db.customSounds or {}) do
    out[#out + 1] = { "F:" .. f, "File: " .. (tostring(f):match("([^\\/]+)$") or f) }
  end
  return out
end

local PALETTE = {
  { 0.80, 0.35, 1.00 }, { 0.30, 0.55, 1.00 }, { 0.30, 0.85, 0.40 }, { 0.95, 0.75, 0.25 },
  { 1.00, 0.40, 0.40 }, { 0.40, 0.90, 0.90 }, { 1.00, 0.55, 0.85 }, { 0.75, 0.75, 0.75 },
}

-- All auras are read; each is kept if you cast it, or if its spell is set to "from anyone".
local AURA_FILTERS = { "HARMFUL", "HELPFUL" }

local db, cdb
local channel            -- the player's current tracked channel
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

-- Seconds in "18 sec", "2 min", "1 hour" (or nil).
local UNIT_SECONDS = { sec = 1, min = 60, hour = 3600 }
local function Seconds(n, unit) return tonumber(n) and UNIT_SECONDS[unit] and tonumber(n) * UNIT_SECONDS[unit] end

-- How long a spell's aura lasts according to its tooltip: the last "over N sec" (the periodic
-- part), else "lasts N sec", else the first "for N sec". The tooltip is the client's current one.
local function DescriptionDuration(d)
  local over
  for n, u in d:gmatch("over ([%d%.]+) (%a+)") do over = Seconds(n, u:gsub("s$", "")) or over end
  if over then return over end
  local n, u = d:match("lasts ([%d%.]+) (%a+)")
  local lasts = n and Seconds(n, u:gsub("s$", ""))
  if lasts then return lasts end
  n, u = d:match("for ([%d%.]+) (%a+)")
  return n and Seconds(n, u:gsub("s$", ""))
end

-- School masks by the word a tooltip uses ("30 Shadow damage over 18 sec").
local SCHOOLS = { physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64 }

-- The amount and school in the clause that ends at `stop` (an index into `d`): the last number
-- before it, and the school word between that number and the end. School is nil when the clause
-- doesn't say "damage" (a heal).
local function ClauseAmount(d, stop)
  local lead = d:sub(1, stop - 1)
  local numAt, numEnd, n
  local i = 1
  while true do
    local s, e, found = lead:find("(%d+)", i)
    if not s then break end
    numAt, numEnd, n, i = s, e, found, e + 1
  end
  if not n then return end
  local words = lead:sub(numEnd + 1)
  local school
  if words:find("damage") then
    school = 1
    for w in words:gmatch("%a+") do
      if SCHOOLS[w] then school = SCHOOLS[w] end
    end
  end
  return tonumber(n), school
end

-- What a tooltip says the periodic part deals or heals in total, and its school. The periodic part
-- is the clause ending "over <time>" (the last one, after any direct part such as Holy Fire's);
-- failing that, "<amount> every <period>" times the number of periods in its duration.
local function DescriptionAmount(d)
  local total, school
  local from = 1
  while true do
    local s, e = d:find(" over [%d%.]+ %a+", from)
    if not s then break end
    local n, sc = ClauseAmount(d, s)
    if n then total, school = n, sc end
    from = e + 1
  end
  if total then return total, school end
  local s, _, every = d:find(" every ([%d%.]+) sec")
  local lasts = DescriptionDuration(d)
  if s and tonumber(every) and lasts then
    local n, sc = ClauseAmount(d, s)
    if n then return n * floor(lasts / tonumber(every) + 0.5), sc end
  end
end

-- What a spell's tooltip says: "every N sec" ticks, whether it's timed, for how long, and how
-- much it deals or heals over that time. Also the fallback for spells missing from Data.lua.
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
  d = d:lower():gsub("(%d),(%d)", "%1%2")
  local every = tonumber(d:match("every ([%d%.]+) sec")) or ((d:find("every sec") or d:find("per sec")) and 1) or nil
  local periodic = every ~= nil or d:find("over [%d%.]+ sec") ~= nil or d:find("over [%d%.]+ min") ~= nil
  c = {
    every = every,
    periodic = periodic,
    duration = DescriptionDuration(d),
    timed = periodic or d:find("for [%d%.]+ sec") ~= nil or d:find("for [%d%.]+ min") ~= nil
      or d:find("lasts [%d%.]+ sec") ~= nil or d:find("lasts [%d%.]+ min") ~= nil,
  }
  c.amount, c.school = DescriptionAmount(d)
  descCache[id] = c
  return c
end
ns.TooltipInfo = DescriptionInfo

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

-- "harm" (cast on enemies), "help" (on friends or yourself) or "any".
local kindCache = {}
local function SpellKind(id)
  local k = kindCache[id]
  if k == nil then
    local harm = C_Spell.IsSpellHarmful and C_Spell.IsSpellHarmful(id)
    local help = C_Spell.IsSpellHelpful and C_Spell.IsSpellHelpful(id)
    if Secret(harm) or Secret(help) then return "any" end
    k = (harm and not help and "harm") or (help and not harm and "help") or "any"
    kindCache[id] = k
  end
  return k
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

-- A timer from a readable aura, or nil (secret, untracked, someone else's, or no duration).
local function TimerFromAura(aura)
  if Secret(aura) then return end
  local id, duration, expires = aura.spellId, aura.duration, aura.expirationTime
  if Secret(id) or Secret(duration) or Secret(expires) or not id or not duration or duration <= 0 then return end
  local name, icon = SpellInfo(id)
  if not name then return end
  local key = name:lower()
  local cfg = cdb.spells[key]
  if not cfg or cfg.isChannel then return end
  local mine = FromMe(aura)
  if not cfg.anyCaster and not mine then return end
  local stacks = aura.applications
  if Secret(stacks) or type(stacks) ~= "number" then stacks = nil end
  return {
    key = key, name = name, icon = icon or cfg.icon, stacks = stacks, spellID = id, mine = mine,
    start = expires - duration, expires = expires, interval = AuraPeriod(id),
  }
end

-- Tracked auras on a unit. Returns nil if they couldn't be read at all (on Forever, reading a
-- target's auras in combat fails), else the timers and whether every aura was readable.
local function ScanUnit(unit)
  local out, complete = {}, true
  local ok = pcall(function()
    for _, filter in ipairs(AURA_FILTERS) do
      for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if aura == nil then break end
        if Secret(aura) or Secret(aura.spellId) or Secret(aura.expirationTime) then complete = false end
        local t = TimerFromAura(aura)
        if t then out[#out + 1] = t end
      end
    end
  end)
  if ok then return out, complete end
end

local function HasTarget()
  local exists = UnitExists("target")
  return Secret(exists) or exists and true or false
end
ns.HasTarget = HasTarget

local function IsDead(unit)
  local dead = UnitIsDeadOrGhost(unit)
  return not Secret(dead) and dead == true
end

local function NameOf(unit)
  local n = UnitName(unit)
  if n and not Secret(n) then return n end
end

-- The nameplate token ("nameplate3") showing the mob behind `unit`, or nil.
local function PlateToken(unit)
  if unit:match("^nameplate%d+$") then return unit end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" or Secret(plate) or type(plate.GetUnit) ~= "function" then return end
  local token -- Blizzard's nameplate frames answer GetUnit() with their token
  ok, token = pcall(plate.GetUnit, plate)
  if ok and type(token) == "string" and not Secret(token) and token:match("^nameplate%d+$") then return token end
end

-- A stable key for the unit's mob: its GUID when readable (open world, players), else
-- "plate:nameplateN" while it has a nameplate (instances hide creature GUIDs), else "target"
-- for the current target only. nil if the unit can't be tracked.
local function MobKey(unit)
  if not unit or Secret(unit) then return end
  local g = GuidOf(unit)
  if g then return g end
  local exists = UnitExists(unit)
  if not Secret(exists) and not exists then return end
  local token = PlateToken(unit)
  if token then return "plate:" .. token end
  if unit == "target" then return "target" end
end

-- The unit token for a mob key right now, if it has one (for death checks).
local function UnitForMob(mob)
  if not mob or mob == "target" then return mob end
  local token = mob:match("^plate:(nameplate%d+)$")
  if token then return token end
  token = UnitTokenFromGUID and UnitTokenFromGUID(mob)
  if token and not Secret(token) then return token end
end

-- Alerts -----------------------------------------------------------------

-- A spell's own sound for an event, else the default from the Sounds tab.
local function SoundFor(key, which)
  local cfg = cdb.spells[key]
  local own = cfg and cfg[which]
  if own and own ~= "DEFAULT" then return own end
  return db[which]
end
ns.SoundFor = SoundFor

-- Seconds before the end that the warning fires: the spell's own, else the default.
local function WarnSeconds(key)
  local cfg = cdb.spells[key]
  local own = cfg and cfg.warnSeconds
  if own and own > 0 then return own end
  return db.warnSeconds
end
ns.WarnSeconds = WarnSeconds

-- The words "Say it" speaks: the spell's spoken text, its bar text, or its name.
local function SpokenName(key, fallback)
  local cfg = cdb.spells[key]
  if cfg and cfg.speech and cfg.speech ~= "" then return cfg.speech end
  if cfg and cfg.label and cfg.label ~= "" then return cfg.label end
  return fallback or (cfg and cfg.name) or key
end

local function Speak(text)
  if not text or text == "" or not (C_VoiceChat and C_VoiceChat.SpeakText and C_TTSSettings) then return end
  pcall(function()
    local voice = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
    C_VoiceChat.SpeakText(voice, text, C_TTSSettings.GetSpeechRate(), C_TTSSettings.GetSpeechVolume(), true)
  end)
end

-- A sound file as the game wants it: a file ID, or a path from the WoW folder with backslashes
-- ("Interface\AddOns\MySounds\ding.ogg"). Pasted full paths, quotes and forward slashes are
-- cleaned up. Returns the file and a warning, or nil and why it can't be one.
function ns.CleanSoundPath(input)
  local f = strtrim(input or ""):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
  f = strtrim(f)
  if f == "" then return nil, "Enter a file path or a sound file ID." end
  if f:match("^%d+$") then return f end
  f = f:gsub("/", "\\"):gsub("\\+", "\\")
  local at = f:lower():find("interface\\", 1, true)
  if not at then
    return nil, "A path has to be inside the WoW folder and start with Interface\\ (for example "
      .. "Interface\\AddOns\\MySounds\\ding.ogg)."
  end
  f = f:sub(at)
  local ext = f:lower():match("%.(%w+)$")
  if not ext then return nil, "Include the file's extension, for example ding.ogg." end
  if ext ~= "ogg" and ext ~= "mp3" then return f, ".ogg and .mp3 files are the safest; other types may not play." end
  return f
end

-- Play a sound choice: a SOUNDKIT name, "SPEAK" (says `text`), or "F:" plus a file path or file ID.
-- For files, returns whether the game said it will play it.
function ns.PlaySound(key, text)
  if not key or key == "NONE" or key == "DEFAULT" then return end
  if key == "SPEAK" then return Speak(text) end
  if key:sub(1, 2) == "F:" then
    local file = key:sub(3)
    if not PlaySoundFile then return false end
    local ok, willPlay = pcall(PlaySoundFile, tonumber(file) or file, db.soundChannel)
    return ok and willPlay and true or false
  end
  local e = ns.Lookup(ns.SOUNDS, key)
  local id = (SOUNDKIT and SOUNDKIT[key]) or e[3]
  if id then PlaySound(id, db.soundChannel) end
end

-- Forget a sound file the player added, and anything that was set to play it.
function ns.RemoveCustomSound(file)
  local key = "F:" .. file
  for i = #db.customSounds, 1, -1 do
    if db.customSounds[i] == file then table.remove(db.customSounds, i) end
  end
  for _, e in ipairs(ns.SOUND_EVENTS) do
    if db[e[1]] == key then db[e[1]] = "NONE" end
    for _, cfg in pairs(cdb.spells) do
      if cfg[e[1]] == key then cfg[e[1]] = nil end
    end
  end
end

-- Play what a spell would play for an event; used by the options' Test buttons.
function ns.TestSound(key, which, choice)
  ns.PlaySound(choice or SoundFor(key, which), SPEECH[which]:format(SpokenName(key)))
end

local function AlertAllowed(t)
  if db.alertOnlyInCombat and not inCombat then return false end
  if t.mob ~= MobKey("target") and t.mob ~= playerGUID then
    if not db.alertOtherTargets then return false end
    -- Don't announce DoTs falling off something that died.
    local unit = UnitForMob(t.mob)
    if unit and IsDead(unit) then return false end
  end
  return true
end

local function Alert(t, which)
  if not AlertAllowed(t) then return end
  ns.PlaySound(SoundFor(t.key, which), SPEECH[which]:format(SpokenName(t.key, t.name)))
  local m = MESSAGES[which]
  if m and db[m[1]] and ns.ShowMessage then
    local cfg = cdb.spells[t.key]
    local label = cfg and cfg.label and cfg.label ~= "" and cfg.label or t.name
    ns.ShowMessage(m[2]:format(label), cfg and cfg.color)
  end
end

local function Expire(t)
  if t.expired then return end
  t.expired = true
  Alert(t, "expireSound")
end

local function Warn(t)
  t.warned = true
  Alert(t, "warnSound")
end

-- How many of ComputeTicks' ticks have happened by `now`: one every interval from the
-- start, and the last one at expiry.
local function TicksPassed(t, now)
  local iv, span = t.interval, t.expires - t.start
  local before = math.ceil((span - 0.05) / iv) - 1 -- ticks before the one at expiry
  if now >= t.expires then return before + 1 end
  return min(before, floor((now - t.start) / iv + 0.001))
end

-- A tick sound plays each time the count goes up. The first check only sets the count.
local function CheckTick(t, now)
  local iv = t.interval
  if not iv or iv < 0.1 or t.expires - t.start <= 0 then return end
  local n = TicksPassed(t, now)
  if t.tickN and n > t.tickN then Alert(t, "tickSound") end
  t.tickN = n
end

-- Timers ---------------------------------------------------------------------
--
-- timers[mob][spellKey] holds every tracked buff and debuff Ticky knows about, on every mob.
-- Two sources feed it:
--   * your casts (UNIT_SPELLCAST_SENT/SUCCEEDED stay readable in combat): the timer starts at
--     the cast and lasts the spell's duration (learned from an earlier aura read, else its
--     tooltip). This is what works in combat, where Forever hides aura details.
--   * aura reads, whenever the game allows them (usually out of combat): exact times and stacks,
--     and they correct or remove cast timers.

local timers = {}
local learned -- cdb.durations: [spellID] = seconds, from aura reads (talents and ranks included)
local tickSizes -- cdb.tickSizes: [spellID] = damage or healing per tick, seen on UNIT_COMBAT

-- Auras that vanished early (seen by an aura read) wait a moment before counting as removed:
-- a refresh can briefly drop the aura before the new one arrives.
local gone = {} -- [mob] = { [key] = { t = timer, at = time } }
local REMOVE_GRACE = 0.3
-- A cast timer isn't judged by aura reads until its aura has had time to arrive.
local CAST_SETTLE = 1

local function MobTimers(mob)
  local list = timers[mob]
  if not list then
    list = {}
    timers[mob] = list
  end
  return list
end

-- Drop a mob's timers without alerts (it died, its plate went to another mob, ...).
local function ForgetMob(mob)
  if mob then timers[mob], gone[mob] = nil, nil end
end

-- Drop a mob's debuffs (yours on an enemy) without alerts; buffs and HoTs stay.
local function ForgetDebuffs(mob)
  local list = timers[mob]
  if not list then return end
  for key, t in pairs(list) do
    local cfg = cdb.spells[key]
    local id = t.spellID or (cfg and cfg.id)
    if not id or SpellKind(id) ~= "help" then list[key] = nil end
  end
  if gone[mob] then
    for key, g in pairs(gone[mob]) do
      if not g.t.spellID or SpellKind(g.t.spellID) ~= "help" then gone[mob][key] = nil end
    end
    if not next(gone[mob]) then gone[mob] = nil end
  end
  if not next(list) then timers[mob] = nil end
end

local function Removed(t)
  if t.expires - GetTime() > 0.5 then Alert(t, "removeSound") end
end

-- Put a timer on a mob; returns the timer it replaced.
local function Store(mob, t)
  t.mob = mob
  local list = MobTimers(mob)
  local prev = list[t.key]
  list[t.key] = t
  return prev
end

-- Read a unit's auras, if the game allows it, and merge them in.
local function ReadUnit(unit)
  local mob = MobKey(unit)
  if not mob then return end
  local list, complete = ScanUnit(unit)
  if not list then return end
  local now = GetTime()
  local mine = MobTimers(mob)
  local seen = {}
  for _, t in ipairs(list) do
    seen[t.key] = true
    t.mob = mob
    if t.mine and t.spellID then learned[t.spellID] = floor((t.expires - t.start) * 10 + 0.5) / 10 end
    local prev = mine[t.key]
    local lost = gone[mob] and gone[mob][t.key]
    if lost then gone[mob][t.key] = nil end
    if prev and abs(prev.expires - t.expires) < 0.1 then
      t.warned, t.expired, t.tickN = prev.warned, prev.expired, prev.tickN
    elseif not (prev and prev.castAt and now - prev.castAt < CAST_SETTLE + 0.5) and now - t.start < 1 then
      -- Applied just now and not by a cast we saw (out of combat someone else's, for example).
      Alert(t, (prev or lost) and "refreshSound" or "applySound")
    elseif prev then
      t.warned, t.tickN = prev.warned, prev.tickN
    end
    Store(mob, t)
  end
  if complete then
    for key, prev in pairs(mine) do
      if not seen[key] and not (prev.castAt and now - prev.castAt < CAST_SETTLE) then
        mine[key] = nil
        if prev.expires - now < 0.5 then
          if mob == MobKey("target") or mob == playerGUID then CheckTick(prev, prev.expires) end
          Expire(prev)
        else
          gone[mob] = gone[mob] or {}
          gone[mob][key] = { t = prev, at = now }
        end
      end
    end
  end
  if gone[mob] and not next(gone[mob]) then gone[mob] = nil end
  if not next(mine) then timers[mob] = nil end
end

-- Casts ----------------------------------------------------------------------

local sentTo = {}  -- [castGUID] = { mob, at }: where each cast was aimed when it was sent
local recentCast = {} -- [mob] = { t, prev, at }: the last tracked cast on each mob, for resists

-- The mob a spell cast at `name` goes to. UNIT_SPELLCAST_SENT only gives a name, and you may
-- have tabbed away by the time the cast lands, so this is worked out when it's sent.
local function MobForCast(spellID, name)
  local helpful = SpellKind(spellID) == "help"
  local me = NameOf("player")
  if helpful and (not name or name == "" or name == me) then return playerGUID end
  if name and name ~= "" then
    for _, unit in ipairs({ "target", "focus", "mouseover" }) do
      if NameOf(unit) == name then return MobKey(unit) end
    end
  end
  if helpful and not (HasTarget() and UnitCanAssist("player", "target") == true) then return playerGUID end
  return HasTarget() and MobKey("target") or nil
end

local function CastDuration(spellID)
  local d = learned[spellID]
  if d then return d end
  local info = DescriptionInfo(spellID)
  return info and info.duration
end

-- Misses, dodges, parries, resists, immunities, evades, reflects and deflects: a tracked cast
-- with one of these on its mob right around it never landed. The game can report the result a
-- moment before it reports the cast as done, so a result that comes in while a cast at that mob
-- is under way (sent, not yet done) is kept on that cast, and counts if the cast is done right
-- after. A result shortly after a done cast cancels it.
local AVOIDED = {
  RESIST = true, IMMUNE = true, EVADE = true, MISS = true, DODGE = true, PARRY = true,
  REFLECT = true, DEFLECT = true,
}
-- In game the result arrived in the same tenth of a second as the cast (2026-10-21); keeping the
-- windows tight keeps other players' misses on the mob from being taken for yours.
local AVOID_AFTER = 0.3  -- seconds after a cast is done that its result may still arrive
local AVOID_BEFORE = 0.3 -- ...and before
local avoidLog = {}      -- the last few, for /ticky debug

-- Could this avoid be the spell's own? UNIT_COMBAT reports every attack on the mob, yours or
-- anyone's. Spells can't be dodged, parried or blocked, so those only count for physical spells.
-- The game labels a spell's own miss Physical (school 1, seen in game 2026-10-21), so Physical
-- says nothing; another non-Physical school than the spell's does rule it out.
local MELEE_ONLY = { DODGE = true, PARRY = true, BLOCK = true }
local function SchoolFits(school, spellID, action)
  local info = DescriptionInfo(spellID)
  local spellSchool = info and info.school
  if MELEE_ONLY[action] then return not spellSchool or spellSchool == 1 end
  if not school or school <= 1 or not spellSchool then return true end
  return school == spellSchool
end

-- One of your tracked spells landed: start (or restart) its timer on the mob it was aimed at.
local function OnCast(castGUID, spellID)
  local sent = castGUID and not Secret(castGUID) and sentTo[castGUID]
  if sent then sentTo[castGUID] = nil end
  local name, icon = SpellInfo(spellID)
  if not name then return end
  local key = name:lower()
  local cfg = cdb.spells[key]
  local d = ns.Data[spellID]
  if not cfg or cfg.isChannel or (d and d.d) then return end
  local mob
  if sent then mob = sent.mob else mob = MobForCast(spellID, nil) end
  local duration = CastDuration(spellID)
  if not mob or not duration or duration <= 0 then return end
  local now = GetTime()
  local t = {
    key = key, name = name, icon = icon or cfg.icon, spellID = spellID, castAt = now,
    start = now, expires = now + duration, interval = AuraPeriod(spellID), mob = mob,
  }
  local list = timers[mob]
  local prev = list and list[key]
  if sent and sent.avoidedAt and now - sent.avoidedAt <= AVOID_BEFORE and SpellKind(spellID) ~= "help"
    and SchoolFits(sent.avoidSchool, spellID, sent.avoidAction) then
    -- Its miss (or resist, ...) already came in: the old timer, if any, carries on.
    if sent.avoidEntry then sent.avoidEntry.result = "cancelled " .. name .. " (came first)" end
    if not (prev and prev.expires > now) then Removed(t) end
    return
  end
  if sent and sent.avoidedAt and sent.avoidEntry and sent.avoidEntry.result == "kept for the cast under way" then
    sent.avoidEntry.result = "ignored for " .. name .. ": not the spell's (school or melee-only)"
  end
  prev = Store(mob, t)
  if prev and prev.expires > now then
    t.stacks = prev.stacks
    Alert(t, "refreshSound")
  else
    Alert(t, "applySound")
  end
  recentCast[mob] = { t = t, prev = prev, at = now }
end

-- An avoid on a mob: cancel the tracked cast just before it, or remember it for the cast that's
-- about to be reported. `school`: the avoided attack's school, if the game said.
local function OnAvoided(mob, action, school, unit)
  local now = GetTime()
  -- The same result arrives for each unit token showing the mob (target, softenemy, nameplateN).
  local last = avoidLog[1]
  if last and last.mob == mob and last.action == action and now == last.at then return end
  local entry = { at = now, action = action, school = school, unit = unit, mob = mob }
  table.insert(avoidLog, 1, entry)
  avoidLog[6] = nil
  local c = recentCast[mob]
  if not c or now - c.at > AVOID_AFTER or SpellKind(c.t.spellID) == "help" then
    -- Maybe the result of a cast at this mob that's under way: keep it on that cast.
    local pending = 0
    for _, sent in pairs(sentTo) do
      if sent.mob == mob and now - sent.at < 10 then
        sent.avoidedAt, sent.avoidSchool, sent.avoidAction, sent.avoidEntry = now, school, action, entry
        pending = pending + 1
      end
    end
    entry.result = pending > 0 and "kept for the cast under way" or "no tracked cast on that mob"
    return
  end
  if not SchoolFits(school, c.t.spellID, action) then
    entry.result = "ignored: not the spell's (school or melee-only)"
    return
  end
  recentCast[mob] = nil
  local list = timers[mob]
  if not list or list[c.t.key] ~= c.t then
    entry.result = "cast already replaced"
    return
  end
  entry.result = "cancelled " .. c.t.name
  if c.prev and c.prev.expires > now then
    list[c.t.key] = c.prev -- a refresh that missed leaves the old one running
  else
    list[c.t.key] = nil
    Removed(c.t)
  end
end

local toRead = {}
-- Tick amounts --------------------------------------------------------------
--
-- For the health bar overlay: how much a DoT or HoT will still deal or heal. Per tick, that's
-- what its ticks actually did (UNIT_COMBAT on the unit, matched to the timer by school and
-- timing, crits left out), else the tooltip's total over its tick count (no spell power).

local function ExpectedTick(spellID)
  local size = tickSizes[spellID]
  if size then return size end
  local info = DescriptionInfo(spellID)
  local d = ns.Data[spellID]
  if not (info and info.amount and d and d.p) then return end
  local span = d.d and d.d / 1000 or info.duration
  if not span then return end
  return info.amount / math.max(1, floor(span / (d.p / 1000) + 0.5))
end

-- How much the timer will still deal or heal, or nil if unknown.
-- When does a tick count as done for the shading? Together with the health change it causes, so
-- the shading shrinks in the same moment the health drops and its far end holds still. The game
-- reports the hit (UNIT_COMBAT) and the health change (UNIT_HEALTH) separately, in the same frame
-- and in either order (in game, 2026-10-21: no later health message came). A seen tick counts on
-- its mob's UNIT_HEALTH (at once if that came earlier in the same frame), or PENDING_MAX after the
-- hit if none came. A tick never seen counts once its time is UNSEEN_TICK_GRACE past.
local UNSEEN_TICK_GRACE = 0.5
local PENDING_MAX = 0.2
-- The health end is held too: the game can update a unit's health a few frames before it sends
-- UNIT_HEALTH, so a routine redraw could move it ahead of the shading. From just before a tick is
-- due until it's counted (or the grace runs out), the overlay keeps the health it last drew.
local HOLD_BEFORE = 0.5  -- wide: ticks can land a little before or after when they're expected
local healthAt = {}      -- [mob] = when its health last changed
local healthAtAny = 0    -- the last health message for a unit Ticky couldn't tell apart
-- The shading is drawn from the frame update, not inside the events: after a tick or a health
-- message it's due, and the next frame draws it (/ticky sparktest held still drawn that way).
local drawDue = false

-- When `mob`'s health last changed, for the shading: it sets its health end only then.
function ns.HealthAt(mob)
  return math.max(mob and healthAt[mob] or 0, healthAtAny)
end

-- The last tick on your target, step by step, for /ticky debug: when its hit came (and how far off
-- the expected time), when the health message came, when it was counted, when the shading moved.
local trace
function ns.TickTrace() return trace end
local function TraceFor(mob) return trace and trace.mob == mob and trace end

local function Commit(t)
  if t.pendingTick then
    t.lastTick = math.max(t.lastTick or 0, t.pendingTick)
    t.pendingTick = nil
    local tr = TraceFor(t.mob or (t.channel and MobKey("target")))
    if tr and tr.timer == t and not tr.counted then tr.counted = GetTime() end
  end
end

-- The next tick of a timer that hasn't been counted yet, and when it's due (nil if none left).
local function NextTick(t, now)
  if not t.interval or t.interval < 0.1 then return end
  -- Past the ticks seen, counted, or gone by unseen.
  local n = math.max(t.matchedTick or 0, t.lastTick or 0, TicksPassed(t, now - UNSEEN_TICK_GRACE)) + 1
  local total = TicksPassed(t, t.expires)
  if n > total then return end
  return n, n == total and t.expires or t.start + n * t.interval
end

-- Should the overlay keep the health it last drew for this unit? While one of its ticks is seen but
-- not yet counted, or due and not yet seen.
function ns.HoldHealth(unit, now)
  local mob = MobKey(unit)
  local function holds(t)
    if t.pendingTick then return true end
    local n, due = NextTick(t, now)
    return n and now >= due - HOLD_BEFORE and now <= due + UNSEEN_TICK_GRACE
  end
  for _, t in pairs(mob and timers[mob] or {}) do
    if holds(t) then return true end
  end
  if channel and mob and mob == (HasTarget() and MobKey("target")) and holds(channel) then return true end
  return false
end

function ns.RemainingAmount(t, now)
  if not t.spellID or not t.interval or t.interval < 0.1 or t.expires <= now then return end
  local size = ExpectedTick(t.spellID)
  if not size then return end
  if t.pendingTick and now - t.pendingAt > PENDING_MAX then Commit(t) end
  local done = math.max(t.lastTick or 0, TicksPassed(t, now - UNSEEN_TICK_GRACE))
  return math.max(0, TicksPassed(t, t.expires) - done) * size
end

local TICK_WINDOW = 0.35
local lastHit

local function OnTickAmount(mob, isHeal, amount, school, crit)
  local now = GetTime()
  local sig = mob .. ":" .. amount .. ":" .. school .. ":" .. now
  if sig == lastHit then return end -- the same hit arrives for target, nameplateN, focus
  lastHit = sig
  local best, bestK, bestDist
  local function consider(t)
    if not t.spellID or not t.interval or t.interval < 0.1 then return end
    local helpful = SpellKind(t.spellID) == "help"
    if helpful ~= isHeal then return end
    local info = DescriptionInfo(t.spellID)
    if not isHeal and info and info.school and info.school ~= school then return end
    local k = floor((now - t.start) / t.interval + 0.5)
    local dist = abs(now - (t.start + k * t.interval))
    local last = TicksPassed(t, t.expires)
    if abs(now - t.expires) < dist then k, dist = last, abs(now - t.expires) end
    if k >= 1 and k <= last and dist <= TICK_WINDOW and k > (t.matchedTick or 0)
      and (not bestDist or dist < bestDist) then
      best, bestK, bestDist = t, k, dist
    end
  end
  for _, t in pairs(timers[mob] or {}) do consider(t) end
  if channel and not isHeal and mob == MobKey("target") then consider(channel) end
  if not best then return end
  best.matchedTick = bestK
  best.pendingTick, best.pendingAt = bestK, now
  local healthNow = healthAt[mob] == now -- its health message came first, in this frame
  -- Learn where this DoT's ticks really land, so the next ones are expected (and drawn) there.
  local expected = bestK == TicksPassed(best, best.expires) and best.expires or best.start + bestK * best.interval
  local off = now - expected
  if not best.channel then
    best.start, best.expires = best.start + off * 0.5, best.expires + off * 0.5
  end
  if mob == (HasTarget() and MobKey("target")) then
    trace = { mob = mob, timer = best, name = best.name, hit = now, off = off, amount = amount,
      health = healthNow and now or nil }
  end
  if healthNow then
    Commit(best)
    drawDue = true
  end
  if crit then return end
  local id, old = best.spellID, tickSizes[best.spellID]
  -- Something else's hit that happened to line up: far off what this spell has been doing.
  if old and (amount < old * 0.4 or amount > old * 3) then return end
  tickSizes[id] = old and floor(old * 0.6 + amount * 0.4 + 0.5) or amount
end

local function CheckAlerts(now)
  local targetMob = HasTarget() and MobKey("target")
  if targetMob and IsDead("target") then ForgetMob(targetMob) end
  wipe(toRead)
  for mob, list in pairs(timers) do
    local ticking = mob == targetMob or mob == playerGUID
    for key, t in pairs(list) do
      if ticking then CheckTick(t, now) end
      -- Once a cast's aura has had time to arrive, read it if the game lets us (out of combat).
      if t.castAt and not t.checked and now - t.castAt > CAST_SETTLE + 0.1 then
        t.checked = true
        toRead[#toRead + 1] = UnitForMob(mob)
      end
      if now >= t.expires then
        Expire(t)
        list[key] = nil
      else
        local warn = WarnSeconds(key)
        if not t.warned and warn > 0 and t.expires - now <= warn then Warn(t) end
      end
    end
    if not next(list) then timers[mob] = nil end
  end
  for mob, lost in pairs(gone) do
    for key, g in pairs(lost) do
      if now - g.at > REMOVE_GRACE then
        lost[key] = nil
        Removed(g.t)
      end
    end
    if not next(lost) then gone[mob] = nil end
  end
  if channel then CheckTick(channel, now) end
  for _, unit in ipairs(toRead) do ReadUnit(unit) end
end

-- A channel that ran its course (or nearly) gets its last tick before it goes.
local function EndChannel(now)
  if not channel then return end
  CheckTick(channel, channel.expires - now < 0.15 and channel.expires or now)
  channel = nil
end

-- Refreshing ----------------------------------------------------------------

local function sortKey(e)
  if db.sortMode == "remaining" then return e.expires end
  if db.sortMode == "custom" then
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

local function RefreshDisplay()
  if HasTarget() then ReadUnit("target") end
  ReadUnit("player")
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
    for _, list in pairs(timers) do list[key] = nil end
  end
  local start, finish = startMS / 1000, endMS / 1000
  local t = {
    key = key, name = name, icon = icon, channel = true, mob = playerGUID, spellID = spellID,
    start = start, expires = finish, interval = ChannelPeriod(spellID, finish - start),
  }
  if channel and channel.key == key and abs(channel.start - start) < 0.1 then t.tickN = channel.tickN end
  return t
end

-- Missing spells --------------------------------------------------------------

-- How a tracked spell shows while it isn't on your target: "hide", "space" or "show".
local function MissingMode(cfg)
  local m = cfg.missing
  if m and m ~= "DEFAULT" then return m end
  return db.missingMode
end

local function FitsTarget(cfg)
  if not db.missingMatchTarget or not cfg.id then return true end
  local kind = SpellKind(cfg.id)
  if kind == "any" then return true end
  local ok
  if kind == "harm" then ok = UnitCanAttack("player", "target") else ok = UnitCanAssist("player", "target") end
  return Secret(ok) or ok == true
end

local placeholders = {}
local function Placeholder(key, cfg, mode)
  local p = placeholders[key]
  if not p then
    p = { key = key, start = 0, expires = math.huge }
    placeholders[key] = p
  end
  p.name, p.icon, p.missing, p.channel = cfg.name, cfg.icon, mode, cfg.isChannel
  return p
end

-- Building the display list --------------------------------------------------------

local active, group, present = {}, {}, {}
-- `extra` is the channel timer: added to this group in your own order, otherwise shown on
-- top and only marked present here so it doesn't also get a missing bar.
local function AddGroup(list, now, youTag, extra, addExtra, missingTest)
  wipe(group)
  wipe(present)
  for _, e in ipairs(list) do
    if e.expires > now then
      e.youTag = youTag
      group[#group + 1] = e
      present[e.key] = true
    end
  end
  if extra and not present[extra.key] then
    present[extra.key] = true
    if addExtra then
      extra.youTag = nil
      group[#group + 1] = extra
    end
  end
  if missingTest then
    for key, cfg in pairs(cdb.spells) do
      if not present[key] then
        local mode = MissingMode(cfg)
        if mode ~= "hide" and missingTest(cfg) then group[#group + 1] = Placeholder(key, cfg, mode) end
      end
    end
  end
  table.sort(group, byMode)
  for _, e in ipairs(group) do active[#active + 1] = e end
end

-- The bars to show, top to bottom: your channel (or, in your own order, in its slot),
-- your target's auras with any missing spells, then your own auras.
-- `targetList`/`selfList` are timers, `chan` the channel timer, `missingTest(cfg)` says
-- whether a missing spell gets a placeholder (nil: none).
function ns.BuildDisplay(now, targetList, selfList, chan, missingTest, youTag)
  wipe(active)
  local custom = db.sortMode == "custom"
  if chan and (chan.expires <= now or not db.showChannel) then chan = nil end
  if chan and not custom then active[1] = chan end
  AddGroup(targetList, now, false, chan, custom, missingTest)
  if selfList then AddGroup(selfList, now, youTag) end
  return active
end

-- A mob's timers as a list (reused tables; the display reads them right away).
local targetList, selfList = {}, {}
local function ListOf(mob, out)
  wipe(out)
  local list = mob and timers[mob]
  if list then
    for _, t in pairs(list) do out[#out + 1] = t end
  end
  return out
end

function ns.ActiveTimers(now)
  if channel and channel.expires <= now then EndChannel(now) end
  local hasTarget = HasTarget()
  local targetMob = hasTarget and MobKey("target")
  if targetMob and IsDead("target") then ForgetMob(targetMob) end
  local missingTest
  if hasTarget and not IsDead("target") and (inCombat or not db.missingOnlyInCombat) then
    missingTest = FitsTarget
  end
  local mine = (db.showSelf and targetMob ~= playerGUID) and ListOf(playerGUID, selfList) or nil
  return ns.BuildDisplay(now, ListOf(targetMob, targetList), mine, channel, missingTest, hasTarget)
end

-- A unit's timers for its nameplate, in bar order (into `out`), and its mob key.
function ns.UnitTimers(unit, now, out)
  wipe(out)
  local mob = MobKey(unit)
  local list = mob and timers[mob]
  if list then
    for _, t in pairs(list) do
      local cfg = cdb.spells[t.key]
      if t.expires > now and cfg and not cfg.noPlate then out[#out + 1] = t end
    end
    table.sort(out, byMode)
  end
  return out, mob
end
ns.MobKey = MobKey

-- What your DoTs and HoTs on a unit (the target, a nameplate) will still deal and heal, for the
-- health bar overlay: two lists of { key, amount, color } in bar order (reused tables, so use them
-- before the next call), or nil when the unit isn't there or is dead.
local damageList, healList, amountsSrc = {}, {}, {}
function ns.UnitAmounts(unit, now)
  local exists = UnitExists(unit)
  if (not Secret(exists) and not exists) or IsDead(unit) then return end
  local mob = MobKey(unit)
  ListOf(mob, amountsSrc)
  -- Your channel is on your target.
  if channel and channel.expires > now and SpellKind(channel.spellID or 0) ~= "help"
    and mob and mob == (HasTarget() and MobKey("target")) then
    amountsSrc[#amountsSrc + 1] = channel
  end
  table.sort(amountsSrc, byMode)
  wipe(damageList)
  wipe(healList)
  for _, t in ipairs(amountsSrc) do
    local cfg = cdb.spells[t.key]
    local amount = cfg and not cfg.noOverlay and ns.RemainingAmount(t, now)
    if amount and amount > 0 then
      local out = SpellKind(t.spellID) == "help" and healList or damageList
      out[#out + 1] = { key = t.key, amount = amount, color = cfg.color }
    end
  end
  return damageList, healList
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

-- Tracked spell keys in your own order (the "Your order" bar order).
function ns.OrderedSpells()
  local keys = {}
  for key in pairs(cdb.spells) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    local oa, ob = cdb.spells[a].order or 0, cdb.spells[b].order or 0
    if oa == ob then return a < b end
    return oa < ob
  end)
  return keys
end

-- Move a tracked spell one place up (-1) or down (+1) in your own order.
function ns.MoveSpell(key, dir)
  local keys = ns.OrderedSpells()
  for i, k in ipairs(keys) do cdb.spells[k].order = i end
  cdb.nextOrder = #keys + 1
  local i = cdb.spells[key] and cdb.spells[key].order
  local j = i and i + dir
  if not j or j < 1 or j > #keys then return end
  cdb.spells[keys[i]].order, cdb.spells[keys[j]].order = j, i
end

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
  for _, list in pairs(timers) do list[key] = nil end
  for _, lost in pairs(gone) do lost[key] = nil end
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
  local point, sounds = db.point, db.customSounds
  wipe(db)
  for k, v in pairs(ns.CopyDefaults(ns.DEFAULTS, {})) do db[k] = v end
  db.point, db.customSounds = point, sounds
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
    -- 0.6.0 renamed the "order you added them" sort to "your order" (reorderable).
    if TickyDB.sortMode == "added" then TickyDB.sortMode = "custom" end
    -- 0.6.0: a warning sound picked while the warning time was Off never played; give it 3s.
    local wantsWarning = TickyDB.warnSound and TickyDB.warnSound ~= "NONE"
    for _, cfg in pairs(TickyCharDB.spells) do
      if cfg.warnSound and cfg.warnSound ~= "NONE" then wantsWarning = true end
    end
    if wantsWarning and (TickyDB.warnSeconds or 0) == 0 then TickyDB.warnSeconds = 3 end
    -- 0.6.0: the health bar shading shows one segment with the total by default, in a dark color
    -- that reads on any health bar color (the old red vanished on red enemy bars).
    if (TickyDB.version or 0) < 7 then
      if TickyDB.overlayColors == "each" then TickyDB.overlayColors = "single" end
      local c = TickyDB.overlayDamageColor
      if c and c[1] == 0.9 and c[2] == 0.1 and c[3] == 0.1 then TickyDB.overlayDamageColor = { 0.1, 0.1, 0.1 } end
    end
    TickyDB.version = DB_VERSION
  end
  db = ns.CopyDefaults(ns.DEFAULTS, TickyDB)
  db.plateWidth, db.plateHeight, db.plateOffsetX = nil, nil, nil -- replaced by plateHeightPct
  cdb = TickyCharDB
  learned = cdb.durations
  tickSizes = cdb.tickSizes

  ns.CreateBars()
  ns.CreateOverlay()
  ns.CreatePlates()

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
  self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  self:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
  self:RegisterEvent("UNIT_COMBAT")
  self:RegisterEvent("UNIT_HEALTH")
  self:RegisterEvent("UNIT_MAXHEALTH")
  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

  local elapsedSinceCheck = 0
  self:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    ns.UpdateBars(now)
    ns.UpdatePlates(now)
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    local draw = drawDue
    drawDue = false
    if elapsedSinceCheck > 0.1 then
      elapsedSinceCheck = 0
      CheckAlerts(now)
      draw = true
    end
    if draw then ns.UpdateOverlay(now) end
  end)
end

function TB:PLAYER_LOGIN()
  playerGUID = GuidOf("player")
  -- Nameplates already up after a /reload don't fire NAME_PLATE_UNIT_ADDED again.
  for i = 1, 40 do
    local unit = "nameplate" .. i
    local exists = UnitExists(unit)
    if not Secret(exists) and exists then ns.plateUnits[unit] = true end
  end
  local c = UnitAffectingCombat("player")
  inCombat = not Secret(c) and c or false
  RefreshDisplay()
  if not next(cdb.spells) then
    print("|cff99ccffTicky|r: type /ticky to choose which spells to track.")
  end
end

function TB:PLAYER_TARGET_CHANGED()
  ForgetMob("target") -- only used while the target's GUID is secret and it has no nameplate
  RefreshDisplay()
  ns.UpdateOverlay(GetTime())
end
function TB:PLAYER_REGEN_DISABLED() inCombat = true end
-- Combat is over, so auras can be read again. Mobs Ticky can still see (target, nameplates) are
-- read for their exact timers; this keeps DoTs on mobs that are still alive after a Vanish or Feign
-- Death. Your debuffs on mobs it can't see are dropped: those mobs almost always died out of
-- sight, and their timers would otherwise run on and alert after the fight.
function TB:PLAYER_REGEN_ENABLED()
  inCombat = false
  RefreshDisplay()
  local mobs = {}
  for mob in pairs(timers) do
    if mob ~= playerGUID then mobs[#mobs + 1] = mob end
  end
  for _, mob in ipairs(mobs) do
    local unit = UnitForMob(mob)
    local exists = unit and UnitExists(unit)
    if unit and not Secret(exists) and exists and not IsDead(unit) then
      ReadUnit(unit)
    else
      ForgetDebuffs(mob)
    end
  end
end

-- What UNIT_AURA and your casts looked like, for /ticky debug.
local seen = { auraEvents = 0, secretUnits = 0, added = 0, addedSecret = 0, casts = {} }

local function NoteAuraUpdate(info)
  if not info or Secret(info) or not info.addedAuras or Secret(info.addedAuras) then return end
  for _, a in ipairs(info.addedAuras) do
    seen.added = seen.added + 1
    if Secret(a) or Secret(a.auraInstanceID) then seen.addedSecret = seen.addedSecret + 1 end
  end
end

function TB:UNIT_AURA(unit, info)
  seen.auraEvents = seen.auraEvents + 1
  pcall(NoteAuraUpdate, info)
  if Secret(unit) then
    -- Can't tell which unit changed: re-read the two that matter.
    seen.secretUnits = seen.secretUnits + 1
    RefreshDisplay()
  elseif unit == "target" or unit == "player" or unit:find("^nameplate%d") then
    ReadUnit(unit)
  end
end

function TB:UNIT_SPELLCAST_SENT(_, name, castGUID, spellID)
  if Secret(castGUID) or Secret(spellID) or not castGUID then return end
  local now = GetTime()
  for g, s in pairs(sentTo) do
    if now - s.at > 10 then sentTo[g] = nil end
  end
  sentTo[castGUID] = { mob = MobForCast(spellID, not Secret(name) and name or nil), at = now }
end

function TB:UNIT_SPELLCAST_SUCCEEDED(_, castGUID, spellID)
  table.insert(seen.casts, 1, { GetTime(), Secret(spellID) and "secret" or spellID })
  seen.casts[6] = nil
  if not Secret(spellID) then OnCast(castGUID, spellID) end
end

-- Misses, dodges, parries, resists and the like drop a cast that didn't land; hits and heals that
-- land on a tick teach the spell's real tick size (tooltips leave out spell power).
function TB:UNIT_COMBAT(unit, action, flag, amount, school)
  if Secret(unit) or Secret(action) then return end
  if AVOIDED[action] then
    local mob = MobKey(unit)
    -- Attacks on you missing aren't your casts missing.
    if not mob or mob == playerGUID then return end
    local sc = not Secret(school) and type(school) == "number" and school or nil
    OnAvoided(mob, action, sc, unit)
  elseif action == "WOUND" or action == "HEAL" then
    if Secret(amount) or Secret(school) or Secret(flag) or type(amount) ~= "number" then return end
    local mob = MobKey(unit)
    if mob then OnTickAmount(mob, action == "HEAL", amount, school, flag == "CRITICAL") end
  end
end

ns.plateUnits = {} -- nameplate unit tokens that are up, for Plates.lua

-- The health shading's mirror bar follows health as it changes (drawn in the next frame update).
function TB:UNIT_HEALTH(unit)
  if not Secret(unit) and unit ~= "target" and not unit:find("^nameplate%d") then return end
  local now = GetTime()
  -- Ticks seen landing on this mob count now, together with the health drop.
  local mob = not Secret(unit) and MobKey(unit)
  for m, list in pairs(timers) do
    if not mob or m == mob then
      for _, t in pairs(list) do
        if t.pendingTick then Commit(t) end
      end
    end
  end
  if channel and channel.pendingTick and (not mob or mob == MobKey("target")) then Commit(channel) end
  if mob then healthAt[mob] = now else healthAtAny = now end
  local tr = mob and TraceFor(mob)
  if tr and not tr.health and now >= tr.hit then tr.health = now end
  drawDue = true
end
function TB:UNIT_MAXHEALTH(unit)
  if ns.MaxHealthChanged then ns.MaxHealthChanged() end
  self:UNIT_HEALTH(unit)
end

function TB:NAME_PLATE_UNIT_ADDED(unit)
  if Secret(unit) then return end
  ns.plateUnits[unit] = true
  ForgetMob("plate:" .. unit) -- the token now shows another mob
  ReadUnit(unit)
end

function TB:NAME_PLATE_UNIT_REMOVED(unit)
  if Secret(unit) then return end
  ns.plateUnits[unit] = nil
  ForgetMob("plate:" .. unit)
  local g = GuidOf(unit)
  if g and IsDead(unit) then ForgetMob(g) end
end

function TB:SPELLS_CHANGED()
  wipe(descCache)
  if ns.RefreshOptions then ns.RefreshOptions(true) end
end

function TB:SPELL_DATA_LOAD_RESULT()
  if ns.RefreshOptions then ns.RefreshOptions(true) end
end

function TB:UNIT_SPELLCAST_CHANNEL_START() channel = ReadChannel() end
function TB:UNIT_SPELLCAST_CHANNEL_UPDATE() if channel then channel = ReadChannel() end end
function TB:UNIT_SPELLCAST_CHANNEL_STOP() EndChannel(GetTime()) end

---------------------------------------------------------------------------
-- Slash commands and the addon compartment (minimap) entry
---------------------------------------------------------------------------

local function Print(msg) print("|cff99ccffTicky|r: " .. msg) end

---------------------------------------------------------------------------
-- /ticky debug: what the game lets Ticky see right now (run it in combat, with your DoTs up)
---------------------------------------------------------------------------

local function Show(v)
  if Secret(v) then return "secret" end
  if v == nil then return "-" end
  if v == true then return "yes" end
  if v == false then return "no" end
  return tostring(v)
end

-- Call fn(...) and show its first result; "n/a" if the API is missing, "error" if it fails.
local function Try(fn, ...)
  if not fn then return "n/a" end
  local ok, v = pcall(fn, ...)
  return ok and Show(v) or "error"
end

local SECRECY = { [0] = "never", [1] = "always", [2] = "in combat/restricted" }

-- The short report: everything that's been needed so far, small enough to paste into a chat
-- message whole (Discord's limit is 2000 characters).
local function ShortDebug()
  local now = GetTime()
  local out = {}
  local function L(s) out[#out + 1] = s end
  local function ago(t) return ("%.1fs"):format(now - t) end
  local RA, R, CS = C_RestrictedActions, Enum.AddOnRestrictionType, C_Secrets
  local restricted = RA and R and pcall(RA.IsAddOnRestrictionActive, R.Combat)
    and RA.IsAddOnRestrictionActive(R.Combat)
  local secret = CS and CS.ShouldAurasBeSecret and CS.ShouldAurasBeSecret()
  L(("Ticky build %s | combat %s%s | auras secret %s"):format(tostring(ns.Build), Show(inCombat),
    restricted == true and " (restricted)" or "", Show(secret)))

  local spells = {}
  for _, key in ipairs(ns.OrderedSpells()) do
    local cfg = cdb.spells[key]
    local id = cfg.id
    local tick = id and (tickSizes[id] and (tickSizes[id] .. " seen") or (ExpectedTick(id)
      and (floor(ExpectedTick(id) + 0.5) .. " tip")))
    spells[#spells + 1] = ("%s %s/%s"):format(cfg.name, id and learned[id] and (learned[id] .. "s") or "-",
      tick or "-")
  end
  L("Spells (lasts/tick): " .. (#spells > 0 and table.concat(spells, ", ") or "none tracked"))

  local tm = HasTarget() and MobKey("target")
  local parts = {}
  for _, t in pairs(tm and timers[tm] or {}) do
    parts[#parts + 1] = ("%s %.0fs%s"):format(t.name, t.expires - now, t.castAt and "" or " (aura)")
  end
  local hostile = tm and UnitCanAttack("player", "target")
  hostile = not Secret(hostile) and hostile == true
  L(("Target: %s, key %s | timers: %s%s"):format(tm and (hostile and "enemy" or "friend") or "none", tm and (tm:sub(1, 6) == "plate:" and tm or tm == "target" and "target" or "GUID") or "-",
    #parts > 0 and table.concat(parts, ", ") or "none", channel and (" | channel " .. channel.name) or ""))
  local hb = ns.FindHealthBar and ns.FindHealthBar()
  local attaches, width, scale
  if ns.OverlayInfo then attaches, width, scale = ns.OverlayInfo() end
  L("Health bar shading on: " .. (hb and (ns.FramePath(hb) or "a bar with no name") or "none found")
    .. (attaches and (" | re-anchored " .. attaches .. "x, width " .. tostring(width and floor(width * 10 + 0.5) / 10)
      .. ", scale " .. tostring(scale)) or ""))
  -- And on nameplates: the bar picked on up to two plates (their names show which addon drew them).
  local plates = {}
  if C_NamePlate and C_NamePlate.GetNamePlateForUnit and ns.PlateHealthBar then
    for unit in pairs(ns.plateUnits) do
      if #plates >= 2 then break end
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
      if ok and type(plate) == "table" and not Secret(plate) then
        local pb = ns.PlateHealthBar(plate)
        plates[#plates + 1] = unit .. " " .. (pb and (ns.FramePath(pb) or "a bar with no name") or "none (whole plate)")
      end
    end
  end
  L("Nameplate health bars: " .. (#plates > 0 and table.concat(plates, "; ") or "no nameplates up"))

  local casts = {}
  for _, c in ipairs(seen.casts) do
    casts[#casts + 1] = (type(c[2]) == "number" and SpellInfo(c[2]) or tostring(c[2])) .. " " .. ago(c[1])
  end
  L("Casts: " .. (#casts > 0 and table.concat(casts, ", ") or "-"))
  local tr = ns.TickTrace()
  local function at(v) return v and ("%+.3f"):format(v - tr.hit) or "never" end
  L(tr and ("Last tick on target (%s, %.2fs %s than expected): hit 0, health %s, counted %s, drawn %s, %s ago; "
    .. "%s hit, shading %s")
    :format(tr.name, math.abs(tr.off), tr.off < 0 and "earlier" or "later", at(tr.health), at(tr.counted), at(tr.drawn),
      ago(tr.hit), tostring(tr.amount), tr.shrink and ("%+d"):format(floor(-tr.shrink + 0.5)) or "?")
    or "Last tick on target: none seen yet")

  local avoids = {}
  for _, a in ipairs(avoidLog) do
    avoids[#avoids + 1] = ("%s(%s) %s %s: %s"):format(a.action, tostring(a.school), tostring(a.unit), ago(a.at),
      a.result or "?")
  end
  L("Misses etc: " .. (#avoids > 0 and table.concat(avoids, "; ") or "-"))
  for _, line in ipairs(out) do print("|cff99ccffTicky|r " .. line) end
end

function ns.Debug(all)
  if not all then return ShortDebug() end
  local function V(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    print("|cff99ccffTicky|r  " .. table.concat(parts, "  "))
  end
  Print("debug, version " .. tostring(C_AddOns.GetAddOnMetadata(ADDON, "Version")) .. ", build "
    .. tostring(ns.Build))
  local names = {}
  for _, key in ipairs(ns.OrderedSpells()) do names[#names + 1] = cdb.spells[key].name end
  V("Tracked:", #names > 0 and table.concat(names, ", ") or "nothing - tick spells on the Spells tab")

  local RA, R, CS = C_RestrictedActions, Enum.AddOnRestrictionType, C_Secrets
  local active = RA and RA.IsAddOnRestrictionActive
  V("In combat:", Show(inCombat), "restrictions: combat", Try(active, R and R.Combat),
    "map", Try(active, R and R.Map), "encounter", Try(active, R and R.Encounter))
  V("Auras secret right now:", Try(CS and CS.ShouldAurasBeSecret))
  for _, key in ipairs(ns.OrderedSpells()) do
    local cfg = cdb.spells[key]
    if cfg.id then
      local ok, level = pcall(CS and CS.GetSpellAuraSecrecy, cfg.id)
      V(cfg.name .. " (" .. cfg.id .. "):", "aura secrecy", ok and (SECRECY[level] or Show(level)) or "n/a",
        "secret now", Try(CS and CS.ShouldSpellAuraBeSecret, cfg.id),
        "| lasts", Show(learned[cfg.id]), "| tick", Show(tickSizes[cfg.id] or ExpectedTick(cfg.id)),
        tickSizes[cfg.id] and "(seen)" or "(tooltip)")
    end
  end

  V("Target:", Show(HasTarget()), "GUID", GuidOf("target") and "readable" or Show(UnitGUID("target")),
    "enemy", Try(UnitCanAttack, "player", "target"))
  local total, secretAura, secretId, secretDur, secretSrc, readable = 0, 0, 0, 0, 0, {}
  pcall(function()
    for _, filter in ipairs(AURA_FILTERS) do
      for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex("target", i, filter)
        if a == nil then break end
        total = total + 1
        if Secret(a) then
          secretAura = secretAura + 1
        else
          if Secret(a.spellId) then secretId = secretId + 1 end
          if Secret(a.duration) or Secret(a.expirationTime) then secretDur = secretDur + 1 end
          if Secret(a.isFromPlayerOrPlayerPet) then secretSrc = secretSrc + 1 end
          if not Secret(a.spellId) then
            local n = SpellInfo(a.spellId)
            readable[#readable + 1] = (n or tostring(a.spellId)) .. (FromMe(a) and " (yours)" or "")
          end
        end
      end
    end
  end)
  V("Target auras:", total, "| whole aura secret", secretAura, "| spell secret", secretId,
    "| time secret", secretDur, "| caster secret", secretSrc)
  if #readable > 0 then V("Readable:", table.concat(readable, ", ")) end

  local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, "target", "HARMFUL|PLAYER")
  if ok and type(ids) == "table" and not Secret(ids) then
    local first = ids[1]
    V("Your debuffs by instance ID:", #ids, "| first ID", Show(first))
    if first and not Secret(first) then
      V("  instance secret", Try(CS and CS.ShouldUnitAuraInstanceBeSecret, "target", first))
      local dok, d = pcall(C_UnitAuras.GetAuraDuration, "target", first)
      V("  duration object", dok and (d and "yes" or "no") or "error",
        "has secret values", dok and d and Try(d.HasSecretValues, d) or "-")
    end
  else
    V("Your debuffs by instance ID:", ok and Show(ids) or "error")
  end
  local tm, fromCasts, n = HasTarget() and MobKey("target"), 0, 0
  for _, t in pairs(tm and timers[tm] or {}) do
    n = n + 1
    if t.castAt then fromCasts = fromCasts + 1 end
  end
  V("Ticky's timers on target:", n, "| from your casts", fromCasts, "| key", Show(tm),
    "| channel", channel and channel.name or "-")

  local casts = {}
  for _, c in ipairs(seen.casts) do
    local n = type(c[2]) == "number" and SpellInfo(c[2]) or c[2]
    casts[#casts + 1] = ("%s %.1fs ago"):format(tostring(n), GetTime() - c[1])
  end
  V("Your last casts:", #casts > 0 and table.concat(casts, ", ") or "-")
  local avoids = {}
  for _, a in ipairs(avoidLog) do
    avoids[#avoids + 1] = ("%s (school %s) on %s %.1fs ago: %s"):format(a.action, tostring(a.school),
      tostring(a.unit), GetTime() - a.at, a.result or "?")
  end
  V("Misses, resists, dodges on mobs:", #avoids > 0 and table.concat(avoids, "; ") or "-")
  V("UNIT_AURA events:", seen.auraEvents, "| unit secret", seen.secretUnits, "| added", seen.added,
    "| added with secret ID", seen.addedSecret)
end

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
    Print("Appearance, layout and sound settings reset. Your spells are unchanged.")
  elseif cmd == "debug" then
    ns.Debug(rest:lower() == "all")
  elseif cmd == "sparktest" then
    ns.SparkTest()
  elseif cmd == "report" then
    Print("report a problem or ask for a feature at " .. ns.ISSUES_URL
      .. " (include what /ticky debug shows right after it happens).")
    if ns.ShowReport then ns.ShowReport() end
  else
    Print("/ticky [options | lock | unlock | add <spell> | remove <spell> | list | preview | reset | debug "
      .. "| report]")
  end
end
