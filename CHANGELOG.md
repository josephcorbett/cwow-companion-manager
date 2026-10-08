# Changelog

## v0.1.0 — 2026-10-08 (beta)

- Add a compact, movable Warcraft-style window with saved position and recruitment tab.
- Recruit available Mercenaries from all ten WotLK classes, including the server's `dk` command token.
- Display and activate eligible entries from the Playerbots roster without claiming account ownership.
- Show one Active Companions list with grouped, disconnected and active-but-ungrouped states.
- Use AzerothCore's existing addon command channel with four-digit request correlation.
- Verify recruitment using response text, party membership and a subsequent roster query.
- Combine verified party removal and bot deactivation in a single Dismiss action.
- Revalidate bot evidence, membership, GUID, leadership and combat state before dismissal.
- Expose partial failures and require a deliberate refresh after uncertain mutations; do not replay commands.
- Include Lua 5.1 tests, a deterministic packaging script and a live-client checklist.

The diagnostic predecessor's protocol and basic game operations were reported as live-tested by the project owner. This production window and its complete workflows still require in-game validation. No production screenshots or gameplay verification are claimed.
