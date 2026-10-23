-- The minimap button (the owner, 2026-10-23): on the minimap's edge with Ticky's art, shown by
-- default; left-click opens the options, right-click locks or unlocks the bars, dragging moves it
-- around the edge and the angle is kept; the General tab's switch and /ticky minimap hide it.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
local db = ns.DB()
local b = TickyMinimapButton
check(b and b.parent == Minimap and b:IsShown(), "shown on the minimap by default")
local art
for _, t in ipairs(b.children) do if t.texture then art = t.texture end end
check(art == "Interface\\AddOns\\Ticky\\Media\\Minimap", "with Ticky's own art: " .. tostring(art))

-- At 225 degrees (lower left), 6 past the edge of a 140-wide round minimap: (-53.7, -53.7).
local p = b.points[1]
check(p[2] == Minimap and math.abs(p[4] + 53.74) < 0.1 and math.abs(p[5] + 53.74) < 0.1,
  "on the edge at its angle: " .. tostring(p[4]) .. ", " .. tostring(p[5]))

-- Left-click: options; right-click: lock or unlock.
b.scripts.OnClick(b, "LeftButton")
check(TickyOptions and TickyOptions:IsShown(), "left-click opens the options")
local was = db.locked
b.scripts.OnClick(b, "RightButton")
check(db.locked ~= was, "right-click locks or unlocks the bars")

-- Drag: the cursor straight above the minimap's centre puts it at the top (90 degrees).
M.cursor = { 700, 600 }
b.scripts.OnDragStart(b)
b.scripts.OnUpdate(b, 0.02)
b.scripts.OnDragStop(b)
p = b.points[1]
check(db.minimapAngle == 90 and math.abs(p[4]) < 0.1 and math.abs(p[5] - 76) < 0.1,
  "dragged to the top: angle " .. tostring(db.minimapAngle) .. " at " .. tostring(p[4]) .. ", " .. tostring(p[5]))
check(b.scripts.OnUpdate == nil, "dragging stops with the mouse")

-- A square minimap (a minimap addon says so): along its sides, so a corner sits in the corner.
GetMinimapShape = function() return "SQUARE" end
db.minimapAngle = 45; ns.ApplyStyle()
p = b.points[1]
check(math.abs(p[4] - 76) < 0.1 and math.abs(p[5] - 76) < 0.1, "square minimap: in the corner at 45 degrees")
GetMinimapShape = nil

-- The switch, and /ticky minimap.
db.minimapButton = false; ns.ApplyStyle()
check(not b:IsShown(), "switched off: hidden")
SlashCmdList.TICKY("minimap")
check(db.minimapButton and b:IsShown(), "/ticky minimap brings it back")
