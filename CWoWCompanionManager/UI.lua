local C = CWoWCompanionManager
local M, P = C.Manager, C.Party
local UI = {tab = "mercenaries", class = "priest"}
C.UI = UI

local function label(parent, text, x, y, width, template)
    local f = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT", x, y)
    f:SetWidth(width)
    f:SetJustifyH("LEFT")
    f:SetText(text)
    return f
end
local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end
local function enabled(buttonFrame, value)
    if value then buttonFrame:Enable() else buttonFrame:Disable() end
end
local function classColor(font, token)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if color then font:SetTextColor(color.r, color.g, color.b) else font:SetTextColor(0.8, 0.8, 0.8) end
end
local function border(frame)
    frame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
    frame:SetBackdropColor(0.035, 0.03, 0.025, 0.95)
    frame:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.9)
end

-- Four reusable rows with wheel and arrow scrolling keep the window compact.
local function list(parent, y, active)
    local view = CreateFrame("Frame", nil, parent)
    view:SetSize(756, 120)
    view:SetPoint("TOPLEFT", 22, y)
    border(view)
    view.offset, view.rows, view.items = 0, {}, {}
    view.empty = label(view, "", 14, -14, 680)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.items - 4), self.offset - delta))
        UI.Render()
    end)
    view.up = button(view, "^", 723, -8, 25, function()
        view.offset = math.max(0, view.offset - 1); UI.Render()
    end)
    view.down = button(view, "v", 723, -86, 25, function()
        view.offset = math.min(math.max(0, #view.items - 4), view.offset + 1); UI.Render()
    end)
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, view)
        row:SetSize(702, 26)
        row:SetPoint("TOPLEFT", 10, -7 - (i - 1) * 27)
        row.name = label(row, "", 4, -6, 205)
        row.class = label(row, "", 215, -6, 118)
        row.detail = label(row, "", 339, -6, 237)
        row.action = button(row, active and "Dismiss" or "Invite", 589, -1, 105, function()
            local data = row.data
            if not data then return end
            if active then M.Dismiss(data.name, data.guid) else M.Invite(data.name) end
        end)
        view.rows[i] = row
    end
    return view
end

local function renderList(view, items, active)
    view.items = items
    view.offset = math.min(view.offset, math.max(0, #items - 4))
    enabled(view.up, view.offset > 0)
    enabled(view.down, view.offset < #items - 4)
    if #items == 0 then
        view.empty:SetText(active and (M.rosterValid and "No active companions." or "Refresh to identify companions.")
            or (M.rosterValid and "No eligible characters were returned." or "Refresh to load the roster."))
        view.empty:Show()
    else view.empty:Hide() end
    for i, row in ipairs(view.rows) do
        local data = items[i + view.offset]
        row.data = data
        if data then
            row:Show()
            row.name:SetText(C.Safe(data.name))
            row.class:SetText(C.Safe(data.class or "Unknown"))
            classColor(row.name, data.token)
            classColor(row.class, data.token)
            local member = P.members[data.key]
            local detail = data.detail or (not M.rosterValid and "Refresh to verify" or (data.active
                and (member and (member.connected and "Active - in party" or "Active - disconnected") or "Active - not grouped")
                or (member and "Inactive - still grouped" or "Inactive")))
            row.detail:SetText(C.Safe(detail))
            local canAct = not M.Busy() and not M.uncertain and C.ready
            if active then canAct = canAct and data.canDismiss
            else canAct = canAct and M.rosterValid and not data.active and not member end
            enabled(row.action, canAct)
            row.action:SetText(active and "Dismiss" or (data.active and "Active" or "Invite"))
        else row:Hide() end
    end
end

function UI.SelectTab(tab)
    UI.tab = tab == "alts" and "alts" or "mercenaries"
    if C.db then C.db.tab = UI.tab end
    UI.Render()
end

function UI.Fit()
    if not UI.frame then return end
    local scale = math.min(1, (UIParent:GetWidth() - 20) / 800, (UIParent:GetHeight() - 20) / 450)
    UI.frame:SetScale(math.max(0.4, scale))
end

function UI.Create()
    if UI.frame then return end
    local frame = CreateFrame("Frame", "CWoWCompanionManagerFrame", UIParent)
    UI.frame = frame
    frame:SetSize(800, 450)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
        edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}})
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        C.db.position = {point = point, relativePoint = relativePoint, x = x, y = y}
    end)
    UI.Fit()
    local position = C.db.position
    if position then frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else frame:SetPoint("CENTER") end
    local title = label(frame, "CWoW Companion Manager", 25, -22, 710, "GameFontNormalLarge")
    title:SetTextColor(1, 0.82, 0)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)
    label(frame, "Active Companions", 25, -54, 260, "GameFontNormal")
    UI.groupHint = label(frame, "", 276, -56, 370)
    UI.refresh = button(frame, "Refresh", 670, -48, 106, function() M.Refresh(true) end)
    UI.active = list(frame, -78, true)
    label(frame, "Recruit Companions", 25, -211, 400, "GameFontNormal")
    UI.mercTab = button(frame, "Mercenaries", 22, -231, 130, function() UI.SelectTab("mercenaries") end)
    UI.altTab = button(frame, "Alts", 156, -231, 100, function() UI.SelectTab("alts") end)
    UI.tabHint = label(frame, "", 269, -238, 503)
    UI.alts = list(frame, -264, false)
    UI.merc = CreateFrame("Frame", nil, frame)
    UI.merc:SetSize(756, 120)
    UI.merc:SetPoint("TOPLEFT", 22, -264)
    border(UI.merc)
    label(UI.merc, "Choose a class", 20, -17, 230, "GameFontNormal")
    UI.dropdown = CreateFrame("Frame", "CWoWCompanionClassDropdown", UI.merc, "UIDropDownMenuTemplate")
    UI.dropdown:SetPoint("TOPLEFT", 4, -38)
    UIDropDownMenu_SetWidth(UI.dropdown, 200)
    UIDropDownMenu_Initialize(UI.dropdown, function()
        for _, class in ipairs(C.classes) do
            local item = UIDropDownMenu_CreateInfo()
            local command = class.command
            item.text, item.value, item.checked = class.name, command, UI.class == command
            item.func = function()
                UI.class = command
                UIDropDownMenu_SetText(UI.dropdown, class.name)
                CloseDropDownMenus()
                UI.Render()
            end
            UIDropDownMenu_AddButton(item)
        end
    end)
    UI.recruit = button(UI.merc, "Recruit", 250, -39, 130, function() M.Recruit(UI.class) end)
    UI.mercHint = label(UI.merc, "Availability is determined by your server.", 20, -84, 710)
    UI.status = label(frame, "", 25, -400, 746)
    UI.status:SetHeight(36)
    UI.status:SetJustifyV("TOP")
    tinsert(UISpecialFrames, "CWoWCompanionManagerFrame")
    frame:Hide()
