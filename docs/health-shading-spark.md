# The health shading's spark: why it hops, what was tried

Notes from the 2026-10-21 investigation, for picking it up again. Written for whoever comes back to
this (owner or coding assistant).

## Status

- **Accepted by the owner at 3e3c896 (code of d6a2af6), 2026-10-21.** The spark (the far end of
  the DoT shading on a health bar) still hops by about a pixel now and then as DoTs tick, on the
  unit frame and on nameplates. With "Smooth changes" off (Health bar tab) it hops noticeably less
  often. Good enough to move on; not solved.
- After that, 55e6ce4 added `/ticky log` (logging only, no change to what's drawn). Its output
  hasn't been seen from the game yet: that's the first thing to collect when coming back.
- **Then the cause was found and fixed (see "Found: the tick size estimate" below).** On b388b30
  `/ticky debug` showed "25 hit, shading -31": the shading shrank 6 more than the tick did, and
  the first `/ticky log` showed a critical tick taken off as a normal one.
- **Owner on e3394b8 (code of f5dc0fd), 2026-10-21: "the most stable it's been. It doesn't really
  hop around anymore", it only "drops to the left a bit every once in a while".** The log at one
  of those drops: `hit 25 (not a tick), health, drew health (changed)`, with Shoot (the wand)
  among the casts. Damage that isn't your DoT's tick lowers the health the DoTs will leave, so the
  spark moving left by it is correct. The last SW:P tick showed "26 hit, shading -24": the summed
  deviation showing at the DoT's end (2 health, about 0.16 pixel), the expected trade-off.
  Treated as solved; the rest of this file is the record.

## What the shading is

On your target's health bar (and each nameplate's), the part of the health your DoTs will still
take off, ending at the current health. Its far end, marked by the spark, is where the health
should end up once the DoTs are done. As a tick lands, the health drops by the tick and the
shading shrinks by the same amount, so **the spark should not move**. It moves only when something
else changes the health (your wand, a party member) or a DoT is added, refreshed or ends.

How it's built (Ticky/Overlay.lua, see also CLAUDE.md's Overlay.lua row):

- A clipping holder over the unit frame's health bar (only its rect, fill direction and scale are
  used; `Attach`, `ScaleOf`).
- An invisible "mirror" StatusBar of our own, range 0..`UnitHealthMax(unit)`, fed
  `UnitHealth(unit)`. Both are **secret** for mobs on Forever: Lua can't read, compare or do math on
  them, but StatusBar `SetMinMaxValues`/`SetValue` accept them.
- A chain of StatusBars (one per DoT, or one with the total: "single", the default), each as wide
  as the health bar and ranged 0..max health (secret), filled with a plain amount (what the DoT
  will still do; see `RemainingAmount` below). The first is anchored to the mirror's fill end, each next to the end of the
  previous fill. So the far end sits at health - remaining damage without Lua ever knowing either.
- Spark and outline: textures on a top layer anchored to the last segment's fill end (`Trim`).
- Easing: `SetValue(v, Enum.StatusBarInterpolation.ExponentialEaseOut)` while the mob stays the same
  ("Smooth changes", on by default), else `Immediate`.

How it's fed (Ticky/Core.lua), as of 3e3c896:

- `UNIT_COMBAT` WOUND/HEAL -> `OnTickAmount`: matched to a DoT on that mob by school and tick time
  (+-0.35s, `TICK_WINDOW`), each tick once (`t.matchedTick`). It becomes `t.pendingTick`; it counts
  (`Commit` -> `t.lastTick`) on that mob's `UNIT_HEALTH` (either order within the same frame:
  `healthAt[mob] == now`), or 0.2s later (`PENDING_MAX`) if no health message comes. A tick never
  seen counts 0.5s after its expected time (`UNSEEN_TICK_GRACE`). Each matched tick moves the
  timer's start/expiry half way to where it really landed (phase learning). A hit far off the
  learned size (under 0.4x or over 3x) isn't matched as a tick (another spell of the same school).
  Non-crit hits update the learned tick size: `floor(old * 0.6 + hit * 0.4 + 0.5)`.
- `ns.HoldHealth(unit, now)`: true while one of the mob's ticks is pending, or due (0.5s before,
  `HOLD_BEFORE`, until 0.5s after) and not yet counted. While it's true **neither end is set**: the
  mirror keeps its value and the segments keep theirs (5b9c384; before that only the mirror waited).
