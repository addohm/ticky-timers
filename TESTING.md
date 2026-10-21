# Testing

What needs checking in the Forever client, newest first. Each item names the commit that changed
it. When something is confirmed, move it to Confirmed with the date; when a change lands, add what
it needs checked here in the same commit.

If something's off: a screenshot plus `/ticky debug`, taken right then (in combat if possible). It's
five lines, short enough to paste whole. Its first line says the build you just installed (`install_beta.cmd` prints
it); "dev" or an older commit means the game is still running an old copy.

## To test

1. **`/ticky report`** (this push). A box opens with the issues link selected; Ctrl+C copies it, typing
   can't change it, Esc or the X closes it. Also General > Report a problem, and the repo address
   in the options window's bottom right.
2. **Health shading on nameplates** (8164a0c). Health bar tab: damage (and healing) on, "Also on
   nameplates" on. Each mob's nameplate health bar shows its own DoTs' remaining damage from the
   health edge; the timer bars still sit on the plate's health bar, not on the shading.
3. **Nameplate bars' own look** (8164a0c). Nameplates tab, "Their own look": texture, border,
   background, font etc. change only the nameplate bars, not the main bars; off again, they match
   the main bars.
4. **A missed recast** (90b6bc6) leaves the old bar running, and **with several mobs** a miss on one
   doesn't touch the DoTs on the others. `/ticky debug` should show it as "cancelled …".
5. **A miss by someone else doesn't** (90b6bc6). In a group with melee, your DoT bars shouldn't
   vanish when a party member's swing misses as you cast.
6. **Nameplate bars stay on their own mob** (f0bf01b). Two or three mobs with plate bars on "All",
   including as mobs die and new ones come into view.
7. **No "ended" sounds after a fight** for mobs that died (dd71ea1). Buffs and HoTs (Renew,
   Fortitude) should still count down and alert after combat.
8. **Your own sound file** (ff9d0b1). Add it on the Sounds tab, restart the game, press Test: you
   should hear it and see "Playing."
9. **Warning sound** (ff9d0b1). About 3s before a DoT ends on a living mob you hear it and the bar
   flashes.
10. **Health bar overlay after the rewrite** (f6f6aa4). On your EllesmereUI target frame: starts at
   the edge of the health fill, drawn above the frame.
11. **Nameplate bars after the rewrite** (f6f6aa4). They sit on the plate's health bar and match its
   width.
12. **Recasting a running DoT.** The bar restarts at full length and the tick marks still line up
   with the damage numbers.
13. **Tab-dotting.** Cast and tab away at once; the bar is on the mob you cast at.
14. **A full resist** drops the bar.
15. **A dying mob** clears its bars without an "ended" sound.
16. **Dungeon, enemy nameplates on.** Bars stay with the right mob across several mobs.
17. **Feign Death or Vanish** (hunter or rogue) with the mob targeted: DoT bars survive combat
    dropping.
18. **A dodge or parry on a physical DoT** (warrior Rend, rogue) cancels it.
19. **Mind Flay** tick marks match its damage ticks.
20. **"Say it"** speaks in combat.

## Confirmed

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

- A `/reload` mid-fight loses timers from casts (bars and nameplates) until you recast.
- Feign Death or Vanish with nameplates off and the mob not targeted drops its DoT bars.
- A physical DoT can be cancelled by your own white hit being dodged in the same instant.
