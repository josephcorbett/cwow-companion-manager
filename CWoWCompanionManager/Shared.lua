CWoWCompanionManager = {version = "0.1.1"}
local C = CWoWCompanionManager
C.classes = {
    {name = "Warrior", token = "WARRIOR", command = "warrior"},
    {name = "Paladin", token = "PALADIN", command = "paladin"},
    {name = "Hunter", token = "HUNTER", command = "hunter"},
    {name = "Rogue", token = "ROGUE", command = "rogue"},
    {name = "Priest", token = "PRIEST", command = "priest"},
    {name = "Death Knight", token = "DEATHKNIGHT", command = "dk"},
    {name = "Shaman", token = "SHAMAN", command = "shaman"},
    {name = "Mage", token = "MAGE", command = "mage"},
    {name = "Warlock", token = "WARLOCK", command = "warlock"},
    {name = "Druid", token = "DRUID", command = "druid"},
}
C.classByName, C.classByCommand = {}, {}
for _, class in ipairs(C.classes) do
    C.classByName[class.name], C.classByCommand[class.command] = class, class
end
C.classByName.DeathKnight = C.classByName["Death Knight"]

function C.Key(name) return type(name) == "string" and name:lower() or "" end
function C.Trim(s) return (s or ""):match("^%s*(.-)%s*$") end
-- Adapted from CWoWBotDiagnostics. One name, never a bulk selector or command.
function C.ValidName(name)
    return type(name) == "string" and #name > 0 and #name <= 48
        and not name:find("[%s%c%d%p]")
end
function C.Plain(s)
    -- Core messages may escape pipes before sending them over the addon channel.
    return (s or ""):gsub("||", "|"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
function C.Safe(s)
    return tostring(s or ""):gsub("|", "||"):gsub("%c", " ")
end
function C.ParseRoster(message)
    local body = C.Plain(message):match("^Bot roster:%s*(.-)%s*$")
    if body == nil then return nil, "No roster was returned." end
    local rows, seen = {}, {}
    -- An empty roster is accepted only within a complete correlated list request.
    if body == "" then return rows end
    for entry in (body .. ","):gmatch("(.-),") do
        local sign, name, className = C.Trim(entry):match("^([+-])(%S+)%s+(.+)$")
        local class = C.classByName[className]
        if not C.ValidName(name) or not class or seen[C.Key(name)] then
            return nil, "The roster contains an ambiguous or unsupported entry."
        end
        seen[C.Key(name)] = true
        rows[#rows + 1] = {name = name, key = C.Key(name), class = class.name,
            token = class.token, active = sign == "+"}
    end
    return rows
end
function C.Reply(message)
    local text = C.Trim(C.Plain(message))
    local action, name, result = text:match("^(%a+): (%S+) %- (.+)$")
    if (action == "add" or action == "remove") and C.ValidName(name) then
        return action, name, result
    end
    local class = text:match("^Add class (%a+)$")
    if class then return "recruit", class end
    if text == "Add class failed, no available characters!" then return "unavailable" end
    return "other", text
end
function C.Debug(message)
    if C.db and C.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100CWoW debug:|r " .. C.Safe(message))
    end
end
function C.Changed() if C.UI then C.UI.Render() end end
function C.Status(message, kind)
    C.status, C.statusKind = message, kind or "info"
    C.Changed()
end
