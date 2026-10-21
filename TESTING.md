# Testing

What needs checking in the Forever client, newest first. Each item names the commit that changed
it. When something is confirmed, move it to Confirmed with the date; when a change lands, add what
it needs checked here in the same commit.

If something's off: a screenshot plus `/ticky debug`, taken right then (in combat if possible). It's
five lines, short enough to paste whole. Its first line says the build you just installed (`install_beta.cmd` prints
it); "dev" or an older commit means the game is still running an old copy.

## To test

1. **One shading segment** (d5cd7ea). With two DoTs on a mob, the shading is one dark segment
   from the health edge covering both DoTs' remaining damage together. Health bar tab, "Segments"
   switches to one per spell.
2. **Health shading on the right side** (3832bb0). With a DoT on a mob, the shading covers the end of
   the green (the health your DoT will take off), not the missing part. With two DoTs (or two HoTs)
   there are two segments end to end. The Health bar tab and `/ticky debug` ("Health bar shading
   on") say which bar it's on; if the shading is still wrong, send that line. On nameplates (with
   "Also on nameplates"): same check; `/ticky debug`'s "Nameplate health bars" line names the bar
   picked on up to two plates.
3. **Built-in sound files** (6b7bbe5). After installing, restart the game (new files only load at
   startup). Sounds tab: set a sound to "Ticky beep" or "Ticky chime" and press Test. If you hear
   it, addon sound files work and the problem is your own file's location or path; if not, the game
   isn't playing addon sound files at all. Then for your own file: where it is on disk (full path),
   what the "Added files" list shows, and the message next to Test.
4. **Health shading on nameplates** (8164a0c). Health bar tab: damage (and healing) on, "Also on
   nameplates" on. Each mob's nameplate health bar shows its own DoTs' remaining damage from the
   health edge; the timer bars still sit on the plate's health bar, not on the shading.
5. **Nameplate bars' own look** (8164a0c). Nameplates tab, "Their own look": texture, border,
   background, font etc. change only the nameplate bars, not the main bars; off again, they match
   the main bars.
6. **A missed recast** (90b6bc6) leaves the old bar running, and **with several mobs** a miss on one
   doesn't touch the DoTs on the others. `/ticky debug` should show it as "cancelled …".
7. **A miss by someone else doesn't** (90b6bc6). In a group with melee, your DoT bars shouldn't
   vanish when a party member's swing misses as you cast.
8. **Nameplate bars stay on their own mob** (f0bf01b). Two or three mobs with plate bars on "All",
   including as mobs die and new ones come into view.
9. **No "ended" sounds after a fight** for mobs that died (dd71ea1). Buffs and HoTs (Renew,
   Fortitude) should still count down and alert after combat.
10. **Warning sound** (ff9d0b1). About 3s before a DoT ends on a living mob you hear it and the bar
    flashes.
11. **Health bar overlay after the rewrite** (f6f6aa4). On your EllesmereUI target frame: starts at
    the edge of the health fill, drawn above the frame.
12. **Nameplate bars after the rewrite** (f6f6aa4). They sit on the plate's health bar and match its
    width.
13. **Recasting a running DoT.** The bar restarts at full length and the tick marks still line up
    with the damage numbers.
14. **Tab-dotting.** Cast and tab away at once; the bar is on the mob you cast at.
15. **A full resist** drops the bar.
16. **A dying mob** clears its bars without an "ended" sound.
17. **Dungeon, enemy nameplates on.** Bars stay with the right mob across several mobs.
18. **Feign Death or Vanish** (hunter or rogue) with the mob targeted: DoT bars survive combat
    dropping.
19. **A dodge or parry on a physical DoT** (warrior Rend, rogue) cancels it.
20. **Mind Flay** tick marks match its damage ticks.
21. **"Say it"** speaks in combat.

## Confirmed

- 2026-10-21: health shading spark: accepted as it is at 3e3c896. It still hops by about a pixel
  now and then as DoTs tick (less often with "Smooth changes" off); see Known gaps.
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

- The health shading's spark still hops by about a pixel now and then as DoTs tick (unit frames
  and nameplates; less often with "Smooth changes" off). Accepted for now (3e3c896). Everything
  known and tried, and how to pick it up again (start with `/ticky log` right after a hop):
  [docs/health-shading-spark.md](docs/health-shading-spark.md).
- A `/reload` mid-fight loses timers from casts (bars and nameplates) until you recast.
- Feign Death or Vanish with nameplates off and the mob not targeted drops its DoT bars.
- A physical DoT can be cancelled by your own white hit being dodged in the same instant.