- `ns.RemainingAmount(t)`: (total ticks - max(lastTick, ticks gone by unseen)) x `t.tickSize`, plus
  for the seen ticks counted (`t.paidCount`) their real amounts (`t.paid`) instead of the estimate.
  `t.tickSize` is fixed per timer from `ExpectedTick` and replaced only if that's over 15% off. So a
  seen tick takes off exactly what it did. (Before the fix: ticks left x `ExpectedTick`, see below.)
- Drawing (`ns.UpdateOverlay` -> `Draw`): from Core's OnUpdate, every 0.1s and in the frame after a
  counted tick or any `UNIT_HEALTH` (`drawDue`, 442456f); never from inside an event handler.
  The mirror is set only when the mob's health changed since the last set (`ns.HealthAt(mob)`, the
  time of its last `UNIT_HEALTH`), for a new mob or a max-health change, or once a second at rest
  ("1s check"). A segment's value, texture, color, and the holder's strata and level, are set only
  when they change. The range only for a new mob or after `UNIT_MAXHEALTH`.

## The symptom, as seen

- Owner's 60 fps captures, frames extracted by the owner (they don't send videos any more). The
  hop is about 1 pixel on EllesmereUI's 123-pixel target bar (`EllesmereUIUnitFrames_Target._barClip`,
  scale 1). A tick is about 2 pixels there (25 of roughly 1500 health), so a 1-pixel hop is half a
  tick.
- Direction varied with the build (see the history). On 4d11641: "hops to the right and back",
  smaller and steadier than before. Later: "hopping around".
- Seen on EllesmereUI's target frame, Blizzard's target frame (EllesmereUI off) and Blizzard's
  nameplates. A live copy of the shading on a plain bar of Ticky's own (`/ticky sparktest copy`)
  hops too.
- "Smooth changes" off: hops less often, but still some.

## What's established (with the evidence)

1. **A DoT tick's health message comes in the same frame as its hit, and no later one follows.**
   ec824ce waited for a `UNIT_HEALTH` in a later frame; `/ticky debug` showed "health never" and
   the tick counted on the 0.2s timeout instead (06ad68a, 2026-10-21). On 7e5471e: hit, health,
   counted and drawn all +0.000.
2. **The shading shrinks by the right amount.** `/ticky debug`'s last-tick line: "20 hit, shading
   -21" (b14b1f1), "26 hit, shading -25" (f43c9c9). One health point off is under a tenth of a pixel.
3. **Setting a bar's range, texture or color while it eases seems to end the ease at once.** Doing
   that on every redraw made the segments snap while the mirror eased. Removing it (e50ddf3 for the
   range, 4d11641 for texture and color) made the hop smaller and steadier. Not measured directly.
4. **The structure holds still when fed cleanly** (`/ticky sparktest`, in game):
   - 600-wide bar, plain values (cc0d069/442456f): eased or instant, set once or again every 0.1s,
     still if both ends are set in the same frame; with the shading set 1 or 2 frames after the
     health it bounced.
   - 600-wide bar, hidden values (b14b1f1): hidden health and max, or everything hidden, eased or
     instant: all acceptable.
   - Bar the size of the target's (123x12), a realistic tick (25 of 1500), three runs each
     (f43c9c9): eased, instant, eased and instant with pixel snapping off, eased and instant with a
     hidden health: the spark holds still in all six.
5. **The unit frame isn't the cause.** The live copy (d6a2af6) hops like the real one, and Blizzard's
   frames hop with EllesmereUI off.
6. So: **something in a live fight changes one end without the other** (or not in step), and it
   happens more with easing on. The test bar only ever sees clean ticks.

## History of attempts

