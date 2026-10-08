local C = CWoWCompanionManager
local M, P, UI = C.Manager, C.Party, C.UI
local events = CreateFrame("Frame")
C.events = events
local elapsedTotal, localScanAt, refreshAt = 0, 0, nil
local points = {CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}

local function loadPreferences()
    local saved = type(CWoWCompanionManagerDB) == "table" and CWoWCompanionManagerDB or {}
    local db = {tab = saved.tab == "alts" and "alts" or "mercenaries", debug = saved.debug == true}
    local p = saved.position
    if type(p) == "table" and points[p.point] and points[p.relativePoint]
        and type(p.x) == "number" and type(p.y) == "number"
        and math.abs(p.x) < 10000 and math.abs(p.y) < 10000 then
        db.position = {point = p.point, relativePoint = p.relativePoint, x = p.x, y = p.y}
    end
    CWoWCompanionManagerDB, C.db = db, db
    UI.tab = db.tab
end

events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if (...) == "CWoWCompanionManager" then loadPreferences() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C.ready = true
        P.Scan()
        if C.wantRefresh or UI.frame and UI.frame:IsShown() then
            C.wantRefresh = nil
            M.Refresh(true)
        end
        C.Changed()
    elseif event == "PLAYER_LEAVING_WORLD" then
        C.ready, refreshAt = false, nil
        M.ResetWorld()
    elseif event == "CHAT_MSG_ADDON" then C.Transport.Receive(...)
    elseif event == "CHAT_MSG_SYSTEM" then M.SystemMessage(...)
    elseif event == "UI_ERROR_MESSAGE" then
        if M.operation then
            local message = ...
            C.Debug("UI error: " .. tostring(message))
            C.Status(tostring(message), "error")
        end
    elseif event == "DISPLAY_SIZE_CHANGED" then UI.Fit()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        M.OnPartyChange(true)
        refreshAt = GetTime() + 0.4
    else
        M.OnPartyChange(false)
    end
end)
events:SetScript("OnUpdate", function(self, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.2 then return end
    elapsedTotal = 0
    M.Tick()
    -- Legacy clients need local connection/name rechecks. This never sends mutations
    -- by elapsed time alone: uninvite continuation still requires a roster event.
    if C.ready and GetTime() >= localScanAt and (M.Busy() or UI.frame and UI.frame:IsShown()) then
        localScanAt = GetTime() + 1
        M.OnPartyChange(false)
    end
    if refreshAt and C.ready and not M.Busy() and GetTime() >= refreshAt then
        refreshAt = nil
        if UI.frame and UI.frame:IsShown() then M.Refresh(false) end
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "CHAT_MSG_ADDON",
    "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "PARTY_LEADER_CHANGED", "UNIT_NAME_UPDATE", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "DISPLAY_SIZE_CHANGED"}) do
    local ok, err = pcall(events.RegisterEvent, events, event)
    if not ok then C.Debug("Event unavailable: " .. event .. " " .. tostring(err)) end
end
SLASH_CWOWCOMPANIONMANAGER1 = "/cwow"
SlashCmdList.CWOWCOMPANIONMANAGER = function(message)
    local command = C.Trim(message):lower()
    if command == "debug" and C.db then
        C.db.debug = not C.db.debug
        DEFAULT_CHAT_FRAME:AddMessage("CWoW Companion Manager debug " .. (C.db.debug and "enabled." or "disabled."))
    elseif command == "refresh" then M.Refresh(true)
    elseif command == "reset" and C.db then
        C.db.position = nil
        if UI.frame then UI.frame:ClearAllPoints(); UI.frame:SetPoint("CENTER"); UI.Fit() end
    else UI.Toggle() end
end
