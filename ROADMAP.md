# Roadmap

## Next (priority order)
1. Test cast tracking in the client: bars appear in combat for SW:P / Devouring Plague; tab-dotting
   puts them on the right mob; resists drop them; durations match after a talent (learned from an
   out-of-combat read); timers survive switching targets in the open world; nameplate keys in a
   dungeon; channel reads. If `/ticky debug` shows aura instance IDs and duration objects readable
   in combat, `StatusBar:SetTimerDuration` could draw exact bars even for secret auras.
2. Test the health bar overlay in the client: on Blizzard's and EllesmereUI's target frames, both
   directions, layering above the frame, learned tick sizes (`/ticky debug` could list them).
   Then maybe the same on nameplates and the focus frame, as Does It Die does. Also test bars on
   nameplates: placement with Blizzard's and EllesmereUI's plates, layering, plates after /reload.
3. Detect DoTs dispelled in combat: their ticks stop. `UNIT_COMBAT` shows tick amounts and schools;
   match them to DoTs as Does It Die does, and drop a DoT after missed ticks.
4. Check how Forever handles refreshing a DoT (does the tick timer restart?) and adjust tick phase.
5. Profiles (copy settings between characters).
6. Regenerate Data.lua when Forever's launch build lands (Nov 4, 2026).
7. In the client, confirm: `PlaySoundFile` (not in the generated API docs) plays custom files and
   file IDs; text-to-speech works in combat; apply/refresh/removed sounds fire once each (refresh
   timing, item 4); `C_Spell.IsSpellHarmful`/`IsSpellHelpful` classify spells correctly.
8. More WeakAuras-style options: vertical bars, glow effects, missing bars for your own buffs,
   a movable on-screen message, per-spell "only show in the last N seconds", per-spell text color.

## Done
- Unreleased: timers from your casts (bars in combat), health bar overlay for DoTs and HoTs, bars on
  nameplates.
- Unreleased: your own bar order (fixed slots, channel in its slot), missing-spell bars, sounds for
  every event (apply, refresh, tick, warning, end, removed) per spell, text to speech, custom sound
  files, on-screen messages, and more bar/text styling.
- 0.5.0: spell data generated for every class spell; any buff/debuff can be tracked.
- 0.4.0: renamed to Ticky; full options window (styling, per-spell settings, sounds and warnings).
- 0.3.0: rebuilt for WoW: Forever's API (no combat log, secret-value safe), tick data from game data.
- 0.2.0: any DoT/HoT/channel from a spellbook picker; automatic tick interval and haste handling.
- 0.1.0: spell selection, per-target timer memory, tick markers, channel ticks.
