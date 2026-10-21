# Testing

What needs checking in the Forever client, newest first. Each item names the commit that changed
it. When something is confirmed, move it to Confirmed with the date; when a change lands, add what
it needs checked here in the same commit.

If something's off: a screenshot plus `/ticky debug`, taken right then (in combat if possible).
First check `/ticky debug`'s first line says the build you just installed (`install_beta.cmd` prints
it); "dev" or an older commit means the game is still running an old copy.

## To test

0. **Build stamp** (this commit). After `install_beta.cmd` and `/reload`, `/ticky debug`'s first line
   and the options window title show the commit the script printed.
1. **A miss cancels the cast** (90b6bc6). A missed first cast leaves no bar; a missed recast leaves
   the old bar running. `/ticky debug` should show the miss as "cancelled …".
2. **A miss by someone else doesn't** (90b6bc6). In a group with melee, your DoT bars shouldn't
   vanish when a party member's swing misses as you cast.
3. **Nameplate bars stay on their own mob** (f0bf01b). Two or three mobs with plate bars on "All",
   including as mobs die and new ones come into view.
4. **No "ended" sounds after a fight** for mobs that died (dd71ea1). Buffs and HoTs (Renew,
   Fortitude) should still count down and alert after combat.
5. **Your own sound file** (ff9d0b1). Add it on the Sounds tab, restart the game, press Test: you
   should hear it and see "Playing."
6. **Warning sound** (ff9d0b1). About 3s before a DoT ends on a living mob you hear it and the bar
   flashes.
7. **Health bar overlay after the rewrite** (f6f6aa4). On your EllesmereUI target frame: starts at
   the edge of the health fill, drawn above the frame.
8. **Nameplate bars after the rewrite** (f6f6aa4). They sit on the plate's health bar and match its
   width.
9. **Recasting a running DoT.** The bar restarts at full length and the tick marks still line up
   with the damage numbers.
10. **Tab-dotting.** Cast and tab away at once; the bar is on the mob you cast at.
11. **A full resist** drops the bar.
12. **A dying mob** clears its bars without an "ended" sound.
13. **Dungeon, enemy nameplates on.** Bars stay with the right mob across several mobs.
14. **Feign Death or Vanish** (hunter or rogue) with the mob targeted: DoT bars survive combat
    dropping.
15. **A dodge or parry on a physical DoT** (warrior Rend, rogue) cancels it.
16. **Mind Flay** tick marks match its damage ticks.
17. **"Say it"** speaks in combat.

## Confirmed

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
