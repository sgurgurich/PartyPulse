# Changelog

## v0.6.2

- Spell spacing can now go down to -40 (was -4) for tight or overlapping layouts.

## v0.6.1

- Row spacing slider can now go negative (-20 to 40) so bars can truly touch or overlap.

## v0.6.0

- Bars now have separate "ready" and "on-cooldown" fill colors. Ready color defaults to green, on-cooldown color defaults to class color (toggle "Use class color for bars" off to use a custom override).
- New "Invert bar direction" toggle fills bars up during cooldown instead of draining them.
- New "Show Ready text" toggle (on by default) renders customizable idle text inside the bar when the spell is off cooldown.
- Customizable countdown format ("5.3", "5", "5.3s", "5s").

## v0.5.1

- Slider editboxes now reliably prepopulate with the current value when a settings panel opens.

## v0.5.0

- Options menu reorganized into subcategories: Sizing, Text, Colors, Spells. Test mode toggle moved to the top of the main panel.
- Every slider now has an editbox next to it for exact numeric input; the separate "Fine-tune" subcategory has been removed.
- New color pickers: backdrop background/border, bar background, bar fill override, and text color.
- New toggle "Use class color for bars" lets you switch between class-colored bars and a custom override color.
- New sliders: row spacing between members, player-name font size, spell-name font size, countdown font size.
- New toggle "Show spell name on bars".
- Spell spacing can now go negative for tighter layouts; extra row padding removed so the value applies cleanly.

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
