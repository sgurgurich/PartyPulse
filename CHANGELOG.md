# Changelog

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
