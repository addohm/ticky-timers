# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]
### Added
- CLAUDE.md: guidance for coding assistants (repo, addon code and tools in one file).
- `tools/check_lua.py`: syntax-checks the addon's Lua and the TOC file list.
- DEPLOY.md: installing, releasing, rolling back, saved variables and troubleshooting.
- TESTING.md: the running list of what needs checking in the game client.
- `tools/package.py`: packages the addon as `release/Ticky-<version>-<commit>.zip` (the `Ticky`
  folder alone, its Build.lua stamped with the commit); release packages are kept in `release/`.
- docs/listing.md: the CurseForge / Wago listing, ready to paste, with a before-publishing list.
  The logo (docs/images: icon PNGs and SVG, a 1200x400 banner, made by `tools/make_logo.py`) is
  at the top of the README. The TOC's author is now addohm.
- docs/health-shading-spark.md: how the health bar shading's spark was made to hold still, and
  the long way there.
- `tools/tests/`: behaviour tests against a stand-in Forever client (`python tools/tests/run.py`).
- "Ticky beep" and "Ticky chime": two sound files that come with Ticky (`Ticky/Sounds`, made by
  `tools/make_sounds.py`). They also show whether the game plays addon sound files at all. The Sounds
  tab's Test message now names the exact path it tried, and the in-game note says to keep your files
  outside Ticky's folder (an update replaces it).
- `/ticky report` and General > Report a problem: the issues link
  (https://github.com/addohm/ticky-timers/issues) in a box, selected for copying. The repo address
  is in the options window's footer and the TOC (`X-Website`). GitHub issue templates ask for the
  build and `/ticky debug` output.
- Build stamp: `install_beta.cmd` writes the installed commit into `Build.lua`; `/ticky debug` and
  the options window show it ("dev" for a copy taken straight from the repo).
- `/ticky log`: the last four seconds around your target's health bar shading (hits and whether
  they were one of your ticks, health changes, your spells going on and ending, how much the
  shading changed; the same number for the same frame).
- `tools/install_beta.cmd`: pulls the repo and mirrors the addon into the beta client (Windows).
- `/ticky debug`: a five-line report that fits in a chat message (build, combat, learned lengths and
  ticks, target timers, casts, misses); `/ticky debug all` prints the long one: what the game lets
  Ticky read right now (restriction state, each tracked
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
- Nameplates: "Their own look" (texture, background color and opacity, border and its color, fill
  direction, spark, tick color, font, outline) instead of copying the main bars, and the health bar
  shading on every nameplate's health bar ("Shade what DoTs/HoTs will still do", also "Also on
  nameplates" on the Health bar tab). The Nameplates tab is laid out in three columns.
- Bars on nameplates (new Nameplates tab, off by default): your tracked buffs and debuffs on each mob,
  as small bars above or below its nameplate, always as wide as the plate's health bar (the largest
  status bar on the plate, so nameplate addons work too), with the height a share of that width. All
  plates but your target's, all, or only your target's; distance, spacing, font size,
  icon/name/time/ticks; per-spell opt-out. "Hide on nameplates in raids" (on by default): inside
  a raid instance, nothing on nameplates (bars or health shading).
  The options window is wider for the eighth tab.
- "Your spells on other units" (General tab, off by default): your HoTs and DoTs on anyone but
  your target get bars too, after your target's, each with who it's on. "Who it's on" (Text &
  Ticks tab): the unit's name after the spell's, "Renew (Bob)", on other units' bars, every bar,
  or never; main bars only.
- "Hide the main bars" (General and Nameplates tabs), e.g. to use only nameplate bars. Sounds,
  nameplate bars and the health bar overlay keep working; the options preview still shows them.
