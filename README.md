# CWoW Companion Manager

A small companion-management addon for **World of Warcraft 3.3.5a (interface 30300)** on compatible **AzerothCore WotLK + mod-playerbots** servers.

Recruit a Mercenary by class, activate an existing character from the server roster, and dismiss identified bots from one Active Companions list. The addon uses AzerothCore's existing addon-message command channel; it requires no custom server module or external addon framework.

**v0.1.0 is an initial beta.** Its diagnostic predecessor's transport, roster parsing, bot removal and party APIs were reported as successfully tested in game. The production UI, complete recruitment/dismissal workflows, and behavior on other server revisions still need the [manual test checklist](docs/MANUAL_TESTS.md). Local tests use mocks and do not establish gameplay compatibility. Real screenshots will be added after in-game validation.

## Features

- A movable 800 × 450 window using Blizzard textures and buttons, gold accents and class colors, with automatic scaling to smaller UI areas.
- Mercenary recruitment for Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock and Druid.
- An Alts tab with roster status and one-step Invite for inactive entries.
- A unified, scrollable Active Companions list, including disconnected bots and active bots outside the party.
- One-click dismissal: verify the bot, remove it from the party, observe removal, deactivate it, then verify the result.
- Roster refresh when opening, after relevant group changes while open, and during operation verification; manual Refresh is always available when idle.
- Clear pending, success, error and uncertain-result feedback, with optional debug output.
- Saved window position and selected tab; no persistent roster or bot-identity cache.

## Requirements

- A WoW 3.3.5a client using interface `30300` and its legacy Lua APIs.
- An AzerothCore server with the existing `AzerothCore` addon command handler enabled and reachable via addon whispers to the player.
- A compatible `mod-playerbots` installation exposing `playerbots bot list`, `add`, `addclass`, and `remove`.
- Server permission and configuration allowing the requested operation. For example, account bots and class recruitment may be restricted by server configuration. The server must already have an eligible Mercenary pool.
- Normal-party leadership for recruitment into an existing party or uninviting a companion. This beta deliberately disables mutations in combat and raids.

The addon never creates characters, manages the server pool, changes server configuration or touches a database. Faction, level, ownership and availability rules remain server-controlled. No specific pool size or bot names are assumed.

## Installation