| Commit | Change | Result in game |
|---|---|---|
| acd88f8 | Count a tick when its hit is seen (not by the clock); ease the segments; spark and outline | Far end still jumped and settled each tick |
| 5a37229 | Hang the shading off a mirror bar of our own instead of the unit frame's fill | Nameplates smooth, unit frame still jumped |
| 93042ba | Any frame can be the area; re-anchor count in debug | (diagnostic) re-anchored 1x: the frame doesn't change size |
| 17c02eb | Holder takes the health bar's scale (shading was sized in the unit frame's units at UIParent's scale) | Real bug, fixed. Then both unit frame and nameplates jumped on every tick |
| bc26e28 (5cdadb4) | Hold a seen tick until the mob's `UNIT_HEALTH` | Still hopped. Capture: toward the health ~3 frames, then back |
| 5925ad4 | `HoldHealth`: keep the mirror while a tick is pending or just due; test suite in the repo | Still hopped |
| 57fb31f (150577c) | Set the segments a frame after the mirror (anchor-lag theory) | Wrong: capture showed the spark moving with the health first, the shading a frame later. Reverted |
| e50ddf3 (d225c61) | Same-moment updates; range only on change | Still hopped |
| 01e76dc (8946a01) | Hold from 0.5s before a tick; skip ticks gone by unseen; phase learning; last-tick trace in debug | Still hopped. Frames 915-924: target spark +1px for frames 916-918, back at 919; plate spark +1px at 918; plate's own health end moved at 919; trace all +0.000 |
| ec824ce | Count only on a health message in a later frame (stale-health theory) | Wrong: no later message comes ("health never"); counted on the 0.2s timeout |
| 4d11641 (7e5471e) | Segment texture/color, holder strata/level only on change; count on the same-frame message again | "Hops to the right and back", smaller, steadier |
| ae8d7ef, cc0d069 | `/ticky sparktest` (plain values, 600 wide; reset hidden in cc0d069) | 1 (smooth) and 4 (instant) still; delayed shading bounced |
| 442456f | Draw from the frame update; mirror only on a health change (or 1s), segments only on change; test 7 (set every 0.1s) | Still hopping. Test 7 still too |
| 5b9c384 (b14b1f1) | Shading waits with the health end (two DoTs ticking close together); shrink in debug; sparktest with hidden values | Still hopping; all sparktests acceptable; "20 hit, shading -21" |
| 8411c65 (f43c9c9) | sparktest at the target bar's size; no-snapping variants | Still hopping; all six tests still |
| d6a2af6 (3e3c896) | `/ticky sparktest copy`: live copy on a plain bar | Copy hops too; Blizzard frames too; smooth off: less often. **Accepted** |
| 55e6ce4 (b388b30) | `/ticky log` | Not yet used in game |

## Ruled out

- The unit frame (EllesmereUI or Blizzard) and anchoring to it (d6a2af6 copy).
- Scale mismatch (real, fixed in 17c02eb).
- Hidden (secret) health and max (sparktest 3-6 at 600 wide, 5-6 at real size).
- Pixel snapping on our textures at the real size (sparktest 3-4 at real size were no better
  because 1-2 were already still).
- How often the values are set (sparktest 7; "set only on change" didn't fix the live hop).
- Wrong shrink amount (debug: within 1 health point).
- A stale health value in the hit's frame (no later health message exists).
- Setting the shading a frame or two after the health (bounces; 57fb31f, sparktest).

## Still open: candidates, roughly most likely first

1. **Other damage near a tick.** Any hit that isn't your tick (wand "Shoot", melee, party members,
   another DoT's tick that wasn't matched) moves the health end alone; that's correct, but inside a
   hold window it's applied together with the next tick, and outside one it moves the spark by the
   hit. If the owner's "hops" include these, they're not a bug. `/ticky log` shows them as
   "hit N (not a tick)".
2. **A tick landing outside its windows.** Matching needs the hit within 0.35s of the expected time,
   and the hold covers 0.5s either side. A tick outside that (lag spike, phase drift, a
   refreshed DoT whose ticks restart differently than expected; ROADMAP item 4) moves the health at
   once, and the shading shrinks later when the unseen tick counts: a hop toward the health that
   comes back. In the log: "health" with no matched "hit", then later "drew shading" alone.
3. **`UnitHealth(unit)` defaults to `usePredicted = true`.** Unclear what "predicted" means for a
   mob. The mirror reads it on each health change and on the "1s check". If predicted and actual
   differ for a moment, the health end moves alone. Try `UnitHealth(unit, false)`; the log shows
   "drew health (1s check)" draws, which should never move anything.
4. ~~**The learned tick size changes.**~~ Found and fixed; see the next section. (This note had
   guessed it at "up to about 0.7 pixel, doesn't come back". It was bigger and it does come back,
   because the size flips back and forth.)
5. **The last tick.** `RemainingAmount` returns nil once `expires <= now`, so the last tick's share
   (and with one DoT, the whole shading) goes at the expected expiry, not with the hit.
6. **Easing under live conditions.** Easing is what makes it worse. Both ends are set in the same
   call, but in a fight the frame rate varies and other things redraw; if the two eases don't
   advance identically, the far end drifts for a few frames. Options: make "Smooth changes" off the
   default (fewer hops, per the owner), or accept.
7. **Engine-level anchor timing.** A frame anchored to an easing fill texture might lag a frame
   under load. sparktest at real size says no when idle; not tested under load.

