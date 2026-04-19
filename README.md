# PartyPulse

A lightweight party interrupt cooldown tracker for World of Warcraft, built for the Midnight (Patch 12.0) addon API.

Each party member running PartyPulse broadcasts their own interrupt usage over the hidden addon-message channel. Everyone else's client listens and renders the cooldown. No combat-log inference, no restricted APIs — just each player self-reporting, which is the sanctioned pattern under Midnight's API restrictions.

## Features

- Tracks the baseline interrupt for every class, with spec overrides (e.g. Hunter BM/SV → Muzzle)
- Adds secondary abilities where relevant: Death Knight **Death Grip**, Balance Druid **Solar Beam**
- Party rows with class-colored names and cooldown-sweep icons
- Late-join sync: if you join mid-pull, existing members whisper their active cooldowns so your UI is immediately accurate
- Draggable frame with persisted position, scale, and per-spell toggles
- Settings panel via Interface → AddOns → PartyPulse, or `/pp config`

## Install

**From CurseForge / Wago:** search "PartyPulse" in your addon manager.

**Manual:** download the latest release zip from [Releases](https://github.com/sgurgurich/PartyPulse/releases) and extract into `World of Warcraft/_retail_/Interface/AddOns/`.

## Usage

- `/pp` — toggle the tracker frame
- `/pp config` — open the settings panel

Drag the frame to position it. Position, scale, and per-spell settings save per character.

## How it works

PartyPulse uses `C_ChatInfo.SendAddonMessage` on the PARTY/RAID channel with prefix `PartyPulse`. Messages are invisible to players and are only delivered to other clients running the addon. No data leaves your group.

Wire protocol:
- `HELLO:<class>:<id1,id2,...>` — announce yourself and your tracked spells
- `CD:<spellID>:<seconds>` — your interrupt fired; peers start the sweep
- `SYNC:<id,rem>;<id,rem>;...` — whispered to new arrivals so they see active cooldowns

## ToS / API compliance

PartyPulse only reads **your own** combat events (`UNIT_SPELLCAST_SUCCEEDED` on `player`) and broadcasts them via the standard addon-message API. It does not attempt to inspect other players' combat state, rotations, or cooldowns — which matches Blizzard's Midnight addon restrictions.

## License

MIT — see [LICENSE](LICENSE).
