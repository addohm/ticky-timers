-- A small stand-in for the WoW: Forever client, enough to load Ticky and drive it from tests.
-- Unknown widget methods are recorded in MOCK.unknown (and do nothing) rather than faked, so a
-- test run lists any method Ticky calls that the mock doesn't model. Keep it faithful to the
-- forever-branch API docs; a failure here can be a mock artifact.
local M = {
  now = 1000, unknown = {}, sounds = {}, spoken = {}, files = {}, frames = {}, events = {},
  printed = {}, healthN = 0, fileOK = true,
}
MOCK = M

local Widget, methods = {}, {}
local function new(kind, parent, name)
  local w = setmetatable({ kind = kind, parent = parent, name = name, points = {}, shown = true,
    scripts = {}, w = 0, h = 0, alpha = 1, children = {} }, Widget)
  if parent then table.insert(parent.children, w) end
  if name then _G[name] = w end
  table.insert(M.frames, w)
  return w
end
Widget.__index = function(t, k)
  local m = methods[k]
  if m then return m end
  if k == "Refresh" or k == "OnRefresh" then return nil end -- fields the addon sets itself
  if type(k) == "string" and k:match("^[A-Z]") then
    M.unknown[t.kind .. ":" .. k] = true
    return function() end
  end
end

-- Layout ----------------------------------------------------------------------
function methods:SetPoint(p, rel, rp, x, y)
  if type(rel) == "number" then rel, rp, x, y = nil, p, rel, rp end
  if type(rel) == "string" then rel = _G[rel] end
  table.insert(self.points, { p, rel or self.parent, rp or p, x or 0, y or 0 })
end
function methods:SetAllPoints(rel)
  rel = rel or self.parent
  self.points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint(i)
  local p = self.points[i or 1]
  if p then return p[1], p[2], p[3], p[4], p[5] end
end
function methods:SetSize(w, h) self.w, self.h = w, h end
function methods:SetWidth(w) self.w = w end
function methods:SetHeight(h) self.h = h end
function methods:GetWidth()
  -- Anchored to the left and right edges of one frame: as wide as it.
  local a, b = self.points[1], self.points[2]
  if a and b and a[2] == b[2] and a[2] and a[3]:find("LEFT") and b[3]:find("RIGHT") then return a[2]:GetWidth() end
  return self.w
end
function methods:GetHeight() return self.h end
function methods:SetScale(sc) self.scale = sc end
function methods:GetEffectiveScale()
  local sc, f = 1, self
  while f do sc = sc * (f.scale or 1); f = f.parent end
  return sc
end
function methods:SetParent(p)
  if self.parent then
    for i, c in ipairs(self.parent.children) do
      if c == self then table.remove(self.parent.children, i) break end
    end
  end
  self.parent = p
  if p then table.insert(p.children, self) end
end
function methods:GetParent() return self.parent end
function methods:GetChildren()
  local out = {}
  for _, c in ipairs(self.children) do
    if c.kind ~= "Texture" and c.kind ~= "FontString" then out[#out + 1] = c end
  end
  return unpack(out)
end
function methods:GetDebugName() return self.debugName or self.name end
function methods:SetFrameStrata(s) self.strata = s end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameLevel(l) self.level = l end
function methods:GetFrameLevel() return self.level or 5 end

-- Visibility and scripts -----------------------------------------------------
function methods:Show()
  if not self.shown then
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
  end
end
function methods:Hide()
  if self.shown then
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
  end
end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible()
  local f = self
  while f do
    if not f.shown then return false end
    f = f.parent
  end
  return true
end
function methods:SetScript(e, fn) self.scripts[e] = fn end
function methods:GetScript(e) return self.scripts[e] end
function methods:HookScript(e, fn)
  local old = self.scripts[e]
  self.scripts[e] = function(...)
    if old then old(...) end
    fn(...)
  end
end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:RegisterEvent(e) M.events[e] = self end
function methods:RegisterUnitEvent(e) M.events[e] = self end
function methods:UnregisterEvent() end
function methods:SetAttribute(k, v) self.attrs = self.attrs or {}; self.attrs[k] = v end
function methods:GetAttribute(k) return self.attrs and self.attrs[k] end

-- Text, values, textures ---------------------------------------------------------
function methods:SetText(t) self.text = t ~= nil and tostring(t) or nil end
function methods:GetText() return self.text end
function methods:SetFormattedText(f, ...) self.text = f:format(...) end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:SetFont(f, s, o) self.font = { f, s, o } end
function methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function methods:SetFontObject(o) self.fontObject = o end
function methods:SetValue(v, interp)
  self.value, self.interp = v, interp
  if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function methods:GetValue() return self.value or 0 end
function methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function methods:SetReverseFill(v) self.reverse = v end
function methods:GetReverseFill() return self.reverse or false end
function methods:SetStatusBarTexture(t) self.barTexture = t end
function methods:GetStatusBarTexture()
  self._fill = self._fill or new("Texture", self)
  return self._fill
end
function methods:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a } end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:CreateTexture(name) return new("Texture", self, name) end
function methods:CreateFontString(name) return new("FontString", self, name) end
function methods:SetTexture(t) self.texture = t end
function methods:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function methods:SetVertexColor(r, g, b, a) self.vcolor = { r, g, b, a } end
function methods:SetDesaturated(v) self.desat = v end
function methods:SetScrollChild(c) self.child = c end
function methods:HasFocus() return self.focus or false end
function methods:SetFocus()
  self.focus = true
  if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:ClearFocus() self.focus = false end
