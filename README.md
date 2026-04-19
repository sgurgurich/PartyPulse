# PartyPulse

A lightweight party interrupt + cooldown tracker for World of Warcraft, built for the Midnight (Patch 12.0) addon API.

Every player running PartyPulse reports their **own** interrupt usage over the hidden addon-message channel. Peers listen and render the cooldowns. No combat-log inference, no restricted APIs — just self-report, which is the sanctioned pattern under Midnight's addon restrictions.

## Features

- Primary interrupt for every class, with spec overrides (e.g. Hunter BM/SV → Muzzle)
- Secondary abilities where relevant: Death Knight **Death Grip**, Balance Druid **Solar Beam**
- Party rows with class-colored names and cooldown-sweep icons **or** horizontal progress bars with countdown text — pick whichever you prefer
- Late-join sync: joining mid-pull shows remaining cooldowns immediately (whispered SYNC)
- Settings panel with per-spell toggles, scale, lock, and a Fine-tune sub-panel for entering exact numeric values
- Draggable frame with persisted position

## Install

**CurseForge:** search "PartyPulse" in your CurseForge client (pending approval at first release).

**Manual:** download the zip from the latest GitHub Action run's Artifacts — [Actions page](https://github.com/sgurgurich/PartyPulse/actions) — and extract into `World of Warcraft/_retail_/Interface/AddOns/`. The folder must be named exactly `PartyPulse/` with `PartyPulse.toc` at its root.

If the addon doesn't appear in the in-game AddOn list, enable **"Load out of date addons"** (the TOC's `Interface` version may lag the live client).

## Usage

- `/pp` or `/partypulse` — open the settings panel
- All behavior is controlled from settings: show/hide frame, lock, scale, display mode (Icons / Bars), per-spell toggles, fine-tune numeric values

Drag the frame to position it. Position and settings save per character.

## How it works

PartyPulse uses `C_ChatInfo.SendAddonMessage` with prefix `PartyPulse`. Messages are invisible to players and only delivered to other clients running the addon. No data leaves your group.

Wire protocol:
- `HELLO:<class>:<id1,id2,...>` — announce self and tracked spells
- `CD:<spellID>:<seconds>` — your interrupt fired; peers start a sweep/bar
- `SYNC:<id,rem>;<id,rem>;...` — whispered to new arrivals so they see active cooldowns

## ToS / API compliance

PartyPulse only reads **your own** combat events (`UNIT_SPELLCAST_SUCCEEDED` on `player`) and broadcasts them via the standard addon-message API. It does not try to inspect other players' combat state, rotations, or cooldowns — which matches Blizzard's Midnight addon restrictions.

## Contributing

See [CLAUDE.md](CLAUDE.md) for architecture notes, wire-protocol details, and how to add new tracked spells.

## License

MIT — see [LICENSE](LICENSE).
