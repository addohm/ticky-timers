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
  - bar color and bar text; whether to track it from anyone (e.g. another priest's Fortitude on
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
  text-to-speech, e.g. "Pain ending"), or your own sound files (a path such as
  `Interface\AddOns\MySounds\ding.ogg`, or a sound file ID; new files load when the game starts).
- **General**: lock/unlock (drag the blue handle), channel bar, tracked auras on yourself,
  hide out of combat, hide with no target, in/out of combat opacity, reset position, reset all
  settings.

A fixed stack, for example Shadow Word: Pain on top, Devouring Plague in the middle and Mind Flay
at the bottom: track the three, put them in that order on the Spells tab, set Layout > "Order bars
by" to "Your order", and pick "Show a faded bar" (or "Keep its slot empty") for missing spells.
Your channel then sits in its own slot instead of on top.

Commands: `/ticky`, `/ticky lock | unlock`, `/ticky preview`, `/ticky add <spell>`,
`/ticky remove <spell>`, `/ticky list`, `/ticky reset`.

## How tick placement is worked out

- **Duration** comes from the aura, so talents (Improved Shadow Word: Pain: 18s → 24s), gear and
  rank are already included.
- **Tick period** comes from the game's own spell data for Forever (`SpellEffect.EffectAuraPeriod`),
  in [Ticky/Data.lua](Ticky/Data.lua), divided by spell haste for spells the data marks as
  haste-affected. Buffs and debuffs that don't tick get a plain timer. Spells missing from the
  data fall back to "every N sec" in the tooltip.
- **Channels** spread the data's tick count across the client's (hasted) channel time:
  Mind Flay's 3 ticks over 3s.
- Ticks land every period from when the aura started; a final tick cut short lands at expiry.

## Forever limitations

Forever uses the modern Mainline addon API with Midnight's combat restrictions. The combat log is
not available to addons, and some values can be "secret". Auras or casts the game marks secret
are skipped, so in restricted content the bars may not appear.

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

See [ROADMAP.md](ROADMAP.md), [CHANGELOG.md](CHANGELOG.md), [SECURITY.md](SECURITY.md),
[DEPLOY.md](DEPLOY.md) (installing, releasing, troubleshooting).
