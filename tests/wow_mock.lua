-- Explicit mock with a hardware-input boundary; not the real WoW security system or renderer.
local function new(saved)
    local W = {time = 0, party = {}, leader = true, combat = false, raid = false,
        sent = {}, kicks = {}, frames = {}, chat = {}, menu = {}}
    CWoWCompanionManagerDB = saved
    SlashCmdList, UISpecialFrames, RAID_CLASS_COLORS = {}, {}, {PRIEST = {r = 1, g = 1, b = 1}}
    UNKNOWN, UNKNOWNOBJECT = "Unknown", "Unknown Object"
    tinsert = table.insert
    local methods = {}
    for _, method in ipairs({"SetFrameStrata", "SetMovable", "SetClampedToScreen", "EnableMouse",
        "RegisterForDrag", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetJustifyH",
        "SetJustifyV", "EnableMouseWheel", "SetTextColor", "StartMoving", "StopMovingOrSizing",
        "RegisterForClicks", "SetTexCoord", "SetHighlightTexture", "SetOwner", "AddLine"}) do
        methods[method] = function() end
    end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetPoint(...) self.point = {...} end
    function methods:GetPoint() return unpack(self.point) end
    function methods:ClearAllPoints() self.point = nil end
    function methods:SetScale(scale) self.scale = scale end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:Enable() self.enabled = true end
    function methods:Disable() self.enabled = false end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:GetFrameLevel() return self.level or 1 end
    function methods:GetEffectiveScale() return self.scale or 1 end
    function methods:GetCenter() return 500, 400 end
    function methods:CreateTexture() return CreateFrame("Texture") end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:SetNormalTexture(texture)
        self.normal = self:CreateTexture(); self.normal:SetTexture(texture)
    end
    function methods:GetNormalTexture() return self.normal end
    function methods:CreateFontString() return CreateFrame("FontString") end
    function CreateFrame(kind, name, parent)
        local frame = setmetatable({kind = kind, name = name, parent = parent, scripts = {},
            events = {}, shown = true, enabled = true}, {__index = methods})
        W.frames[#W.frames + 1] = frame
        if name then _G[name] = frame end
        return frame
    end
    UIParent = CreateFrame("Frame")
    UIParent:SetSize(1024, 768)
    Minimap = CreateFrame("Frame"); Minimap:SetSize(140, 140)
    GameTooltip = CreateFrame("GameTooltip")
    function GetCursorPosition() return W.cursorX or 600, W.cursorY or 400 end
    DEFAULT_CHAT_FRAME = {AddMessage = function(_, s) W.chat[#W.chat + 1] = s end}
    function UIDropDownMenu_SetWidth(frame, width) frame.width = width end
    function UIDropDownMenu_Initialize(frame, fn) frame.initialize = fn end
    function UIDropDownMenu_SetText(frame, text) frame.text = text end
    function UIDropDownMenu_CreateInfo() return {} end
    function UIDropDownMenu_AddButton(item) W.menu[#W.menu + 1] = item end
    function CloseDropDownMenus() end
    function GetTime() return W.time end
    function GetNumPartyMembers() return W.raid and 0 or #W.party end
    function GetNumRaidMembers() return W.raid and #W.party or 0 end
    function IsPartyLeader() return W.leader end
    function InCombatLockdown() return W.combat end
    local player = {name = "Tester", guid = "PLAYER-GUID", class = "Mage", token = "MAGE", connected = true}
    local function member(unit)
        if unit == "player" then return player end
        local index = tonumber(unit:match("%d+$"))
        return index and W.party[index]
    end
    function UnitName(unit) local m = member(unit); return m and m.name end
    function UnitGUID(unit) local m = member(unit); return m and m.guid end
    function UnitClass(unit) local m = member(unit); return m and m.class, m and m.token end
    function UnitIsConnected(unit) local m = member(unit); return m and m.connected end
    function UnitIsUnit(a, b) return UnitGUID(a) ~= nil and UnitGUID(a) == UnitGUID(b) end
    function SendAddonMessage(...)
        if W.sendError then error("mock API error") end
        W.sent[#W.sent + 1] = {...}
    end
    function UninviteUnit(name)
        if not W.hardware then error("UninviteUnit requires a hardware event") end
        if W.kickError then error("mock protected action error") end
        W.kicks[#W.kicks + 1] = name
    end
    for _, file in ipairs({"Shared", "Transport", "Party", "Manager", "UI", "Core"}) do
        dofile("CWoWCompanionManager/" .. file .. ".lua")
    end
    W.C = CWoWCompanionManager
    function W.event(event, ...)
        local f = W.C.events
        local hardware = W.hardware
        W.hardware = false
        f.scripts.OnEvent(f, event, ...)
        W.hardware = hardware
    end
    function W.dismiss(name, guid)
        W.hardware = true
        W.C.Manager.Dismiss(name, guid)
        W.hardware = false
    end
    function W.load()
        W.event("ADDON_LOADED", "CWoWCompanionManager")
        W.event("PLAYER_ENTERING_WORLD")
    end
    function W.advance(seconds)
        W.time = W.time + seconds
        W.C.events.scripts.OnUpdate(W.C.events, seconds)
    end
    function W.reply(opcode, text, id, sender, channel, prefix)
        id = id or assert(W.C.Transport.pending, "no request to reply to").id
        W.event("CHAT_MSG_ADDON", prefix or "AzerothCore", opcode .. id .. (text or ""),
            channel or "WHISPER", sender or "Tester")
    end
    function W.roster(text)
        W.reply("m", "Bot roster: " .. (text or ""))
        W.reply("o")
    end
    function W.lastCommand() return W.sent[#W.sent] and W.sent[#W.sent][2]:sub(6) end
    function W.group(...)
        W.party = {...}
        W.event("PARTY_MEMBERS_CHANGED")
    end
    function W.bot(name, class, guid)
        local info = W.C.classByName[class or "Priest"]
        return {name = name, class = info.name, token = info.token, guid = guid or (name .. "-GUID"), connected = true}
    end
    function W.refresh(text)
        W.C.Manager.Refresh(true)
        W.roster(text)
    end
    return W
end
return new
