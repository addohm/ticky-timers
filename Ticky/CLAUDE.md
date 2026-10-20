# Ticky/CLAUDE.md: the addon code

Read the root [CLAUDE.md](../CLAUDE.md) first for the hard rules (Mainline API, no combat log,
secret values, no hand-entered timing).

## Modules and what they own

All files share the addon namespace `ns`. Load order (from `Ticky.toc`) matters: a file may only
call another file's `ns` functions at runtime, not at load time, unless that file loaded earlier.

| File | Owns | Exposes on `ns` |
|---|---|---|
| `Data.lua` | Generated spell data | `ns.Data`, `ns.DataBuild` |
| `Core.lua` | Defaults, lists (textures, fonts, sounds), aura and channel reading, alert watch, tick math, events, slash commands | `DEFAULTS`, `CHAR_DEFAULTS`, `TEXTURES`, `FONTS`, `OUTLINES`, `SOUNDS`, `CHANNELS`, `Secret`, `Lookup`, `SpellInfo`, `AuraPeriod`, `ComputeTicks`, `ActiveTimers`, `RefreshDisplay`, `SpellbookSpells`, `Track`, `Untrack`, `IsTracked`, `AddSpell`, `Describe`, `PlaySound`, `ResetSettings`, `CopyDefaults`, `SpellCfg`, `DB`, `CharDB`, `InCombat`, `TB` (event frame) |
| `Bars.lua` | Anchor and bar frames, styling, drawing, preview | `CreateBars`, `ApplyStyle`, `UpdateBars`, `SetPreview`, `preview`, `ResetPosition` |
| `Widgets.lua` | Option controls | `ns.W` (`Label`, `Header`, `Button`, `Check`, `Slider`, `Cycle`, `Swatch`, `EditBox`, `Setting`) |
| `Options.lua` | Options window, Settings-panel entry, shift-click link hook | `ToggleOptions`, `RefreshOptions` |

Globals (keep this list short): `TickyDB`, `TickyCharDB`, `SLASH_TICKY1`, `SlashCmdList.TICKY`,
`Ticky_OnAddonCompartmentClick`, and frame names `TickyAnchor`, `TickyOptions`,
`TickyOptionsSpellScroll`.

## Data flow

```
UNIT_AURA (target/player/nameplateN), PLAYER_TARGET_CHANGED, NAME_PLATE_UNIT_ADDED
  -> Refresh(unit) -> ScanUnit(unit)              all HARMFUL + HELPFUL auras, in pcall
       -> TimerFromAura(aura)                      skip secret; keep tracked spells you cast
                                                   (or any caster if cfg.anyCaster)
       -> timer { key, name, icon, start, expires, interval = AuraPeriod(spellID) }
  -> Remember(unit, list)                          watch[guid][key] for alerts
  -> targetTimers / selfTimers

UNIT_SPELLCAST_CHANNEL_* (player) -> ReadChannel() -> channel timer (interval = ChannelPeriod)

OnUpdate (every frame)  -> ns.UpdateBars(now) -> ActiveTimers(now) or preview -> UpdateBar
         (every 0.1s)   -> CheckAlerts(now)   -> Warn / Expire -> PlaySound
```

- A timer's ticks are `ComputeTicks`: start + k * interval, plus a final tick at expiry.
- `AuraPeriod(id)`: `Data[id].p` (divided by haste if `h`), `nil` for non-ticking data entries,
  tooltip "every N sec" for spells missing from the data.
- Alerts: an aura that vanishes more than 0.5s before its expiry was removed early, so it's silent.
  One that vanishes at expiry, or whose expiry passes while watched, plays the end sound once.

## Saved variables

`TickyDB` (account-wide, defaults in `ns.DEFAULTS`, filled by `CopyDefaults` on load): look,
alerts and general settings as flat keys, plus `point` and `version`. Bump `DB_VERSION` in
Core.lua and add a migration in `ADDON_LOADED` when changing the meaning of an existing key.

`TickyCharDB` (per character): `spells[lowerCaseName] = { name, id, icon, color, order, label,
expireSound, warnSound, anyCaster, isChannel }` and `nextOrder`. Spells are keyed by lower-case
name so every rank matches; `id` is the rank that was added (used for data lookups in the UI).

## How to add a setting

1. Add the key and default to `ns.DEFAULTS` in Core.lua.
2. Use it where it matters (usually `LayoutBar` or `UpdateBar` in Bars.lua, or the alert code).
   Layout-affecting values are applied when `styleVersion` changes, which `ns.ApplyStyle()` does.
3. Add a control on the right page in Options.lua: `local g, s = W.Setting("key")` then
   `Place(p, W.Slider/Check/Cycle/Swatch(p, "Label", ..., g, s), x, y)`. `W.Setting` calls
   `ApplyStyle` on change. Each page has two columns at x = 0 and x = `COL2`.
4. Document it in README.md's Options section and CHANGELOG.md.

Per-spell settings live on the spell's `cfg` and get a control in the Spells page detail panel
(`c.list` for refreshable controls).

## UI templates that exist on Forever (verified on the forever branch)

`UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate`, `InputBoxTemplate`,
`SearchBoxTemplate`, `UIPanelScrollFrameTemplate`, `MinimalSliderTemplate`, `ButtonFrameTemplate`.
Not present: `OptionsSliderTemplate`, `BasicFrameTemplateWithInset`. The color picker is
`ColorPickerFrame:SetupColorPickerAndShow(info)` (load `Blizzard_ColorPickerFrame` if missing).
Sliders and dropdowns are built by hand in Widgets.lua to avoid template churn.

## Secret-value patterns

```lua
local v = aura.expirationTime
if Secret(v) then return end           -- never compare, branch on or index with a secret

local exists = UnitExists("target")
if Secret(exists) or exists then ...   -- treat "unknown" as "yes" only where harmless
```

`StatusBar:SetValue`, `SetMinMaxValues` and `FontString:SetText` accept secrets, but Ticky
currently skips secret auras entirely because the spell ID needed to find tick data would be
secret too.

## Style

Two-space indent, `local` everything, short comments that explain why. Functions on `ns` are
PascalCase; locals are camelCase. Keep UI text in plain words (no "aura instance", "GUID").
