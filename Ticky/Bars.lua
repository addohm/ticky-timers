-- Ticky bars: drawing the timer bars, their tick markers, styling, the preview and
-- on-screen alert messages.
local ADDON, ns = ...

local ipairs, pairs, wipe, max, abs, sin, floor = ipairs, pairs, wipe, math.max, math.abs, math.sin, math.floor

local db
local anchor
local bars = {}
local styleVersion = 0
ns.preview = false

local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

local function Path(list, key) return ns.Lookup(list, key)[2] end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function IconSpace() return db.showIcon and (db.height + 2) or 0 end

local function LayoutAnchor()
  anchor:SetScale(db.scale)
  anchor:SetSize(db.width + IconSpace(), db.height)
  anchor:ClearAllPoints()
  anchor:SetPoint(db.point[1], UIParent, db.point[1], db.point[2], db.point[3])
  local unlocked = not db.locked
  anchor:EnableMouse(unlocked)
  anchor.bg:SetShown(unlocked)
  anchor.label:SetShown(unlocked)
end

-- A border drawn just outside the bar; size 0 hides it.
local function LayoutBorder(b)
  local s, c = db.borderSize, db.borderColor
  local e = b.edges
  for _, t in ipairs(e) do
    t:SetShown(s > 0)
    t:SetColorTexture(c[1], c[2], c[3], 1)
    t:ClearAllPoints()
  end
  if s <= 0 then return end
  e[1]:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -s, 0)
  e[1]:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", s, 0)
  e[1]:SetHeight(s)
  e[2]:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -s, 0)
  e[2]:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", s, 0)
  e[2]:SetHeight(s)
  e[3]:SetPoint("TOPRIGHT", b, "TOPLEFT", 0, 0)
  e[3]:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", 0, 0)
  e[3]:SetWidth(s)
  e[4]:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, 0)
  e[4]:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 0, 0)
  e[4]:SetWidth(s)
end

local function StyleText(fs, font, color)
  fs:SetFont(font, db.fontSize, db.outline)
  fs:SetTextColor(color[1], color[2], color[3], 1)
  fs:SetShadowColor(0, 0, 0, 1)
  if db.shadow then fs:SetShadowOffset(1, -1) else fs:SetShadowOffset(0, 0) end
end

local function LayoutBar(b, i)
  local h, w = db.height, db.width
  b:SetSize(w, h)
  b:ClearAllPoints()
  local x = (db.showIcon and db.iconSide == "LEFT") and IconSpace() or 0
  local y = (i - 1) * (h + db.spacing)
  if db.growUp then
    b:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", x, y)
  else
    b:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
  end
  b:SetStatusBarTexture(Path(ns.TEXTURES, db.texture))
  b:SetReverseFill(db.reverse)
  local bg = db.bgColor
  b.bg:SetColorTexture(bg[1], bg[2], bg[3], db.bgAlpha)
  LayoutBorder(b)
  b.spark:SetSize(12, h * 2)

  b.icon:SetShown(db.showIcon)
  b.icon:SetSize(h, h)
  b.icon:ClearAllPoints()
  if db.iconSide == "LEFT" then
    b.icon:SetPoint("RIGHT", b, "LEFT", -2, 0)
  else
    b.icon:SetPoint("LEFT", b, "RIGHT", 2, 0)
  end

  local font = Path(ns.FONTS, db.font)
  StyleText(b.name, font, db.nameColor)
  StyleText(b.time, font, db.timeColor)
  b.stacks:SetFont(font, max(8, floor(h * 0.6)), "OUTLINE")
  b.name:SetShown(db.showName)
  b.time:SetShown(db.showTime or db.showTickCount)
  b.name:ClearAllPoints()
  b.time:ClearAllPoints()
  if db.timeSide == "LEFT" then
    b.time:SetPoint("LEFT", 4, 0)
    b.name:SetPoint("LEFT", b.time, "RIGHT", 4, 0)
    b.name:SetPoint("RIGHT", -4, 0)
  else
    b.time:SetPoint("RIGHT", -4, 0)
    b.name:SetPoint("LEFT", 4, 0)
    b.name:SetPoint("RIGHT", b.time, "LEFT", -4, 0)
  end

  local th = max(1, floor(h * db.tickHeight + 0.5))
  for _, tk in ipairs(b.ticks) do tk:SetSize(db.tickWidth, th) end
  b.version = styleVersion
