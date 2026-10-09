# CWoW Companion Manager v0.1.1 — dismissal hotfix (beta)

Fixes the asynchronous party-removal path behind a reported “Interface action failed because of an AddOn” message when dismissing a recruited alt.

- `UninviteUnit` now runs directly within the Dismiss button click, using recent roster evidence and current identity/permission checks.
- If evidence is over 15 seconds old or the party composition changed, the first click only refreshes the roster and asks for another click. Server-response callbacks never uninvite.
- Blocked/forbidden uninvite events stop dismissal without sending deactivation.
- No automatic mutation retries; party removal is still observed before deactivation and final verification.

**Update:** download `CWoWCompanionManager.zip`, replace `Interface/AddOns/CWoWCompanionManager/`, then type `/reload` and `/cwow`. Click Refresh, wait for it to finish, and test Dismiss as party leader outside combat. If asked, click Dismiss again after refreshing.

**Validation:** Lua 5.1 syntax checks and 37 test cases / 246 assertions pass, including explicit hardware-event regression tests. The fix still needs validation in the actual WoW 3.3.5a client; mocks do not establish live compatibility. This remains a prerelease.
