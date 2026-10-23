# Testing

What needs checking in the Forever client, newest first. Each item names the commit that changed
it. When something is confirmed, move it to Confirmed with the date; when a change lands, add what
it needs checked here in the same commit.

If something's off: a screenshot plus `/ticky debug`, taken right then (in combat if possible). It's
five lines, short enough to paste whole. Its first line says the build you just installed (`install_beta.cmd` prints
it); "dev" or an older commit means the game is still running an old copy.

## To test

1. **Ticky's own icon** (2fe7252). After installing, restart the game (new files only load at startup).
   The ring-timer icon shows in the AddOns list, in the minimap addon menu, and next to "Ticky" at
   the top of the options window. A green square or a question mark means the game didn't load
   the file.
2. **Your spells on other units** (b4f6e93; doubled HoT bars: 8a0d24a, "Nit Pik" / "Nit" in 63ea0a0; bars keep their places: c599031). One bar per HoT, on you or
   anyone else, with one timing; if one still shows twice, send `/ticky debug` (its "Elsewhere" line). General tab, "Your spells on other units" on. Renew on a
   party member by clicking their party frame (with an enemy targeted): a bar "Renew (name)" after
   your target's bars, not "Renew (you)", running out when it falls off. DoTs on a mob you tabbed
   away from: named bars there too. Text & Ticks, "Who it's on": every bar / never. Nameplate bars
   never show names.
3. **Nameplates in raids** (35fdbca). With nameplate bars (and nameplate shading) on: in a raid, nothing
   from Ticky on nameplates; your main bars and your target's shading still show. In a dungeon or
   the open world, nameplates as before. Nameplates tab, "Hide on nameplates in raids" off: they
   come back in the raid.
4. **Every health change moves the spark** (93034cb; nameplates confirmed, see below). On the unit
   frame too: on a mob someone else is fighting, with your DoTs
   on it: the spark moves with the health bar for their damage too, so the health doesn't run
   past it. Your own ticks don't move it (crits by their extra), your wand and Mind Blast do.
   When a DoT goes on, the spark moves left by its total. If the health still overruns it:
   `/ticky log` right after.
5. **Other players' spells aren't yours** (f5653c6). With another priest nearby casting the same spells
   (their Shadow Word: Pain on your target, their Fortitude or Renew on you): no bar and no sound
   from theirs, out of combat or in. Yours still show and sound as before. With "Track it from
   anyone" on for a spell, theirs shows (out of combat).
6. **One shading segment** (d5cd7ea). With two DoTs on a mob, the shading is one dark segment
   from the health edge covering both DoTs' remaining damage together. Health bar tab, "Segments"
   switches to one per spell.
7. **Health shading on the right side** (3832bb0). With a DoT on a mob, the shading covers the end of
   the green (the health your DoT will take off), not the missing part. With two DoTs (or two HoTs)
   there are two segments end to end. The Health bar tab and `/ticky debug` ("Health bar shading
   on") say which bar it's on; if the shading is still wrong, send that line. On nameplates (with
   "Also on nameplates"): same check; `/ticky debug`'s "Nameplate health bars" line names the bar
   picked on up to two plates.
8. **Built-in sound files** (6b7bbe5). After installing, restart the game (new files only load at
   startup). Sounds tab: set a sound to "Ticky beep" or "Ticky chime" and press Test. If you hear
   it, addon sound files work and the problem is your own file's location or path; if not, the game
   isn't playing addon sound files at all. Then for your own file: where it is on disk (full path),
   what the "Added files" list shows, and the message next to Test.
9. **Health shading on nameplates** (8164a0c). Health bar tab: damage (and healing) on, "Also on
   nameplates" on. Each mob's nameplate health bar shows its own DoTs' remaining damage from the
   health edge; the timer bars still sit on the plate's health bar, not on the shading.
10. **Nameplate bars' own look** (8164a0c). Nameplates tab, "Their own look": texture, border,
    background, font etc. change only the nameplate bars, not the main bars; off again, they match
    the main bars.
11. **A missed recast** (90b6bc6) leaves the old bar running, and **with several mobs** a miss on one
    doesn't touch the DoTs on the others. `/ticky debug` should show it as "cancelled …".
12. **A miss by someone else doesn't** (90b6bc6). In a group with melee, your DoT bars shouldn't
    vanish when a party member's swing misses as you cast.