end

local function NewBar(i)
  local b = CreateFrame("StatusBar", nil, anchor)
  b:SetMinMaxValues(0, 1)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.edges = {}
  for j = 1, 4 do b.edges[j] = b:CreateTexture(nil, "BACKGROUND", nil, -8) end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.stacks = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.stacks:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, -1)
  b.spark = b:CreateTexture(nil, "OVERLAY", nil, 1)
  b.spark:SetTexture(SPARK)
  b.spark:SetBlendMode("ADD")
  b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.name:SetJustifyH("LEFT")
  b.name:SetWordWrap(false)
  b.ticks = {}
  bars[i] = b
  return b
end

local function GetBar(i)
  local b = bars[i] or NewBar(i)
  if b.version ~= styleVersion then LayoutBar(b, i) end
  return b
end

local function GetTick(b, i)
  local tk = b.ticks[i]
  if not tk then
    tk = b:CreateTexture(nil, "OVERLAY")
    tk:SetSize(db.tickWidth, max(1, floor(db.height * db.tickHeight + 0.5)))
    b.ticks[i] = tk
  end
  return tk
end

function ns.ApplyStyle()
  styleVersion = styleVersion + 1
  if anchor then LayoutAnchor() end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local fracs = {}
local DEFAULT_COLOR = { 0.8, 0.35, 1 }

-- Tenths under db.decimals seconds (4.2), whole seconds under a minute (37),
-- then 4:05 under 10 minutes, then 25m / 2h.
local function FormatTime(t)
  if t < db.decimals then return ("%.1f"):format(t) end
  if t < 60 then return ("%d"):format(floor(t)) end
  if t < 600 then return ("%d:%02d"):format(floor(t / 60), floor(t % 60)) end
  if t < 3600 then return ("%dm"):format(floor(t / 60)) end
  return ("%dh"):format(floor(t / 3600))
end

local function Label(e, cfg)
  local label = (cfg and cfg.label and cfg.label ~= "") and cfg.label or e.name
  if e.stacks and e.stacks > 1 and db.showStacks and not db.showIcon then
    label = ("%s (%d)"):format(label, e.stacks)
  end
  if e.youTag then label = label .. " |cff999999(you)|r" end
  return label
end

-- A tracked spell that isn't on the target: a faded, empty-looking bar in its slot.
local function DrawMissing(b, e, cfg)
  local c = db.missingColor
  b:SetStatusBarColor(c[1], c[2], c[3])
  b:SetValue(1)
  b.icon:SetTexture(e.icon or (cfg and cfg.icon))
  b.icon:SetDesaturated(db.missingDesaturate)
  b.name:SetText(Label(e, cfg))
  b.time:SetText("")
  b.stacks:Hide()
  b.spark:Hide()
  for _, tk in ipairs(b.ticks) do tk:Hide() end
  b:SetAlpha(db.missingAlpha)
  b:Show()
end

