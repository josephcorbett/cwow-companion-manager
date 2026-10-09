# CWoW Companion Manager v0.1.3 — remembered faction (beta)

- Learn a character's Alliance/Horde faction when you log into it with the addon enabled, even with the window closed.
- Also learn faction from connected party units that match the Playerbots roster.
- Share observations between characters on the same local WoW account, separated by realm; update values from direct observations and guard observed name reuse with GUIDs.
- Show Alliance, Horde or Faction unknown in the Active Companions and Alts lists.
- No added server queries, faction guesses from failed joins, or changes to dismissal order or invitation eligibility.

**Update:** exit WoW, replace `Interface/AddOns/CWoWCompanionManager/` using `CWoWCompanionManager.zip` (including its new `Factions.lua`), then restart. Log into an opposite-faction alt once with the addon enabled, log out normally, and return to your main to see its cached faction.

**Validation:** Lua 5.1 syntax checks and 46 cases / 299 assertions passed, including cross-character persistence, realm isolation, party learning, missing data and identity changes. Prior minimap and dismissal functionality was confirmed in game by the project owner; this new faction-cache feature and column layout still require live validation. This remains a prerelease.