13. **Nameplate bars stay on their own mob** (f0bf01b). Two or three mobs with plate bars on "All",
    including as mobs die and new ones come into view.
14. **No "ended" sounds after a fight** for mobs that died (dd71ea1). Buffs and HoTs (Renew,
    Fortitude) should still count down and alert after combat.
15. **Warning sound** (ff9d0b1). About 3s before a DoT ends on a living mob you hear it and the bar
    flashes.
16. **Health bar overlay after the rewrite** (f6f6aa4). On your EllesmereUI target frame: starts at
    the edge of the health fill, drawn above the frame.
17. **Nameplate bars after the rewrite** (f6f6aa4). They sit on the plate's health bar and match its
    width.
18. **Recasting a running DoT.** The bar restarts at full length and the tick marks still line up
    with the damage numbers.
19. **Tab-dotting.** Cast and tab away at once; the bar is on the mob you cast at.
20. **A full resist** drops the bar.
21. **A dying mob** clears its bars without an "ended" sound.
22. **Dungeon, enemy nameplates on.** Bars stay with the right mob across several mobs.
23. **Feign Death or Vanish** (hunter or rogue) with the mob targeted: DoT bars survive combat
    dropping.
24. **A dodge or parry on a physical DoT** (warrior Rend, rogue) cancels it.
25. **Mind Flay** tick marks match its damage ticks.
26. **"Say it"** speaks in combat.

## Confirmed

- 2026-10-21: health bar shading spark on nameplates (93034cb, hanging from the health end): "looks
  good".
- 2026-10-21: health bar shading on the owner's model (040e432): the spark goes at the health when
  a DoT goes on less its total, moves by each DoT added and by a crit's extra, and otherwise holds
  still. "This worked very well."
- 2026-10-21: health shading spark after the tick-size fix (f5dc0fd, installed as e3394b8): "the
  most stable it's been", no more hopping around. It still dropped left now and then (not from a
  wand or melee: the owner wasn't using either); see To test.
- 2026-10-21: health shading spark: accepted as it is at 3e3c896. It still hops by about a pixel
  now and then as DoTs tick (less often with "Smooth changes" off). The cause was found after
  that and fixed in f5dc0fd (entry above).
- 2026-10-21: `/ticky sparktest` (cc0d069): tests 1 (smooth, same frame) and 4 (instant, same
  frame) hold the spark still; 1 looks smoother. 442456f: test 7 (both set again every 0.1s) holds
  still too, and looks very smooth.
- 2026-10-21: `/ticky sparktest` (b14b1f1, 600-wide bar): all six (plain, hidden health and max,
  everything hidden; smooth and instant) look acceptable.
- 2026-10-21: `/ticky sparktest` (f43c9c9, at the target bar's size, 123 wide): the spark holds
  still in all six.
- 2026-10-21: `/ticky sparktest copy` (d6a2af6): the copy hops like the real one; Blizzard's
  target frame hops too (EllesmereUI off); "Smooth changes" off: hops less often.
- 2026-10-21: `/ticky report` box and link (7d78904).
- 2026-10-21: a missed first cast leaves no bar (two SW:P misses on one mob, both caught just after
  the cast was reported, within the same tenth of a second).
- 2026-10-21: build stamp: `/ticky debug` shows the installed commit (0fc179a).
- 2026-10-21: bars in combat, timed from your casts.
- 2026-10-21: tick sizes learned from real ticks (`/ticky debug` "(seen)").
- 2026-10-21: talented SW:P learned as 24s.
- 2026-10-21: HoT overlay on a friend (green from the health edge).
- 2026-10-21: put on, refreshed and removed sounds play once each.
- 2026-10-21: self buffs stay through combat (Inner Fire no longer vanishes on the first hit).
- 2026-10-21: health bar overlay and nameplate bars working (before the f6f6aa4 rewrite).

## Known gaps

- The game doesn't say whose damage hit a mob: another player's same DoT ticking at the same
  moment on the same mob can be taken for yours (and yours for other damage). The spark ends up
  in the same place; the tick sizes in `/ticky debug` can be off.
- A `/reload` mid-fight loses timers from casts (bars and nameplates) until you recast.
- Feign Death or Vanish with nameplates off and the mob not targeted drops its DoT bars.
- A physical DoT can be cancelled by your own white hit being dodged in the same instant.
