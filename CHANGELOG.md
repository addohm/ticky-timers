# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]
### Added
- CLAUDE.md: guidance for coding assistants (repo, addon code and tools in one file).
- `tools/check_lua.py`: syntax-checks the addon's Lua and the TOC file list.
- DEPLOY.md: installing, releasing, rolling back, saved variables and troubleshooting.
- TESTING.md: the running list of what needs checking in the game client.
- Build stamp: `install_beta.cmd` writes the installed commit into `Build.lua`; `/ticky debug` and
  the options window show it ("dev" for a copy taken straight from the repo).
- `tools/install_beta.cmd`: pulls the repo and mirrors the addon into the beta client (Windows).
- `/ticky debug`: prints what the game lets Ticky read right now (restriction state, each tracked
  spell's aura secrecy, your target's auras, aura instance IDs and durations, your recent casts).
- Your own bar order: Move up / Move down on the Spells tab, and "Your order" under Layout >
  "Order bars by". Your channel takes its slot in that order instead of sitting on top.
- Missing spells: a tracked spell that isn't on your target can be hidden (as before), keep its slot
  empty, or show as a faded bar (opacity, color, grayed icon). Set a default on the Layout tab and
  override it per spell; optionally only in combat and only on targets the spell can go on.
- Sounds for more events: put on, refreshed, every tick (DoTs, HoTs and channels), warning, ended,
  and removed early (dispelled). Each has a default and a per-spell choice.
- "Say it" sounds (the game's text-to-speech) with per-spell words, and your own sound files
  (path or file ID).
- Per-spell warning time.
- On-screen text for warnings, endings and early removals.
- Bars: background color, border (size and color), spark at the fill edge, full side left or right.
- Text: stack counts, name and time colors, time on the left or right, when to show tenths of a
  second, text shadow. Tick height.
- "Hide bars when you have no target".
- Bars on nameplates (new Nameplates tab, off by default): your tracked buffs and debuffs on each mob,
  as small bars above or below its nameplate, always as wide as the plate's health bar (the largest
  status bar on the plate, so nameplate addons work too), with the height a share of that width. All
  plates but your target's, all, or only your target's; distance, spacing, font size,
  icon/name/time/ticks; per-spell opt-out.
  The options window is wider for the eighth tab.
- "Hide the main bars" (General and Nameplates tabs), e.g. to use only nameplate bars. Sounds,
  nameplate bars and the health bar overlay keep working; the options preview still shows them.
- Health bar overlay (new Health bar tab, off by default): on your target's health bar, the part your
  DoTs and channel will still take off, ending at its current health, and the part your HoTs will
  still heal. Per-spell colors or one color each, opacity, texture, dividers; per-spell opt-out.
  Finds a unit frame addon's target frame or Blizzard's, or takes a frame name. Amounts
  come from the tooltip until Ticky has seen the spell's ticks land, then from the real ticks.
### Fixed
- A missed, dodged or parried cast (and a reflected or deflected one) restarted the timer; only
  resists, immunities and evades were caught, and only when the game reported them after the cast.
  All of them now cancel the cast (a missed refresh leaves the old timer running), including when
  the result arrives while the cast is still under way. The game reports everyone's attacks on a
  mob and labels a spell's own miss Physical, so a miss counts only within 0.3s of your cast,
  dodges and parries only count for physical DoTs (spells can't be dodged), and an avoid in a
  different non-Physical school than the spell's is ignored.
  `/ticky debug` lists the last few and what Ticky did with each. A miss in a different school than the spell's, such as your pet's
  melee being dodged as you cast a Shadow DoT, is ignored.
- DoTs on a mob that died out of sight (not your target, no nameplate) kept their timers and played
  their "ended" sound after the fight. When combat ends, your debuffs on mobs Ticky can't see, or
  that are dead, are now dropped silently; mobs it can still see are re-read (so DoTs survive a
  Vanish or Feign Death). Buffs and HoTs are kept.
- Nameplate bars could all pile up on one mob. Blizzard reuses the frames inside nameplates (the
  health bar included) and moves them between plates; Ticky now checks every frame that the bar it
  sits on still belongs to that plate.
- Your own sound files: a pasted full path (C:\...\Interface\...), quotes or forward slashes are
  cleaned up, and Add/Test now say whether the game played the file and, if not, what to check.
- The warning sound never played while the warning time was Off (the default). Picking a warning
  sound now sets it to 3s, and existing settings with a warning sound but no time get 3s.
- Bars now show in combat. Forever hides aura details from addons in combat, so Ticky starts each
  timer from your cast instead (on the mob you targeted when casting, so tab-dotting works). Its
  length is the one last read from that spell's aura (talents included), else the tooltip. Exact
  times and stacks replace the estimate whenever auras are readable, a resist or immunity right
  after the cast drops it, and mobs are tracked by nameplate in dungeons where their IDs are hidden.
- `UNIT_AURA` with a secret unit token no longer risks an error; Ticky re-reads target and self.
### Changed
- The options window is larger and has six tabs: Spells, Bars, Layout, Text & Ticks, Sounds
  (was Alerts), General. The spell settings panel scrolls.
- "Order you added them" is now "Your order" and can be rearranged; existing settings carry over.
- Preview bars use all your tracked spells (up to 8), including your channel, and show missing
  spells between runs.

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
