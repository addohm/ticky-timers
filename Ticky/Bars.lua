-- Ticky bars: drawing the timer bars, their tick markers, styling and the preview.
local ADDON, ns = ...

local ipairs, wipe, min, max, abs, sin, floor = ipairs, wipe, math.min, math.max, math.abs, math.sin, math.floor

local db
local anchor
local bars = {}
local styleVersion = 0
ns.preview = false

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
  b.bg:SetColorTexture(0, 0, 0, db.bgAlpha)

  b.icon:SetShown(db.showIcon)
  b.icon:SetSize(h, h)
  b.icon:ClearAllPoints()
  if db.iconSide == "LEFT" then
    b.icon:SetPoint("RIGHT", b, "LEFT", -2, 0)
  else
    b.icon:SetPoint("LEFT", b, "RIGHT", 2, 0)
  end

  local font = Path(ns.FONTS, db.font)
  b.name:SetFont(font, db.fontSize, db.outline)
  b.time:SetFont(font, db.fontSize, db.outline)
  b.name:SetShown(db.showName)
  b.time:SetShown(db.showTime or db.showTickCount)
  b.name:ClearAllPoints()
  b.name:SetPoint("LEFT", 4, 0)
  b.name:SetPoint("RIGHT", b.time, "LEFT", -4, 0)

  for _, tk in ipairs(b.ticks) do tk:SetSize(db.tickWidth, h) end
  b.version = styleVersion
end

local function NewBar(i)
  local b = CreateFrame("StatusBar", nil, anchor)
  b:SetMinMaxValues(0, 1)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.time:SetPoint("RIGHT", -4, 0)
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
    tk:SetSize(db.tickWidth, db.height)
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

-- 4.2 under 10s, 37 under a minute, 4:05 under 10 minutes, then 25m / 2h.
local function FormatTime(t)
  if t < 10 then return ("%.1f"):format(t) end
  if t < 60 then return ("%d"):format(floor(t)) end
  if t < 600 then return ("%d:%02d"):format(floor(t / 60), floor(t % 60)) end
  if t < 3600 then return ("%dm"):format(floor(t / 60)) end
  return ("%dh"):format(floor(t / 3600))
end

local function UpdateBar(b, e, now)
  local span = e.expires - e.start
  local remain = max(0, e.expires - now)
  local cfg = ns.SpellCfg(e.key)
  local drain = db.fillMode == "drain"

  local c = (db.lowEnabled and remain <= db.lowSeconds) and db.lowColor or (cfg and cfg.color) or DEFAULT_COLOR
  b:SetStatusBarColor(c[1], c[2], c[3])
  b:SetValue(drain and remain / span or 1 - remain / span)
  b.icon:SetTexture(e.icon or (cfg and cfg.icon))
  local label = (cfg and cfg.label and cfg.label ~= "") and cfg.label or e.name
  b.name:SetText(e.youTag and (label .. " |cff999999(you)|r") or label)

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
      tk:SetPoint("CENTER", b, "LEFT", (drain and (1 - f) or f) * db.width, 0)
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
    b.time:SetFormattedText("|cffbbbbbbx%d|r  %s", left, timeText)
  elseif db.showTickCount and #fracs > 0 then
    b.time:SetFormattedText("x%d", left)
  elseif db.showTime then
    b.time:SetText(timeText)
  else
    b.time:SetText("")
  end

  if db.warnFlash and db.warnSeconds > 0 and remain <= db.warnSeconds then
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
local previewList = {}

local function PreviewTimers(now)
  wipe(previewList)
  local src = {}
  for key, cfg in pairs(ns.CharDB().spells) do
    if not cfg.isChannel then src[#src + 1] = { key = key, cfg = cfg } end
  end
  table.sort(src, function(a, b) return a.key < b.key end)
  if db.showChannel then
    local t = now % 4
    previewList[1] = { key = "~channel", name = "Sample Channel", icon = 136208, channel = true,
      start = now - t, expires = now - t + 3, interval = 1 }
    if t >= 3 then previewList[1] = nil end
  end
  for i = 1, max(#src, 1) do
    if i > 3 then break end
    local s = src[i]
    local sample = SAMPLES[i]
    local dur = sample.dur
    local iv = sample.iv
    if s then iv = s.cfg.id and ns.AuraPeriod(s.cfg.id) end
    local offset = (now + i * 4.7) % (dur + 2)
    if offset < dur then
      previewList[#previewList + 1] = {
        key = s and s.key or ("~sample" .. i), name = s and s.cfg.name or sample.name,
        icon = s and s.cfg.icon or sample.icon,
        start = now - offset, expires = now - offset + dur, interval = iv,
      }
    end
  end
  return previewList
end

function ns.SetPreview(on)
  ns.preview = on and true or false
end

---------------------------------------------------------------------------
-- Frame updates
---------------------------------------------------------------------------

function ns.UpdateBars(now)
  local list = ns.preview and PreviewTimers(now) or ns.ActiveTimers(now)
  local combat = ns.InCombat()
  local visible = ns.preview or combat or not db.hideOutOfCombat or not db.locked
  anchor:SetShown(visible)
  if not visible then return end
  anchor:SetAlpha((combat or ns.preview) and db.alpha or db.oocAlpha)
  for i, e in ipairs(list) do UpdateBar(GetBar(i), e, now) end
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
