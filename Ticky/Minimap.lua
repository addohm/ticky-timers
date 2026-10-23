local ADDON, ns = ...

-- Ticky's minimap button: the ring-timer logo on the minimap's edge. Left-click opens the
-- options, right-click locks or unlocks the bars, dragging moves it around the edge (the angle is
-- saved). Forever's own minimap art is atlases, so the button brings its own round art
-- (Media\Minimap, made by tools/make_logo.py). The addon compartment entry stays too.

local db, button
local ICON = "Interface\\AddOns\\Ticky\\Media\\Minimap"
local OUTSIDE = 6 -- how far past the minimap's edge the button's centre sits

-- On the edge at the saved angle (0 = right, counter-clockwise); along a square minimap's sides
-- when a minimap addon makes it square (and says so with GetMinimapShape).
local function Place()
  local angle = math.rad(db.minimapAngle or 225)
  local x, y = math.cos(angle), math.sin(angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  if shape == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + OUTSIDE),
    y * (Minimap:GetHeight() / 2 + OUTSIDE))
end

-- While dragging: the angle from the minimap's centre to the cursor.
local function Drag()
  local mx, my = Minimap:GetCenter()
  if not mx then return end
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  db.minimapAngle = math.floor(math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360 + 0.5)
  Place()
end

local function Tooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Ticky")
  GameTooltip:AddLine("Left-click: options", 1, 1, 1)
  GameTooltip:AddLine("Right-click: " .. (db.locked and "unlock" or "lock") .. " the bars", 1, 1, 1)
  GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
  GameTooltip:Show()
end

local function Create()
  button = CreateFrame("Button", "TickyMinimapButton", Minimap)
  button.tickyOwned = true
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT")
  icon:SetPoint("BOTTOMRIGHT")
  icon:SetTexture(ICON)
  local glow = button:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(icon)
  glow:SetTexture(ICON)
  glow:SetBlendMode("ADD")
  glow:SetAlpha(0.35)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnClick", function(self, which)
    if which == "RightButton" then
      db.locked = not db.locked
      ns.ApplyStyle()
      print("|cff99ccffTicky|r: " .. (db.locked and "Locked." or "Unlocked - drag the blue bar to move."))
      Tooltip(self)
    else
      ns.ToggleOptions()
    end
  end)
  button:SetScript("OnMouseDown", function() -- pressed: the icon sinks a pixel
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", 1, -1)
  end)
  button:SetScript("OnMouseUp", function()
    icon:SetPoint("TOPLEFT")
    icon:SetPoint("BOTTOMRIGHT")
  end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", Drag)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", Tooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Show or hide it as the settings say (called on load, at login and by ns.ApplyStyle).
function ns.UpdateMinimapButton()
  if not db then return end
  if not db.minimapButton then
    if button then button:Hide() end
    return
  end
  if not button then
    if not Minimap then return end -- another addon took the minimap away
    Create()
  end
  Place()
  button:Show()
end

function ns.CreateMinimapButton()
  db = ns.DB()
  ns.UpdateMinimapButton()
end
