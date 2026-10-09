# CWoW Companion Manager v0.1.2 — minimap launcher (beta)

- Left-click the new minimap button to open or close Companion Manager.
- Drag it around the minimap rim; position is saved between sessions.
- `/cwow reset` restores the window and launcher positions.
- No dependencies or action-bar slot required.

Dismissal keeps the v0.1.1 flow: uninvite first, observe party removal, then deactivate. The proposed reversed two-click flow is not included.

**Update:** download `CWoWCompanionManager.zip`, replace `Interface/AddOns/CWoWCompanionManager/`, then type `/reload`. Look for the launcher near the lower-left edge of the minimap. `/cwow` still works.

**Validation:** Lua 5.1 syntax checks and 39 test cases / 264 assertions passed, including launcher click/drag/persistence checks and the existing dismissal regressions. Actual client rendering and gameplay still require in-game validation; this remains a prerelease.
