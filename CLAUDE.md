# CLAUDE.md — PartyPulse

Context for an agent picking up work on this addon cold. Keep this file current when architecture changes.

## What this is

A World of Warcraft addon (Midnight / Patch 12.0+) that shows party members' interrupt + select CD cooldowns. Every client tracks **its own** casts via `UNIT_SPELLCAST_SUCCEEDED` and broadcasts over the hidden addon-message channel; peers render what they receive. This is the sanctioned model post-Midnight because Blizzard locked down the APIs that would let one client inspect another's combat state.

Do **not** try to read other players' cooldowns, auras, or combat events directly — it won't work under the Midnight API and would violate the spirit of the restrictions even if a loophole existed.

## File layout

- `PartyPulse.toc` — addon manifest. `Interface: 120000` is a best-guess; bump if the live TOC changes. Includes `X-Curse-Project-ID: 1519200`.
- `Spells.lua` — `ns.INTERRUPTS` (class defaults) and `ns.INTERRUPTS_BY_SPEC` (spec overrides, keyed by global spec ID). `GetInterruptsFor(class, specID)` returns the resolved list. Use `replace = { ... }` in a spec entry to swap out the class default (Hunter BM/SV → Muzzle); otherwise spec entries are appended (Balance Druid → Solar Beam).
- `Comm.lua` — thin wrapper around `C_ChatInfo.SendAddonMessage`. Prefix `PartyPulse`. PARTY/RAID auto-select. `SendWhisper` for targeted messages (used for late-join sync).
- `UI.lua` — all rendering. Container frame (draggable, backdrop), one row per party member. Each row has multiple widgets: **icon widget** (cooldown-sweep texture) or **bar widget** (StatusBar with OnUpdate-driven countdown). `ns.ui.SetMember(name, class, spells)`, `ns.ui.TriggerCD(name, spellID, cd)`, `ns.ui.RebuildAll()` (called on display-mode change). Member data cached in `memberData[name]` so mode swaps keep active CDs.
- `Config.lua` — Blizzard Settings API registration. Main category has: show/lock checkboxes, display-mode dropdown, scale slider, per-spell toggles. `RegisterCanvasLayoutSubcategory` adds a "Fine-tune" sub-panel with an EditBox for exact numeric input (slider's steppers complement the EditBox).
- `Core.lua` — event loop + slash commands. Owns `playerClass`, `playerFullName`, `playerSpecID`, `localActive[spellID]` (for late-join sync). Sends HELLO/CD, handles HELLO/CD/SYNC. `/pp` opens the settings panel (there is no toggle slash — visibility is a setting).

## Wire protocol

All messages use prefix `PartyPulse` on PARTY/RAID (broadcast) or WHISPER (targeted).

- `HELLO:<CLASS>:<id1,id2,...>` — announce self and tracked spell IDs. Broadcast on login, roster change, entering world, spec change, spell toggle change.
- `CD:<spellID>:<seconds>` — own interrupt fired; receivers start a sweep/bar on the matching icon.
- `SYNC:<id,rem>;<id,rem>;...` — whispered to a new arrival after their HELLO; tells them which of our spells are still on cooldown and how long is left.

Receivers decode spell IDs and look up CDs from their own tables (`Spells.lua`) because the sender doesn't transmit CDs. Unknown spell IDs still render but without a proper sweep — both ends must be on a compatible version for unfamiliar IDs.

## Adding a tracked spell

1. If it's class-wide, append to the class's list in `ns.INTERRUPTS`.
2. If it's spec-specific and *adds* to the class default, append the entry to `ns.INTERRUPTS_BY_SPEC[<specID>]`.
3. If it's spec-specific and *replaces* the class default (e.g. Muzzle for Hunter BM/SV), use `[<specID>] = { replace = { { id = ..., cd = ... } } }`.
4. No other changes required — UI picks up new spells automatically. Both players must update to see unfamiliar IDs render correctly.

Spec IDs: see [Warcraft Wiki spec ID list](https://warcraft.wiki.gg/wiki/SpecializationID).

## Display modes

Controlled by `PartyPulseDB.displayMode` (`"icons"` | `"bars"`). Switching calls `ns.ui.RebuildAll()` which wipes rows and reconstructs from `memberData`. Widgets are created via `CreateWidget(parent)` which dispatches on `DisplayMode()`. Both widget types implement `:SetSpell(id)` and `:Trigger(cd)` — the rest of the rendering code is mode-agnostic.

Bars are OnUpdate-driven (`StatusBar` with a 0..1 range). OnUpdate stops itself when `remaining <= 0`. Keep widget count bounded (party is ≤5) so OnUpdate load is negligible.

## Saved variables

`PartyPulseDB` (per character) holds:
- `pos` — `{ point, relPoint, x, y }`
- `shown`, `locked`, `scale`, `displayMode`
- `spell_<spellID>` — per-spell enable flag (defaults `true`)

Defaults live in `Config.lua` `DEFAULTS` and are back-filled in `EnsureDefaults()`.

## Distribution

- **Source of truth:** GitHub (`sgurgurich/PartyPulse`)
- **Workflow:** `.github/workflows/release.yml` runs on tag push (`v*`) or `workflow_dispatch`. Uses `BigWigsMods/packager@v2` which reads `.pkgmeta` and publishes to CurseForge via `CF_API_KEY` secret, and attaches the addon zip to the auto-created GitHub Release on annotated-tag pushes.
- **CurseForge project ID:** 1519200 (set via `X-Curse-Project-ID` in the TOC).
- **Wago:** not set up yet. Add `X-Wago-ID` TOC line and `WAGO_API_TOKEN` secret when ready.
- **GitHub releases:** packager auto-creates them only for annotated tags. Use `git tag -a vX.Y.Z -m "..."`, not lightweight tags.

Test a build without tagging: `gh workflow run release.yml --ref main` will run the packager and upload to CurseForge, but no GitHub Release (and therefore no downloadable zip outside CF) is produced for non-tag runs. To get a local zip from a dispatch run, re-add an `actions/upload-artifact` step temporarily.

## Local install after a release

Stefan's WoW install is at `E:\Blizzard Games\World of Warcraft\_retail_\Interface\addons` (writable, no admin needed). After pushing a tagged release and confirming the workflow run succeeded, install the new build into that folder so the addon is ready in-game:

1. Wait for the release workflow to finish: `gh run watch <run-id>` (or poll `gh run list --workflow=release.yml --limit 1`).
2. Download the zip from the GitHub Release: `gh release download <tag> -p 'PartyPulse-*.zip' -D /tmp/pp` (use a temp dir).
3. Remove the existing addon folder: `rm -rf "E:/Blizzard Games/World of Warcraft/_retail_/Interface/addons/PartyPulse"`.
4. Unzip into the addons directory: `unzip -o /tmp/pp/PartyPulse-*.zip -d "E:/Blizzard Games/World of Warcraft/_retail_/Interface/addons"`.

The packager's zip already contains a top-level `PartyPulse/` folder, so step 4 lands files in the right place. Stefan needs to `/reload` (or relaunch WoW) to pick up the new build.

## In-game install / testing

1. Extract the packaged zip into `World of Warcraft/_retail_/Interface/AddOns/`. Folder must be named exactly `PartyPulse/` with `PartyPulse.toc` at its root.
2. Enable "Load out of date addons" in the AddOn list if the TOC's `Interface` number doesn't match the live client.
3. `/console scriptErrors 1` to see Lua errors.
4. Real testing requires at least two players with the addon installed in the same party/raid.

## Gotchas to remember

- Lightweight git tags do not create GitHub releases via the packager. Use annotated tags.
- CHAT_MSG_ADDON sender format is `Name-Realm`. `UnitName("player")` returns just `Name`. Normalize to `Name-Realm` everywhere (see `GetPlayerFullName`).
- The Settings panel caches registered settings; spec-specific spell toggles are registered from the player's *current* spec at login. `/reload` after a respec to refresh the toggle list. (Toggle *behavior* still applies instantly; it's just the panel's checkbox list that's static.)
- `C_ChatInfo.RegisterAddonMessagePrefix` must be called before any send/receive; done in `comm.Init()` on PLAYER_LOGIN.
- Private addon channels inside instances were removed in Midnight; stick to the public PARTY/RAID/WHISPER channels, which still work and remain invisible to players.
- New CurseForge projects require manual approval before appearing in listings or the CurseForge client. Uploads via the API succeed during that window regardless.

## What's intentionally not here

- No automated decision-making (no "cast X now" prompts, no auto-interrupt assignments). Blizzard restricts this, and the philosophy is display-only.
- No inference of other players' cooldowns from combat logs or unit auras. Self-report is the only channel.
- No unit tests / CI for Lua — addon code is tested in-game. Don't add a fake Lua test harness.
