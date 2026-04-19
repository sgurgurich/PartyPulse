# Changelog

## v0.4.1

- Test mode now respects the per-spell enable toggles (e.g. disabling Death Grip hides it on TestDK too).
- One-time migration flips Death Grip to off on characters that had it enabled from earlier versions.

## v0.4.0

- New "Test mode" toggle simulates 4 party members (Death Knight, Mage, Shaman, Druid) with randomized cooldowns every ~2.5s for previewing layouts.
- Sliders for icon size, bar width, bar height, and spell spacing.
- Sliders for player-name X/Y offset (precise name positioning).

## v0.3.0

- Bars are now colored by the class of the player whose cooldown they represent.
- Player name is hidden by default; new "Show player name" toggle and "Player name position" dropdown (Left of cooldowns / Above cooldowns) under Settings.

## v0.2.1

- Death Grip is now off by default in the spell list (still toggleable).
- New "Show frame background" option (off by default) to hide the dark backdrop and border.
- Bar texture switched to a clean flat texture.
- Workflow now attaches the addon zip directly to the GitHub Release on tag pushes.
- CLAUDE.md is no longer bundled into the addon zip.

## v0.2.0

- New "Icons + Bars" display mode showing both an icon sweep and a bar per spell.
- "Bars" mode now shows pure bars with the spell name on the bar (no leading icon).
- Settings panel now lists every tracked spell across all classes and specs, grouped by class, so you can disable any spell you don't want to see.
- Disabling a spell now also hides it on party members (receive-side filtering on HELLO/CD/SYNC).
- Toggling spells refreshes all rows immediately without `/reload`.

## v0.1.0

- Initial release.
- Per-class / per-spec interrupt tracking with self-report protocol (Midnight-compatible).
- Death Knight Death Grip and Balance Druid Solar Beam included alongside primary interrupts.
- Party member rows with class-colored name + icon cooldown sweeps.
- Late-join cooldown sync via whispered SYNC message.
- SavedVariables persistence for frame position and visibility.
- Settings panel: lock frame, scale, per-spell tracking toggles.
- Slash commands: `/pp` toggles the frame, `/pp config` opens settings.
