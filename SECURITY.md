# Security

## Reporting
Open an issue at https://github.com/addohm/ticky-timers/issues, or contact the author (Addohm)
privately for anything sensitive.

## What the addon can access
Only the in-game WoW addon API: your own and your target's auras, your channeled casts, and your spellbook.
It has no network access and runs only inside the game client. The only files it touches are sound
files you add yourself, which the game plays (it never reads or writes them).

## Data and secrets
Settings are saved locally in `WTF\Account\<account>\SavedVariables\Ticky.lua` (look and alerts)
and per character in `WTF\Account\<account>\<realm>\<character>\SavedVariables\Ticky.lua` (tracked spells and their settings,
and the spell lengths and tick sizes Ticky learned from the game).
No credentials or personal data are stored. The addon plays built-in game sounds, sound files you
choose, and the game's text-to-speech voice for words you set.