- Health bar overlay (new Health bar tab, off by default; "Also on nameplates" for each mob's
  plate): on your target's health bar, the part your DoTs and channel will still take off, ending
  at its current health, and the part your HoTs will still heal, starting there, with a spark at
  the far end: where the health should end up. Each spell's part is its tooltip's total (read at
  the cast: talents, gear, spell power) over its ticks, times the ticks still to come. Your ticks
  shrink it as they land, so the spark holds still through them; a tick that crits moves it by
  its extra; anything else that changes the health (other damage, healing on the mob) moves it
  with the health bar. One segment with the total (dark, by default) or one per spell in its
  color with dividers; opacity, texture, spark and its color, outline (none, thin, thick) and its
  color, "Smooth changes"; per-spell opt-out. Finds a unit frame addon's target frame (the bar
  named like a health bar) or Blizzard's, or takes any frame by name, at the health bar's scale.
### Changed
- A cast is timed by its tooltip's duration first (the client's current tooltip, with talents and
  gear, read again at every cast), then by the one learned from an aura read: a learned 18s for Shadow Word: Pain, stale after
  Improved Shadow Word: Pain made it 24s, ended its bar 6 seconds early. Tooltips that say "seconds" or
  "minutes" are understood too. `/ticky debug` shows a learned length that disagrees: "24s (read
  18s)".
- The options window is larger and has eight tabs: Spells, Bars, Layout, Text & Ticks, Sounds
  (was Alerts), Health bar, Nameplates, General. The spell settings panel scrolls.
- "Order you added them" is now "Your order" and can be rearranged; existing settings carry over.
- Preview bars use all your tracked spells (up to 8), including your channel, and show missing
  spells between runs.
### Fixed
- Bars of the same spell on several units swapped places on every redraw (they sorted equal, and
  the sort doesn't keep equal ones in order); they're now in order of who they're on.
- With "Your spells on other units" on, each HoT could show twice, with two timings: the game can
  give a cast's target with more than the unit's name (a realm, "Name-Realm", or another word,
  "Nit Pik" for a player named Nit), so Ticky didn't recognise them, kept the HoT under that name,
  and reading their buffs added a second one. Names now match with or without the realm, a
  friendly player by the first word, friendly players' nameplates are looked through too, and
  reading someone's buffs takes over a HoT kept under their name. `/ticky debug` lists your spells
  on others and how each one's unit was found.
- A heal or buff cast on a party or raid member who wasn't your target, focus or mouseover (for
  example clicked on their party frame) was put on you ("Renew (you)"). Ticky now finds them in
  your group by name; someone it can't see at all keeps the spell under their name.
- Another player's spells counted as yours when Ticky could read auras (usually out of combat):
  another priest's Shadow Word: Pain on your target or Fortitude on you made a bar and played your
  sounds, and its length was learned as yours. Ticky took the game's "cast by a player" for "cast
  by you"; it now checks the aura's caster. "Track it from anyone" still shows other players'.
- The health bar shading could cover the missing part of the target's health instead of the part
  your DoTs will take off. Unit frames also hold full-size bars for missing health, absorbs or
  incoming heals, often filling from the other side, and Ticky took the largest bar it found. It
  now prefers a bar named like a health bar and skips ones named for absorbs, losses, predictions
  or power (nameplates too). The Health bar tab and `/ticky debug` show the chosen bar's name, and
  `/ticky debug` the bars picked on up to two nameplates.
- A missed, dodged or parried cast (and a reflected or deflected one) restarted the timer; only
  resists, immunities and evades were caught, and only when the game reported them after the cast.
  All of them now cancel the cast (a missed refresh leaves the old timer running), including when
  the result arrives while the cast is still under way. The game reports everyone's attacks on a
  mob and labels a spell's own miss Physical, so a miss counts only within 0.3s of your cast,
  dodges and parries only count for physical DoTs (spells can't be dodged), and an avoid in a
  different non-Physical school than the spell's is ignored.
  `/ticky debug` lists the last few and what Ticky did with each; attacks on you missing aren't
  counted or listed. A miss in a different school than the spell's, such as your pet's
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
  length is the tooltip's (talents included), else the one last read from that spell's aura. Exact
  times and stacks replace the estimate whenever auras are readable, a resist or immunity right
  after the cast drops it, and mobs are tracked by nameplate in dungeons where their IDs are hidden.
- `UNIT_AURA` with a secret unit token no longer risks an error; Ticky re-reads target and self.

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