## Found: the tick size estimate (fixed after the notes were written)

Evidence: `/ticky debug` on b388b30, "Last tick on target (Shadow Word: Pain ...): ... 25 hit,
shading -31", with "Shadow Word: Pain 24s/26 seen". The shading shrank 6 more than the tick did.

Cause: the shading's amount was (ticks left) x `ExpectedTick`, the learned running average
`floor(old * 0.6 + hit * 0.4 + 0.5)`, re-read on every draw. SW:P's ticks with spell power land as
25 and 26 (or 26 and 27). Each hit can flip the rounded average by 1, which changes the estimate
for **every** remaining tick at once: the shrink at that tick is (tick size) + (ticks left) x
(change). From 27 to 26 with 5 ticks left: 26 + 5 = 31 for a 25 hit, as in game. The next hit
can flip it back. So at most ticks the far end moved by several health points, in either
direction: up to about half a pixel on a 123-pixel bar with ~1500 health, which pixel rounding
turns into a 1-pixel hop. The synthetic sparktest never had this: its amounts were exact.

Fix: the estimate is fixed per timer (`t.tickSize`; replaced only if the learned size is over
15% off, like the tooltip's guess before the first tick is seen), and each seen tick takes off
its real amount (`t.paid`, `t.paidCount`, set in `Commit` from `t.pendingAmount`). A same-school
hit far off the learned size (Mind Blast near a SW:P tick) is no longer matched as the tick,
since it would now take its full amount off. `tools/tests/test_ticksize.lua` reproduces it (a
25 hit shrank the shading by 32 on the old code).

**DoT ticks can crit on Forever.** The first `/ticky log` from the game (on b388b30, before the
fix) showed `hit 38! SWP ... drew shading -26` (the `!` is a crit) and `hit 20 DP ... drew shading
-21`. The old code took off the estimate whatever the tick did, so a crit moved the spark by 12
health (about a pixel) on its own. With the fix a crit takes off its real amount
(`test_ticksize.lua` covers it).

Trade-off of the fix: the spark now stays where it was predicted at the start, rather than
moving to the "true" end point after each tick. The two differ by the sum of each tick's
deviation from the estimate (crits push one way, rounding averages out). That difference shows
up only at the end: the DoT's shading runs out a little early (clamped at 0) or a few health
points are left at expiry, so with two DoTs in one segment the spark can move when one of them
ends. A smoother alternative, if that ever matters: fold each deviation in gradually between
ticks (a slow drift over a second or two) instead of not at all.

Left over: an unseen tick still counts as the estimate (the spark moves by the difference).

That log also shows a clean sequence otherwise: hit, counted and health in the same frame,
"stops waiting; drew health (changed); drew shading" in the same frame too, and one "drew health
(1s check)" at rest.

## How to pick it up again

1. Install the latest build. DoT a mob with nothing else hitting it. The moment the spark hops,
   type `/ticky log` and paste it, with the direction of the hop. Do it a few times with "Smooth
   changes" on and off.
2. In the log (same number = same frame), a clean tick reads: `hit 26 SWP, counted SWP, health`
   then `drew health (changed); drew shading -25` in the next frame. Look for:
   - "drew health" without "drew shading" near a tick, or the other way round;
   - "hit N (not a tick)" near the hop (other damage, or a tick that didn't match);
   - "counted X (no health message)": the tick's health message never came;
   - "drew health (1s check)" at the hop (point 3);
   - "max health" (resets the range: ends the ease);
   - "waits for a tick" / "stops waiting" around the hop.
3. `/ticky debug`'s "Last tick on target" line: timing of hit, health, counted, drawn, and
   "N hit, shading -N".
4. `/ticky sparktest` (six variants at the target bar's size) and `/ticky sparktest copy` (live
   copy on a plain bar) are still there for comparisons.
5. Tests: `tools/tests/test_hold.lua` (hold and counting order, what's set on each redraw),
   `test_twodots.lua` (two DoTs ticking close together, the log), `test_sparktest.lua`. The mock
   has no layout, so it can't show positions: in-game captures and logs are the evidence.

## Don't repeat

- Guessing a cause and shipping a fix per round: about fifteen builds went that way. Measure
  first (the log, the sparktest, captures), then change one thing.
- Delaying the shading behind the health end (57fb31f): bounces the other way.
- Waiting for a later health message (ec824ce): there isn't one.
- Anchoring the shading to the unit frame's own fill (before 5a37229): it animates on its own.
