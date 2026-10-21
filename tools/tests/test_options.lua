-- The options window builds, every tab opens, every control can be used without an error.
local M, ns, check = MOCK, NS, MOCK.check
M.start()
ns.Track(589, "Shadow Word: Pain", 136207)
ns.ToggleOptions(true)
check(TickyOptions and TickyOptions.shown, "options open")
for _, f in ipairs(M.frames) do
  if f.kind == "Button" and f.data and f.data.key == "shadow word: pain" then f.scripts.OnClick(f) end
end
local skip = { ["Stop tracking"] = true, ["Reset all settings"] = true, ["Remove"] = true }
local function clickAll(f, depth)
  if depth > 12 then return end
  for _, c in ipairs(f.children) do
    if (c.kind == "Button" or c.kind == "CheckButton") and c.scripts.OnClick and not skip[c.text] then
      local ok, err = pcall(c.scripts.OnClick, c)
      check(ok, "click " .. tostring(c.text) .. ": " .. tostring(err))
    end
    clickAll(c, depth + 1)
  end
end
clickAll(TickyOptions, 0)
local tabs = 0
for _, c in ipairs(TickyOptions.children) do
  if c.kind == "Button" and c.text and c.scripts.OnClick and c.points[1] and c.points[1][5] == -42 then
    tabs = tabs + 1
    c.scripts.OnClick(c)
  end
end
check(tabs == 8, "eight tabs: " .. tabs)
SlashCmdList.TICKY("report")
check(TickyReport and TickyReport.shown and TickyReport.box.text:find("issues"), "report box with the link")
SlashCmdList.TICKY("debug")
SlashCmdList.TICKY("debug all")
check(true, "debug reports ran")
