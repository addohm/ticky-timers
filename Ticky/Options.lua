-- Ticky options window: Spells, Bars, Layout, Text & Ticks, Sounds, Health bar, Nameplates, General.
-- Open with /ticky, the minimap addon menu, or Game Menu > Options > AddOns > Ticky.
local ADDON, ns = ...

local W = ns.W
local panel
local pages, tabs = {}, {}
local ROW_H = 26
local COL2 = 350

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

local function RefreshDetail()
  local cfg = selected and ns.CharDB().spells[selected.key]
  detail:SetShown(selected ~= nil)
  if not selected then return end
  detail.icon:SetTexture(selected.icon or (cfg and cfg.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
  detail.name:SetText(selected.name)
  detail.info:SetText(ns.Describe(selected.key, selected.id))
  detail.untracked:SetShown(cfg == nil)
  detail.scroll:SetShown(cfg ~= nil)
  if cfg then
    local keys = ns.OrderedSpells()
    for i, k in ipairs(keys) do
      if k == selected.key then detail.position:SetText(("Position %d of %d"):format(i, #keys)) end
    end
    for _, c in ipairs(detail.controls.list) do c:Refresh() end
    detail.labelBox:SetText(cfg.label or "")
    detail.speechBox:SetText(cfg.speech or "")
  end
end

local function GetRow(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, content)
  r:SetSize(280, ROW_H)
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

-- The selected spell's settings: order, look, text, missing behaviour, warning and sounds.
local function BuildSpellDetail(p)
  detail = CreateFrame("Frame", nil, p)
  detail:SetPoint("TOPLEFT", 310, 0)
  detail:SetPoint("BOTTOMRIGHT")
  detail.icon = detail:CreateTexture(nil, "ARTWORK")
  detail.icon:SetSize(36, 36)
  detail.icon:SetPoint("TOPLEFT")
  detail.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  detail.name = W.Label(detail, "", "GameFontNormalLarge")
  detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.info = W.Label(detail, "", "GameFontHighlightSmall")
  detail.info:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
  detail.info:SetWidth(300)
  detail.untracked = W.Label(detail, "Not tracked. Tick its box in the list to track it.", "GameFontDisable")
  detail.untracked:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -16)

  local scroll = CreateFrame("ScrollFrame", "TickyOptionsDetailScroll", detail, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -46)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  local c = CreateFrame("Frame", nil, scroll)
  c:SetSize(330, 640)
  scroll:SetScrollChild(c)
  detail.scroll = scroll
  c.list = {}
  detail.controls = c
  local function Keep(ctrl, x, y)
    ctrl:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
    if ctrl.Refresh then c.list[#c.list + 1] = ctrl end
    return ctrl
  end
  -- These controls are only shown for a tracked spell; the fallback table just keeps them safe.
  local function cfg() return selected and ns.CharDB().spells[selected.key] or {} end
  local function changed()
    ns.RefreshDisplay()
    RefreshSpellList()
  end

  detail.position = Keep(W.Label(c, "", "GameFontHighlightSmall"), 4, -6)
  local function move(dir)
    if selected and ns.IsTracked(selected.key) then
      ns.MoveSpell(selected.key, dir)
      RefreshDetail()
    end
  end
  local up = Keep(W.Button(c, "Move up", 80, function() move(-1) end), 156, 0)
  Keep(W.Button(c, "Move down", 80, function() move(1) end), 240, 0)
  local orderTip = "Sets this spell's place when bars are ordered by \"Your order\" (Layout tab)."
  up:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(orderTip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  up:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Keep(W.Swatch(c, "Bar color", function() return cfg().color end, function(v) cfg().color = v end), 4, -30)
  local onBar = Keep(W.Check(c, "On the target's health bar", function() return not cfg().noOverlay end,
    function(v) cfg().noOverlay = not v or nil end,
    "Include this spell in the health bar overlay (Health bar tab), if it's a DoT or HoT."), 120, -28)
  onBar.label:SetFontObject("GameFontHighlightSmall")
  local onPlate = Keep(W.Check(c, "On nameplates", function() return not cfg().noPlate end,
    function(v) cfg().noPlate = not v or nil end,
    "Show this spell's bar on nameplates too (Nameplates tab)."), 120, -52)
  onPlate.label:SetFontObject("GameFontHighlightSmall")

  local anyone = Keep(W.Check(c, "Track it from anyone, not just you", function() return cfg().anyCaster end,
    function(v)
      cfg().anyCaster = v or nil
      changed()
    end, "For example a buff another player puts on you, or a debuff a raid member applies to the boss. "
      .. "Only while the game lets addons read auras (usually out of combat)."), 0, -80)
  anyone.label:SetFontObject("GameFontHighlightSmall")

  Keep(W.Label(c, "Bar text (blank = spell name)", "GameFontHighlightSmall"), 4, -110)
  detail.labelBox = Keep(W.EditBox(c, 220), 10, -124)
  detail.labelBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      local t = strtrim(self:GetText())
      cfg().label = t ~= "" and t or nil
    end
  end)

  Keep(W.Label(c, "Words for \"Say it\" sounds (blank = bar text)", "GameFontHighlightSmall"), 4, -152)
  detail.speechBox = Keep(W.EditBox(c, 220), 10, -166)
  detail.speechBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      local t = strtrim(self:GetText())
      cfg().speech = t ~= "" and t or nil
    end
  end)

  Keep(W.Cycle(c, "When it's not on your target", {
    { "DEFAULT", "Use default (Layout tab)" }, { "hide", "Hide it (bars close up)" },
    { "space", "Keep its slot empty" }, { "show", "Show a faded bar" },
  }, function() return cfg().missing or "DEFAULT" end, function(v)
    cfg().missing = v ~= "DEFAULT" and v or nil
  end), 4, -196)

  Keep(W.Slider(c, "Warning time", 0, 10, 0.5, function() return cfg().warnSeconds or 0 end,
    function(v) cfg().warnSeconds = v > 0 and v or nil end,
    function(v) return v == 0 and "Default (Sounds tab)" or ("%gs before it ends"):format(v) end,
    "When the warning sound, message and flash happen for this spell."), 4, -244)

  Keep(W.Header(c, "Sounds"), 0, -290)
  local y = -312
  for _, ev in ipairs(ns.SOUND_EVENTS) do
    local field = ev[1]
    local cyc = Keep(W.Cycle(c, ev[2], function() return ns.SoundChoices(true) end,
      function() return cfg()[field] or "DEFAULT" end,
      function(v)
        cfg()[field] = v ~= "DEFAULT" and v or nil
        -- A warning sound with no warning time would never play: give this spell one.
        if field == "warnSound" and v ~= "NONE" and selected and ns.WarnSeconds(selected.key) == 0 then
          cfg().warnSeconds = 3
          RefreshDetail()
        end
      end), 4, y)
    W.Button(c, "Test", 50, function()
      if selected then ns.TestSound(selected.key, field) end
    end):SetPoint("LEFT", cyc, "RIGHT", 6, -8)
    y = y - 46
  end

  Keep(W.Button(c, "Stop tracking", 120, function()
    if selected then ns.Untrack(selected.key) end
    RefreshSpellList()
  end), 4, y - 6)
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
  list:SetSize(280, 360)
  content = CreateFrame("Frame", nil, list)
  content:SetSize(280, 1)
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

  BuildSpellDetail(p)
  p.OnRefresh = RefreshSpellList
end

---------------------------------------------------------------------------
-- Shared helpers for the settings pages
---------------------------------------------------------------------------

local function Place(page, ctrl, x, y)
  ctrl:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
  return Add(page, ctrl)
end

local function Note(page, text, x, y, width)
  local n = W.Label(page, text, "GameFontDisableSmall")
  n:SetPoint("TOPLEFT", x, y)
  n:SetWidth(width or 300)
  return n
end

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

---------------------------------------------------------------------------
-- Bars page
---------------------------------------------------------------------------

local function BuildBarsPage()
  local p = NewPage("Bars")
  local S = W.Setting

  W.Header(p, "Size"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("width")
  Place(p, W.Slider(p, "Width", 80, 500, 5, g, s), 4, -22)
  g, s = S("height")
  Place(p, W.Slider(p, "Height", 8, 48, 1, g, s), 4, -62)
  g, s = S("scale")
  Place(p, W.Slider(p, "Scale", 0.5, 2, 0.05, g, s, pct), 4, -102)

  W.Header(p, "Fill"):SetPoint("TOPLEFT", 0, -146)
  g, s = S("fillMode")
  Place(p, W.Cycle(p, "Bar fill", { { "drain", "Empties as time runs out" }, { "fill", "Fills as time passes" } },
    g, s), 4, -168)
  g, s = S("reverse")
  Place(p, W.Cycle(p, "Direction", { { false, "Full side on the left" }, { true, "Full side on the right" } },
    g, s), 4, -212)
  g, s = S("spark")
  Place(p, W.Check(p, "Spark at the edge of the fill", g, s), 0, -258)

  W.Header(p, "Running low"):SetPoint("TOPLEFT", 0, -294)
  g, s = S("lowEnabled")
  Place(p, W.Check(p, "Change color near the end", g, s,
    "Recolor the bar in its last seconds, so you know when to reapply."), 0, -314)
  g, s = S("lowSeconds")
  Place(p, W.Slider(p, "Seconds left", 1, 10, 0.5, g, s), 4, -342)
  g, s = S("lowColor")
  Place(p, W.Swatch(p, "Low-time color", g, s), 4, -386)

  W.Header(p, "Look"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("texture")
  Place(p, W.Cycle(p, "Texture", Choices(ns.TEXTURES), g, s), COL2 + 4, -22)
  g, s = S("bgColor")
  Place(p, W.Swatch(p, "Background color", g, s), COL2 + 4, -70)
  g, s = S("bgAlpha")
  Place(p, W.Slider(p, "Background opacity", 0, 1, 0.05, g, s, pct), COL2 + 4, -98)
  g, s = S("borderSize")
  Place(p, W.Cycle(p, "Border", { { 0, "None" }, { 1, "Thin" }, { 2, "Medium" }, { 3, "Thick" } }, g, s),
    COL2 + 4, -140)
  g, s = S("borderColor")
  Place(p, W.Swatch(p, "Border color", g, s), COL2 + 4, -188)

  W.Header(p, "Icon"):SetPoint("TOPLEFT", COL2, -226)
  g, s = S("showIcon")
  Place(p, W.Check(p, "Show spell icon", g, s), COL2, -246)
  g, s = S("iconSide")
  Place(p, W.Cycle(p, "Icon side", { { "LEFT", "Left" }, { "RIGHT", "Right" } }, g, s), COL2 + 4, -274)
end

---------------------------------------------------------------------------
-- Layout page
---------------------------------------------------------------------------

local function BuildLayoutPage()
  local p = NewPage("Layout")
  local S = W.Setting

  W.Header(p, "Stacking"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("growUp")
  Place(p, W.Cycle(p, "New bars stack", { { false, "Downward" }, { true, "Upward" } }, g, s), 4, -22)
  g, s = S("sortMode")
  Place(p, W.Cycle(p, "Order bars by", { { "name", "Spell name" }, { "remaining", "Time left" },
    { "custom", "Your order (Spells tab)" } }, g, s), 4, -66)
  g, s = S("spacing")
  Place(p, W.Slider(p, "Space between bars", 0, 20, 1, g, s), 4, -112)
  Note(p, "\"Your order\" gives every spell a fixed place: set it with Move up / Move down on the "
    .. "Spells tab. Your channel takes its place too, instead of sitting on top.\n\nFor bars that never "
    .. "move, pair it with \"Keep its slot empty\" or \"Show a faded bar\".", 4, -158, 300)

  W.Header(p, "When a spell isn't on your target"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("missingMode")
  Place(p, W.Cycle(p, "Tracked spells that are missing", { { "hide", "Hide it (bars close up)" },
    { "space", "Keep its slot empty" }, { "show", "Show a faded bar" } }, g, s), COL2 + 4, -22)
  g, s = S("missingAlpha")
  Place(p, W.Slider(p, "Faded bar opacity", 0.1, 1, 0.05, g, s, pct), COL2 + 4, -68)
  g, s = S("missingColor")
  Place(p, W.Swatch(p, "Faded bar color", g, s), COL2 + 4, -110)
  g, s = S("missingDesaturate")
  Place(p, W.Check(p, "Gray out its icon", g, s), COL2, -136)
  g, s = S("missingOnlyInCombat")
  Place(p, W.Check(p, "Only in combat", g, s), COL2, -162)
  g, s = S("missingMatchTarget")
  Place(p, W.Check(p, "Only on targets it can go on", g, s,
    "Damage spells on enemies, heals and buffs on friends."), COL2, -188)
  Note(p, "Missing bars only show while you have a living target. Each spell can override this on the "
    .. "Spells tab.", COL2 + 4, -222, 300)
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
  g, s = S("showStacks")
  Place(p, W.Check(p, "Show stacks", g, s, "On the icon, or after the name if the icon is hidden."), 0, -98)
  g, s = S("font")
  Place(p, W.Cycle(p, "Font", Choices(ns.FONTS), g, s), 4, -128)
  g, s = S("fontSize")
  Place(p, W.Slider(p, "Font size", 6, 24, 1, g, s), 4, -172)
  g, s = S("outline")
  Place(p, W.Cycle(p, "Outline", ns.OUTLINES, g, s), 4, -212)
  g, s = S("shadow")
  Place(p, W.Check(p, "Text shadow", g, s), 0, -258)

  W.Header(p, "Colors and format"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("nameColor")
  Place(p, W.Swatch(p, "Name color", g, s), COL2 + 4, -24)
  g, s = S("timeColor")
  Place(p, W.Swatch(p, "Time color", g, s), COL2 + 4, -50)
  g, s = S("timeSide")
  Place(p, W.Cycle(p, "Time position", { { "RIGHT", "Right, name on the left" },
    { "LEFT", "Left, name after it" } }, g, s), COL2 + 4, -76)
  g, s = S("decimals")
  Place(p, W.Cycle(p, "Tenths of a second", { { 10, "Under 10 seconds" }, { 3, "Under 3 seconds" },
    { 0, "Never" } }, g, s), COL2 + 4, -120)

  W.Header(p, "Tick marks"):SetPoint("TOPLEFT", COL2, -168)
  g, s = S("tickColor")
  Place(p, W.Swatch(p, "Tick color", g, s), COL2 + 4, -192)
  g, s = S("tickWidth")
  Place(p, W.Slider(p, "Tick width", 1, 6, 1, g, s), COL2 + 4, -218)
  g, s = S("tickHeight")
  Place(p, W.Slider(p, "Tick height", 0.2, 1, 0.05, g, s, pct), COL2 + 4, -258)
  g, s = S("pastTicks")
  Place(p, W.Cycle(p, "Ticks that already happened", { { "dim", "Dimmed" }, { "hide", "Hidden" }, { "show", "Shown" } },
    g, s), COL2 + 4, -298)
  g, s = S("highlightNext")
  Place(p, W.Check(p, "Highlight the next tick", g, s), COL2, -342)
  g, s = S("nextColor")
  Place(p, W.Swatch(p, "Next-tick color", g, s), COL2 + 4, -370)
end

---------------------------------------------------------------------------
-- Sounds page
---------------------------------------------------------------------------

local function BuildSoundsPage()
  local p = NewPage("Sounds")
  local S = W.Setting
  local db = ns.DB
  local secs = function(v) return v == 0 and "Off" or ("%gs"):format(v) end

  W.Header(p, "Default sounds"):SetPoint("TOPLEFT", 0, 0)
  local y = -22
  for _, ev in ipairs(ns.SOUND_EVENTS) do
    local field = ev[1]
    local g, s = S(field)
    if field == "warnSound" then
      -- A warning sound with the warning time Off would never play: switch it on.
      local set = s
      s = function(v)
        set(v)
        if v ~= "NONE" and db().warnSeconds == 0 then
          db().warnSeconds = 3
          p:Refresh()
        end
      end
    end
    local cyc = Place(p, W.Cycle(p, ev[2], function() return ns.SoundChoices(false) end, g, s), 4, y)
    W.Button(p, "Test", 50, function() ns.PlaySound(db()[field], "Test") end):SetPoint("LEFT", cyc, "RIGHT", 6, -8)
    y = y - 44
  end

  W.Header(p, "Warning"):SetPoint("TOPLEFT", 0, y - 6)
  local g, s = S("warnSeconds")
  Place(p, W.Slider(p, "Warn with this many seconds left", 0, 10, 0.5, g, s, secs), 4, y - 28)
  g, s = S("warnFlash")
  Place(p, W.Check(p, "Flash the bar during the warning", g, s), 0, y - 68)

  W.Header(p, "Options"):SetPoint("TOPLEFT", COL2, 0)
  g, s = S("soundChannel")
  Place(p, W.Cycle(p, "Play sounds on channel", ns.CHANNELS, g, s), COL2 + 4, -22)
  g, s = S("alertOtherTargets")
  Place(p, W.Check(p, "Also alert for other targets", g, s,
    "Alert for your DoTs on enemies you've switched away from, or that you can see a nameplate for."),
    COL2, -66)
  g, s = S("alertOnlyInCombat")
  Place(p, W.Check(p, "Only alert in combat", g, s), COL2, -92)

  W.Header(p, "On-screen text"):SetPoint("TOPLEFT", COL2, -126)
  g, s = S("msgWarn")
  Place(p, W.Check(p, "\"Ends soon\" at the warning", g, s), COL2, -146)
  g, s = S("msgExpire")
  Place(p, W.Check(p, "\"Has ended\" when it ends", g, s), COL2, -172)
  g, s = S("msgRemove")
  Place(p, W.Check(p, "\"Was removed\" when removed early", g, s), COL2, -198)

  W.Header(p, "Your own sound files"):SetPoint("TOPLEFT", COL2, -232)
  Note(p, "A path inside the WoW folder, like Interface\\AddOns\\MySounds\\ding.ogg, or a sound file ID. "
    .. "New files only load when the game starts.", COL2 + 4, -252, 320)
  local box = W.EditBox(p, 220)
  box:SetPoint("TOPLEFT", COL2 + 10, -284)
  local chosen
  local function files() return db().customSounds end
  local fileCycle = Place(p, W.Cycle(p, "Added files", function()
    local out = {}
    for _, f in ipairs(files()) do out[#out + 1] = { f, f:match("([^\\/]+)$") or f } end
    if #out == 0 then out[1] = { nil, "(none yet)" } end
    return out
  end, function() return chosen end, function(v) chosen = v end), COL2 + 4, -312)
  local status = W.Label(p, "", "GameFontHighlightSmall")
  status:SetWidth(250)
  local function say(ok, msg) status:SetText((ok and "|cff66ff66" or "|cffff6666") .. msg .. "|r") end
  local function test(f)
    if not PlaySoundFile then return say(false, "This game client can't play sound files.") end
    if ns.PlaySound("F:" .. f) then
      say(true, "Playing.")
    else
      say(false, "The game didn't play it. Check the file is there and restart the game "
        .. "(new files only load at startup; /reload isn't enough).")
    end
  end
  local function add()
    local f, why = ns.CleanSoundPath(box:GetText())
    if not f then return say(false, why) end
    if why then print("|cff99ccffTicky|r: " .. why) end
    box:SetText("")
    box:ClearFocus()
    local known = false
    for _, v in ipairs(files()) do if v == f then known = true end end
    if not known then table.insert(files(), f) end
    chosen = f
    p:Refresh()
    test(f)
  end
  W.Button(p, "Add", 60, add):SetPoint("LEFT", box, "RIGHT", 6, 0)
  box:SetScript("OnEnterPressed", add)
  W.Button(p, "Remove", 70, function()
    if chosen then
      ns.RemoveCustomSound(chosen)
      chosen = files()[1]
      p:Refresh()
    end
  end):SetPoint("LEFT", fileCycle, "RIGHT", 6, -8)
  local testButton = W.Button(p, "Test", 50, function()
    if chosen then test(chosen) end
  end)
  testButton:SetPoint("TOPLEFT", fileCycle, "BOTTOMLEFT", 0, -2)
  status:SetPoint("TOPLEFT", testButton, "TOPRIGHT", 8, -2)
  Note(p, "\"Say it\" speaks with the game's text-to-speech voice. Each spell can pick its own sounds "
    .. "and words on the Spells tab.", COL2 + 4, -400, 320)
  p.OnRefresh = function() if not chosen then chosen = files()[1] end end
end

---------------------------------------------------------------------------
-- Health bar page
---------------------------------------------------------------------------

local function BuildHealthPage()
  local p = NewPage("Health bar")
  local S = W.Setting
  local db = ns.DB

  W.Header(p, "On your target's health bar"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("overlayDamage")
  Place(p, W.Check(p, "Damage your DoTs will still do", g, s,
    "Covers the part of your target's health that your DoTs (and your channel) will still take off, "
    .. "ending at its current health."), 0, -20)
  g, s = S("overlayHeal")
  Place(p, W.Check(p, "Healing your HoTs will still do", g, s,
    "Covers the part your HoTs will still heal, starting at your target's current health."), 0, -46)
  g, s = S("overlayColors")
  Place(p, W.Cycle(p, "Colors", { { "each", "Each spell's bar color" },
    { "single", "One for damage, one for healing" } }, g, s), 4, -80)
  g, s = S("overlayDamageColor")
  Place(p, W.Swatch(p, "Damage color (one-color mode)", g, s), 4, -128)
  g, s = S("overlayHealColor")
  Place(p, W.Swatch(p, "Healing color (one-color mode)", g, s), 4, -154)
  g, s = S("overlayAlpha")
  Place(p, W.Slider(p, "Opacity", 0.1, 1, 0.05, g, s, pct), 4, -182)
  g, s = S("overlayTexture")
  Place(p, W.Cycle(p, "Texture", Choices(ns.TEXTURES), g, s), 4, -222)
  g, s = S("overlayDividers")
  Place(p, W.Check(p, "Line between spells", g, s), 0, -268)
  Note(p, "Any spell can be left out with \"On the target's health bar\" on the Spells tab.", 4, -298, 300)

  W.Header(p, "Which health bar"):SetPoint("TOPLEFT", COL2, 0)
  local status = W.Label(p, "", "GameFontHighlightSmall")
  status:SetPoint("TOPLEFT", COL2 + 4, -24)
  status:SetWidth(320)
  W.Label(p, "Another addon's target health bar (frame name):", "GameFontHighlightSmall")
    :SetPoint("TOPLEFT", COL2 + 4, -50)
  local box = W.EditBox(p, 220)
  box:SetPoint("TOPLEFT", COL2 + 10, -66)
  local function use()
    db().overlayFrame = strtrim(box:GetText() or "")
    box:ClearFocus()
    p:Refresh()
  end
  W.Button(p, "Use", 60, use):SetPoint("LEFT", box, "RIGHT", 6, 0)
  box:SetScript("OnEnterPressed", use)
  Note(p, "For example MyUnitFrames_Target.Health. Leave empty to find it automatically "
    .. "(a unit frame addon's target frame, else Blizzard's). Use /fstack to find a frame's name.",
    COL2 + 4, -94, 320)
  Note(p, "How much is left comes from each spell's tooltip at first, which leaves out spell power. "
    .. "Once Ticky has seen the spell's ticks land on your target, it uses what they actually did.\n\n"
    .. "The health bar has to be horizontal. Nothing shows while your target has none of your DoTs "
    .. "or HoTs.", COL2 + 4, -146, 320)
  p.OnRefresh = function()
    box:SetText(db().overlayFrame or "")
    local bar, what = ns.FindHealthBar()
    local custom = db().overlayFrame ~= ""
    if bar then
      status:SetText("Drawing on: |cff66ff66" .. what .. "|r"
        .. ((custom and what ~= db().overlayFrame) and " (|cffff6666your frame name wasn't found|r)" or ""))
    else
      status:SetText("|cffff6666No target health bar found.|r Is a target frame shown?")
    end
  end
end

---------------------------------------------------------------------------
-- Nameplates page
---------------------------------------------------------------------------

local function BuildPlatesPage()
  local p = NewPage("Nameplates")
  local S = W.Setting

  W.Header(p, "Bars on nameplates"):SetPoint("TOPLEFT", 0, 0)
  local g, s = S("plateEnabled")
  Place(p, W.Check(p, "Show timer bars on nameplates", g, s,
    "Your tracked buffs and debuffs on each mob, on its nameplate. Needs nameplates turned on."), 0, -20)
  g, s = S("hideMain")
  Place(p, W.Check(p, "Hide the main bars", g, s, "Your channel bar too. Sounds, nameplate bars and the health bar overlay keep working. The preview still shows them while this window is open."), 0, -46)
  g, s = S("plateWhich")
  Place(p, W.Cycle(p, "Which nameplates", { { "others", "All but your target's" }, { "all", "All" },
    { "target", "Only your target's" } }, g, s), 4, -78)
  g, s = S("plateAnchor")
  Place(p, W.Cycle(p, "Where", { { "TOP", "Above the nameplate" }, { "BOTTOM", "Below the nameplate" } }, g, s),
    4, -124)
  g, s = S("plateOffsetY")
  Place(p, W.Slider(p, "Distance from the nameplate", -20, 60, 1, g, s), 4, -170)
  Note(p, "Colors, texture, background, border, ticks and font follow the Bars and Text & Ticks tabs. "
    .. "Each spell can be left off nameplates on the Spells tab.\n\n"
    .. "A mob only gets bars for what Ticky knows is on it: your casts on it, or its auras when the game "
    .. "lets addons read them.", 4, -214, 320)

  W.Header(p, "Size and text"):SetPoint("TOPLEFT", COL2, 0)
  Note(p, "Bars always span the nameplate's health bar.", COL2 + 4, -20, 300)
  g, s = S("plateHeightPct")
  Place(p, W.Slider(p, "Height (share of the width)", 0.03, 0.25, 0.01, g, s, pct,
    "Bars keep this shape as nameplates get wider or narrower."), COL2 + 4, -40)
  g, s = S("plateSpacing")
  Place(p, W.Slider(p, "Space between bars", 0, 6, 1, g, s), COL2 + 4, -80)
  g, s = S("plateFontSize")
  Place(p, W.Slider(p, "Font size", 6, 16, 1, g, s), COL2 + 4, -120)
  g, s = S("plateShowIcon")
  Place(p, W.Check(p, "Show spell icon", g, s), COL2, -162)
  g, s = S("plateShowName")
  Place(p, W.Check(p, "Show spell name", g, s), COL2, -188)
  g, s = S("plateShowTime")
  Place(p, W.Check(p, "Show time left", g, s), COL2, -214)
  g, s = S("plateShowTickCount")
  Place(p, W.Check(p, "Show ticks left", g, s), COL2, -240)
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
  g, s = S("hideNoTarget")
  Place(p, W.Check(p, "Hide bars when you have no target", g, s), 0, -124)
  g, s = S("hideMain")
  Place(p, W.Check(p, "Hide the main bars", g, s, "Your channel bar too. Sounds, nameplate bars and the health bar overlay keep working. The preview still shows them while this window is open."), 0, -150)
  g, s = S("alpha")
  Place(p, W.Slider(p, "Opacity in combat", 0.1, 1, 0.05, g, s, pct), 4, -184)
  g, s = S("oocAlpha")
  Place(p, W.Slider(p, "Opacity out of combat", 0.1, 1, 0.05, g, s, pct), 4, -224)

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
  Note(p, "Resets look, layout and sounds. Your tracked spells and sound files are kept.", COL2 + 4, -78, 280)

  W.Header(p, "Commands"):SetPoint("TOPLEFT", COL2, -110)
  local help = W.Label(p, "/ticky - this window\n/ticky lock | unlock\n/ticky preview\n/ticky add <spell>\n"
    .. "/ticky remove <spell>\n/ticky list\n/ticky reset\n/ticky debug", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", COL2 + 4, -132)
  help:SetSpacing(3)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function Build()
  panel = CreateFrame("Frame", "TickyOptions", UIParent)
  panel:SetSize(800, 600)
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
  BuildLayoutPage()
  BuildTextPage()
  BuildSoundsPage()
  BuildHealthPage()
  BuildPlatesPage()
  BuildGeneralPage()

  local x = 16
  for i, p in ipairs(pages) do
    local t = W.Button(panel, p.title, 92, function() ShowPage(i) end)
    t:SetPoint("TOPLEFT", x, -42)
    x = x + 96
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
