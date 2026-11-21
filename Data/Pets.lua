local _, ns = ...
---@class BR
local BR = ns
local L = BR.L

local IsSpellKnown = C_SpellBook.IsSpellKnown

-- ============================================================================
-- PET HELPERS MODULE
-- ============================================================================
-- Builds per-class lists of pet summon actions for expanded pet icons.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class PetAction
---@field key string
---@field spellID number
---@field spellName string             -- Localized spell name for SecureActionButton casting
---@field icon number
---@field label string
---@field sortOrder number
---@field petFamily? string            -- Pet specialization (hunter only, e.g. "Ferocity")
---@field petSpecIcon? number          -- Spec ability icon texture (hunter only)
---@field petSpiritBeast? boolean      -- True if Spirit Beast family

---@class PetActionList : PetAction[]
---@field genericIndex? number  -- Preferred index for generic (collapsed) display mode

local PET_SPELLS = BR.PET_SPELLS

local CALL_PET_SPELLS = PET_SPELLS.callPet

local REVIVE_PET = 982

-- Hunter pet spec -> ability icon texture
local PET_SPEC_ICONS = {
    Cunning = 348567,
    Ferocity = 136224,
    Tenacity = 571585,
}

local SUMMON_DEMON_FLYOUT = PET_SPELLS.demonFlyout
local SUMMON_FELHUNTER = 691
local SUMMON_FELGUARD = PET_SPELLS.felguard

-- Warlock summon spell ID -> short pet name (fallback: full spell name)
local WARLOCK_PET_NAMES = {
    [688] = L["Label.Imp"],
    [697] = L["Label.Voidwalker"],
    [691] = L["Label.Felhunter"],
    [712] = L["Label.Succubus"],
    [366222] = L["Label.Sayaad"],
    [30146] = L["Label.Felguard"],
}

-- Warlock summon spell ID -> creature family IDs that UnitCreatureFamily reports for
-- the pet. Cosmetic reskins (Wrathguard, Incubus, ...) report their own family.
local WARLOCK_DEMON_FAMILIES = {
    [688] = { [23] = true, [100] = true }, -- Imp
    [697] = { [16] = true, [101] = true }, -- Voidwalker
    [691] = { [15] = true, [103] = true }, -- Felhunter
    [712] = { [17] = true, [302] = true }, -- Succubus
    [366222] = { [17] = true, [102] = true, [302] = true }, -- Sayaad
    [30146] = { [29] = true, [104] = true }, -- Felguard
}

-- Resolve Spirit Beast family name from Blizzard's creature family data (localized)
local GetCreatureFamilyInfo = C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo
local SPIRIT_BEAST_FAMILY = (GetCreatureFamilyInfo and GetCreatureFamilyInfo(46) or {}).name or "Spirit Beast"

local GetStablePetInfo = C_StableInfo and C_StableInfo.GetStablePetInfo

---Build hunter pet actions. With stable slots, each Call Pet spell shows the pet in its
---slot. Without them, each Call Pet spell shows its own name and icon.
---@return PetAction[]?
local function BuildHunterActions()
    -- Marksmanship hunters have no pet without Unbreakable Bond.
    if BR.StateHelpers.GetPlayerSpecId() == 254 and not IsSpellKnown(1223323) then
        return nil
    end

    local canUseExotic = IsSpellKnown(53270) -- Exotic Beasts (BM passive)
    local actions = {}
    local order = 0

    for slotIndex, spellID in ipairs(CALL_PET_SPELLS) do
        local known = IsSpellKnown(spellID)
        if known and not PET_SPELLS.stableSlots then
            local info = C_Spell.GetSpellInfo(spellID)
            if info then
                order = order + 1
                actions[#actions + 1] = {
                    key = "pet_action_" .. spellID,
                    spellID = spellID,
                    spellName = info.name,
                    icon = info.iconID,
                    label = info.name,
                    sortOrder = order,
                }
            end
        elseif known and GetStablePetInfo then
            local info = GetStablePetInfo(slotIndex)
            if info and info.name and info.icon and (not info.isExotic or canUseExotic) then
                order = order + 1
                actions[#actions + 1] = {
                    key = "pet_action_" .. spellID,
                    spellID = spellID,
                    spellName = BR.GetSpellName(spellID),
                    icon = info.icon,
                    label = info.name,
                    sortOrder = order,
                    petFamily = info.specialization,
                    petSpecIcon = PET_SPEC_ICONS[info.specialization],
                    petSpiritBeast = info.familyName == SPIRIT_BEAST_FAMILY or nil,
                }
            end
        end
    end

    if #actions > 0 and IsSpellKnown(REVIVE_PET) then
        order = order + 1
        local icon = C_Spell.GetSpellTexture(REVIVE_PET)
        if icon then
            actions[#actions + 1] = {
                key = "pet_action_" .. REVIVE_PET,
                spellID = REVIVE_PET,
                spellName = BR.GetSpellName(REVIVE_PET),
                icon = icon,
                label = L["Label.RevivePet"],
                sortOrder = order,
            }
        end
    end

    return #actions > 0 and actions or nil