local function UpdateBar(b, e, now)
  local cfg = ns.SpellCfg(e.key)
  if e.missing then return DrawMissing(b, e, cfg) end
  local span = e.expires - e.start
  local remain = max(0, e.expires - now)
  local drain = db.fillMode == "drain"

  local c = (db.lowEnabled and remain <= db.lowSeconds) and db.lowColor or (cfg and cfg.color) or DEFAULT_COLOR
  b:SetStatusBarColor(c[1], c[2], c[3])
  local value = drain and remain / span or 1 - remain / span
  b:SetValue(value)
  b.icon:SetTexture(e.icon or (cfg and cfg.icon))
  b.icon:SetDesaturated(false)
  b.name:SetText(Label(e, cfg))
  b.stacks:SetShown(db.showStacks and db.showIcon and e.stacks ~= nil and e.stacks > 1)
  if e.stacks then b.stacks:SetText(e.stacks) end

  -- Where along the bar (0..1 from the left) the fill edge is at a given fill value.
  local function EdgeX(v) return (db.reverse and (1 - v) or v) * db.width end
  if db.spark and value > 0 and value < 1 then
    b.spark:ClearAllPoints()
    b.spark:SetPoint("CENTER", b, "LEFT", EdgeX(value), 0)
    b.spark:Show()
  else
    b.spark:Hide()
  end

  -- A tick at time t sits where the fill edge will be at time t.
  ns.ComputeTicks(e, fracs)
  local shown, left, nextDone = 0, 0, false
  local tc, nc = db.tickColor, db.nextColor
  for _, f in ipairs(fracs) do
    local upcoming = e.start + f * span > now
    if upcoming then left = left + 1 end
    local visible = f < 0.999 and (upcoming or db.pastTicks ~= "hide")
    if visible then
      shown = shown + 1
      local tk = GetTick(b, shown)
      tk:ClearAllPoints()
      tk:SetPoint("CENTER", b, "LEFT", EdgeX(drain and (1 - f) or f), 0)
      if upcoming and db.highlightNext and not nextDone then
        nextDone = true
        tk:SetColorTexture(nc[1], nc[2], nc[3], 1)
        tk:SetWidth(db.tickWidth + 1)
        tk:SetAlpha(1)
      else
        tk:SetColorTexture(tc[1], tc[2], tc[3], 1)
        tk:SetWidth(db.tickWidth)
        tk:SetAlpha((upcoming or db.pastTicks == "show") and 0.95 or 0.25)
      end
      tk:Show()
    end
  end
  for i = shown + 1, #b.ticks do b.ticks[i]:Hide() end

  local timeText = FormatTime(remain)
  if db.showTickCount and #fracs > 0 and db.showTime then
    if db.timeSide == "LEFT" then
      b.time:SetFormattedText("%s  |cffbbbbbbx%d|r", timeText, left)
    else
      b.time:SetFormattedText("|cffbbbbbbx%d|r  %s", left, timeText)
    end
  elseif db.showTickCount and #fracs > 0 then
    b.time:SetFormattedText("x%d", left)
  elseif db.showTime then
    b.time:SetText(timeText)
  else
    b.time:SetText("")
  end

  local warn = ns.WarnSeconds(e.key)
  if db.warnFlash and warn > 0 and remain <= warn then
    b:SetAlpha(0.55 + 0.45 * abs(sin(now * 6)))
  else
    b:SetAlpha(1)
  end
  b:Show()
end

---------------------------------------------------------------------------
-- Preview: looping sample timers so styling can be seen out of combat
---------------------------------------------------------------------------

local SAMPLES = {
  { name = "Sample DoT", icon = 136207, dur = 18, iv = 3 },
  { name = "Sample HoT", icon = 135953, dur = 15, iv = 3 },
  { name = "Sample DoT 2", icon = 136118, dur = 24, iv = 3 },
}
local MAX_PREVIEW = 8
local previewList, previewChannel = {}, {}

local function ShowAll() return true end

