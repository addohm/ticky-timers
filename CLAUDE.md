# Guidance for coding assistants

## Layout
- `Ticky/Ticky.toc`: manifest (interface 16001, `TickyDB` account-wide, `TickyCharDB` per character,
  addon-compartment entry). Load order: Data, Core, Bars, Widgets, Options.
- `Ticky/Data.lua`: generated; never hand-edit. `ns.Data[spellID]` exists for every class spell that
  leaves a timed buff/debuff; `p` = tick period ms (ticking spells only), `h` = haste-affected,
  `d` = channel base duration ms.
- `tools/gen_data.py`: builds Data.lua from wago.tools CSV exports (see README "Regenerating").
- `Ticky/Core.lua`: settings and defaults, aura/channel reading, expiry/warning alerts, tick math
  (`ComputeTicks`), events, slash commands.
- `Ticky/Bars.lua`: bar frames, styling (`ApplyStyle`), drawing, preview timers.
- `Ticky/Widgets.lua`: option controls (check, slider, cycle selector, color swatch) with get/set.
- `Ticky/Options.lua`: the tabbed options window and the Settings-panel entry.

## Rules
- Target is **World of Warcraft: Forever**: original-Azeroth content on the modern **Mainline**
  addon API (12.x family), not Classic/TBC. Use `C_Spell`, `C_SpellBook`, `C_UnitAuras`; the old
  globals (`GetSpellInfo`, `UnitAura`, ...) are gone.
- Check APIs against the `forever` branch of https://github.com/Gethe/wow-ui-source
  (`Interface/AddOns/Blizzard_APIDocumentationGenerated`).
- No combat log (`COMBAT_LOG_EVENT_UNFILTERED` is blocked). Guard every combat value with
  `issecretvalue` before comparing, branching or doing math; skip secret data.
- Never hard-code tick intervals in Core.lua: durations come from auras, periods from Data.lua.
- Spells are tracked by lower-case name so every rank matches; Data.lua is keyed by spell ID.
- Lua 5.1, no libraries. Syntax-check with the `lupa` Python package
  (`pip install --target <dir> lupa`, then `load()` each file) or `/reload` in game.

## Docs to update
Update README.md (usage and options), CHANGELOG.md (Unreleased), and ROADMAP.md in the same change.
