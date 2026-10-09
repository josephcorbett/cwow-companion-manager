# Live-client acceptance checklist — v0.1.2 beta

**Partial live feedback:** v0.1.0 successfully recruited an alt but hit a blocked dismissal action. The v0.1.2 fix and full checklist remain to be validated. Passing Lua tests is not a substitute. Use a normal player account as well as any administrator account used for comparison. Record client build, locale, UI scale, addon version, server/module revisions if available, initial party state and the result of each case. Do not include account names, credentials or private connection details in public reports.

## 1. Install and initialize

1. Exit the actual 3.3.5a client and extract the addon ZIP into `Interface/AddOns/`.
2. Confirm the manifest is one directory below AddOns and enable the addon at character selection.
3. Enable `/console scriptErrors 1` for testing. Enter the world: no roster command or bot mutation should be sent merely on login.
4. Open `/cwow`. Verify a compact, readable Warcraft-style window with Active Companions above Mercenaries/Alts. The initial roster request should finish or show a useful timeout.
5. Drag, close, reopen, reload and relog. Confirm window position and selected tab persist, but roster data is re-queried. Test `/cwow reset`.
6. Check typical and small resolutions/UI scales, long names, every class choice, scrolling beyond four roster entries, keyboard Escape and the close button. No clipping or Lua errors should occur. Capture only real game screenshots.

7. Verify the minimap launcher appears without issuing a roster query at login. Left-click to open and close, drag around the rim, and reload to confirm the position persists. A drag must not toggle the window. `/cwow reset` restores its default position. Check icon, tooltip, overlap with other minimap buttons and behavior at different UI scales.

## 2. Transport and roster

1. Enable `/cwow debug`. Open or Refresh; confirm addon whispers and correlated `a/m/o` (or `f`) responses. Ordinary chat must remain untouched.
2. Compare the Alts tab against a manually issued `.playerbots bot list`. Check every name, class and +/- state, including Death Knights, an empty roster where possible, and active characters not currently grouped.
3. Invite an ordinary human into the party. A human absent from the active bot roster must not receive a Dismiss action. Have them whisper roster-like text and greetings: nothing should grant bot identity.
4. Change the group outside the addon: invite/kick a known bot, disconnect a bot, disband, and reload with bots still active. The upper list and connection/group details should follow available state. Missing unit information should block removal rather than identify a replacement.
5. Test disabled/denied server commands or addon-channel unavailability only in an environment where an operator can arrange them. Expect a bounded error/unknown state, never a fake success or automatic mutation retry. Do not change a shared server simply to complete a test.

## 3. Recruitment

1. With party room, select Priest and click Recruit once. Buttons must prevent another operation while pending. An ACK or “Add class priest” alone must not show success.
2. Observe the actual new member and subsequent roster status. Only then should the addon show the character joined. Greeting text must not determine identity.
3. Test another class and Death Knight where the server allows it. Verify class tokens, eligibility/faction/level errors and no assumed names or pool size.
4. Intentionally test an unavailable class. Expected feedback is that the class is currently unavailable, without claiming another user occupies it. Handler OK alongside this text must still show failure.
5. On Alts, Invite a known eligible inactive character. It should activate and join from this single action. The row becomes active and cannot be activated again.
6. Test a controlled activation failure (faction, permissions, capacity or another known restriction). Check that the returned reason is useful and the UI becomes usable after completion/timeout and a deliberate Refresh.
7. Observe a case where activation succeeds but joining does not. The addon should report uncertainty or active-but-ungrouped state. Refresh and inspect before repeating. It must not automatically send another activation or a separate party invite.
8. Test a delayed join, a human joining during recruitment, and—if safely reproducible—two possible same-class bots joining together. The latter must remain uncertain rather than pick a name arbitrarily.
9. Verify a full party, raid, nonleader party and combat block recruitment locally with useful feedback.

## 4. Dismissal and recovery

1. With a known active bot and party leadership, click Refresh, wait for completion, then promptly click Dismiss. No confirmation dialog is expected. `UninviteUnit` must execute on that click without the blocked-addon message.
2. Verify the order: recent roster evidence, one `UninviteUnit` during the click, actual group removal, one Playerbots remove request, then a roster verification query. Wait more than 15 seconds after refreshing and try again: the first click must only refresh and request another click. The response callback must not uninvite. Also test a party composition change between refresh and dismissal.
3. Confirm the character has left the party and is no longer active before accepting the “dismissed” message.
4. Dismiss an active bot already outside the party. There should be no uninvite and exactly one removal request after roster validation.
5. Test ordinary humans, the player character, an inactive roster entry still in a party, and a target whose bot evidence disappears between refresh and clicking Dismiss. No destructive action should execute without active bot evidence.
6. Lose leadership or enter combat between refresh and clicking Dismiss. The action should stop. In raids, removal should be refused.
7. If uninvite fails or cannot be observed, wait for timeout. The addon must not send remove. Refresh before trying again.
8. If deactivation fails after successful uninvite, expect an explicit partial result. Refresh; if the bot is still active outside the group, deliberately Dismiss again. The addon must attempt only deactivation, not repeat the kick.
9. If remove says OK but the roster still says active, or the character rejoins during verification, expect partial/unknown rather than success. No repeated kick should occur.
10. If the bot becomes inactive but an offline group slot remains, the addon may refuse further automatic cleanup. Inspect the identity and use normal group controls; this is a documented safety boundary.

## 5. Lifecycle and final evidence

1. Close the window while an operation is pending; it should still process responses. Reopen without issuing another mutation.
2. Change maps/loading screens during an operation. Pending state should be cancelled, not replayed, and a fresh roster requested when the visible window is ready.
3. Check that delayed/duplicate replies do not complete a newer request or cause repeat actions.
4. Turn debug off; normal operation should be quiet and the setting should persist.
5. Record each case as **passed**, **failed with evidence**, or **not tested**. Note real party state separately from response wording. File sanitized issues and attach real screenshots if available.

After these tests pass on the intended client/server pair, a follow-up release can update validation claims. Until then, keep v0.1.2 marked as a prerelease.
