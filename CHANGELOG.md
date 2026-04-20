# Changelog

## v0.15.1

- Wind Shear now tracks a 30s cooldown on Restoration Shaman (base 12s still used for Elemental and Enhancement).

## v0.15.0

- New "Class Colors" subcategory: override the color used for any class individually. Each row has a color picker and a Reset button that restores the PartyPulse default (deeper crimson for Death Knight) or Blizzard default.

## v0.14.1

- Death Knight class color now uses a deeper crimson (#8B1A1E) instead of the brighter Blizzard default. Applies to names, bars, and icon colors.

## v0.14.0

- New defaults tuned from the author's in-game setup: display mode "Icons + Bars", bar width 110, bar height 24, row spacing 1, name font 20, countdown font 10, icon border 2px, icon-to-bar gap 0, and a slightly transparent on-cooldown override.
- About page credit now reads "Created by theirontip".

## v0.13.0

- New primary slash command `/pulse` opens the settings panel. `/pp` and `/partypulse` still work.

## v0.12.1

- Added the logo asset to the addon so the about page renders the image.

## v0.12.0

- PartyPulse tab is now an info/about page with logo, a short description, and a credit to theirontip.
- All settings that used to live on the main tab moved to a new "General" subcategory (Behavior / Frame / Display).

## v0.11.2

- More breathing room between sections inside settings panels.

## v0.11.1

- Section headers inside settings panels are now centered above their underline.

## v0.11.0

- New frame background controls (Colors panel → Frame background section): border thickness (0 hides the border) and inner padding sliders, plus the existing color/transparency pickers.
- "Show frame background" toggle moved from the main panel into the Colors panel alongside its related options.
- Settings reorganized with section headers within each panel. Main panel grouped into Behavior / Frame / Display; Sizing renamed to Layout and grouped into Widget sizes / Spacing / Cooldown offset / Icons mode / Icons + Bars mode; Text grouped into Player name / Spell name / Countdown / Ready state; Colors grouped into Frame background / Bars / Icons / Text.

## v0.10.0

- New "Icon orientation" (Sizing panel) toggles between vertical (default) and horizontal stacking for the Icons-only display mode. Does not apply to Icons + Bars.
- New "Sort order" (main panel): Standard (group order, default), Tank / Healer / DPS, or Healer / Tank / DPS.
- New "Player anchor" (main panel): always pin your own row to the front or back of the list.

## v0.8.2

- New "Ready text color" picker in the Colors panel. Defaults to bright green; only affects the "Ready" text, not the countdown.

## v0.8.1

- Default on-cooldown override color changed to deep navy (#01051e).

## v0.8.0

- New "Show player name when Ready" toggle (on by default) swaps the spell name for the player's name while a bar is off cooldown.
- Ready color now defaults to the owner's class color (new "Ready uses class color" toggle in the Colors panel, on by default).
- On-cooldown color now defaults to dark gray. Class-colored cooldowns are still one toggle away.

## v0.7.0

- New icon borders: toggle "Show icon border", customizable color and thickness (0-6 px).
- New "Show cooldown countdown text" toggle hides the remaining-seconds text on both icons and bars.
- Player-name offset no longer moves the icons/bars. New "Cooldown offset X/Y" sliders position the icon/bar block independently.

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
