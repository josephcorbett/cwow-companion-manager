local C = CWoWCompanionManager
local F = {}
C.Factions = F

local function factionKnown(value)
    return value == "Alliance" or value == "Horde"
end
local function validGUID(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and not value:find("%c")
end
local function validRealm(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and not value:find("%c")
end

-- Account-wide SavedVariables share observations between characters on this
-- client. Realm + name locates an entry; GUID protects against observed name reuse.
function F.Load(saved)
    local cache = {}
    if type(saved) ~= "table" then return cache end
    for realm, characters in pairs(saved) do
        if validRealm(realm) and type(characters) == "table" then
            cache[realm] = {}
            for name, entry in pairs(characters) do
                if C.ValidName(name) and type(entry) == "table" and factionKnown(entry.faction)
                    and validGUID(entry.guid) then
                    cache[realm][C.Key(name)] = {faction = entry.faction, guid = entry.guid}
                end
            end
        end
    end
    return cache
end

function F.Observe(unit)
    if not C.ready or not C.db then return end
    local realm = GetRealmName()
    local name, unitRealm = UnitName(unit)
    local guid = UnitGUID(unit)
    if not validRealm(realm) or not C.ValidName(name) or not validGUID(guid) then return end
    if unitRealm and unitRealm ~= "" and unitRealm ~= realm then return end
    local key = C.Key(name)
    local characters = C.db.factions[realm]
    -- Never keep a previous character's faction after directly observing a new GUID.
    if characters and characters[key] and characters[key].guid ~= guid then characters[key] = nil end
    if unit ~= "player" and not UnitIsConnected(unit) then return end
    local faction = UnitFactionGroup(unit)
    if not factionKnown(faction) then return end
    if not characters then characters = {}; C.db.factions[realm] = characters end
    characters[key] = {faction = faction, guid = guid}
end

function F.Get(name)
    if not C.db then return nil end
    local realm = GetRealmName()
    local characters = realm and C.db.factions[realm]
    local entry = characters and characters[C.Key(name)]
    return entry and entry.faction or nil
end
