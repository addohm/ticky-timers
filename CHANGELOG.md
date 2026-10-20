# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.5.0] - 2026-10-20
### Added
- Spell data for all 1,928 class spells that leave a timed buff or debuff (598 tick, 140 channels),
  generated from Forever build 1.60.1.70245 by `tools/gen_data.py`.
- Track any buff or debuff, not just ones that tick; non-ticking ones get a plain timer.
- Your own tracked auras show below your target's, tagged "(you)".
- Per-spell "track it from anyone" option (another player's buff on you, a raid debuff on a boss).
- Long timers read as 4:05, 25m or 2h.
### Changed
- The spell list shows spells that leave a buff or debuff, not only ones with ticks.

## [0.4.0] - 2026-10-20
### Added
- Options window with Spells, Bars, Text & Ticks, Alerts and General tabs, and preview bars.
- Per-spell bar color, bar text, and end/warning sounds.
- Styling: size, spacing, scale, stack direction, sort order, fill direction, texture, background,
  icon, fonts, outline, tick color/width, past-tick style, next-tick highlight, low-time color.
- Alerts: sound when a timer ends, warning sound and flash before it ends, sound channel,
  alerts for other targets (remembered, plus nameplates), combat-only alerts; early removal is silent.
- Hide out of combat, combat/out-of-combat opacity, reset position, reset all settings.
- Minimap addon-menu entry and an Options > AddOns entry.
### Changed
- Renamed to **Ticky** (`/ticky`; saved variables `TickyDB` and per-character `TickyCharDB`).
- Tracked spells are now saved per character.

## [0.3.0] - 2026-10-20
### Changed
- Rebuilt for World of Warcraft: Forever: interface 16001, Mainline `C_Spell` / `C_SpellBook` /
  `C_UnitAuras` APIs only.
- Tick periods now come from the game's spell data (`Data.lua`) instead of combat-log measurement,
  which Forever doesn't allow.
- Channels spread the data's tick count across the client's channel time.
- Per-target memory now reads the target's auras on every target change instead of tracking GUIDs.
### Added
- Secret-value guards: secret auras, casts and haste are skipped instead of erroring.
### Removed
- Combat-log tracking, measured timings, off-target tracking, and the "Re-measure ticks" button.

## [0.2.0] - 2026-10-20
### Added
- Pick spells from a list of the periodic (DoT/HoT/channel) spells in your current spec's spellbook.
- HoT tracking (buffs you cast), and your own timers when you have no target.
- Haste awareness: detects whether a spell's ticks scale with haste and predicts from current haste.
- Tick timings are saved per spec; tooltip "every N sec" is used before the first measurement.
### Changed
- Tick interval, channel tick count and haste scaling are now fully automatic; the manual
  tick interval, "hasted" and "channeled" settings are gone. Channels are detected when cast.
- No spells are tracked by default.
- Measured timings from 0.1.0 are discarded (storage format changed).

## [0.1.0] - 2026-10-20
### Added
- TickBars addon, ported from the "Ticky Target Timers" and "Cast Bar" WeakAuras.
- Choose tracked spells by name, ID, or spellbook shift-click.
- Timer bars with tick markers, remembered per target GUID.
- Channel bars with tick markers (Mind Flay by default).
- Measures real tick intervals and channel tick counts from the combat log.
- Movable/lockable bars, size setting, slash commands.