function methods:HighlightText() self.highlighted = true end

-- Real Forever methods Ticky uses whose effect the tests don't look at.
for _, n in ipairs({ "SetClipsChildren", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
  "EnableMouse", "SetTexCoord", "SetBlendMode", "SetJustifyH", "SetWordWrap", "SetShadowColor",
  "SetShadowOffset", "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "EnableMouseWheel",
  "SetThumbTexture", "SetHighlightTexture", "SetAutoFocus", "SetSpacing", "StartMoving",
  "StopMovingOrSizing", "LockHighlight", "UnlockHighlight" }) do
  methods[n] = function() end
end

-- Globals -------------------------------------------------------------------------
UIParent = new("Frame", nil, "UIParent")
GameTooltip = new("GameTooltip", UIParent, "GameTooltip")
function CreateFrame(kind, name, parent, template)
  local f = new(kind, parent or UIParent, name)
  f.template = template
  return f
end
UISpecialFrames = {}
tinsert = table.insert
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc() end
ChatFrameUtil = { InsertLink = function() end }
function issecretvalue(v) return type(v) == "table" and v.__secret == true end
function issecrettable() return false end
function GetTime() return M.now end
M.realprint = print
print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  table.insert(M.printed, table.concat(t, " "))
end
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
C_AddOns = { GetAddOnMetadata = function() return "0.6.0" end, LoadAddOn = function() end }
Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = function() end }
ColorPickerFrame = {
  SetupColorPickerAndShow = function(_, info) M.picker = info; info.swatchFunc() end,
  GetColorRGB = function() return 0.1, 0.2, 0.3 end,
}
Enum = {
  SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 }, TtsVoiceType = { Standard = 0 },
  StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
}

-- Units: M.units[token] = { guid, name, exists, auras, canAttack, canAssist, dead, secretGuid }
M.units = { player = { guid = "Player-1", name = "Whoat", exists = true, auras = {}, canAssist = true } }
local function unitOf(u) return M.units[u == "softenemy" and "target" or u] end
function UnitExists(u) return unitOf(u) ~= nil end
function UnitGUID(u)
  local d = unitOf(u)
  if not d then return nil end
  if d.secretGuid then return { __secret = true } end
  return d.guid
end
function UnitName(u) return unitOf(u) and unitOf(u).name end
function UnitIsUnit(a, b) return unitOf(a) ~= nil and unitOf(a) == unitOf(b) end
function UnitIsDeadOrGhost(u) return unitOf(u) and unitOf(u).dead or false end
function UnitCanAttack(_, u) return unitOf(u) and unitOf(u).canAttack or false end
function UnitCanAssist(_, u) return unitOf(u) and unitOf(u).canAssist or false end
function UnitTokenFromGUID(g)
  for u, d in pairs(M.units) do if d.guid == g then return u end end
end
function UnitSpellHaste() return 0 end
function UnitAffectingCombat() return false end
function UnitHealthMax() return { __secret = true } end
function UnitHealth()
  M.healthN = M.healthN + 1 -- a new (secret) value per read, so tests can see when it's read
  return { __secret = true, n = M.healthN }
end
function UnitChannelInfo()
  local c = M.channel
  if c then return c.name, "", c.icon, c.startMS, c.endMS, false, false, c.spellID end
end
C_UnitAuras = {}
function C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
  if M.auraLock then error("Secret values are only allowed during untainted execution") end
  local u = M.units[unit]
  if not u then return nil end
  local n = 0
  for _, a in ipairs(u.auras or {}) do
    if (filter == "HARMFUL") == (a.harmful == true) then
      n = n + 1
      if n == i then return a end
    end
  end
end

-- Spells (priest, plus Rend for physical checks) ------------------------------------
M.spells = {
  [589] = { name = "Shadow Word: Pain", icon = 136207, harm = true,
    desc = "A word of darkness that causes 30 Shadow damage over 18 sec." },
  [2944] = { name = "Devouring Plague", icon = 252997, harm = true,
    desc = "Afflicts the target with a disease that causes 152 Shadow damage over 24 sec." },
  [15407] = { name = "Mind Flay", icon = 136208, harm = true,
    desc = "Assault the target's mind with Shadow energy, causing 75 Shadow damage over 3 sec and slowing their movement speed by 50% for 3 sec." },
  [772] = { name = "Rend", icon = 132155, harm = true,
    desc = "Wounds the target causing them to bleed for 21 damage over 9 sec." },
  [139] = { name = "Renew", icon = 135953, help = true, desc = "Heals the target of 45 damage over 15 sec." },
  [588] = { name = "Inner Fire", icon = 135926, help = true,
    desc = "A burst of Holy energy fills the caster, increasing armor by 315. Lasts 10 min or 20 charges." },
}
C_Spell = {}
function C_Spell.GetSpellInfo(s)
  if type(s) == "string" then
    for id, d in pairs(M.spells) do if d.name:lower() == s:lower() then s = id end end
  end
  local d = M.spells[s]
  if d then return { name = d.name, iconID = d.icon, spellID = s } end