1. Download **`CWoWCompanionManager.zip`** from the [v0.1.0 prerelease](https://github.com/josephcorbett/cwow-companion-manager/releases/tag/v0.1.0) or a newer compatible release. Use the addon asset rather than GitHub's automatic “Source code” archive.
2. Exit WoW and extract the ZIP into the client's `Interface/AddOns/` directory.
3. Check that the manifest is directly at:

   ```text
   Interface/AddOns/CWoWCompanionManager/CWoWCompanionManager.toc
   ```

4. Start WoW, enable **CWoW Companion Manager** in the AddOns menu at character selection, log in, and type **`/cwow`**.

For Linux/Wine, use the directory containing the `Wow.exe` your Wine/Lutris/Bottles launcher actually runs. Linux filenames are case-sensitive. Do not install into a Retail client or introduce another directory above `CWoWCompanionManager`. Restart the client after first installation; `/reload` is enough for subsequent source updates.

The release contains the manifest and `Shared.lua`, `Transport.lua`, `Party.lua`, `Manager.lua`, `UI.lua`, and `Core.lua`, plus documentation and the MIT license. Only preferences are saved in `CWoWCompanionManagerDB`.

## Usage

**Open and position:** type `/cwow`, drag the window background, and close it with Escape or the close button. Position and recruitment tab survive reloads. `/cwow reset` centers the window if necessary. A minimap button is intentionally omitted.

**Recruit a Mercenary:** select the Mercenaries tab, choose a class, and click Recruit once. Wait for the result. The server chooses the character; unavailable-class feedback does not imply that another player is necessarily using it.

**Recruit an Alt:** select Alts, refresh if needed, then click Invite next to an inactive character. Activation already includes the server's party invitation; there is no second invitation action. “Active - not grouped” means the server reports the bot active but the local party does not contain it. You can inspect or dismiss it from the upper list rather than activating it again.

**Dismiss:** click Dismiss next to an identified active bot. There is no confirmation dialog. The addon first re-queries the roster, validates identity and group permissions, and then uninvites if necessary. It sends `remove` only after observing a group change and verifying the target's absence. An already ungrouped active bot goes directly to deactivation after validation.

**Recover from an uncertain or partial result:** read the status message, click Refresh, and inspect both the game party and addon roster before trying again. If uninvite succeeded but deactivation failed, the bot can appear as active outside the party; a new deliberate Dismiss attempts only the remaining deactivation. No uncertain mutation is retried automatically. If a character is no longer reported as an active bot but still occupies a group slot, use normal game group controls after checking its identity; this beta will not guess that it is safe to kick.

**Refresh and debug:** the Refresh button or `/cwow refresh` issues a read-only roster query when idle. `/cwow debug` toggles protocol diagnostics in the normal chat frame, off by default. The preference is saved. Debug may show character names and server messages; review logs before sharing them. Normal use is quiet, and the addon never filters the game's normal chat output.

## Bot identity and roster ambiguity

The Playerbots roster is not a guaranteed account-character inventory. It can include controlled bots and some grouped random bots. The Alts tab therefore labels server status without claiming ownership; the server decides which inactive entries can be activated.

Ordinary party members are not automatically treated as companions. A fresh correlated roster response must report a target active (`+`) before dismissal may execute. A grouped target must also have a resolvable matching GUID. Inactive entries, arbitrary whispers, greetings, class matches alone, and stale recruitment history never authorize a kick. Unmanaged group members are counted in a small note rather than given Dismiss buttons. Missing or malformed roster data disables destructive controls until refresh.

Recruitment attribution requires the expected Playerbots response, a subsequent active roster entry, and the newly observed party member. For Mercenaries the candidate must match the selected class, be newly active relative to preflight, and be the only matching new candidate. Concurrent ambiguous joins produce an uncertain result rather than an invented identity.

## Technical architecture

`Shared.lua` contains validation, class tokens and the roster parser adapted from CWoWBotDiagnostics. `Transport.lua` implements its proven protocol framing: `SendAddonMessage("AzerothCore", "i" .. fourDigitID .. command, "WHISPER", UnitName("player"))`. Commands contain no leading dot. Responses arrive through `CHAT_MSG_ADDON` as `a` (ACK), `m` (text), `o` (handler OK), or `f` (handler failure). Prefix, ID, channel and sender must match. Counters are not reused within a UI session.

`Party.lua` reads the legacy `GetNumPartyMembers`, `GetNumRaidMembers`, and `Unit*` APIs. `Manager.lua` serializes requests and gameplay operations. `UI.lua` uses legacy Blizzard frames/dropdown templates; `Core.lua` owns events, slash commands and preference initialization. No command is sent on addon load. Opening before entering the world defers the roster query until the player is ready.

ACK and handler OK never directly become gameplay success. Expected command text is required, errors take precedence, and post-command roster/group evidence completes an operation. Requests time out after 10 seconds; a completed recruitment command gets up to 15 seconds to observe the join; uninvite gets 8 seconds for a verifiable group event. These are failure/unknown deadlines, not evidence of success. Safe roster reads can follow events; mutations are never retried or sent through a fallback transport. Leaving the world cancels pending state instead of replaying it on arrival.

Reference implementations: [AzerothCore addon command handler](https://github.com/mod-playerbots/azerothcore-wotlk/blob/7f12e89ee5f467a50e62eba1d525eac7dc953d03/src/server/game/Chat/Chat.cpp), [Playerbots command/roster semantics](https://github.com/mod-playerbots/mod-playerbots/blob/7bae1b5c58c76a0aa20381155edc08096d1485b2/src/Bot/PlayerbotMgr.cpp), and [historical 3.3.5 Blizzard UI sources](https://github.com/tekkub/wow-ui-source/tree/3.3.5/FrameXML). These are reference revisions, not a promise that every fork implements the same protocol or output.

## Limitations

- No battleground bot management, character creation, equipment, talents, AI controls, quest automation or pool administration.
- Normal parties and out-of-combat management only in this beta. No automatic party-to-raid conversion. Local party capacity is checked before recruitment.
- English Playerbots response grammar. Both `DeathKnight` and `Death Knight` roster spellings are supported; recruitment uses `dk`. Unknown classes, duplicate names, malformed entries and multiple roster fragments are rejected. A syntactically valid but truncated roster may be incomplete; absence alone never identifies a bot.
- Source ownership is not exposed reliably by the existing roster. The addon intentionally cannot offer destructive controls for every unknown or offline group slot.
- Very late replies remain uncertain; refreshing cannot guarantee that a delayed mutation will never finish later. Inspect actual state before repeating any action. Other bot-control addons or manual commands can interfere with attribution and should be disabled during initial testing.
- A correlated response is not cryptographic authentication. Other addons in the same client share the Lua environment and could forge events or collide with request identifiers.
- Names are validated as single tokens up to 48 bytes. Realm suffixes, punctuation, whitespace, digits and bulk selectors are rejected. Unicode bytes are preserved, but Lua 5.1 lowercase comparison does not fully case-fold international names.
- UI rendering, resolution/font fit, secure-action behavior, real network timing and complete gameplay workflows remain unverified in the production addon. No mock-generated screenshots are presented as game screenshots.

## Development and contributing

From the repository root, use Lua 5.1 and Python 3:

```bash
lua5.1 tests/run.lua
luac5.1 -p CWoWCompanionManager/*.lua tests/*.lua
python3 scripts/package.py
```

If your Lua 5.1 binaries are named `lua` and `luac`, use those names. The packaging command writes `dist/CWoWCompanionManager.zip` and its SHA-256 checksum with a single top-level addon folder. Generated archives are release assets, not source commits.

Tests cover parsing, command framing/correlation, initialization, recruitment transitions and failures, event ordering, one-click dismissal sequencing, partial recovery, stale identities, humans/self-targets, group restrictions, UI wiring, preferences and list bounds. The test environment is deliberately mocked; complete [MANUAL_TESTS.md](docs/MANUAL_TESTS.md) on a real 3.3.5a client before calling the beta validated.

Bug reports should include addon version, client build/locale, server revision when known, reproduction steps, expected/actual state and sanitized debug output. Keep changes compatible with Lua 5.1, add regression tests for behavior changes, and avoid submitting SavedVariables, account details, credentials or server database data.

## License

[MIT](LICENSE). Blizzard UI assets are referenced from the installed game and are not redistributed in this repository.
