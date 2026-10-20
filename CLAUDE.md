# CLAUDE.md

Guidance for coding assistants working in this repository. More specific guidance lives next to
the code: [Ticky/CLAUDE.md](Ticky/CLAUDE.md) (the addon) and [tools/CLAUDE.md](tools/CLAUDE.md)
(data generation and checks).

## What this is

**Ticky** is a World of Warcraft addon: timer bars for buffs and debuffs, with a marker for every
tick of DoTs, HoTs and channels. Repo: https://github.com/addohm/ticky-timers.

It targets **World of Warcraft: Forever** (Blizzard's "Classic+", launch Nov 4, 2026):
original-Azeroth content (level 60, vanilla-era spells, ranks and talents) running on the
**modern Mainline addon API** (12.x family), TOC interface **16001**. It is *not* Classic Era and
*not* TBC. The owner's old TBC WeakAuras were inspiration only.

Status: 0.5.0, never run in a real client yet. All verification so far is syntax checks and a
mocked API (see Testing).

## Layout

```
Ticky/            the addon (this folder is what players copy into Interface\AddOns)
  Ticky.toc       manifest; load order Data, Core, Bars, Widgets, Options
  Data.lua        GENERATED spell data; never hand-edit
  Core.lua        settings, aura/channel reading, alerts, tick math, events, slash commands
  Bars.lua        bar frames, styling, drawing, preview
  Widgets.lua     option controls (check, slider, cycle, color swatch)
  Options.lua     tabbed options window, Settings-panel entry
tools/
  gen_data.py     builds Ticky/Data.lua from wago.tools CSV exports
  check_lua.py    syntax-checks Ticky/*.lua and the TOC file list
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
restarting the client.

## Hard rules

1. **Mainline API only.** Use `C_Spell`, `C_SpellBook`, `C_UnitAuras`, `C_AddOns`, `C_Timer`.
   Old globals (`GetSpellInfo`, `UnitAura`, `GetSpellBookItemInfo`, `GetNumSpellTabs`,
   `CombatLogGetCurrentEventInfo`) don't exist on Forever. Don't add compat shims for other clients.
2. **No combat log.** Registering `COMBAT_LOG_EVENT_UNFILTERED` errors. Everything comes from
   `UNIT_AURA`, aura queries, channel events and spell data.
3. **Secret values.** Combat values (aura fields, GUIDs, haste, channel info, `UnitExists`) can be
   secret. Check `ns.Secret(v)` before comparing, branching, indexing or doing math on them. Skip
   secret data; never let it error the UI (aura scans run in `pcall`).
4. **No hand-entered timing.** Durations come from the aura; tick periods come from
   `Ticky/Data.lua`. Don't hard-code intervals and don't add "tick every N" settings: the owner
   wants nothing configured by hand.
5. **Display and sound only.** Never automate combat decisions, call protected functions, or touch
   Blizzard unit frames.
6. **Lua 5.1, no libraries.** No `goto`, `//`, bitwise operators, `require`. No Ace/LibStub.
   Every file starts `local ADDON, ns = ...`; shared state goes on `ns`.
7. **Data.lua is generated.** Change `tools/gen_data.py` and regenerate; never edit values by hand.

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
[tools/CLAUDE.md](tools/CLAUDE.md).

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
  changes), SECURITY.md (what the addon accesses or stores), and these CLAUDE.md files if layout
  or rules change.
- Releases: bump `## Version:` in `Ticky/Ticky.toc`, turn Unreleased into a dated version section.
- Before committing, confirm no secret-looking file is staged (`.gitignore` covers the usual ones).
  Never print credentials from git remotes.

## Things that went wrong before

- Assuming TBC from the old WeakAura tag. Forever is vanilla content on the Mainline API.
- Assuming wago.tools lacked Forever data. It has it (product `wowf`).
- Designing around the combat log (measuring ticks). It isn't available on Forever.
