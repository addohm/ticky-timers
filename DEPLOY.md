# Deploying ticky-timers

Ticky is a World of Warcraft addon, so nothing runs on a server. "Deploying" means getting the
`Ticky` folder into a player's `Interface\AddOns` folder for **WoW: Forever** (TOC interface
`16001`). There is no build step: the `Ticky` folder in the repo is the release.

Source: https://github.com/addohm/ticky-timers

TODO: where are releases published for players (GitHub Releases, CurseForge, Wago Addons,
or just "copy from the repo")? No tags or release packages exist yet.

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
   repo are removed from the install too). It only installs what's pushed to GitHub. Edit the
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

TODO: should releases be tagged (`vX.Y.Z`) and packaged as a zip of the `Ticky` folder?

Keep non-addon files (docs, tools, CLAUDE.md) out of `Ticky/`: players copy that folder whole.

Rolling back: copy the `Ticky` folder from an earlier commit (`git checkout <commit> -- Ticky`)
over the installed one and restart the client. Saved settings carry over; if an older version
can't read them, delete the `Ticky.lua` files listed under Configuration.

## Configuration

No environment variables or secrets. Settings live in the game's saved variables:

- `TickyDB` (account-wide look, layout, sounds, and your list of sound files):
  `WTF\Account\<account>\SavedVariables\Ticky.lua`
- `TickyCharDB` (per-character tracked spells, their order and per-spell settings):
  `WTF\Account\<account>\<realm>\<character>\SavedVariables\Ticky.lua`

`/ticky reset` (or General > Reset all settings) restores defaults. Spell data is in the generated
`Ticky/Data.lua`; regenerate it for a new Forever build as described in
[README.md](README.md#regenerating-the-spell-data) and CLAUDE.md ("The tools").

## Troubleshooting

- **A sound file you added doesn't play**: the path is relative to the WoW folder (e.g.
  `Interface\AddOns\MySounds\ding.ogg`), and the file must exist when the game starts; restart
  after adding it. Keep your files outside `Interface\AddOns\Ticky`, which an update replaces.
- **No health bar shading**: turn it on in the Health bar tab, and check its "Drawing on" line. For a
  unit frame addon other than EllesmereUI, enter its target health bar's frame name (`/fstack`
  while hovering it). Nothing shows while your target has none of your DoTs or HoTs.
- **No bars on nameplates**: turn them on in the Nameplates tab and turn nameplates on in the game
  (V). A mob only gets bars for spells Ticky saw you cast on it (or read from its auras). With a
  nameplate addon, the bars follow Blizzard's plate position; adjust the offsets to fit.
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
