# CWoW Companion Manager v0.1.0 — initial beta

Recruit Mercenaries by class, activate eligible roster characters, and dismiss identified bots from one compact Warcraft-style window. Open with `/cwow`.

- Uses the existing AzerothCore addon command protocol; no custom server module or addon framework.
- All ten WotLK classes, roster refresh, class colors, scrolling and saved window preferences.
- Dismissal verifies bot identity, observes party removal, then deactivates and checks the result.
- Explicit partial/unknown states; no automatic mutation retries.
- Lua 5.1 local tests and deterministic release packaging.

Download **CWoWCompanionManager.zip**, extract into **Interface/AddOns/**, and check that **CWoWCompanionManager/CWoWCompanionManager.toc** is directly underneath it. The `.sha256` asset records the archive checksum.

**Prerelease:** the diagnostic predecessor was live-tested, but the production UI and full workflows still need actual WoW 3.3.5a validation. Tests here mock client APIs. Normal-party, out-of-combat management only; English Playerbots responses; server permissions and Mercenary availability apply. The server roster may include bots beyond owned alts. Unknown human/group identities never receive automatic dismissal.

See the README and `docs/MANUAL_TESTS.md` for usage, recovery instructions and the remaining live tests. No screenshots are included because no real production-addon screenshots are available yet.
