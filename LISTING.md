# Ticky: CurseForge and Wago listing

Copy-paste material for the project pages. Placeholders are in [brackets].

---

## Basics

| Field | Value |
| --- | --- |
| Name | Ticky |
| Slug | `ticky-timers` |
| Game version | WoW: Forever (Interface 16001, client 1.60.1) |
| Author | addohm |
| License | [choose: All Rights Reserved, MIT, ...] |
| Source | https://github.com/addohm/ticky-timers |
| Issues | https://github.com/addohm/ticky-timers/issues |

**Categories**
- CurseForge: Buffs & Debuffs (main), Combat, Unit Frames, Class
- Wago: Buffs & Debuffs (main), Combat, Unit Frames, Class

**Summary** (the one-liner under the name; 142 characters)

> Timer bars for your DoTs, HoTs, buffs and channels, with a mark for every tick and health bar
> shading that shows what your DoTs will still do.

**Short tagline** (for images or a Discord post)

> Know every tick.

**Art** (in [art/](art); `tools/make_logo.py` regenerates it)
- Project icon: `art/ticky-icon-512.png` (`art/ticky-icon.svg` scales to any size)
- Header or banner image: `art/ticky-banner-1200x400.png`

---

## Description

*(Paste as Markdown. Both sites accept it.)*

### Ticky

**Built for WoW: Forever, where the combat log is gone and buffs hide in combat.**

Ticky puts a timer bar on every buff, debuff and channel you care about, with a mark for every
tick of your DoTs, HoTs and channels. You see when the next tick lands, how many are left and when
to refresh, without squinting at a debuff icon. On your target's health bar it shades what your
DoTs will still take off, with a spark where the health will end up.

#### Timer bars with every tick

- Track any spell that leaves a buff, debuff or channel: tick it in your spellbook list, or add it
  by name, ID or shift-click. Spell data covers all 1,928 class spells with a timed effect, 598 of
  which tick.
- A mark for every tick, from Forever's own spell data and sped up by haste where the spell allows
  it. Past ticks dim or hide, the next one can be highlighted, and the bar can show the ticks
  left.
- Your target's bars on top, your own buffs below. Turn on **your spells on other units** to also
  see your DoTs and HoTs on everyone else, each labelled with who it's on ("Renew (Bob)"), so you
  know when the HoT you're keeping on someone falls off.
- **Missing spells:** hide them, keep their slot empty, or show a faded bar, so a DoT that isn't up
  stands out.
- Order the bars your own way, by name, or by time left.

#### Made for Forever

- **Timers start from your own casts**, which the game always shows, so your bars run in combat.
  When the game lets addons read buffs and debuffs (usually out of combat), Ticky uses the exact
  times.
- **Talents, gear and spell power count:** each cast's length and damage come from the spell's
  current tooltip, so a talented 24-second Shadow Word: Pain runs 24 seconds.
- **Misses, resists, dodges and parries** drop the bar. A missed refresh leaves the old one
  running.
- **Only your spells**, unless you ask for others: another priest's Shadow Word: Pain isn't taken
  for yours.

#### Health bar shading

- On your target's health bar: the part your DoTs will still take off, with a **spark where the
  health will end up** once they're done. Your HoTs show the healing still to come.
- The spark holds still as your ticks land. Anything else that changes the health, other players'
  damage, healing on the mob, a crit, moves it with the bar.
- Works on Blizzard's target frame and on unit frame addons' frames, and optionally on every
  nameplate. One shaded segment, or one per spell in its color; spark, outline, opacity and texture
  are yours to set.

#### Nameplates

- Small timer bars on each mob's nameplate, always the plate's width: on every plate but your
  target's, on all of them, or only your target's.
- Their own look if you like. Hidden inside raids by default, to keep raid nameplates clean.

#### Sounds and alerts

- A sound for each event: put on, refreshed, every tick, about to end, ended, removed early. Set
  one for all your spells, or per spell.
- Game sounds, two built-in Ticky sounds, **text-to-speech** ("Pain ending"), or your own sound
  files.
- A warning before a DoT ends, with a bar flash and on-screen text.

#### Make it yours

- Textures, borders, backgrounds, colors (per spell too), fonts, outlines, icon side, spark, fill
  direction, time format, bar size, spacing, and opacity in and out of combat.
- A live preview runs while the options window is open.

#### Commands

- `/ticky`: the options window (also in the minimap addon menu).
- `/ticky lock`, `/ticky unlock`, `/ticky preview`
- `/ticky add [spell]`, `/ticky remove [spell]`, `/ticky list`, `/ticky reset`
- `/ticky debug`: a short report to paste when something looks wrong. `/ticky report`: where to
  report it.

#### Good to know

- Your own casts always work. Other players' spells ("track it from anyone") only show while the
  game lets addons read buffs and debuffs, usually out of combat.
- A DoT dispelled during a fight keeps its bar until Ticky can read debuffs again, and a `/reload`
  mid-fight forgets the timers from your casts until you cast again.
- Display and sound only: Ticky never acts for you.
- Everything stays on your computer in the game's own saved data. No network access, no libraries.
- Found a problem? `/ticky report` gives the link; please include what `/ticky debug` shows.

---

## Screenshots to take

1. **Hero:** a Shadow Priest mid-fight with Shadow Word: Pain, Devouring Plague and a Mind Flay
   channel bar, tick marks showing.
2. The target frame's health bar shaded by two DoTs, with the spark.
3. Nameplate bars (and shading) on three or four mobs.
4. Your spells on other units: a healer's bars with "Renew (name)" on two or three people.
5. A missing DoT as a faded bar.
6. Options → Spells, a spell selected with its own sounds.
7. Options → Sounds.
8. Options → Health bar.
9. The warning before a DoT ends: the flashing bar and on-screen text.

Tips: use a clean UI (hide other addons), 16:9 at 1920×1080, crop to the subject, and keep
character names you're happy to show.

---

## Release notes for 0.6.0

> First public release, for WoW: Forever.
>
> - Timer bars for any buff, debuff or channel, with a mark for every tick
> - Timed from your own casts so they run in combat; lengths and damage from each spell's current
>   tooltip (talents, gear, spell power), tick timing from Forever's spell data with haste
> - Health bar shading with a spark where the health will end up, on your target and nameplates
> - Timer bars on nameplates, hidden in raids by default
> - Your spells on other units, named
> - Missing-spell bars, your own bar order
> - Sounds for every event, per spell: game sounds, text-to-speech or your own files
> - Misses, resists, dodges and parries drop the bar

---

## Before publishing

- Work through the open items in TESTING.md that matter for a first release.
- Choose a license and add a `LICENSE` file.
- Bump `## Version` in `Ticky/Ticky.toc` to 0.6.0 (the package in `release/` is 0.5.0), move the
  CHANGELOG entries under the version, then `python tools/package.py` and commit the new zip in
  `release/` (see DEPLOY.md).
- Add the project IDs to `Ticky/Ticky.toc` (`## X-Curse-Project-ID`, `## X-Wago-ID`) once the
  projects exist.
- Check that CurseForge and Wago list a Forever game version (Interface 16001) at launch, Nov 4,
  2026.
- Project icon: `art/ticky-icon-512.png`. In game the addon list keeps the Shadow Word: Pain icon
  (`## IconTexture` in the TOC).
