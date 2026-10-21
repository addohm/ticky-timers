# Ticky

A **World of Warcraft: Forever** addon. Pick any buff, debuff or channeled spell and Ticky shows a
timer bar for it. Spells that work over time (DoTs, HoTs, channels) also get a marker for every
tick. Switching targets shows that target's bars; your own buffs show below them.
Inspired by Woat's Shadow Priest WeakAuras ([example](https://wago.io/AYC53i2vy)).

**Status:** 0.5.0 plus unreleased changes. Loads in the Forever client; bars, ticks and sounds are
checked against a mocked Forever API but not yet confirmed in game. Spell data
covers all 1,928 class spells that leave a timed buff or debuff (598 of them tick), generated from
Forever build 1.60.1.70245.

## Install

Copy the `Ticky` folder into `World of Warcraft\<Forever folder>\Interface\AddOns\`
(beta: `World of Warcraft\_classic_beta_\Interface\AddOns\`), then restart the client.
Check the interface number with `/dump select(4, GetBuildInfo())`; the TOC says `16001`.
For development on Windows, `tools\install_beta.cmd` pulls the latest code and copies it into the
beta client (see [DEPLOY.md](DEPLOY.md)).

## Options

Open with `/ticky`, the minimap addon menu, or Game Menu > Options > AddOns > Ticky. Preview bars
loop while the window is open so you can see your changes. In the preview each tracked spell runs,
then goes missing for a few seconds, so you can see how missing spells look too.

- **Spells**: the spells in your spellbook that leave a buff or debuff (search, or "Show all
  spells"). Tick to track. Add any other spell by name, ID or shift-click. Select a tracked spell
  to set, for that spell only:
  - its place in your own order (Move up / Move down);
  - bar color and bar text; whether it's part of the health bar overlay and shown on nameplates;
    whether to track it from anyone (e.g. another priest's Fortitude on
    you, or a raid member's debuff on the boss);
  - what happens while it's not on your target (hide, keep its slot empty, or show a faded bar);
  - its warning time;
  - its own sound for each event (put on, refreshed, every tick, warning, ended, removed early),
    and the words "Say it" speaks.

  Spell choices are saved per character.
- **Bars**: width, height, scale; fill or empty; which side is full; a spark at the fill edge;
  texture; background color and opacity; border size and color; icon on/off and side; a
  different color for the last few seconds.
- **Layout**: stack up or down; order by name, time left, or your own order; space between bars.
  For spells that aren't on your target: hide them (the rest move up), keep their slot empty, or
  show a faded bar (opacity, color, grayed icon). Missing bars can be limited to combat, and to
  targets the spell can go on (damage spells on enemies, heals and buffs on friends).
- **Text & Ticks**: spell name, time left, ticks left and stacks on/off; font, size, outline,
  shadow; name and time colors; time on the left or right; tenths of a second under 10s, under 3s,
  or never; tick color, width and height; past ticks dimmed, hidden or shown; highlight the next
  tick in its own color.
- **Sounds**: a default sound for each event (put on, refreshed, every tick, warning, ended,
  removed early); warning time and bar flash; sound channel; alerts for DoTs on enemies you've
  switched away from (or see a nameplate for); combat-only alerts; on-screen text for warnings,
  endings and early removals. Sounds can be any of the built-in ones, "Say it" (the game's
  text-to-speech, e.g. "Pain ending"), "Ticky beep" and "Ticky chime" (sound files that come with
  Ticky), or your own sound files (a path such as
  `Interface\AddOns\MySounds\ding.ogg`, or a sound file ID; a pasted full Windows path is cut
  down to the part from `Interface\`; Add and Test say whether the game played it; new files only
  load when the game starts). Picking a warning sound while the warning time is Off sets it to 3s.
- **Health bar**: on your target's health bar, shade the part your DoTs (and channel) will still
  take off, ending at its current health, and the part your HoTs will still heal, starting there.
  Off by default. One segment with the total (dark for damage, green for healing; colors are
  yours to pick) or one segment per spell in its bar color, with a line between them; opacity;
  texture; a spark where the shading ends (where the health should end up) and its color; an
  outline and its color; smooth changes (the shading eases down like a smooth health bar, so its
  far end holds still as ticks land). "Also on nameplates" shades each nameplate's health bar the
  same way, for your DoTs and HoTs on that mob. It finds a unit frame addon's target frame (or
  Blizzard's) by itself, picking the bar named like a health bar over absorb or missing-health bars,
  and shows which bar it's drawing on; if it picks the wrong one, enter the health bar's frame name
  (find it with `/fstack`).
- **Nameplates**: small timer bars on each mob's nameplate for your tracked buffs and debuffs on
  it. Off by default. On every nameplate but your target's (your target has the main bars), on all,
  or only your target's; above or below the plate, with a distance. The bars always span the
  nameplate's health bar (Blizzard's, or a nameplate addon's built on it), and their height
  is a share of that width, so they keep their shape when plates change size. Spacing, font size,
  icon, name, time and ticks left. They look like the main bars, or, with "Their own look", have
  their own texture, background color and opacity, border, fill direction, spark, tick color, font
  and outline. "Shade what DoTs/HoTs will still do" puts the health bar shading on each plate.
  Needs nameplates turned on. "Hide the main bars" (also on the General tab) leaves just the
  nameplate bars.
- **General**: lock/unlock (drag the blue handle), channel bar, tracked auras on yourself,
  hide out of combat, hide with no target, hide the main bars altogether (sounds, nameplate bars
  and the health bar overlay keep working), in/out of combat opacity, reset position, reset all
  settings.

A fixed stack, for example Shadow Word: Pain on top, Devouring Plague in the middle and Mind Flay
at the bottom: track the three, put them in that order on the Spells tab, set Layout > "Order bars
by" to "Your order", and pick "Show a faded bar" (or "Keep its slot empty") for missing spells.
Your channel then sits in its own slot instead of on top.

Commands: `/ticky`, `/ticky lock | unlock`, `/ticky preview`, `/ticky add <spell>`,
`/ticky remove <spell>`, `/ticky list`, `/ticky reset`, `/ticky debug` (a short report, small
enough to paste into a chat message: build, combat state, each spell's learned length and tick,
the timers on your target, your last casts, the timing of the last tick on your target, and the
last misses/resists and what Ticky did with them), `/ticky debug all` (the long version, with what the game is hiding), `/ticky report`
(the link for reporting a problem, ready to copy) and `/ticky sparktest` (a 15-second test of the
health bar shading's spark on a big test bar; it prints how far the spark strayed in each variant).

## Reporting problems

Open an issue at https://github.com/addohm/ticky-timers/issues (`/ticky report` or General >
Report a problem in game gives you the link to copy). Say what happened and what you expected, and
paste what `/ticky debug` shows right after it happens: its first line says which build you have.

## How tick placement is worked out

- **Start and duration.** In combat Forever hides aura details from addons, so a timer starts when
  your cast lands, aimed at the mob you targeted when you cast it (tab-dotting works). Its length is
  what Ticky last read from that spell's aura (talents such as Improved Shadow Word: Pain's 18s →
  24s included), or, until it has seen one, the spell's tooltip ("over 18 sec"). Whenever the game
  does let Ticky read the aura (usually out of combat), the exact times and stacks replace the
  estimate, and a spell that was dispelled or never landed is removed. A miss, dodge, parry, resist
  or immunity right after the cast drops it too (a missed recast leaves the old timer running).
- **Health bar amounts.** What's left is the ticks still to come times the size of one tick: what
  the spell's ticks actually did on your target (Ticky watches the damage and healing the game
  reports on it, matched by timing and school, crits left out), or, until it has seen some, the
  tooltip's total over its tick count, which leaves out spell power. The game hides your target's
  health, so the shading is drawn by bars the game scales to it; Ticky never sees the numbers.
- When combat ends, your debuffs on mobs Ticky can no longer see (or that are dead) are dropped
  without alerts; mobs it can still see, such as after a Vanish or Feign Death, keep theirs with
  exact times. Buffs and HoTs carry on.
- Mobs are remembered by their ID in the open world, so switching targets and back keeps their
  timers. In dungeons, where mob IDs are hidden, Ticky uses the mob's nameplate instead (turn
  enemy nameplates on), or only your current target.
- **Tick period** comes from the game's own spell data for Forever (`SpellEffect.EffectAuraPeriod`),
  in [Ticky/Data.lua](Ticky/Data.lua), divided by spell haste for spells the data marks as
  haste-affected. Buffs and debuffs that don't tick get a plain timer. Spells missing from the
  data fall back to "every N sec" in the tooltip.
- **Channels** spread the data's tick count across the client's (hasted) channel time:
  Mind Flay's 3 ticks over 3s.
- Ticks land every period from when the aura started; a final tick cut short lands at expiry.

## Forever limitations

Forever uses the modern Mainline addon API with Midnight's combat restrictions. The combat log is
not available to addons, and in combat aura details (which spell, its timing, who cast it) are
"secret": addons can't read them. Your own casts stay readable, so Ticky times your spells from
your casts (see above). What that means:

- Your own casts are tracked in combat. "Track it from anyone" (someone else's buff or debuff) only
  works while auras are readable, usually out of combat.
- A DoT dispelled in combat keeps its bar until the next time Ticky can read auras.
- Until Ticky has read a spell's aura once, its length comes from the tooltip, which may not
  include talents.
- `/ticky debug` shows what the game is hiding right now.

## Regenerating the spell data

Download these tables as CSV from wago.tools for the Forever build (product `wowf`), e.g.
`https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70245`: SpellEffect, SpellMisc,
SpellDuration, SpellClassOptions, SkillLineAbility, SkillLine, SpellName. Then:

```bash
python tools/gen_data.py <csv folder> 1.60.1.70245 Ticky/Data.lua
```

## Development

Coding guidance is in [CLAUDE.md](CLAUDE.md). Check the Lua after changes with
`python tools/check_lua.py` (needs `pip install lupa`).

See [ROADMAP.md](ROADMAP.md), [TESTING.md](TESTING.md), [CHANGELOG.md](CHANGELOG.md), [SECURITY.md](SECURITY.md),
[DEPLOY.md](DEPLOY.md) (installing, releasing, troubleshooting).