end

---@param actions PetAction[]
---@param spellID number
local function AddDemonAction(actions, spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    if info then
        actions[#actions + 1] = {
            key = "pet_action_" .. spellID,
            spellID = spellID,
            spellName = info.name,
            icon = info.iconID,
            label = WARLOCK_PET_NAMES[spellID] or info.name,
            sortOrder = #actions + 1,
        }
    end
end

---Build warlock pet actions from the Summon Demon flyout, or from the summon spells
---of a client without the flyout.
---@return PetAction[]?
local function BuildWarlockActions()
    local actions = {}

    if SUMMON_DEMON_FLYOUT then
        local ok, _, _, numSlots, isKnown = pcall(GetFlyoutInfo, SUMMON_DEMON_FLYOUT)
        if not ok or not isKnown or not numSlots then
            return nil
        end
        for i = 1, numSlots do
            local slotOk, spellID, _, slotIsKnown = pcall(GetFlyoutSlotInfo, SUMMON_DEMON_FLYOUT, i)
            if slotOk and spellID and slotIsKnown then
                AddDemonAction(actions, spellID)
            end
        end
    else
        for _, spellID in ipairs(PET_SPELLS.demonSummons or {}) do
            if IsSpellKnown(spellID) then
                AddDemonAction(actions, spellID)
            end
        end
    end

    return #actions > 0 and actions or nil
end

---@param actions PetActionList
---@param spellID number
---@return number?
local function IndexOfSpell(actions, spellID)
    for idx, action in ipairs(actions) do
        if action.spellID == spellID then
            return idx
        end
    end
    return nil
end

---@class WarlockDemonChoice
---@field spellID number
---@field key string Saved-variable key in the warlockDemons rows
---@field label string

---@type table<string, WarlockDemonChoice>
local WARLOCK_DEMONS = {
    imp = { spellID = 688, key = "imp", label = L["Label.Imp"] },
    voidwalker = { spellID = 697, key = "voidwalker", label = L["Label.Voidwalker"] },
    felhunter = { spellID = 691, key = "felhunter", label = L["Label.Felhunter"] },
    succubus = { spellID = 712, key = "succubus", label = L["Label.Succubus"] },
    sayaad = { spellID = 366222, key = "sayaad", label = L["Label.Sayaad"] },
}

---@param keys string[]
---@return WarlockDemonChoice[]
local function DemonList(keys)
    local list = {}
    for _, key in ipairs(keys) do
        list[#list + 1] = WARLOCK_DEMONS[key]
    end
    return list
end

-- Demons that the content rows can allow, in grid order.
local WARLOCK_DEMON_CHOICES = DemonList(PET_SPELLS.demonChoices)
-- The click summons the first demon in this order that the row allows and the player knows.
local WARLOCK_DEMON_PREFERENCE = DemonList(PET_SPELLS.demonPreference)

---@return string
local function GetWarlockDemonRow()
    return BR.StateHelpers.GetContentRow()
end

---@param row string
---@param key string
---@return boolean
local function IsWarlockDemonAllowed(row, key)
    return BR.StateHelpers.IsContentChoiceAllowed("warlockDemons", row, key)
end

---Summon spell ID for the current content row: the first demon in preference order
---that the row allows and the player knows, else Felhunter.
---@param actions PetActionList
---@return number
local function GetPreferredDemonSpell(actions)
    local row = GetWarlockDemonRow()
    for _, demon in ipairs(WARLOCK_DEMON_PREFERENCE) do
        if IsWarlockDemonAllowed(row, demon.key) and IndexOfSpell(actions, demon.spellID) then
            return demon.spellID
        end
    end
    return SUMMON_FELHUNTER
end

---Felguard on Demonology overrides the preferred demon. The result is nil when the
---player knows neither the preferred demon nor Felhunter.
---@param actions PetActionList
---@param preferred number
---@return number?
local function ResolveWarlockGenericIndex(actions, preferred)
    if SUMMON_FELGUARD and BR.StateHelpers.GetPlayerSpecId() == 266 then
        local idx = IndexOfSpell(actions, SUMMON_FELGUARD)
        if idx then
            return idx
        end
    end
    return IndexOfSpell(actions, preferred) or IndexOfSpell(actions, SUMMON_FELHUNTER)
end

-- These classes summon one pet with one spell. The name is the short name a
-- player uses. The full spell name is the fallback.
local SINGLE_PET = {
    DEATHKNIGHT = { spellID = 46584, name = L["Label.Ghoul"] }, -- Raise Dead
    MAGE = { spellID = 31687, name = L["Label.WaterElemental"] }, -- Summon Water Elemental
}

local SINGLE_PET_NAMES = {}
for _, pet in pairs(SINGLE_PET) do
    SINGLE_PET_NAMES[pet.spellID] = pet.name
end

---Build a single-action list for a given spell
---@param spellID number
---@return PetAction[]?
local function BuildSingleAction(spellID)
    if not IsSpellKnown(spellID) then
        return nil
    end
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then
        return nil
    end
    return {
        {
            key = "pet_action_" .. spellID,
            spellID = spellID,
            spellName = info.name,
            icon = info.iconID,
            label = SINGLE_PET_NAMES[spellID] or info.name,
            sortOrder = 1,
        },
    }
end

---@type PetActionList?
local cachedActions = nil
local cacheValid = false
local resolvedPreferredPet = nil
-- Single-entry list for the wrong-demon reminder: click summons the desired demon.
---@type PetActionList?
local cachedDesiredDemonList = nil

local CLASS_PET_BUILDERS = {
    HUNTER = BuildHunterActions,
    WARLOCK = BuildWarlockActions,
}
for class, pet in pairs(SINGLE_PET) do
    CLASS_PET_BUILDERS[class] = function()
        return BuildSingleAction(pet.spellID)
    end
end

---Build and cache the list of pet summon actions for the given class.
---Returns cached result on subsequent calls until invalidated.
---@param class ClassName?
---@return PetActionList?
local function GetPetActions(class)
    if not cacheValid then
        local builder = CLASS_PET_BUILDERS[class]
        cachedActions = builder and builder() or nil
        resolvedPreferredPet = nil
        cachedDesiredDemonList = nil
        cacheValid = true
    end

    -- Keyed on the preferred spell, so a content change, a profile switch or an
    -- import also re-resolves.
    if cachedActions and class == "WARLOCK" then
        local preferred = GetPreferredDemonSpell(cachedActions)
        if preferred ~= resolvedPreferredPet then
            local gi = ResolveWarlockGenericIndex(cachedActions, preferred)
            cachedActions.genericIndex = gi
            cachedDesiredDemonList = gi and { cachedActions[gi], genericIndex = 1 } or nil
            resolvedPreferredPet = preferred
        end
    end
    return cachedActions
end

---The warlock demon that the player wants out now, or nil if none can be summoned.
---@return PetAction?
local function GetDesiredWarlockDemon()
    local actions = GetPetActions("WARLOCK")
    return actions and actions.genericIndex and actions[actions.genericIndex] or nil
end

---Whether a pet of this creature family is allowed for the current content row. Felguard
---on Demonology allows only Felguard. A row with no allowed demon allows all demons.
---@param familyID number
---@return boolean
local function IsAllowedWarlockFamily(familyID)
    local desired = GetDesiredWarlockDemon()
    local desiredFamilies = desired and WARLOCK_DEMON_FAMILIES[desired.spellID]
    if not desired or not desiredFamilies or desiredFamilies[familyID] then
        return true
    end
    if desired.spellID == SUMMON_FELGUARD then
        return false
    end
    local row = GetWarlockDemonRow()
    local anyAllowed = false
    for _, demon in ipairs(WARLOCK_DEMON_CHOICES) do
        if IsWarlockDemonAllowed(row, demon.key) then
            if WARLOCK_DEMON_FAMILIES[demon.spellID][familyID] then
                return true
            end
            anyAllowed = true
        end
    end
    return not anyAllowed
end

---@return PetActionList?
local function GetDesiredWarlockDemonList()
    GetPetActions("WARLOCK")
    return cachedDesiredDemonList
end

---@return boolean? true if the pet exists and is on passive, nil otherwise
local function IsPetOnPassive()
    if not UnitExists("pet") then
        return nil
    end
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isActive = GetPetActionInfo(i)
        if name == "PET_MODE_PASSIVE" and isActive then
            return true
        end
    end
    return nil
end

---Invalidate cached pet actions (call on spec/talent/stable changes).
local function InvalidatePetActions()
    cacheValid = false
    cachedActions = nil
    cachedDesiredDemonList = nil
end

-- Export
BR.PetHelpers = {
    REVIVE_PET_ID = REVIVE_PET,
    FELGUARD_SPELL_ID = SUMMON_FELGUARD,
    GetPetActions = GetPetActions,
    IsPetOnPassive = IsPetOnPassive,
    WARLOCK_DEMON_FAMILIES = WARLOCK_DEMON_FAMILIES,
    WARLOCK_DEMON_CHOICES = WARLOCK_DEMON_CHOICES,
    IsAllowedWarlockFamily = IsAllowedWarlockFamily,
    GetDesiredWarlockDemon = GetDesiredWarlockDemon,
    GetDesiredWarlockDemonList = GetDesiredWarlockDemonList,
    InvalidatePetActions = InvalidatePetActions,
}

BR.GameContext.RegisterCache("petActions", InvalidatePetActions)
