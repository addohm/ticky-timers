# tools/CLAUDE.md: data generation and checks

## check_lua.py

`python tools/check_lua.py` compiles every `Ticky/*.lua` with lupa and checks that `Ticky.toc`
lists exactly the Lua files on disk. Exit code 1 on any failure. It catches syntax errors only;
lupa is Lua 5.4+, so 5.1-only problems aren't caught. Needs `pip install lupa`.

## gen_data.py

Builds `Ticky/Data.lua` from World of Warcraft: Forever's spell tables.

```bash
python tools/gen_data.py <csv dir> <build> Ticky/Data.lua
```

### Inputs

CSV exports from wago.tools for the Forever build (product `wowf`; the beta is
`wow_classic_beta`). Download each with:

```
https://wago.tools/db2/<Table>/csv?build=<build>
```

Tables: `SpellEffect`, `SpellMisc`, `SpellDuration`, `SpellClassOptions`, `SkillLineAbility`,
`SkillLine`, `SpellName` (about 8 MB together). Find the current build at
https://wago.tools/builds (filter `wowf`). Keep the CSVs out of the repo.

### What it selects

- **Class spells**: `SpellClassOptions.SpellClassSet` 3–11 (mage through shaman), plus spells on
  class (`SkillLine.CategoryID` 7, minus pets, mounts, companions) and racial skill lines.
- **Timed auras**: the spell has an apply-aura effect (`Effect` 6, 35, 65, 119, 128, 129, 143)
  and a positive duration (`SpellMisc.DurationIndex` -> `SpellDuration.Duration`), or is a channel.
  Permanent buffs are left out.
- **Ticking**: an effect whose `EffectAura` is periodic (damage 3, heal 8, leech 53, funnel 62,
  mana leech 64, damage % 89; then obs health/power 20/21, energize 24; then trigger 23, dummy 226)
  with `EffectAuraPeriod` > 0. The highest-priority type wins, then the lowest effect index.
- **Flags**: `h` from `SpellMisc.Attributes_5 & 0x2000` (haste affects periodic); channels from
  `Attributes_1 & 0x4` or `& 0x40`, which get `d` = base duration.
- Only `DifficultyID` 0 rows are used.

### Output

`ns.Data[spellID] = { p = periodMs, h = true, d = channelDurationMs }` with a spell-name comment
per line, plus `ns.DataBuild`. Non-ticking auras are `{}`.

### After regenerating

1. Run `python tools/check_lua.py`.
2. Spot-check known spells against the game (build 1.60.1.70245 values): Shadow Word: Pain 589 and
   10894 `p=3000`; Mind Flay 15407 `p=1000,d=3000`; Corruption 172 `p=3000`; Insect Swarm 5570
   `p=2000`; Power Word: Shield 17 `{}`.
3. Note the build and the counts the script prints (1,928 spells / 598 ticking / 140 channels for
   1.60.1.70245) in CHANGELOG.md, and update the build mentioned in README.md.
