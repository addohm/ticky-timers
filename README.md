# Ticky

A **World of Warcraft: Forever** addon. Pick any buff, debuff or channeled spell and Ticky shows a
timer bar for it. Spells that work over time (DoTs, HoTs, channels) also get a marker for every
tick. Switching targets shows that target's bars; your own buffs show below them.
Inspired by Woat's Shadow Priest WeakAuras ([example](https://wago.io/AYC53i2vy)).

**Status:** 0.5.0, untested in game. Logic is checked against a mocked Forever API. Spell data
covers all 1,928 class spells that leave a timed buff or debuff (598 of them tick), generated from
Forever build 1.60.1.70245.

## Install

Copy the `Ticky` folder into `World of Warcraft\<Forever folder>\Interface\AddOns\`
(beta: `World of Warcraft\_classic_beta_\Interface\AddOns\`), then restart the client.
Check the interface number with `/dump select(4, GetBuildInfo())`; the TOC says `16001`.

## Options

Open with `/ticky`, the minimap addon menu, or Game Menu > Options > AddOns > Ticky. Preview bars
loop while the window is open so you can see your changes.

- **Spells**: the spells in your spellbook that leave a buff or debuff (search, or "Show all
  spells"). Tick to track. Select one to set its bar color, its bar text, its own end/warning
  sounds, and whether to track it from anyone (e.g. another priest's Fortitude on you, or a raid
  member's debuff on the boss). Add any other spell by name, ID or shift-click. Spell choices are
  saved per character.
- **Bars**: width, height, spacing, scale; stack up or down; order by name, time left or the
  order you added them; empty or fill; texture; background opacity; icon on/off and side;
  a different color for the last few seconds.
- **Text & Ticks**: spell name, time left and ticks left on/off; font, size, outline; tick color
  and width; past ticks dimmed, hidden or shown; highlight the next tick in its own color.
- **Alerts**: a sound when a timer ends; a warning sound and bar flash N seconds before; sound
  channel; alerts for DoTs on enemies you've switched away from (or see a nameplate for);
  combat-only alerts. A DoT that's dispelled early doesn't alert.
- **General**: lock/unlock (drag the blue handle), channel bar, tracked auras on yourself,
  hide out of combat, in/out of combat opacity, reset position, reset all settings.

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

Coding guidance is in [CLAUDE.md](CLAUDE.md) and [tools/CLAUDE.md](tools/CLAUDE.md). Check the Lua after changes with `python tools/check_lua.py`
(needs `pip install lupa`).

See [ROADMAP.md](ROADMAP.md), [CHANGELOG.md](CHANGELOG.md), [SECURITY.md](SECURITY.md),
[DEPLOY.md](DEPLOY.md) (installing, releasing, troubleshooting).
