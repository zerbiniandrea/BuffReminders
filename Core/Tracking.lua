local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Tracking reminder: the spell to offer is the last tracking spell that the player
-- cast, kept per character, else the first known spell of BR.TRACKING_SPELLS.
-- Only spells of the kinds in defaults.trackingScope count.

local IsPlayerSpellCached = BR.StateHelpers.IsPlayerSpellCached
local Plain = BR.Secret.Plain

local SPELLS = BR.TRACKING_SPELLS

---@type table<number, TrackingSpell>
local BY_ID = {}
-- The choice row takes rank lists, so each spell gets a list of one.
---@type table<number, number[]>
local RANK_LIST = {}
for _, spell in ipairs(SPELLS) do
    BY_ID[spell.spellID] = spell
    RANK_LIST[spell.spellID] = { spell.spellID }
end

---@return table? charDB nil before AceDB loads
local function CharDB()
    return BR.aceDB and BR.aceDB.char
end

---@return "gathering"|"all"
local function Scope()
    local profile = BR.aceDB and BR.aceDB.profile
    local defaults = profile and profile.defaults
    return defaults and defaults.trackingScope or "gathering"
end

---@param spell TrackingSpell
---@return boolean
local function InScope(spell)
    return spell.kind == "gathering" or Scope() == "all"
end

---@param spell TrackingSpell
---@return boolean
local function Castable(spell)
    if not IsPlayerSpellCached(spell.spellID) then
        return false
    end
    return not spell.form or BR.BuffState.GetActiveStance() == spell.form
end

---The spell that the reminder shows and the click casts. nil when the player knows none.
---@return number?
local function Pick()
    local charDB = CharDB()
    local remembered = charDB and BY_ID[charDB.trackingSpell]
    if remembered and InScope(remembered) and IsPlayerSpellCached(remembered.spellID) then
        -- Outside its form, the remembered spell cannot be cast, so no reminder shows.
        return Castable(remembered) and remembered.spellID or nil
    end
    for _, spell in ipairs(SPELLS) do
        if InScope(spell) and Castable(spell) then
            return spell.spellID
        end
    end
    return nil
end

local others = {}

---The other castable tracking spells, as rank lists. The list is reused.
---@param mainSpellID number
---@return number[][]
local function Others(mainSpellID)
    wipe(others)
    for _, spell in ipairs(SPELLS) do
        if spell.spellID ~= mainSpellID and InScope(spell) and Castable(spell) then
            others[#others + 1] = RANK_LIST[spell.spellID]
        end
    end
    return others
end

local eventFrame = CreateFrame("Frame")
BR.Client.RegisterEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    spellID = Plain(spellID)
    local charDB = CharDB()
    local spell = spellID and BY_ID[spellID]
    -- A short swap to a spell outside the scope keeps the remembered choice.
    if charDB and spell and InScope(spell) then
        charDB.trackingSpell = spellID
    end
end)

BR.Tracking = {
    Pick = Pick,
    Others = Others,
}
