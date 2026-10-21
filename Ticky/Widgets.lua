-- Ticky widgets: small option controls built from Forever's stock templates.
-- Every control takes get/set functions and has a :Refresh() that re-reads its value.
local ADDON, ns = ...

local floor = math.floor
local W = {}
ns.W = W

local function Tooltip(frame, title, text)
  if not text then return end
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function W.Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

-- A section title with a rule after it; `width` is the whole header's width (default 320).
function W.Header(parent, text, width)
  local fs = W.Label(parent, text, "GameFontNormal")
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.25)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 6, 0)
  line:SetWidth(math.max(20, (width or 320) - fs:GetStringWidth()))
  return fs
end

function W.Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.Check(parent, text, get, set, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb.label = W.Label(parent, text, "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  function cb:Refresh() self:SetChecked(get() and true or false) end
  Tooltip(cb, text, tip)
  return cb
end

function W.Slider(parent, text, minV, maxV, step, get, set, fmt, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(230, 34)
  f.label = W.Label(f, text, "GameFontHighlightSmall")
  f.label:SetPoint("TOPLEFT")
  f.value = W.Label(f, "", "GameFontNormalSmall")
  f.value:SetPoint("TOPRIGHT")

  local s = CreateFrame("Slider", nil, f)
  s:SetOrientation("HORIZONTAL")
  s:SetPoint("TOPLEFT", 0, -16)
  s:SetPoint("TOPRIGHT", 0, -16)
  s:SetHeight(16)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:EnableMouseWheel(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.15)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  local thumb = s:CreateTexture(nil, "ARTWORK")
  thumb:SetColorTexture(1, 0.82, 0, 1)
  thumb:SetSize(8, 16)
  s:SetThumbTexture(thumb)

  local function show(v) f.value:SetText(fmt and fmt(v) or tostring(v)) end
  s:SetScript("OnValueChanged", function(_, v)
    v = floor(v / step + 0.5) * step
    show(v)
    if not f.refreshing then set(v) end
  end)
  s:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)

  function f:Refresh()
    self.refreshing = true
    s:SetValue(get())
    show(get())
    self.refreshing = false
  end
  Tooltip(s, text, tip)
  f.slider = s
  return f
end

-- A "< choice >" selector, used instead of dropdown menus. `options` is a list of
-- { value, label } or a function returning one (for lists that change, like sounds).
function W.Cycle(parent, text, options, get, set, tip)
  local function opts() return type(options) == "function" and options() or options end
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(230, 40)
  f.label = W.Label(f, text, "GameFontHighlightSmall")
  f.label:SetPoint("TOPLEFT")
  local prev = W.Button(f, "<", 24)
  prev:SetPoint("TOPLEFT", 0, -16)
  local nextB = W.Button(f, ">", 24)
  nextB:SetPoint("TOPRIGHT", 0, -16)
  local box = f:CreateTexture(nil, "BACKGROUND")
  box:SetColorTexture(0, 0, 0, 0.4)
  box:SetPoint("TOPLEFT", prev, "TOPRIGHT", 2, 0)
  box:SetPoint("BOTTOMRIGHT", nextB, "BOTTOMLEFT", -2, 0)
  f.value = W.Label(f, "", "GameFontHighlightSmall")
  f.value:SetPoint("CENTER", box)

  local function index(list)
    local cur = get()
    for i, o in ipairs(list) do
      if o[1] == cur then return i end
    end
    return 1
  end
  local function step(d)
    local list = opts()
    local i = (index(list) - 1 + d) % #list + 1
    set(list[i][1])
    f:Refresh()
  end
  prev:SetScript("OnClick", function() step(-1) end)
  nextB:SetScript("OnClick", function() step(1) end)
  function f:Refresh()
    local list = opts()
    local o = list[index(list)]
    self.value:SetText(o[2] or tostring(o[1]))
  end
  Tooltip(prev, text, tip)
  Tooltip(nextB, text, tip)
  return f
end

local function OpenColorPicker(color, onChange)
  if not ColorPickerFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_ColorPickerFrame") end
  local r, g, b = color[1], color[2], color[3]
  ColorPickerFrame:SetupColorPickerAndShow({
    r = r, g = g, b = b, hasOpacity = false,
    swatchFunc = function()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      onChange({ nr, ng, nb })
    end,
    cancelFunc = function() onChange({ r, g, b }) end,
  })
end

function W.Swatch(parent, text, get, set, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  local border = b:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(1, 1, 1, 0.8)
  b.color = b:CreateTexture(nil, "ARTWORK")
  b.color:SetPoint("TOPLEFT", 2, -2)
  b.color:SetPoint("BOTTOMRIGHT", -2, 2)
  b.label = W.Label(parent, text, "GameFontHighlight")
  b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
  function b:Refresh()
    local c = get()
    if c then self.color:SetColorTexture(c[1], c[2], c[3], 1) end
  end
  b:SetScript("OnClick", function(self)
    OpenColorPicker(get(), function(c)
      set(c)
      self:Refresh()
    end)
  end)
  Tooltip(b, text, tip)
  return b
end

function W.EditBox(parent, width)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width, 20)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  return eb
end

-- get/set pair for an account setting that changes how bars look.
function W.Setting(key)
  return function() return ns.DB()[key] end,
    function(v)
      ns.DB()[key] = v
      ns.ApplyStyle()
    end
end
