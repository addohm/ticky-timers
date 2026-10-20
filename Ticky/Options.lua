-- Ticky options window: Spells, Bars, Text & Ticks, Alerts, General.
-- Open with /ticky, the minimap addon menu, or Game Menu > Options > AddOns > Ticky.
local ADDON, ns = ...

local W = ns.W
local panel
local pages, tabs = {}, {}
local ROW_H = 26
local COL2 = 300

local function Choices(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = { e[1], e[1] } end
  return out
end

local function Add(page, ctrl)
  page.controls[#page.controls + 1] = ctrl
  return ctrl
end

local function NewPage(name)
  local p = CreateFrame("Frame", nil, panel)
  p:SetPoint("TOPLEFT", 16, -76)
  p:SetPoint("BOTTOMRIGHT", -16, 44)
  p.controls = {}
  function p:Refresh()
    for _, c in ipairs(self.controls) do c:Refresh() end
    if self.OnRefresh then self:OnRefresh() end
  end
  p:Hide()
  pages[#pages + 1] = p
  p.title = name
  return p
end

local function ShowPage(i)
  for j, p in ipairs(pages) do
    p:SetShown(i == j)
    if i == j then tabs[j]:LockHighlight() else tabs[j]:UnlockHighlight() end
  end
  pages[i]:Refresh()
  panel.current = i
end

---------------------------------------------------------------------------
-- Spells page
---------------------------------------------------------------------------

local spellsPage, list, content, detail
local rows = {}
local selected

local function SoundChoices(withDefault)
  local out = {}
  if withDefault then out[1] = { "DEFAULT", "Use default (Alerts tab)" } end
  for _, s in ipairs(ns.SOUNDS) do out[#out + 1] = { s[1], s[2] } end
  return out
end

local function RefreshDetail()
  local cfg = selected and ns.CharDB().spells[selected.key]
  detail:SetShown(selected ~= nil)
  if not selected then return end
  detail.icon:SetTexture(selected.icon or (cfg and cfg.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
  detail.name:SetText(selected.name)
  detail.info:SetText(ns.Describe(selected.key, selected.id))
  detail.untracked:SetShown(cfg == nil)
  detail.controls:SetShown(cfg ~= nil)
  if cfg then
    for _, c in ipairs(detail.controls.list) do c:Refresh() end
    detail.labelBox:SetText(cfg.label or "")
  end
end

local function GetRow(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, content)
  r:SetSize(270, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints()
  r.sel:SetColorTexture(1, 0.82, 0, 0.15)
  r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.check:SetSize(24, 24)
  r.check:SetPoint("LEFT")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = W.Label(r, "", "GameFontHighlightSmall")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 2)
  r.info = W.Label(r, "", "GameFontDisableSmall")
  r.info:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, -2)
  r.info:SetPoint("RIGHT", r, "RIGHT", -2, 0)
  r.info:SetWordWrap(false)
  r.check:SetScript("OnClick", function()
    if ns.IsTracked(r.data.key) then ns.Untrack(r.data.key) else ns.Track(r.data.id, r.data.name, r.data.icon) end
    selected = r.data
    ns.RefreshOptions()
  end)
  r:SetScript("OnClick", function()
    selected = r.data
    ns.RefreshOptions()
  end)
  rows[i] = r
  return r
end

local function RefreshSpellList()
  local db, cdb = ns.DB(), ns.CharDB()
  local filter = (spellsPage.search:GetText() or ""):lower()
  local spells, byKey = ns.SpellbookSpells(db.showAll)
  local entries = {}
  for _, s in ipairs(spells) do entries[#entries + 1] = s end
  -- Tracked spells that aren't listed above (other spec, added by ID, etc.).
  local extra = {}
  for key, cfg in pairs(cdb.spells) do
    if not byKey[key] then extra[#extra + 1] = { key = key, id = cfg.id, name = cfg.name, icon = cfg.icon } end
  end
  table.sort(extra, function(a, b) return a.key < b.key end)
  for _, e in ipairs(extra) do entries[#entries + 1] = e end

  local n = 0
  for _, e in ipairs(entries) do
    if filter == "" or e.key:find(filter, 1, true) then
      n = n + 1
      local r = GetRow(n)
      r.data = e
      r.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.name:SetText(e.name)
      r.info:SetText(ns.Describe(e.key, e.id))
      r.check:SetChecked(ns.IsTracked(e.key))
      r.sel:SetShown(selected ~= nil and selected.key == e.key)
      r:Show()
    end
  end
  for i = n + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(1, n * ROW_H))
  spellsPage.empty:SetShown(n == 0)
  RefreshDetail()
end

local function BuildSpellsPage()
  local p = NewPage("Spells")
  spellsPage = p

  p.search = W.EditBox(p, 170)
  p.search:SetPoint("TOPLEFT", 6, 0)
  local hint = W.Label(p, "Search", "GameFontDisableSmall")
  hint:SetPoint("LEFT", p.search, "LEFT", 2, 0)
  p.search:SetScript("OnTextChanged", function(self)
    hint:SetShown(self:GetText() == "")
    RefreshSpellList()
  end)

  local showAll = Add(p, W.Check(p, "Show all spells", function() return ns.DB().showAll end,
    function(v)
      ns.DB().showAll = v
      RefreshSpellList()
    end, "List every spell in your spellbook, not just ones that leave a buff or debuff."))
  showAll:SetPoint("LEFT", p.search, "RIGHT", 8, 0)
  showAll.label:SetFontObject("GameFontHighlightSmall")

  list = CreateFrame("ScrollFrame", "TickyOptionsSpellScroll", p, "UIPanelScrollFrameTemplate")
  list:SetPoint("TOPLEFT", 0, -28)
  list:SetSize(270, 290)
  content = CreateFrame("Frame", nil, list)
  content:SetSize(270, 1)
  list:SetScrollChild(content)
  local listBg = p:CreateTexture(nil, "BORDER")
  listBg:SetPoint("TOPLEFT", list, -2, 2)
  listBg:SetPoint("BOTTOMRIGHT", list, 2, -2)
  listBg:SetColorTexture(1, 1, 1, 0.04)
  p.empty = W.Label(content, "Nothing here. Try \"Show all spells\".", "GameFontDisableSmall")
  p.empty:SetPoint("TOPLEFT", 4, -6)

  local addLabel = W.Label(p, "Add a spell not listed (name, ID, or shift-click):", "GameFontNormalSmall")
  addLabel:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
  p.addBox = W.EditBox(p, 190)
  p.addBox:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 6, -4)
  local addButton = W.Button(p, "Add", 60)
  addButton:SetPoint("LEFT", p.addBox, "RIGHT", 8, 0)
  p.status = W.Label(p, "", "GameFontHighlightSmall")
  p.status:SetPoint("TOPLEFT", p.addBox, "BOTTOMLEFT", -6, -4)
  p.status:SetWidth(290)
  local function doAdd()
    local ok, msg = ns.AddSpell(p.addBox:GetText())
    p.status:SetText(ok and ("|cff66ff66" .. msg) or ("|cffff6666" .. msg))
    if ok then p.addBox:SetText("") end
    p.addBox:ClearFocus()
    RefreshSpellList()
  end
  addButton:SetScript("OnClick", doAdd)
  p.addBox:SetScript("OnEnterPressed", doAdd)

  -- Detail panel for the selected spell.
  detail = CreateFrame("Frame", nil, p)
  detail:SetPoint("TOPLEFT", COL2, 0)
  detail:SetPoint("BOTTOMRIGHT")
  detail.icon = detail:CreateTexture(nil, "ARTWORK")
  detail.icon:SetSize(36, 36)
  detail.icon:SetPoint("TOPLEFT")
  detail.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  detail.name = W.Label(detail, "", "GameFontNormalLarge")
  detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.info = W.Label(detail, "", "GameFontHighlightSmall")
  detail.info:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
  detail.info:SetWidth(240)
  detail.untracked = W.Label(detail, "Not tracked. Tick its box in the list to track it.", "GameFontDisable")
  detail.untracked:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -16)

  local c = CreateFrame("Frame", nil, detail)
  c:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -12)
  c:SetPoint("BOTTOMRIGHT")
  c.list = {}
  detail.controls = c
  -- These controls are only shown for a tracked spell; the fallback table just keeps them safe.
  local function cfg() return selected and ns.CharDB().spells[selected.key] or {} end

  local color = W.Swatch(c, "Bar color", function() return cfg().color end, function(v) cfg().color = v end)
  color:SetPoint("TOPLEFT", 4, 0)
  c.list[#c.list + 1] = color

  local anyone = W.Check(c, "Track it from anyone, not just you", function() return cfg().anyCaster end,
    function(v)
      cfg().anyCaster = v or nil
      ns.RefreshDisplay()
      RefreshSpellList()
    end, "For example a buff another player puts on you, or a debuff a raid member applies to the boss.")
  anyone:SetPoint("TOPLEFT", color, "BOTTOMLEFT", -4, -8)
  anyone.label:SetFontObject("GameFontHighlightSmall")
  c.list[#c.list + 1] = anyone

  local labelText = W.Label(c, "Bar text (blank = spell name)", "GameFontHighlightSmall")
  labelText:SetPoint("TOPLEFT", anyone, "BOTTOMLEFT", 0, -8)
  detail.labelBox = W.EditBox(c, 220)
  detail.labelBox:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 6, -4)
  detail.labelBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      local t = strtrim(self:GetText())
      cfg().label = t ~= "" and t or nil
    end
  end)

  local function soundGetSet(field)
    return function() return cfg()[field] or "DEFAULT" end,
      function(v) cfg()[field] = v ~= "DEFAULT" and v or nil end
  end
  local g, s = soundGetSet("expireSound")
  local expire = W.Cycle(c, "Sound when it ends", SoundChoices(true), g, s)
  expire:SetPoint("TOPLEFT", detail.labelBox, "BOTTOMLEFT", -6, -12)
  c.list[#c.list + 1] = expire
  W.Button(c, "Test", 50, function()
    local v = cfg().expireSound
    ns.PlaySound(v or ns.DB().expireSound)
  end):SetPoint("LEFT", expire, "RIGHT", 6, -8)

  g, s = soundGetSet("warnSound")
  local warn = W.Cycle(c, "Warning sound (Alerts tab sets when)", SoundChoices(true), g, s)
  warn:SetPoint("TOPLEFT", expire, "BOTTOMLEFT", 0, -6)
  c.list[#c.list + 1] = warn
  W.Button(c, "Test", 50, function()
    local v = cfg().warnSound
    ns.PlaySound(v or ns.DB().warnSound)
  end):SetPoint("LEFT", warn, "RIGHT", 6, -8)

  W.Button(c, "Stop tracking", 120, function()
    if selected then ns.Untrack(selected.key) end
    RefreshSpellList()
  end):SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -14)

  p.OnRefresh = RefreshSpellList
end

---------------------------------------------------------------------------
-- Bars page
---------------------------------------------------------------------------

local function Place(page, ctrl, x, y)
  ctrl:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
  return Add(page, ctrl)
end

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

local function BuildBarsPage()
  local p = NewPage("Bars")
  local S = W.Setting

  W.Header(p, "Size"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("width")
  Place(p, W.Slider(p, "Width", 80, 500, 5, g, s), 4, -22)
  g, s = S("height")
  Place(p, W.Slider(p, "Height", 8, 48, 1, g, s), 4, -62)
  g, s = S("spacing")
  Place(p, W.Slider(p, "Space between bars", 0, 20, 1, g, s), 4, -102)
  g, s = S("scale")
  Place(p, W.Slider(p, "Scale", 0.5, 2, 0.05, g, s, pct), 4, -142)

  W.Header(p, "Layout"):SetPoint("TOPLEFT", 0, -188)
  g, s = S("growUp")
  Place(p, W.Cycle(p, "New bars stack", { { false, "Downward" }, { true, "Upward" } }, g, s), 4, -210)
  g, s = S("sortMode")
  Place(p, W.Cycle(p, "Order bars by", { { "name", "Spell name" }, { "remaining", "Time left" },
    { "added", "Order you added them" } }, g, s), 4, -254)
  g, s = S("fillMode")
  Place(p, W.Cycle(p, "Bar fill", { { "drain", "Empties as time runs out" }, { "fill", "Fills as time passes" } },
    g, s), 4, -298)

  W.Header(p, "Look"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("texture")
  Place(p, W.Cycle(p, "Texture", Choices(ns.TEXTURES), g, s), COL2 + 4, -22)
  g, s = S("bgAlpha")
  Place(p, W.Slider(p, "Background opacity", 0, 1, 0.05, g, s, pct), COL2 + 4, -66)
  g, s = S("showIcon")
  Place(p, W.Check(p, "Show spell icon", g, s), COL2, -104)
  g, s = S("iconSide")
  Place(p, W.Cycle(p, "Icon side", { { "LEFT", "Left" }, { "RIGHT", "Right" } }, g, s), COL2 + 4, -132)

  W.Header(p, "Running low"):SetPoint("TOPLEFT", COL2, -188)
  g, s = S("lowEnabled")
  Place(p, W.Check(p, "Change color near the end", g, s,
    "Recolor the bar in its last seconds, so you know when to reapply."), COL2, -208)
  g, s = S("lowSeconds")
  Place(p, W.Slider(p, "Seconds left", 1, 10, 0.5, g, s), COL2 + 4, -236)
  g, s = S("lowColor")
  Place(p, W.Swatch(p, "Low-time color", g, s), COL2 + 4, -280)
end

---------------------------------------------------------------------------
-- Text & Ticks page
---------------------------------------------------------------------------

local function BuildTextPage()
  local p = NewPage("Text & Ticks")
  local S = W.Setting

  W.Header(p, "Text"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("showName")
  Place(p, W.Check(p, "Show spell name", g, s), 0, -20)
  g, s = S("showTime")
  Place(p, W.Check(p, "Show time left", g, s), 0, -46)
  g, s = S("showTickCount")
  Place(p, W.Check(p, "Show ticks left (x3)", g, s), 0, -72)
  g, s = S("font")
  Place(p, W.Cycle(p, "Font", Choices(ns.FONTS), g, s), 4, -104)
  g, s = S("fontSize")
  Place(p, W.Slider(p, "Font size", 6, 24, 1, g, s), 4, -148)
  g, s = S("outline")
  Place(p, W.Cycle(p, "Outline", ns.OUTLINES, g, s), 4, -188)

  W.Header(p, "Tick marks"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("tickColor")
  Place(p, W.Swatch(p, "Tick color", g, s), COL2 + 4, -24)
  g, s = S("tickWidth")
  Place(p, W.Slider(p, "Tick width", 1, 6, 1, g, s), COL2 + 4, -52)
  g, s = S("pastTicks")
  Place(p, W.Cycle(p, "Ticks that already happened", { { "dim", "Dimmed" }, { "hide", "Hidden" }, { "show", "Shown" } },
    g, s), COL2 + 4, -92)
  g, s = S("highlightNext")
  Place(p, W.Check(p, "Highlight the next tick", g, s), COL2, -136)
  g, s = S("nextColor")
  Place(p, W.Swatch(p, "Next-tick color", g, s), COL2 + 4, -166)
end

---------------------------------------------------------------------------
-- Alerts page
---------------------------------------------------------------------------

local function BuildAlertsPage()
  local p = NewPage("Alerts")
  local S = W.Setting
  local secs = function(v) return v == 0 and "Off" or ("%gs"):format(v) end

  W.Header(p, "When a timer ends"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("expireSound")
  local expire = Place(p, W.Cycle(p, "Sound", SoundChoices(false), g, s), 4, -22)
  W.Button(p, "Test", 50, function() ns.PlaySound(ns.DB().expireSound) end):SetPoint("LEFT", expire, "RIGHT", 6, -8)

  W.Header(p, "Warning before it ends"):SetPoint("TOPLEFT", 0, -80)
  g, s = S("warnSeconds")
  Place(p, W.Slider(p, "Warn with this many seconds left", 0, 10, 0.5, g, s, secs), 4, -102)
  g, s = S("warnSound")
  local warn = Place(p, W.Cycle(p, "Warning sound", SoundChoices(false), g, s), 4, -142)
  W.Button(p, "Test", 50, function() ns.PlaySound(ns.DB().warnSound) end):SetPoint("LEFT", warn, "RIGHT", 6, -8)
  g, s = S("warnFlash")
  Place(p, W.Check(p, "Flash the bar during the warning", g, s), 0, -188)

  W.Header(p, "Options"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("soundChannel")
  Place(p, W.Cycle(p, "Play sounds on channel", ns.CHANNELS, g, s), COL2 + 4, -22)
  g, s = S("alertOtherTargets")
  Place(p, W.Check(p, "Also alert for other targets", g, s,
    "Alert for your DoTs on enemies you've switched away from, or that you can see a nameplate for."),
    COL2, -66)
  g, s = S("alertOnlyInCombat")
  Place(p, W.Check(p, "Only alert in combat", g, s), COL2, -92)
  local note = W.Label(p, "Each spell can have its own sounds: pick it on the Spells tab.", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", COL2, -128)
  note:SetWidth(270)
end

---------------------------------------------------------------------------
-- General page
---------------------------------------------------------------------------

local function BuildGeneralPage()
  local p = NewPage("General")
  local S = W.Setting

  W.Header(p, "Showing bars"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("locked")
  Place(p, W.Check(p, "Lock bars in place", g, s, "Unlock to drag the bars by their blue handle."), 0, -20)
  g, s = S("showChannel")
  Place(p, W.Check(p, "Show a bar for your channeled spells", g, s), 0, -46)
  g, s = S("showSelf")
  Place(p, W.Check(p, "Also show tracked auras on yourself", g, s,
    "Your own buffs and HoTs (and debuffs on you) get bars too, below your target's."), 0, -72)
  g, s = S("hideOutOfCombat")
  Place(p, W.Check(p, "Hide bars out of combat", g, s), 0, -98)
  g, s = S("alpha")
  Place(p, W.Slider(p, "Opacity in combat", 0.1, 1, 0.05, g, s, pct), 4, -132)
  g, s = S("oocAlpha")
  Place(p, W.Slider(p, "Opacity out of combat", 0.1, 1, 0.05, g, s, pct), 4, -172)

  W.Header(p, "Reset"):SetPoint("TOPLEFT", COL2, 0)
  W.Button(p, "Reset bar position", 160, ns.ResetPosition):SetPoint("TOPLEFT", COL2 + 4, -22)
  local reset = W.Button(p, "Reset all settings", 160)
  reset:SetPoint("TOPLEFT", COL2 + 4, -50)
  reset:SetScript("OnClick", function(self)
    if self.armed then
      self.armed = nil
      self:SetText("Reset all settings")
      ns.ResetSettings()
      p:Refresh()
    else
      self.armed = true
      self:SetText("Click again to confirm")
    end
  end)
  reset:SetScript("OnHide", function(self)
    self.armed = nil
    self:SetText("Reset all settings")
  end)
  local resetNote = W.Label(p, "Resets look and alerts. Your tracked spells are kept.", "GameFontDisableSmall")
  resetNote:SetPoint("TOPLEFT", COL2 + 4, -78)
  resetNote:SetWidth(260)

  W.Header(p, "Commands"):SetPoint("TOPLEFT", COL2, -110)
  local help = W.Label(p, "/ticky - this window\n/ticky lock | unlock\n/ticky preview\n/ticky add <spell>\n"
    .. "/ticky remove <spell>\n/ticky list\n/ticky reset", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", COL2 + 4, -132)
  help:SetSpacing(3)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function Build()
  panel = CreateFrame("Frame", "TickyOptions", UIParent)
  panel:SetSize(620, 520)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  tinsert(UISpecialFrames, "TickyOptions")

  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
  local edges = {
    { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
  }
  for _, e in ipairs(edges) do
    local line = panel:CreateTexture(nil, "BORDER")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetPoint(e[1])
    line:SetPoint(e[2])
    if e[3] then line:SetHeight(1) else line:SetWidth(1) end
  end

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local title = W.Label(panel, "Ticky", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  local version = C_AddOns.GetAddOnMetadata(ADDON, "Version")
  local sub = W.Label(panel, (version and ("v" .. version .. "  ") or "") .. "Buff and debuff timers with ticks",
    "GameFontDisableSmall")
  sub:SetPoint("LEFT", title, "RIGHT", 8, -1)

  BuildSpellsPage()
  BuildBarsPage()
  BuildTextPage()
  BuildAlertsPage()
  BuildGeneralPage()

  local x = 16
  for i, p in ipairs(pages) do
    local t = W.Button(panel, p.title, 110, function() ShowPage(i) end)
    t:SetPoint("TOPLEFT", x, -42)
    x = x + 114
    tabs[i] = t
  end

  local preview = W.Check(panel, "Show preview bars while this window is open",
    function() return ns.DB().previewInOptions end,
    function(v)
      ns.DB().previewInOptions = v
      ns.SetPreview(v)
    end, "Sample timers loop on the bars so you can see your styling.")
  preview:SetPoint("BOTTOMLEFT", 12, 10)

  panel:SetScript("OnShow", function()
    preview:Refresh()
    ns.SetPreview(ns.DB().previewInOptions)
    ShowPage(panel.current or 1)
  end)
  panel:SetScript("OnHide", function() ns.SetPreview(false) end)
  panel:Hide()
end

function ns.ToggleOptions(show)
  if not panel then Build() end
  if show == nil then show = not panel:IsShown() end
  panel:SetShown(show)
end

local pending
function ns.RefreshOptions(deferred)
  if not panel or not panel:IsShown() or panel.current ~= 1 then return end
  -- Spell data can arrive in bursts; coalesce those refreshes.
  if deferred then
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
      pending = nil
      ns.RefreshOptions()
    end)
    return
  end
  RefreshSpellList()
end

-- Shift-clicking a spell while the add box has focus drops its link in.
local function OnInsertLink(link)
  local box = spellsPage and spellsPage.addBox
  if box and box:IsVisible() and box:HasFocus() and link then box:SetText(link) end
end
if ChatFrameUtil and ChatFrameUtil.InsertLink then
  hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
elseif ChatEdit_InsertLink then
  hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
end

-- An entry under Game Menu > Options > AddOns that opens this window.
if Settings and Settings.RegisterCanvasLayoutCategory then
  local canvas = CreateFrame("Frame")
  local t = W.Label(canvas, "Ticky", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  local d = W.Label(canvas, "Ticky's settings have their own window.", "GameFontHighlight")
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
  W.Button(canvas, "Open Ticky options", 180, function()
    if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
    ns.ToggleOptions(true)
  end):SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
  local category = Settings.RegisterCanvasLayoutCategory(canvas, "Ticky")
  Settings.RegisterAddOnCategory(category)
end
