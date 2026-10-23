# Ticky: CurseForge / Wago listing

Everything below the "Description" heading is ready to paste (both sites take Markdown). The logo
is in [art/](../art): `ticky-icon-512.png` for the project avatar (`ticky-icon.svg` scales to any
size), `ticky-banner-1200x400.png` for a header image. `tools/make_logo.py` regenerates them.

---

## Listing basics

- **Name:** Ticky
- **Summary** (the one-liner under the name):
  > Timer bars for your DoTs, HoTs, buffs and channels, with a mark for every tick. Built for WoW: Forever.
- **Game version:** World of Warcraft: Forever (Interface 16001)
- **Categories:** Buffs & Debuffs (main), Combat, Unit Frames
- **Author:** addohm
- **Links:** source: https://github.com/addohm/ticky-timers; issues:
  https://github.com/addohm/ticky-timers/issues
- **Avatar:** [art/ticky-icon-512.png](../art/ticky-icon-512.png)
- **Header image:** [art/ticky-banner-1200x400.png](../art/ticky-banner-1200x400.png)

---

## Description

![Ticky](https://raw.githubusercontent.com/addohm/ticky-timers/main/art/ticky-banner-1200x400.png)

### Know every tick.

**Ticky** puts a timer bar on every buff, debuff and channel you care about, and a mark on the bar
for **every tick** of your DoTs, HoTs and channels. You see when the next tick lands, how many are
left and when to refresh, without watching a debuff icon.

Built from the ground up for **World of Warcraft: Forever**: original Azeroth on the modern addon
API.

### Made for Forever's rules

Forever hides a lot from addons in combat. There's no combat log, and buff and debuff details are
hidden while you fight. Ticky works with that:

- **Timers start from your own casts**, which the game always shows, so your bars run in combat.
  When the game does let addons read buffs and debuffs (usually out of combat), Ticky uses the
  exact times.
- **Talents, gear and haste count.** Each cast's duration and damage come from the spell's current
  tooltip, so Improved Shadow Word: Pain's 24 seconds is 24 seconds. Tick timing comes from
  Forever's own spell data, sped up by haste where the spell allows it.
- **Misses, resists, dodges and parries** drop the bar. A missed refresh leaves the old one
  running.
- **Display and sound only.** Ticky never automates anything.

### Features

**Timer bars**
- Any spell that leaves a buff, debuff or channel: pick from your spellbook, or add any spell by
  name, ID or shift-click. Spell data covers all 1,928 class spells with a timed effect (598 that
  tick).
- A mark for every tick, past ticks dimmed or hidden, the next tick highlighted, ticks left on the
  bar.
- Your target's bars first, then your own buffs. Optionally, **your spells on other units** too,
  each labelled with who it's on ("Renew (Bob)"), so you can see when the HoT you're keeping on
  someone falls off.
- **Missing spells:** hide them, keep their slot empty, or show a faded bar, so a missing DoT
  stands out.
- Your own bar order, or sort by name or time left.

**Health bar shading**
- On your target's health bar: the part your DoTs will still take off, with a **spark where the
  health will end up** once they're done. Your HoTs show the healing still to come.
- The spark stays put as your ticks land. Other damage, healing and crits move it as the health
  really changes.
- Works on Blizzard's target frame and on unit frame addons' frames, and optionally on every
  nameplate.

**Nameplates**
- Small timer bars on each mob's nameplate, always the plate's width. Show them on every plate but
  your target's, on all plates, or only on your target's.
- Their own look if you like. Hidden inside raids by default, to keep raid nameplates clean.

**Sounds and alerts**
- A sound for each event: put on, refreshed, every tick, about to end, ended, removed early. Set
  one for all spells, or per spell.
- Game sounds, two built-in Ticky sounds, **text-to-speech** ("Pain ending"), or your own sound
  files.
- A warning before a DoT ends, with a bar flash and on-screen text.

**Make it yours**
- Textures, borders, background, colors (per spell too), fonts, outlines, icon side, spark, fill
  direction, time format, bar size, spacing and opacity in and out of combat.
- Live preview while the options window is open.

### Getting started

1. Install, then type **/ticky** (or use the minimap addon menu).
2. On the **Spells** tab, tick the spells you want to track.
3. Cast them. That's it. Everything else is optional.

### Commands

- `/ticky`: options
- `/ticky lock`, `/ticky unlock`: move the bars
- `/ticky preview`: preview bars
- `/ticky add <spell>`, `/ticky remove <spell>`, `/ticky list`
- `/ticky reset`: reset look and sounds (your spells are kept)
- `/ticky debug`: a short report to paste when something looks wrong
- `/ticky report`: the link for reporting a problem

### Good to know

- **Other players' spells** ("track it from anyone") can only show while the game lets addons read
  buffs and debuffs, usually out of combat. Your own casts always work.
- A DoT **dispelled** during a fight keeps its bar until Ticky can read debuffs again.
- A `/reload` in the middle of a fight forgets the timers from your casts until you cast again.

### Feedback

Found a problem or have an idea? Type **/ticky report** in game for the link, or open an issue at
https://github.com/addohm/ticky-timers/issues. Please include what `/ticky debug` shows right
after it happens.

---

## Screenshots to take

1. **Hero shot:** a Shadow Priest with SW:P, Devouring Plague and a Mind Flay channel bar, tick
   marks visible, mid-fight.
2. **Health bar shading:** a target frame with two DoTs shaded and the spark.
3. **Nameplates:** three or four mobs with plate bars (and shading).
4. **Your spells on other units:** a healer's bars with "Renew (Name)" on two or three people.
5. **Options:** the Spells tab with a spell selected (per-spell sounds), and the Sounds tab.
6. **Missing spell:** a faded bar for a DoT that isn't up.

Wide, uncluttered screenshots read best on both sites; crop to the bars where you can.

---

## First release notes (paste into the file's changelog)

**Ticky 0.6.0**: the first public release for WoW: Forever.

- Timers from your own casts, so bars run in combat. Talent and gear changes are taken from each
  spell's tooltip; tick timing comes from Forever's spell data, with haste.
- A mark for every tick; missing spell bars; your own bar order.
- Health bar shading: what your DoTs and HoTs will still do, with a spark where the health ends
  up. Target frame and nameplates.
- Timer bars on nameplates, hidden in raids by default.
- Your spells on other units, named ("Renew (Bob)").
- Sounds for every event, per spell: game sounds, text-to-speech or your own files.
- Misses, resists, dodges and parries drop the bar.

---

## Before publishing

- [ ] **License:** the repo has none yet, and both sites ask for one. Pick one (for example MIT or
      All Rights Reserved) and add a `LICENSE` file.
- [ ] **Version:** bump `## Version:` in `Ticky.toc` (for example to 0.6.0) and turn the
      changelog's Unreleased section into that version.
- [ ] **Packaging:** `python tools/package.py` writes `release/Ticky-<version>-<commit>.zip`: the
      `Ticky` folder alone at its top level, its Build.lua stamped with the commit. Upload that.
- [ ] **Game version:** check that CurseForge and Wago list a Forever game version or flavor
      (Interface 16001) at launch (Nov 4, 2026), and pick it so Forever players find the addon.
- [ ] **Description:** the README's opening line credits an old WeakAura; leave that out of the
      listing (the text above does).
- [ ] **Screenshots:** take the shots listed above in the Forever client.