-- Each tracked spell runs, then is missing for a few seconds, so gaps and missing bars show too.
local function PreviewTimers(now)
  wipe(previewList)
  local cdb = ns.CharDB()
  local chan
  local n = 0
  for _, key in ipairs(ns.OrderedSpells()) do
    local cfg = cdb.spells[key]
    if cfg.isChannel then
      if not chan then
        local d = cfg.id and ns.Data[cfg.id]
        local dur = d and d.d and d.d / 1000 or 3
        local t = now % (dur + 2)
        if t < dur then
          chan = previewChannel
          chan.key, chan.name, chan.icon, chan.channel = key, cfg.name, cfg.icon, true
          chan.start, chan.expires = now - t, now - t + dur
          chan.interval = d and d.p and d.p / 1000 or 1
        end
      end
    elseif n < MAX_PREVIEW then
      n = n + 1
      local sample = SAMPLES[(n - 1) % #SAMPLES + 1]
      local dur = sample.dur
      local offset = (now + n * 4.7) % (dur + 5)
      if offset < dur then
        previewList[#previewList + 1] = {
          key = key, name = cfg.name, icon = cfg.icon, stacks = n == 2 and 3 or nil,
          start = now - offset, expires = now - offset + dur, interval = cfg.id and ns.AuraPeriod(cfg.id),
        }
      end
    end
  end
  if n == 0 then
    -- Nothing tracked yet: show generic samples.
    for i, sample in ipairs(SAMPLES) do
      local offset = (now + i * 4.7) % (sample.dur + 2)
      if offset < sample.dur then
        previewList[#previewList + 1] = { key = "~sample" .. i, name = sample.name, icon = sample.icon,
          start = now - offset, expires = now - offset + sample.dur, interval = sample.iv }
      end
    end
  end
  if not chan and not next(cdb.spells) then
    local t = now % 4
    if t < 3 then
      chan = previewChannel
      chan.key, chan.name, chan.icon, chan.channel = "~channel", "Sample Channel", 136208, true
      chan.start, chan.expires, chan.interval = now - t, now - t + 3, 1
    end
  end
  return ns.BuildDisplay(now, previewList, nil, chan, ShowAll)
end

function ns.SetPreview(on)
  ns.preview = on and true or false
end

---------------------------------------------------------------------------
-- On-screen alert messages
---------------------------------------------------------------------------

local msgFrame
local MSG_HOLD, MSG_FADE = 1.5, 1

function ns.ShowMessage(text, color)
  if not msgFrame then
    msgFrame = CreateFrame("Frame", nil, UIParent)
    msgFrame:SetSize(600, 40)
    msgFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    msgFrame:SetFrameStrata("HIGH")
    msgFrame.text = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    msgFrame.text:SetPoint("CENTER")
    msgFrame:SetScript("OnUpdate", function(self, elapsed)
      self.age = self.age + elapsed
      if self.age > MSG_HOLD + MSG_FADE then
        self:Hide()
      elseif self.age > MSG_HOLD then
        self:SetAlpha(1 - (self.age - MSG_HOLD) / MSG_FADE)
      end
    end)
  end
  local c = color or DEFAULT_COLOR
  msgFrame.text:SetText(text)
  msgFrame.text:SetTextColor(c[1], c[2], c[3], 1)
  msgFrame.age = 0
  msgFrame:SetAlpha(1)
  msgFrame:Show()
end

---------------------------------------------------------------------------
-- Frame updates
---------------------------------------------------------------------------

function ns.UpdateBars(now)
  local combat = ns.InCombat()
  local visible = ns.preview or not db.locked
    or ((combat or not db.hideOutOfCombat) and (not db.hideNoTarget or ns.HasTarget()))
  anchor:SetShown(visible)
  if not visible then return end
  local list = ns.preview and PreviewTimers(now) or ns.ActiveTimers(now)
  anchor:SetAlpha((combat or ns.preview) and db.alpha or db.oocAlpha)
  for i, e in ipairs(list) do
    if e.missing == "space" then
      if bars[i] then bars[i]:Hide() end
    else
      UpdateBar(GetBar(i), e, now)
    end
  end
  for i = #list + 1, #bars do bars[i]:Hide() end
end

function ns.CreateBars()
  db = ns.DB()
  anchor = CreateFrame("Frame", "TickyAnchor", UIParent)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, _, x, y = self:GetPoint()
    db.point = { p, x, y }
  end)
  anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
  anchor.bg:SetAllPoints()
  anchor.bg:SetColorTexture(0.2, 0.6, 1, 0.35)
  anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  anchor.label:SetPoint("CENTER")
  anchor.label:SetText("Ticky - drag to move")
  ns.ApplyStyle()
end

function ns.ResetPosition()
  db.point = { "CENTER", 0, -160 }
  ns.ApplyStyle()
end
