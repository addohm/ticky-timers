# Roadmap

## Next (priority order)
0. Options window cleanup (the owner, 2026-10-21: "very busy"; about 130 settings on 8 tabs). Not
   decided yet which of these: show a setting only when the switch it depends on is on (low-time
   color, faded-bar look, nameplates' own look, health bar look, next-tick color); remove the
   duplicates ("Hide the main bars" on General and Nameplates; "Also on nameplates" and "Shade what
   DoTs/HoTs will still do"); merge Layout into Bars; an Advanced section for rarely changed ones
   (custom health bar frame, in/out of combat opacity, tenths, sound channel) and shorter notes.
1. Work through [TESTING.md](TESTING.md), the running list of what needs checking in the client.
2. Timers from casts live only in memory: a `/reload` mid-fight loses them (bars and nameplates)
   until you recast. Could save them on logout and restore unexpired ones (`GetTime` carries over
   a reload). Low priority: reloading in a fight is rare.
3. Detect DoTs dispelled in combat: their ticks stop. `UNIT_COMBAT` shows tick amounts and schools;
   Ticky already matches them to timers for tick sizes; drop a DoT after missed ticks.
4. Check how Forever handles refreshing a DoT (does the tick timer restart?) and adjust tick phase.
5. Profiles (copy settings between characters).
6. Regenerate Data.lua when Forever's launch build lands (Nov 4, 2026).
7. In the client, confirm `C_Spell.IsSpellHarmful`/`IsSpellHelpful` classify spells correctly (missing
   bars and HoT/DoT split rely on it).
8. More WeakAuras-style options: vertical bars, glow effects, missing bars for your own buffs,
   a movable on-screen message, per-spell "only show in the last N seconds", per-spell text color.
9. The health bar overlay on the focus frame.

## Done
- 0.6.0: Ticky's own icon and a minimap button; your spells on other units, named; nothing on
  nameplates in raids by default; GPLv3; a release package (`release/`) and the CurseForge / Wago
  listing (LISTING.md).
- 0.6.0: the health shading's spark holds still as DoT ticks land (the investigation:
  [docs/health-shading-spark.md](docs/health-shading-spark.md)).
- 0.6.0: timers from your casts (bars in combat), health bar overlay for DoTs and HoTs (target
  and nameplates), bars on nameplates with their own look.
- 0.6.0: your own bar order (fixed slots, channel in its slot), missing-spell bars, sounds for
  every event (apply, refresh, tick, warning, end, removed) per spell, text to speech, custom sound
  files, on-screen messages, and more bar/text styling.
- 0.5.0: spell data generated for every class spell; any buff/debuff can be tracked.
- 0.4.0: renamed to Ticky; full options window (styling, per-spell settings, sounds and warnings).
- 0.3.0: rebuilt for WoW: Forever's API (no combat log, secret-value safe), tick data from game data.
- 0.2.0: any DoT/HoT/channel from a spellbook picker; automatic tick interval and haste handling.
- 0.1.0: spell selection, per-target timer memory, tick markers, channel ticks.
