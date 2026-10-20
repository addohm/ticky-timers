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

1. Copy the `Ticky` folder into one of:
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

TODO: should releases be tagged (`vX.Y.Z`) and packaged as a zip? If so, the zip should contain
only the `Ticky` folder, without `Ticky/CLAUDE.md`.

Rolling back: copy the `Ticky` folder from an earlier commit (`git checkout <commit> -- Ticky`)
over the installed one and restart the client. Saved settings carry over; if an older version
can't read them, delete the `Ticky.lua` files listed under Configuration.

## Configuration

No environment variables or secrets. Settings live in the game's saved variables:

- `TickyDB` (account-wide look and alerts):
  `WTF\Account\<account>\SavedVariables\Ticky.lua`
- `TickyCharDB` (per-character tracked spells):
  `WTF\Account\<account>\<realm>\<character>\SavedVariables\Ticky.lua`

`/ticky reset` (or General > Reset all settings) restores defaults. Spell data is in the generated
`Ticky/Data.lua`; regenerate it for a new Forever build as described in
[tools/CLAUDE.md](tools/CLAUDE.md).

## Troubleshooting

- **Addon not listed or "out of date"**: interface number mismatch; see First-time setup step 3.
  Also check the folder is `AddOns\Ticky\Ticky.toc`, not nested one level deeper.
- **Lua errors**: turn on `/console scriptErrors 1`, or use an error-catching addon, and note the
  file and line.
- **No bars in a raid or dungeon**: the game may mark aura or cast values secret there; Ticky skips
  them on purpose (see README, "Forever limitations").
- **Ticks in the wrong place for a spell**: check its entry in `Ticky/Data.lua` and whether the data
  is from the current Forever build (`ns.DataBuild`).
- **Settings look broken after an update**: `/ticky reset`, or delete the saved-variable files
  while the game is closed.
