# Deploying ticky-timers

Ticky is a World of Warcraft addon, so nothing runs on a server. "Deploying" means getting the
`Ticky` folder into a player's `Interface\AddOns` folder for **WoW: Forever** (TOC interface
`16001`). There is no build step: the `Ticky` folder in the repo is the release.

Source: https://github.com/addohm/ticky-timers

Releases are planned for CurseForge and Wago Addons: the listing text, ready to paste, and a
before-publishing list are in [LISTING.md](LISTING.md), the logo in
[art/](art). Release packages go in [release/](release) (see "Shipping a change").

## First-time setup

For development:

```bash
git clone https://github.com/addohm/ticky-timers.git
cd ticky-timers
pip install lupa                 # embedded Lua for the checker
python tools/check_lua.py        # should pass on a clean checkout
```

To run it in the game:

1. Copy the `Ticky` folder into one of the folders below. On the owner's PC,
   `tools\install_beta.cmd` does this for the beta: it runs `git pull --ff-only` on the local clone,
   then mirrors `Ticky` into the beta AddOns folder with `robocopy /MIR` (files removed from the
   repo are removed from the install too), then writes the commit into the installed `Build.lua`.
   After a `/reload`, `/ticky debug` and the options window title show that build, so you can tell
   which version is running. It only installs what's pushed to GitHub. Edit the
   `REPO` and `ADDON` paths at its top for another PC.
   - live: `World of Warcraft\<Forever folder>\Interface\AddOns\`
   - beta: `World of Warcraft\_classic_beta_\Interface\AddOns\`
2. Restart the client (a `/reload` is enough for Lua changes once the addon is already installed;
   a new or renamed file needs a full restart).
3. In game, check the interface number with `/dump select(4, GetBuildInfo())`. If it isn't
   `16001`, update `## Interface:` in `Ticky/Ticky.toc`, or enable "Load out of date AddOns".

## Shipping a change

1. Make the change and run `python tools/check_lua.py`.
2. Update README.md, CHANGELOG.md (Unreleased) and ROADMAP.md as the change requires.
3. For a release: bump `## Version:` in `Ticky/Ticky.toc`, turn CHANGELOG's Unreleased section
   into `## [x.y.z] - YYYY-MM-DD`, commit, and push to `main`.
4. Test in the Forever client (ROADMAP item 1 is the checklist).

Packages: `python tools/package.py` (from a clean checkout of the commit to release) writes
`release/Ticky-<version>-<commit>.zip`: the `Ticky` folder alone at its top level, as CurseForge,
Wago and players unzipping into `Interface\AddOns` expect, with its `Build.lua` stamped with the
commit so `/ticky debug` names it, and the license (GPLv3) inside as `Ticky/LICENSE.txt`. Commit the zip to `release/` and upload it. The current one is
`release/Ticky-0.6.0-694e496.zip` (0.6.0, the first public release).

TODO: should releases also be tagged (`vX.Y.Z`)?

Keep non-addon files (docs, tools, CLAUDE.md) out of `Ticky/`: players copy that folder whole.

Rolling back: copy the `Ticky` folder from an earlier commit (`git checkout <commit> -- Ticky`)
over the installed one and restart the client. Saved settings carry over; if an older version
can't read them, delete the `Ticky.lua` files listed under Configuration.

## Configuration

No environment variables or secrets. Settings live in the game's saved variables:

- `TickyDB` (account-wide look, layout, sounds, and your list of sound files):
  `WTF\Account\<account>\SavedVariables\Ticky.lua`
- `TickyCharDB` (per-character tracked spells, their order and per-spell settings, and what Ticky
  learned from the game: spell lengths read from auras, the size of your spells' ticks):
  `WTF\Account\<account>\<realm>\<character>\SavedVariables\Ticky.lua`

`/ticky reset` (or General > Reset all settings) restores defaults. Spell data is in the generated
`Ticky/Data.lua`; regenerate it for a new Forever build as described in
[README.md](README.md#regenerating-the-spell-data) and CLAUDE.md ("The tools").

## Troubleshooting

- **A sound file you added doesn't play**: first pick "Ticky beep" (a file that comes with Ticky)
  and press Test. If that's silent too, the game isn't playing addon sound files at all. If it
  plays, the problem is your file: press Test next to it; it says whether the game played it.
  It must not be inside `Interface\AddOns\Ticky`, which an update replaces. The path is relative to the WoW folder (e.g. `Interface\AddOns\MySounds\ding.ogg`;
  a pasted full path is trimmed to that), and the file must exist when the game starts: restart
  the game after adding it, `/reload` isn't enough. .ogg and .mp3 are safest. Keep your files outside `Interface\AddOns\Ticky`, which an update replaces.
- **No health bar shading**: turn it on in the Health bar tab, and check its "Drawing on" line. If it
  found the wrong bar, enter your target frame's health bar name (`/fstack` while hovering it). Nothing shows while your target has none of your DoTs or HoTs.
- **No bars on nameplates**: turn them on in the Nameplates tab and turn nameplates on in the game
  (V). A mob only gets bars for spells Ticky saw you cast on it (or read from its auras). The bars
  sit on the largest visible status bar inside the plate (its health bar); if there is none they
  use the whole plate.
- **"Say it" is silent**: it uses the game's text-to-speech voice (Options > Accessibility > Text
  to Speech); check a voice is installed and the volume there.
- **Addon not listed or "out of date"**: interface number mismatch; see First-time setup step 3.
  Also check the folder is `AddOns\Ticky\Ticky.toc`, not nested one level deeper.
- **Lua errors**: turn on `/console scriptErrors 1`, or use an error-catching addon, and note the
  file and line.
- **No bars**: check the spells are ticked on the Spells tab (nothing is tracked by default). In
  combat, bars come from your casts (aura details are secret; see README, "Forever limitations"),
  so a DoT that was already on the mob before Ticky loaded won't show until you recast it.
  `/ticky debug` shows what the game lets Ticky read right now.
- **Ticks in the wrong place for a spell**: check its entry in `Ticky/Data.lua` and whether the data
  is from the current Forever build (`ns.DataBuild`).
- **Settings look broken after an update**: `/ticky reset`, or delete the saved-variable files
  while the game is closed.
