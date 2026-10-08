local C = CWoWCompanionManager
local T, P = C.Transport, C.Party
local M = {roster = {}, rows = {}, rosterValid = false, recovery = {}}
C.Manager = M

function M.Busy() return M.operation ~= nil or T.pending ~= nil end
function M.ApplyRoster(rows)
    M.rows, M.roster, M.rosterValid = rows, {}, true
    for _, row in ipairs(rows) do
        if row.key ~= C.Key(UnitName("player")) then M.roster[row.key] = row end
    end
    M.rosterTime = GetTime()
    P.Scan()
    if P.complete then
        for key, recovery in pairs(M.recovery) do
            local row = M.roster[key]
            if (not row or not row.active) and not P.members[key] and not P.ContainsGUID(recovery.guid) then
                -- A fresh snapshot can retire a recovery hint without declaring an
                -- earlier command successful or issuing another mutation.
                M.recovery[key] = nil
            end
        end
    end
    C.Changed()
end

function M.ReadRoster(callback)
    local rows, problem, messages, seen = nil, nil, {}, false
    local sent, err = T.Send("playerbots bot list", function(message)
        local text = C.Plain(message)
        if text:match("^Bot roster:") then
            if seen then problem = "Multiple roster fragments were returned; unable to verify the full roster."
            else
                seen = true
                local parsed, parseError = C.ParseRoster(text)
                rows, problem = parsed, parseError
            end
        elseif C.Trim(text) ~= "" then messages[#messages + 1] = text end
    end, function(result)
        if result == "ok" and rows and not problem and #messages == 0 then
            M.ApplyRoster(rows)
            callback(true)
        else
            M.rosterValid = false
            callback(false, problem or messages[1] or (result == "timeout"
                and "The server did not confirm the roster. Try Refresh." or "Unable to read the roster."))
            C.Changed()
        end
    end)
    if not sent then M.rosterValid = false; callback(false, err) end
    C.Changed()
end

function M.Refresh(manual)
    if not C.ready then C.wantRefresh = true; C.Status("Waiting for the world to load..."); return end
    if M.Busy() then return end
    if manual then C.Status("Refreshing companions...") end
    M.ReadRoster(function(ok, err)
        if ok then
            if manual then M.uncertain = false; C.Status("Companion roster updated.") end
        else C.Status(err, "error") end
    end)
end

local function finish(op, text, kind, uncertain)
    if M.operation ~= op then return end
    M.operation = nil
    if uncertain then M.uncertain = true end
    C.Status(text, kind)
end

local function rejectReason()
    if M.Busy() then return "Wait for the current operation to finish." end
    if not C.ready then return "Wait until the world has loaded." end
    if M.uncertain then return "The previous result is uncertain. Refresh and inspect companions before trying again." end
end

local function partial(op, reason)
    local prefix = op.leftParty and (op.name .. " left your party; deactivation is unconfirmed. ") or ""
    M.recovery[op.key] = {name = op.name, key = op.key, guid = op.guid, class = op.class, token = op.token}
    finish(op, prefix .. reason .. " Refresh before trying again.", "error", true)
end

local function mutation(op, command, nextStep)
    op.replyOK, op.error, op.lastText = false, nil, nil
    local sent, err = T.Send(command, function(message)
        if M.operation ~= op then return end
        local kind, name, result = C.Reply(message)
        op.lastText = C.Plain(message)
        if kind == "unavailable" and op.kind == "recruit" then
            op.error = "No " .. op.class .. " mercenary is currently available. Try another class."
        elseif kind == "recruit" and op.kind == "recruit" and name == op.classCommand then
            op.replyOK = true
        elseif (kind == "add" and op.kind == "invite" or kind == "remove" and op.kind == "dismiss")
            and C.Key(name) == op.key then
            if result == "ok" then op.replyOK = true else op.error = op.lastText end
        elseif C.Trim(op.lastText) ~= "" then
            -- Unknown server text is surfaced conservatively, never hidden by handler OK.
            op.error = op.lastText
        end
    end, function(result)
        if M.operation ~= op then return end
        if op.error or op.asyncError or result ~= "ok" then
            local reason = op.error or op.asyncError or (result == "timeout"
                and "Unable to confirm the command result." or "The server rejected the command.")
            if op.kind == "dismiss" then partial(op, reason)
            else finish(op, reason, "error", true) end
            return
        end
        -- No success without the expected Playerbots response text and state verification.
        op.commandDone = true
        nextStep()
    end)
    if not sent then
        if op.kind == "dismiss" then partial(op, err) else finish(op, err, "error", true) end
    end
end

local function joinCandidate(op)
    if not P.complete or P.raid or not M.rosterValid then return end
    if op.kind == "invite" then
        local member, row = P.members[op.key], M.roster[op.key]
        if member and row and row.active and not op.beforeGUIDs[member.guid] then return member end
    else
        local candidate, count = nil, 0
        for key, member in pairs(P.members) do
            local row = M.roster[key]
            if row and row.active and row.token == op.token and member.token == op.token
                and not op.beforeGUIDs[member.guid] and not op.beforeActive[key] then
                candidate, count = member, count + 1
            end
        end
        if count == 1 then return candidate end
        if count > 1 then op.ambiguous = true end
    end
end

function M.VerifyJoin(op)
    if M.operation ~= op or T.pending then return end
    op.phase, op.lastRevision = "verify_join", P.revision
    M.ReadRoster(function(ok, err)
        if M.operation ~= op then return end
        if not ok then finish(op, "Unable to confirm recruitment. " .. err, "error", true); return end
        if op.asyncError then finish(op, op.asyncError, "error", true); return end
        local member = joinCandidate(op)
        if member and op.replyOK then
            finish(op, member.name .. " joined your party.", "success")
        else
            op.phase = "wait_join"
            C.Status(op.kind == "invite" and ("Waiting for " .. op.name .. " to join...")
                or ("Waiting for a " .. op.class .. " mercenary to join..."))
        end
    end)
end

local function recruitAfterPreflight(op)
    P.Scan()
    local reason = P.RecruitReason()
    if reason then finish(op, reason, "error"); return end
    if op.kind == "invite" then
        local row = M.roster[op.key]
        if not row or row.active or P.members[op.key] then
            finish(op, "This character is no longer eligible for Invite. Refresh the roster.", "error"); return
        end
    end
    op.beforeGUIDs, op.beforeActive = {}, {}
    for _, member in pairs(P.members) do op.beforeGUIDs[member.guid] = true end
    for key, row in pairs(M.roster) do if row.active then op.beforeActive[key] = true end end
    op.phase = "recruit_command"
    C.Status(op.kind == "invite" and ("Inviting " .. op.name .. "...") or ("Recruiting " .. op.class .. "..."))
    mutation(op, "playerbots bot " .. (op.kind == "invite" and ("add " .. op.name) or ("addclass " .. op.classCommand)), function()
        op.deadline = GetTime() + 15
        M.VerifyJoin(op)
    end)
end

local function startRecruit(op)
    local reason = rejectReason()
    P.Scan()
    reason = reason or P.RecruitReason()
    if reason then C.Status(reason, "error"); return end
    M.operation = op
    op.phase = "preflight"
    C.Status("Checking companion availability...")
    M.ReadRoster(function(ok, err)
        if M.operation ~= op then return end
        if not ok then finish(op, err, "error"); return end
        recruitAfterPreflight(op)
    end)
end
function M.Recruit(classCommand)
    local class = C.classByCommand[classCommand]
    if not class then return end
    startRecruit({kind = "recruit", class = class.name, token = class.token, classCommand = class.command})
end
function M.Invite(name)
    local key = C.Key(name)
    local row = M.roster[key]
    if not C.ValidName(name) or key == C.Key(UnitName("player")) or not row or row.active then
        C.Status("Select an inactive character from the roster.", "error"); return
    end
    startRecruit({kind = "invite", key = key, name = row.name, class = row.class, token = row.token})
end

local function verifyDismiss(op)
    op.phase = "verify_remove"
    M.ReadRoster(function(ok, err)
        if M.operation ~= op then return end
        if not ok then partial(op, err); return end
        local row = M.roster[op.key]
        if op.replyOK and not op.asyncError and P.complete and not P.members[op.key]
            and not P.ContainsGUID(op.guid) and (not row or not row.active) then
            M.recovery[op.key] = nil
            finish(op, op.name .. " dismissed.", "success")
        else
            partial(op, "Unable to verify dismissal. The character may still be active or grouped.")
        end
    end)
end

local function deactivate(op)
    P.Scan()
    if P.members[op.key] or P.ContainsGUID(op.guid) or not P.complete or P.raid then
        partial(op, "Group membership changed before deactivation."); return
    end
    if InCombatLockdown() then partial(op, "Combat began before deactivation."); return end
    op.phase = "remove_command"
    mutation(op, "playerbots bot remove " .. op.name, function() verifyDismiss(op) end)
end

function M.Dismiss(name, expectedGUID)
    local reason = rejectReason()
    P.Scan()
    reason = reason or P.DismissReason(name, expectedGUID)
    local key = C.Key(name)
    local row = M.roster[key]
    if reason then C.Status(reason, "error"); return end
    if not row or not row.active then C.Status("Bot identity is not established. Refresh the roster.", "error"); return end
    local member = P.members[key]
    local op = {kind = "dismiss", phase = "preflight", name = row.name, key = key,
        class = row.class, token = row.token, guid = member and member.guid or expectedGUID}
    M.operation = op
    C.Status("Dismissing " .. op.name .. "...")
    -- Fresh, correlated '+' evidence is mandatory before any destructive API call.
    M.ReadRoster(function(ok, err)
        if M.operation ~= op then return end
        if not ok then finish(op, err, "error"); return end
        local fresh = M.roster[key]
        if not fresh or not fresh.active then
            finish(op, "This character is not confirmed as an active bot. No dismissal was attempted.", "error"); return
        end
        local blocked = P.DismissReason(op.name, op.guid)
        if blocked then finish(op, blocked, "error"); return end
        local current = P.members[key]
        if current then
            -- An initially ungrouped target joining during preflight is still validated here.
            op.guid = current.guid
            op.phase, op.eventSerial, op.deadline = "uninvite", P.eventSerial, GetTime() + 8
            local success, failure = pcall(UninviteUnit, op.name)
            if not success then
                C.Debug(tostring(failure))
                finish(op, "The client could not remove the companion from the party.", "error", true)
            end
        else
            op.leftParty = true
            deactivate(op)
        end
    end)
end

function M.OnPartyChange(rosterEvent)
    P.Scan(rosterEvent)
    local op = M.operation
    if op and op.phase == "uninvite" and P.eventSerial > op.eventSerial and P.complete
        and not P.members[op.key] and not P.ContainsGUID(op.guid) then
        op.leftParty = true
        deactivate(op)
    elseif op and op.phase == "wait_join" and P.revision ~= op.lastRevision then
        M.VerifyJoin(op)
    end
    C.Changed()
end

function M.SystemMessage(message)
    local op = M.operation
    if not op or op.phase == "preflight" then return end
    local text = C.Plain(message)
    local kind, name, result = C.Reply(text)
    -- Uncorrelated messages can veto success, never establish it or identify a bot.
    if (kind == "add" or kind == "remove") and C.Key(name) == op.key and result ~= "ok"
        or text:match("^Failure:") or text:match("^ERROR:") then
        op.asyncError = text
        if op.phase == "wait_join" then finish(op, text, "error", true) end
    end
end

function M.Tick()
    T.Tick()
    local op = M.operation
    if not op then return end
    if op.phase == "uninvite" and GetTime() >= op.deadline then
        finish(op, "Unable to confirm party removal. No deactivation was sent. Refresh before trying again.", "error", true)
    elseif op.phase == "wait_join" and GetTime() >= op.deadline then
        local row = op.key and M.roster[op.key]
        local text = row and row.active and (op.name .. " is active but not confirmed in your party. Refresh to inspect or dismiss.")
            or "Unable to confirm recruitment. Refresh the roster before trying again."
        if op.ambiguous then text = "Several possible companions joined. Refresh and inspect the roster; recruitment identity is uncertain." end
        finish(op, text, "error", true)
    end
end

function M.ActiveRows()
    local rows, seen = {}, {}
    for key, row in pairs(M.roster) do
        if row.active then
            local member = P.members[key]
            rows[#rows + 1] = {name = row.name, key = key, class = row.class, token = row.token,
                guid = member and member.guid, grouped = member ~= nil,
                detail = not M.rosterValid and "Refresh to verify" or (member
                    and (member.connected and "In party" or "Disconnected") or "Active - not grouped"),
                canDismiss = M.rosterValid}
            seen[key] = true
        end
    end
    for key, recovery in pairs(M.recovery) do
        if not seen[key] then
            rows[#rows + 1] = {name = recovery.name, key = key, class = recovery.class, token = recovery.token,
                guid = recovery.guid, detail = "Unconfirmed - refresh to inspect", canDismiss = false}
        end
    end
    table.sort(rows, function(a, b)
        if a.grouped ~= b.grouped then return a.grouped and true or false end
        return a.name < b.name
    end)
    return rows
end

function M.ResetWorld()
    local wasBusy = M.Busy()
    T.Cancel()
    M.operation, M.roster, M.rows, M.recovery, M.rosterValid = nil, {}, {}, {}, false
    M.uncertain = wasBusy or M.uncertain
    P.members, P.complete = {}, false
    if wasBusy then C.Status("World changed during an operation. Refresh and inspect companions before trying again.", "error") end
end