end

function UI.Render()
    if not UI.frame then return end
    renderList(UI.active, M.ActiveRows(), true)
    local rows = {}
    for _, row in ipairs(M.rows) do
        if row.key ~= C.Key(UnitName("player")) then rows[#rows + 1] = row end
    end
    renderList(UI.alts, rows, false)
    if UI.tab == "alts" then
        UI.merc:Hide(); UI.alts:Show()
        UI.tabHint:SetText("Server roster; may include bots beyond your own alts.")
    else
        UI.alts:Hide(); UI.merc:Show()
        UI.tabHint:SetText("Recruit an available companion by class.")
    end
    enabled(UI.mercTab, UI.tab ~= "mercenaries")
    enabled(UI.altTab, UI.tab ~= "alts")
    UIDropDownMenu_SetText(UI.dropdown, C.classByCommand[UI.class].name)
    local blocked = P.RecruitReason()
    UI.mercHint:SetText(blocked or "Availability is determined by your server.")
    enabled(UI.recruit, C.ready and not M.Busy() and not M.uncertain and not blocked)
    enabled(UI.refresh, C.ready and not M.Busy())
    local unverified = 0
    for key in pairs(P.members) do
        if not M.rosterValid or not M.roster[key] or not M.roster[key].active then unverified = unverified + 1 end
    end
    UI.groupHint:SetText(not P.complete and "Party information is loading..." or (unverified > 0
        and (unverified .. " other group member(s) not managed") or ""))
    UI.status:SetText(C.Safe(C.status or "Open the window to load your companions."))
    if C.statusKind == "error" then UI.status:SetTextColor(1, 0.45, 0.3)
    elseif C.statusKind == "success" then UI.status:SetTextColor(0.4, 1, 0.5)
    else UI.status:SetTextColor(1, 0.82, 0) end
end

function UI.Toggle()
    if not C.db then return end
    UI.Create()
    if UI.frame:IsShown() then UI.frame:Hide(); return end
    UI.Fit()
    UI.frame:Show()
    P.Scan()
    UI.Render()
    if not M.Busy() then M.Refresh(true) end
end


-- Dependency-free launcher using textures shipped with the 3.3.5a client.
function UI.PositionLauncher()
    local b = UI.launcher
    if not b or not C.db then return end
    local angle = math.rad(C.db.minimapAngle or 225)
    local radius = math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2 + 10
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function UI.CreateLauncher()
    if UI.launcher or not C.db or not Minimap then return end
    local b = CreateFrame("Button", "CWoWCompanionManagerMinimapButton", Minimap)
    UI.launcher = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    b:GetNormalTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
    b:GetNormalTexture():ClearAllPoints()
    b:GetNormalTexture():SetPoint("CENTER", b, "CENTER", 0, 0)
    b:GetNormalTexture():SetSize(21, 21)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnMouseDown", function() b.dragged = nil end)
    b:SetScript("OnClick", function() if not b.dragged then UI.Toggle() end end)
    b:SetScript("OnHide", function() b:SetScript("OnUpdate", nil); b.dragged = nil; GameTooltip:Hide() end)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText("CWoW Companion Manager", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click to open or close.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function()
        b.dragged = true
        GameTooltip:Hide()
        b:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            -- Use the standard Lua math library's radian angle.
            C.db.minimapAngle = math.atan2(y / scale - cy, x / scale - cx) * 180 / math.pi
            UI.PositionLauncher()
        end)
    end)
    b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
    UI.PositionLauncher()
end
