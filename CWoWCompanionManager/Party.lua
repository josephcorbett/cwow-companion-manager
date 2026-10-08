local C = CWoWCompanionManager
local P = {members = {}, complete = false, revision = 0, eventSerial = 0}
C.Party = P

function P.Scan(fromRosterEvent)
    if fromRosterEvent then P.eventSerial = P.eventSerial + 1 end
    local members, complete, signature = {}, true, {}
    local raid, count = GetNumRaidMembers() > 0, GetNumPartyMembers()
    if raid then count = GetNumRaidMembers() end
    for i = 1, count do
        local unit = (raid and "raid" or "party") .. i
        if not UnitIsUnit(unit, "player") then
            local name, guid = UnitName(unit), UnitGUID(unit)
            if not C.ValidName(name) or not guid or name == UNKNOWNOBJECT or name == UNKNOWN then
                complete = false
            else
                local class, token = UnitClass(unit)
                local key = C.Key(name)
                if members[key] then complete = false end
                members[key] = {key = key, name = name, guid = guid, class = class, token = token,
                    connected = UnitIsConnected(unit) and true or false}
                signature[#signature + 1] = key .. ":" .. guid .. ":" .. tostring(token)
            end
        end
    end
    table.sort(signature)
    local stamp = table.concat(signature, ";") .. tostring(complete) .. tostring(raid)
    if stamp ~= P.signature then P.revision = P.revision + 1; P.signature = stamp end
    P.members, P.complete, P.raid, P.count = members, complete, raid, count
end

function P.RecruitReason()
    if P.raid then return "Recruitment is limited to normal parties in this beta." end
    if not P.complete then return "Party information is still loading. Try Refresh." end
    if P.count >= 4 then return "Your party is full." end
    if P.count > 0 and not IsPartyLeader() then return "You must be party leader to recruit a companion." end
    if InCombatLockdown() then return "Leave combat before managing companions." end
end
function P.DismissReason(name, expectedGUID)
    if not C.ValidName(name) or C.Key(name) == C.Key(UnitName("player")) then return "Cannot dismiss the player character." end
    if P.raid then return "Dismissal is limited to normal parties in this beta." end
    if not P.complete then return "Party information is still loading. Try Refresh." end
    if InCombatLockdown() then return "Leave combat before managing companions." end
    local member = P.members[C.Key(name)]
    if member then
        if expectedGUID and member.guid ~= expectedGUID then return "The selected character's identity changed. Refresh first." end
        if not IsPartyLeader() then return "You must be party leader to dismiss this companion." end
    end
end
function P.ContainsGUID(guid)
    for _, member in pairs(P.members) do if guid and member.guid == guid then return true end end
    return false
end
