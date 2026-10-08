local C = CWoWCompanionManager
local T = {serial = math.random(1000, 8999), used = {}}
C.Transport = T

-- Exactly one request on the wire. The manager also serializes gameplay operations.
function T.Send(command, onMessage, onDone)
    if T.pending then return false, "Another request is still pending." end
    if not C.ready or not C.ValidName(UnitName("player")) then return false, "Wait until the world has loaded." end
    if type(command) ~= "string" or #command > 238 or command:find("[%c]") then
        return false, "Invalid command."
    end
    T.serial = (T.serial + 1) % 10000
    local id = string.format("%04d", T.serial)
    -- Never reuse a counter within one UI session, even after timeout.
    if T.used[id] then return false, "Request identifiers exhausted; reload the UI." end
    T.used[id] = true
    local request = {id = id, deadline = GetTime() + 10, onMessage = onMessage, onDone = onDone}
    T.pending = request
    C.Debug("TX #" .. id .. " " .. command)
    local ok, err = pcall(SendAddonMessage, "AzerothCore", "i" .. id .. command, "WHISPER", UnitName("player"))
    if not ok then
        T.pending = nil
        C.Debug("SendAddonMessage: " .. tostring(err))
        return false, "The client could not send the request."
    end
    return true
end

function T.Receive(prefix, payload, channel, sender)
    local r = T.pending
    if not r or prefix ~= "AzerothCore" or channel ~= "WHISPER"
        or C.Key(sender) ~= C.Key(UnitName("player")) or type(payload) ~= "string" then return end
    local opcode, id, body = payload:match("^([aomf])(%d%d%d%d)(.*)$")
    if id ~= r.id then return end
    if opcode ~= "m" and body:gsub("%z", "") ~= "" then return end
    if GetTime() >= r.deadline then T.Tick(); return end
    C.Debug("RX #" .. id .. " " .. opcode .. " " .. body)
    if opcode == "a" then r.ack = true
    elseif opcode == "m" then r.onMessage(body)
    else
        T.pending = nil
        r.onDone(opcode == "o" and "ok" or "failed")
    end
end

function T.Tick()
    local r = T.pending
    if r and GetTime() >= r.deadline then
        T.pending = nil
        C.Debug("Timeout #" .. r.id)
        r.onDone("timeout")
    end
end
function T.Cancel() T.pending = nil end
