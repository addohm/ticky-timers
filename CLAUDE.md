# CLAUDE.md

Guidance for coding assistants working in this repository. This is the only CLAUDE.md: keep all
guidance here, not in subfolders. Addon internals are under [The addon code](#the-addon-code-ticky);
data generation and checks under [The tools](#the-tools-tools).

## What this is

**Ticky** is a World of Warcraft addon: timer bars for buffs and debuffs, with a marker for every
tick of DoTs, HoTs and channels. Repo: https://github.com/addohm/ticky-timers.

It targets **World of Warcraft: Forever** (Blizzard's "Classic+", launch Nov 4, 2026):
original-Azeroth content (level 60, vanilla-era spells, ranks and talents) running on the
**modern Mainline addon API** (12.x family), TOC interface **16001**. It is *not* Classic Era and
*not* TBC. The owner's old TBC WeakAuras were inspiration only.

Status: 0.5.0 plus unreleased work. The addon loads in the Forever client and its options window
opens, but bars, ticks and sounds haven't been confirmed in game; that verification is syntax checks
and a mocked API (see Testing).

## Layout

```
Ticky/            the addon (this folder is what players copy into Interface\AddOns)
  Ticky.toc       manifest; load order Data, Core, Bars, Overlay, Plates, Widgets, Options
  Data.lua        GENERATED spell data; never hand-edit
  Core.lua        settings, aura/channel reading, alerts, tick math, events, slash commands
  Bars.lua        bar frames, styling, drawing, preview
  Overlay.lua     DoT/HoT shading on the target frame's health bar
  Plates.lua      timer bars on nameplates
  Widgets.lua     option controls (check, slider, cycle, color swatch)
  Options.lua     tabbed options window, Settings-panel entry
tools/
  gen_data.py     builds Ticky/Data.lua from wago.tools CSV exports
  check_lua.py    syntax-checks Ticky/*.lua and the TOC file list
  install_beta.cmd  (Windows) git pull, then mirror Ticky/ into the beta client's AddOns folder
README.md CHANGELOG.md ROADMAP.md SECURITY.md DEPLOY.md CLAUDE.md
```

## Commands

```bash
pip install lupa                      # once; embedded Lua for the checker
python tools/check_lua.py             # syntax + TOC check; run after every Lua change
python tools/gen_data.py <csv dir> <build> Ticky/Data.lua   # regenerate spell data
```

There is no build step: the `Ticky` folder is the release. Manual testing means copying it into
`World of Warcraft\_classic_beta_\Interface\AddOns\` (beta) or the live Forever AddOns folder and
restarting the client. On the owner's Windows PC, `tools\install_beta.cmd` does the beta copy after
a `git pull`, so changes must be pushed to GitHub before it picks them up. Its paths are hard-coded
for that PC (variables at the top). `.gitattributes` keeps `*.cmd` files CRLF.

## Hard rules

1. **Mainline API only.** Use `C_Spell`, `C_SpellBook`, `C_UnitAuras`, `C_AddOns`, `C_Timer`.
   Old globals (`GetSpellInfo`, `UnitAura`, `GetSpellBookItemInfo`, `GetNumSpellTabs`,
   `CombatLogGetCurrentEventInfo`) don't exist on Forever. Don't add compat shims for other clients.
2. **No combat log.** Registering `COMBAT_LOG_EVENT_UNFILTERED` errors. Everything comes from
   your casts (`UNIT_SPELLCAST_SENT/SUCCEEDED`), `UNIT_COMBAT`, aura queries when they work,
   channel events, spell tooltips and spell data.
3. **Secret values.** Combat values (aura fields, GUIDs, haste, channel info, `UnitExists`) can be
   secret. Aura data is secret whenever *combat* restrictions are active (open world too:
   `SecretWhenUnitAuraRestricted`), unless the spell is flagged never-secret
   (`C_Secrets.GetSpellAuraSecrecy`). `UnitGUID` is secret for units that aren't player-controlled.
   Event payloads can be secret too (`UNIT_AURA` is `SecretWhenAurasRestricted`). Check
   `ns.Secret(v)` before comparing, branching, indexing or doing math on them. Skip secret data;
   never let it error the UI (aura scans run in `pcall`).
   Seen in Ticky's own testing on the Forever beta (2026-10-21): in combat the target's auras
   can't be read (bars vanished on the first aura change), while timers started from your own
   casts (`UNIT_SPELLCAST_SENT/SUCCEEDED`) work; `/ticky debug` showed every tracked priest spell
   as `ContextuallySecret` (`C_Secrets.GetSpellAuraSecrecy`). From the API docs, not yet seen in
   game: `UNIT_COMBAT` payloads have no secret flags; creature GUIDs are secret wherever unit
   identity is restricted (expected in instances), hence the nameplate-token fallback.
4. **No hand-entered timing.** Durations come from the aura when it's readable, else the duration
   last read for that spell (`TickyCharDB.durations`), else the spell's tooltip; tick periods come
   from `Ticky/Data.lua`. Don't hard-code intervals and don't add "tick every N" settings: the owner
   wants nothing configured by hand.
5. **Display and sound only.** Never automate combat decisions, call protected functions, or
   modify Blizzard unit frames. The health bar overlay only anchors our own frames to the target
   frame's health bar; re-anchor only when the bar, its width or fill direction changes.
6. **Lua 5.1, no libraries.** No `goto`, `//`, bitwise operators, `require`. No Ace/LibStub.
   Every file starts `local ADDON, ns = ...`; shared state goes on `ns`.
7. **Data.lua is generated.** Change `tools/gen_data.py` and regenerate; never edit values by hand.

## The addon code (`Ticky/`)

### Modules and what they own

All files share the addon namespace `ns`. Load order (from `Ticky.toc`) matters: a file may only
call another file's `ns` functions at runtime, not at load time, unless that file loaded earlier.

| File | Owns | Exposes on `ns` |
|---|---|---|
| `Data.lua` | Generated spell data | `ns.Data`, `ns.DataBuild` |
| `Core.lua` | Defaults, lists (textures, fonts, sounds, sound events), aura and channel reading, alerts (sounds, speech, messages), missing-spell placeholders, display list, tick math, events, slash commands | `DEFAULTS`, `CHAR_DEFAULTS`, `TEXTURES`, `FONTS`, `OUTLINES`, `SOUNDS`, `SOUND_EVENTS`, `CHANNELS`, `SoundChoices`, `Secret`, `Lookup`, `SpellInfo`, `AuraPeriod`, `ComputeTicks`, `BuildDisplay`, `ActiveTimers`, `RefreshDisplay`, `HasTarget`, `SpellbookSpells`, `Track`, `Untrack`, `IsTracked`, `OrderedSpells`, `MoveSpell`, `AddSpell`, `Describe`, `SoundFor`, `WarnSeconds`, `PlaySound`, `TestSound`, `RemoveCustomSound`, `RemainingAmount`, `TargetAmounts`, `UnitTimers`, `MobKey`, `plateUnits`, `Debug` (`/ticky debug`), `ResetSettings`, `CopyDefaults`, `SpellCfg`, `DB`, `CharDB`, `InCombat`, `TB` (event frame) |
| `Bars.lua` | Anchor and bar frames, styling, drawing, missing bars, preview, on-screen messages. Bar functions take a style `st` (the settings, or the nameplate style) | `CreateBars`, `ApplyStyle`, `UpdateBars`, `SetPreview`, `preview`, `ResetPosition`, `ShowMessage`, `GetBar`, `UpdateBar`, `IconSpace` |
| `Overlay.lua` | Health bar overlay: finding the target health bar (custom path; another addon's unit button whose `unit` attribute is "target", its largest StatusBar; else Blizzard's), and a chain of StatusBars per group (damage, heal) as wide as the health bar, scaled to the secret max health, the first pinned to the fill edge and each next to the end of the previous one's fill, inside a clipping frame | `FindHealthBar`, `UpdateOverlay`, `CreateOverlay` |
| `Plates.lua` | Bars on nameplates: a holder per (recycled) nameplate frame, parented to it and anchored to both edges of the plate's health bar (`PlateBar`: the largest visible StatusBar among the plate's child frames, which covers Blizzard's plates and addons that build on them; re-checked every frame with `IsUnder`, because Blizzard pools the plates' UnitFrames, health bar included, and moves them between plates). Its width sets the bars' size (`plateHeightPct`); Bars.lua's bars are drawn with a per-plate style proxy (`PLATE_KEYS` swap in the `plate*` text settings, `growUp` from `plateAnchor`) | `UpdatePlates`, `LayoutPlates`, `CreatePlates` |
| `Widgets.lua` | Option controls | `ns.W` (`Label`, `Header`, `Button`, `Check`, `Slider`, `Cycle`, `Swatch`, `EditBox`, `Setting`) |
| `Options.lua` | Options window, Settings-panel entry, shift-click link hook | `ToggleOptions`, `RefreshOptions` |

Globals (keep this list short): `TickyDB`, `TickyCharDB`, `SLASH_TICKY1`, `SlashCmdList.TICKY`,
`Ticky_OnAddonCompartmentClick`, and frame names `TickyAnchor`, `TickyOptions`,
`TickyOptionsSpellScroll`, `TickyOptionsDetailScroll`.

### Data flow

```
timers[mob][spellKey]   mob = MobKey(unit): GUID if readable, else "plate:nameplateN",
                        else "target" (forgotten on target change)

UNIT_SPELLCAST_SENT (player)      -> sentTo[castGUID] = MobForCast(spell, target name)
UNIT_SPELLCAST_SUCCEEDED (player) -> OnCast: tracked, not a channel -> Store(mob, timer)
                                     start = now, length = CastDuration (learned, else tooltip);
                                     apply / refresh sound; recentCast[mob] for resists
UNIT_COMBAT RESIST/IMMUNE/EVADE   -> OnAvoided: drop that cast (or restore the one it refreshed)
UNIT_COMBAT WOUND/HEAL            -> OnTickAmount: match to a timer on that mob (or the channel) by
                                     school and tick time (+-0.35s, each tick once); non-crits
                                     teach tickSizes[spellID] (60/40 running average)
every 0.1s                        -> ns.UpdateOverlay: TargetAmounts (ticks left x ExpectedTick:
                                     learned, else tooltip total / tick count) -> segment values

UNIT_AURA (target/player/nameplateN), PLAYER_TARGET_CHANGED, NAME_PLATE_UNIT_ADDED,
PLAYER_REGEN_ENABLED, and each cast timer once it's 1.1s old
  -> ReadUnit(unit) -> ScanUnit(unit)             all HARMFUL + HELPFUL auras, in pcall;
                                                  nil when reading fails (combat)
       -> TimerFromAura(aura)                      skip secret; keep tracked spells you cast
                                                   (or any caster if cfg.anyCaster)
     readable timers replace estimates and teach learned[spellID] (your own only);
     if every aura was readable, tracked timers missing from it (and not cast in the last 1s)
     ended or went to gone[mob][key] (0.3s grace, then "removed")
NAME_PLATE_UNIT_ADDED/REMOVED     -> ForgetMob("plate:" .. token); a dead GUID mob is forgotten
target dead                       -> ForgetMob(target's key), silently

UNIT_SPELLCAST_CHANNEL_* (player) -> ReadChannel() -> channel timer (interval = ChannelPeriod)

OnUpdate (every frame)  -> ns.UpdatePlates(now) -> per ns.plateUnits token: UnitTimers -> bars
                        -> ns.UpdateBars(now) -> ActiveTimers(now) or PreviewTimers(now)
                             -> BuildDisplay: channel, target group (+ missing placeholders), self
                             -> UpdateBar / DrawMissing (a "space" placeholder hides its bar)
         (every 0.1s)   -> CheckAlerts(now)   -> CheckTick / Warn / Expire / removed -> Alert
                                                 -> PlaySound (SOUNDKIT, "SPEAK", "F:<file>")
                                                    and ShowMessage
```

- A timer's ticks are `ComputeTicks`: start + k * interval, plus a final tick at expiry.
- `AuraPeriod(id)`: `Data[id].p` (divided by haste if `h`), `nil` for non-ticking data entries,
  tooltip "every N sec" for spells missing from the data.
- Alerts: each event (`SOUND_EVENTS`: apply, refresh, tick, warn, expire, remove) uses the spell's
  own choice or the account default (`SoundFor`). Apply/refresh come from your casts; an aura read
  only alerts them for an aura that started under 1s ago and wasn't just cast (someone else's with
  "from anyone"), so targeting something with your DoT already on it is silent. "Removed" is a
  resist/immunity after the cast, or an aura read showing it gone more than 0.5s early. Tick sounds
  are only for your target, yourself and your channel.
- Missing spells: with a target (alive, and in combat if `missingOnlyInCombat`), every tracked spell
  not present gets a placeholder `{ missing = "space" | "show" }` unless its mode is "hide". In
  "custom" order the channel sits in its spell's slot; otherwise it's on top.

### Saved variables

`TickyDB` (account-wide, defaults in `ns.DEFAULTS`, filled by `CopyDefaults` on load): look,
layout, text, sound and general settings as flat keys, plus `point`, `version` and
`customSounds` (list of file paths / IDs; kept by reset). Bump `DB_VERSION` (now 6) in Core.lua and
add a migration in `ADDON_LOADED` when changing the meaning of an existing key (5 renamed
`sortMode` "added" to "custom"; 6 gives `warnSeconds` 3 when a warning sound is set but the time
was 0).

`TickyCharDB` (per character): `spells[lowerCaseName] = { name, id, icon, color, order, label,
speech, missing, warnSeconds, anyCaster, isChannel, applySound, refreshSound, tickSound, warnSound,
expireSound, removeSound, noOverlay, noPlate }`, `nextOrder`, `durations[spellID]` (seconds, learned from
your own readable auras; used to time casts in combat) and `tickSizes[spellID]` (damage or healing
per tick seen on `UNIT_COMBAT`; used by the health bar overlay). Unset per-spell fields mean "use the default". Spells
are keyed by lower-case name so every rank matches; `id` is the rank that was added (used for data
lookups in the UI). `order` is the "Your order" slot (`MoveSpell` renumbers 1..n).

Sound values: a `SOUNDS` key, `"NONE"`, `"SPEAK"` (text to speech), or `"F:" .. file` (custom
file path or file ID, cleaned by `ns.CleanSoundPath`, played with the global
`PlaySoundFile(file, channel)`, which isn't in the generated docs but current retail addons still
call; its first return says whether it will play). Per-spell `"DEFAULT"` is stored as nil.

### How to add a setting

1. Add the key and default to `ns.DEFAULTS` in Core.lua.
2. Use it where it matters (usually `LayoutBar` or `UpdateBar` in Bars.lua, or the alert code).
   Layout-affecting values are applied when `styleVersion` changes, which `ns.ApplyStyle()` does.
3. Add a control on the right page in Options.lua (Bars, Layout, Text & Ticks, Sounds, General):
   `local g, s = W.Setting("key")` then
   `Place(p, W.Slider/Check/Cycle/Swatch(p, "Label", ..., g, s), x, y)`. `W.Setting` calls
   `ApplyStyle` on change. Each page is 688x480 with two columns at x = 0 and x = `COL2` (350).
   `W.Cycle` takes a list or a function returning one (for lists that change).
4. Document it in README.md's Options section and CHANGELOG.md.

Per-spell settings live on the spell's `cfg` and get a control in the Spells page detail panel
(`BuildSpellDetail`; `Keep(ctrl, x, y)` places it in the scrolling panel and registers it for
refresh). Grow the scroll child's height if you add rows.

### UI templates that exist on Forever (verified on the forever branch)

`UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate`, `InputBoxTemplate`,
`SearchBoxTemplate`, `UIPanelScrollFrameTemplate`, `MinimalSliderTemplate`, `ButtonFrameTemplate`.
Not present: `OptionsSliderTemplate`, `BasicFrameTemplateWithInset`. The color picker is
`ColorPickerFrame:SetupColorPickerAndShow(info)` (load `Blizzard_ColorPickerFrame` if missing).
Sliders and dropdowns are built by hand in Widgets.lua to avoid template churn.

### Secret-value patterns

```lua
local v = aura.expirationTime
if Secret(v) then return end           -- never compare, branch on or index with a secret

local exists = UnitExists("target")
if Secret(exists) or exists then ...   -- treat "unknown" as "yes" only where harmless
```

`StatusBar:SetValue`, `SetMinMaxValues` and `FontString:SetText` accept secrets, but Ticky
currently skips secret auras entirely because the spell ID needed to find tick data would be
secret too.

### Style

Two-space indent, `local` everything, short comments that explain why. Functions on `ns` are
PascalCase; locals are camelCase. Keep UI text in plain words (no "aura instance", "GUID").

## The tools (`tools/`)

### check_lua.py

`python tools/check_lua.py` compiles every `Ticky/*.lua` with lupa and checks that `Ticky.toc`
lists exactly the Lua files on disk. Exit code 1 on any failure. It catches syntax errors only;
lupa is Lua 5.4+, so 5.1-only problems aren't caught. Needs `pip install lupa`.

### gen_data.py

Builds `Ticky/Data.lua` from World of Warcraft: Forever's spell tables.

```bash
python tools/gen_data.py <csv dir> <build> Ticky/Data.lua
```

#### Inputs

CSV exports from wago.tools for the Forever build (product `wowf`; the beta is
`wow_classic_beta`). Download each with:

```
https://wago.tools/db2/<Table>/csv?build=<build>
```

Tables: `SpellEffect`, `SpellMisc`, `SpellDuration`, `SpellClassOptions`, `SkillLineAbility`,
`SkillLine`, `SpellName` (about 8 MB together). Find the current build at
https://wago.tools/builds (filter `wowf`). Keep the CSVs out of the repo.

#### What it selects

- **Class spells**: `SpellClassOptions.SpellClassSet` 3–11 (mage through shaman), plus spells on
  class (`SkillLine.CategoryID` 7, minus pets, mounts, companions) and racial skill lines.
- **Timed auras**: the spell has an apply-aura effect (`Effect` 6, 35, 65, 119, 128, 129, 143)
  and a positive duration (`SpellMisc.DurationIndex` -> `SpellDuration.Duration`), or is a channel.
  Permanent buffs are left out.
- **Ticking**: an effect whose `EffectAura` is periodic (damage 3, heal 8, leech 53, funnel 62,
  mana leech 64, damage % 89; then obs health/power 20/21, energize 24; then trigger 23, dummy 226)
  with `EffectAuraPeriod` > 0. The highest-priority type wins, then the lowest effect index.
- **Flags**: `h` from `SpellMisc.Attributes_5 & 0x2000` (haste affects periodic); channels from
  `Attributes_1 & 0x4` or `& 0x40`, which get `d` = base duration.
- Only `DifficultyID` 0 rows are used.

#### Output

`ns.Data[spellID] = { p = periodMs, h = true, d = channelDurationMs }` with a spell-name comment
per line, plus `ns.DataBuild`. Non-ticking auras are `{}`.

#### After regenerating

1. Run `python tools/check_lua.py`.
2. Spot-check known spells against the game (build 1.60.1.70245 values): Shadow Word: Pain 589 and
   10894 `p=3000`; Mind Flay 15407 `p=1000,d=3000`; Corruption 172 `p=3000`; Insect Swarm 5570
   `p=2000`; Power Word: Shield 17 `{}`.
3. Note the build and the counts the script prints (1,928 spells / 598 ticking / 140 channels for
   1.60.1.70245) in CHANGELOG.md, and update the build mentioned in README.md.

## Verifying an API before using it

Don't trust memory or Classic-era docs. Check the `forever` branch of
https://github.com/Gethe/wow-ui-source:

- Function signatures and secret flags:
  `Interface/AddOns/Blizzard_APIDocumentationGenerated/<System>Documentation.lua`
  (e.g. `UnitAuraDocumentation.lua`, `SimpleStatusBarAPIDocumentation.lua`). Look at
  `SecretArguments`, `SecretReturns`, `SecretWhen...` and `RequiresNonSecretAura`.
- XML templates: search `Interface/AddOns/Blizzard_SharedXML/` for `virtual="true"`.
- Raw files: `https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/<path>`.

Game data (spell tables) for Forever is on wago.tools under product `wowf`; see
[The tools](#the-tools-tools).

## Testing

1. `python tools/check_lua.py` after every change.
2. Behaviour is checked with a mocked WoW API run through lupa (stub `CreateFrame`,
   `C_UnitAuras`, `C_Spell`, `UnitChannelInfo`, etc., then drive events and `OnUpdate` and
   inspect bar text and tick positions). The harness isn't in the repo yet; keep mocks faithful to
   the forever-branch API docs, and remember a failure can be a mock artifact (e.g. mocks
   returning functions for unknown fields, or not firing `OnHide`).
3. Lupa runs Lua 5.4+, which is stricter than WoW: `("%d"):format(1.5)` errors there but not in
   game. Still floor numbers before `%d`.
4. Nothing is confirmed until tested in the Forever client; ROADMAP item 1 is that checklist.

## Every change

- Update in the same change: README.md (user-visible behaviour), CHANGELOG.md (Unreleased, Keep a
  Changelog), ROADMAP.md (move items to Done), DEPLOY.md (install, release or saved-variable
  changes), SECURITY.md (what the addon accesses or stores), and this CLAUDE.md if layout or
  rules change.
- Releases: bump `## Version:` in `Ticky/Ticky.toc`, turn Unreleased into a dated version section.
- Before committing, confirm no secret-looking file is staged (`.gitignore` covers the usual ones).
  Never print credentials from git remotes.

## Things that went wrong before

- Assuming TBC from the old WeakAura tag. Forever is vanilla content on the Mainline API.
- Assuming wago.tools lacked Forever data. It has it (product `wowf`).
- Designing around the combat log (measuring ticks). It isn't available on Forever.
- Assuming secret values only show up in raids and dungeons. Aura data is secret in any combat, so
  0.5 showed no bars for DoTs on a mob in the open world; fixed by timing from casts. Read
  `SecretPredicatesDocumentation.lua` for what each `SecretWhen...` flag means before relying on an
  API.
- Copying from or crediting other addons. The owner wants Ticky's code and docs to be its own: no
  code, patterns or frame names taken from other addons, and no references to them. Work from
  Blizzard's UI source and API docs, and from tests in the client.
