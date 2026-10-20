# Roadmap

## Next (priority order)
1. Test in the Forever client: confirm interface 16001, aura and channel reads, and whether player
   DoTs become secret anywhere (raids).
2. Check how Forever handles refreshing a DoT (does the tick timer restart?) and adjust tick phase.
3. Nameplate bars for DoTs on non-target enemies.
4. Profiles (copy settings between characters).
5. Regenerate Data.lua when Forever's launch build lands (Nov 4, 2026).
6. In the client, confirm: `PlaySoundFile` (not in the generated API docs) plays custom files and
   file IDs; text-to-speech works in combat; apply/refresh/removed sounds fire once each (refresh
   timing, ROADMAP item 2); `C_Spell.IsSpellHarmful`/`IsSpellHelpful` classify spells correctly.
7. More WeakAuras-style options: vertical bars, glow effects, missing bars for your own buffs,
   a movable on-screen message, per-spell "only show in the last N seconds", per-spell text color.

## Done
- Unreleased: your own bar order (fixed slots, channel in its slot), missing-spell bars, sounds for
  every event (apply, refresh, tick, warning, end, removed) per spell, text to speech, custom sound
  files, on-screen messages, and more bar/text styling.
- 0.5.0: spell data generated for every class spell; any buff/debuff can be tracked.
- 0.4.0: renamed to Ticky; full options window (styling, per-spell settings, sounds and warnings).
- 0.3.0: rebuilt for WoW: Forever's API (no combat log, secret-value safe), tick data from game data.
- 0.2.0: any DoT/HoT/channel from a spellbook picker; automatic tick interval and haste handling.
- 0.1.0: spell selection, per-target timer memory, tick markers, channel ticks.
