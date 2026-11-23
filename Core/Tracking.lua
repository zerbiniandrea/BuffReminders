local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Tracking reminder: the spell to offer is the last tracking spell that the player
-- cast, kept per character, else the first known spell of BR.TRACKING_SPELLS.

local IsPlayerSpellCached = BR.StateHelpers.IsPlayerSpellCached
local Plain = BR.Secret.Plain

local SPELLS = BR.TRACKING_SPELLS

---@type table<number, boolean>
local IS_TRACKING = {}
-- The choice row takes rank lists, so each spell gets a list of one.
---@type table<number, number[]>
local RANK_LIST = {}
for _, id in ipairs(SPELLS) do
    IS_TRACKING[id] = true
    RANK_LIST[id] = { id }
end

---@return table? charDB nil before AceDB loads
local function CharDB()
    return BR.aceDB and BR.aceDB.char
end

---The spell that the reminder shows and the click casts. nil when the player knows none.
---@return number?
local function Pick()
    local charDB = CharDB()
    local remembered = charDB and charDB.trackingSpell
    if remembered and IS_TRACKING[remembered] and IsPlayerSpellCached(remembered) then
        return remembered
    end
    for _, id in ipairs(SPELLS) do
        if IsPlayerSpellCached(id) then
            return id
        end
    end
    return nil
end

local others = {}

---The other known tracking spells, as rank lists. The list is reused.
---@param mainSpellID number
---@return number[][]
local function Others(mainSpellID)
    wipe(others)
    for _, id in ipairs(SPELLS) do
        if id ~= mainSpellID and IsPlayerSpellCached(id) then
            others[#others + 1] = RANK_LIST[id]
        end
    end
    return others
end

local eventFrame = CreateFrame("Frame")
BR.Client.RegisterEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    spellID = Plain(spellID)
    local charDB = CharDB()
    if charDB and spellID and IS_TRACKING[spellID] then
        charDB.trackingSpell = spellID
    end
end)

BR.Tracking = {
    Pick = Pick,
    Others = Others,
}