end
function C_Spell.GetSpellDescription(id) return M.spells[id] and M.spells[id].desc or "" end
function C_Spell.RequestLoadSpellData() end
function C_Spell.IsSpellHarmful(id) return M.spells[id] and M.spells[id].harm or false end
function C_Spell.IsSpellHelpful(id) return M.spells[id] and M.spells[id].help or false end
C_SpellBook = {}
local book = { 589, 2944, 15407, 139, 588 }
function C_SpellBook.GetNumSpellBookSkillLines() return 1 end
function C_SpellBook.GetSpellBookSkillLineInfo() return { itemIndexOffset = 0, numSpellBookItems = #book } end
function C_SpellBook.GetSpellBookItemInfo(i) return { spellID = book[i], itemType = 1, isPassive = false } end

-- Sound ---------------------------------------------------------------------------
SOUNDKIT = { RAID_WARNING = 8959, MAP_PING = 3175, READY_CHECK = 8960 }
function PlaySound(id, ch) table.insert(M.sounds, { id, ch, M.now }) end
function PlaySoundFile(f, ch) table.insert(M.files, { f, ch }); return M.fileOK, 1 end
C_VoiceChat = { SpeakText = function(_, text) table.insert(M.spoken, text) end }
C_TTSSettings = {
  GetVoiceOptionID = function() return 1 end, GetSpeechRate = function() return 0 end,
  GetSpeechVolume = function() return 100 end,
}

-- Blizzard's target frame and nameplates ----------------------------------------------
TargetFrame = CreateFrame("Button", "TargetFrame", UIParent)
M.healthBar = CreateFrame("StatusBar", nil, TargetFrame)
M.healthBar:SetSize(126, 20)
TargetFrame.TargetFrameContent = { TargetFrameContentMain = { HealthBarsContainer = { HealthBar = M.healthBar } } }

M.plates, M.plateWidth = {}, 110
C_NamePlate = {
  GetNamePlateForUnit = function(unit)
    if not M.units[unit] then return nil end
    if not M.plates[unit] then
      local plate = CreateFrame("Frame", nil, UIParent)
      local uf = CreateFrame("Frame", nil, plate)
      local hb = CreateFrame("StatusBar", nil, uf)
      hb:SetSize(M.plateWidth, 10)
      hb.debugName = "NamePlate.UnitFrame.HealthBarsContainer.healthBar"
      uf.HealthBarsContainer = { healthBar = hb }
      plate.UnitFrame, plate.hb = uf, hb
      M.plates[unit] = plate
    end
    return M.plates[unit]
  end,
}

-- Driving the game ------------------------------------------------------------------
function M.fire(event, ...)
  local f = M.events[event]
  if f then f.scripts.OnEvent(f, event, ...) end
end
function M.update(dt)
  M.now = M.now + dt
  for _, f in ipairs(M.frames) do
    if f.scripts.OnUpdate and f:IsVisible() then f.scripts.OnUpdate(f, dt) end
  end
end
-- One rendered frame (60 fps): what Ticky queued for "the next frame" happens here.
function M.frame() M.update(1 / 60) end
-- opts.mine = false: cast by another player (opts.source, default "party1"); as in game,
-- isFromPlayerOrPlayerPet is true for any player's aura, and only sourceUnit says whose.
function M.aura(spellID, dur, opts)
  opts = opts or {}
  local mine = opts.mine ~= false
  return { spellId = spellID, duration = dur, expirationTime = (opts.start or M.now) + dur,
    sourceUnit = mine and "player" or (opts.source or "party1"), isFromPlayerOrPlayerPet = true,
    harmful = opts.harmful ~= false, applications = opts.stacks or 0 }
end
M.castN = 0
-- Cast a tracked spell at the unit named `name` (UNIT_SPELLCAST_SENT then _SUCCEEDED).
function M.cast(id, name)
  M.castN = M.castN + 1
  local g = "Cast-" .. M.castN
  M.fire("UNIT_SPELLCAST_SENT", "player", name or "", g, id)
  M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", g, id)
end
function M.start()
  M.fire("ADDON_LOADED", "Ticky")
  M.fire("PLAYER_LOGIN")
end

-- Checks ------------------------------------------------------------------------------
M.passes, M.fails = 0, 0
function M.check(cond, msg)
  if cond then M.passes = M.passes + 1 else M.fails = M.fails + 1; M.realprint("FAIL: " .. msg) end
end
