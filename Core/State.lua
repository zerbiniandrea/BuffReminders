local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF STATE MODULE
-- ============================================================================
-- Pure data layer: computes "what buffs are missing" without any UI concerns.
-- The display render loop calls BuffState.Refresh, then reads the entries.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class BuffStateEntry
---@field key string                         -- "intellect", "devotionAura", etc.
---@field category CategoryName
---@field sortOrder number                   -- Position within category for display ordering
---@field visible boolean                    -- Should show?
---@field displayType "count"|"text"|"expiring"
---@field countText string?                  -- "17/20" for raid buffs, "5m" for expiring consumables
---@field overlayText string?                -- "NO\nAURA" for non-raid
---@field shouldGlow boolean                 -- Expiration glow?
---@field iconByRole table<RoleType,number>? -- Role-based icon override
---@field rebuffWarning boolean?             -- Consumable rebuff pulsing border?
---@field isEating boolean?                 -- Food entry: player is currently eating
---@field eatingExpirationTime number?      -- GetTime()-based expiration of eating aura
---@field petActions PetActionList?           -- Expanded pet summon actions
---@field dynamicIcon number|string|nil      -- Dynamic icon texture override (e.g. next poison to cast)
---@field glowKindOverride "expiring"|"missing"|nil -- Override glow kind (e.g. healthstone low stock uses expiring glow)
---@field subLabel string?                    -- Wrapping label rendered below the icon (loadout reminders: the set/talent name)
---@field noClick boolean?                    -- The click casts nothing

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local ceil = math.ceil
local format = string.format
local tinsert = table.insert
local tostring = tostring
local IsSpellKnown = C_SpellBook.IsSpellKnown

-- Reusable single-element buffer to avoid { spellID } allocations in hot loops.
-- SAFETY: callers must consume the result immediately - the buffer is overwritten on next call.
local singleSpellBuf = {}
local function AsSpellList(val)
    if type(val) == "table" then
        return val
    end
    singleSpellBuf[1] = val
    return singleSpellBuf
end

-- Localization (resolved once at load time)
-- Short "what's wrong" tags shown ON a loadout reminder icon (newline so they
-- wrap to two lines like "NO\nFLASK"); the specific name renders below the icon.
local LOADOUT_TAGS = {
    gear = BR.L["Loadout.Tag.Gear"],
    talent = BR.L["Loadout.Tag.Talent"],
    loadout = BR.L["Loadout.Tag.Loadout"],
}
local FMT_MINUTES = BR.L["Overlay.MinutesFormat"]
local FMT_LESS_THAN_ONE = BR.L["Overlay.LessThanOneMinute"]
local FMT_SECONDS = BR.L["Overlay.SecondsFormat"]

-- Buff tables from Buffs.lua (via BR namespace)
local BUFF_TABLES = BR.BUFF_TABLES
local REPAIR_SOURCES = BR.REPAIR_SOURCES
local BuffBeneficiaries = BR.BuffBeneficiaries
local SpecBeneficiaries = BR.SpecBeneficiaries

-- Sticky target memory for cast-on-others buffs (Core/TargetMemory.lua)
local TargetMemory = BR.TargetMemory
local GameContext = BR.GameContext

-- Buffs with class-specific aura variants can resolve to a single spell ID per unit.
-- This avoids scanning every possible variant for every raid member on each refresh.
local UNIT_CLASS_BUFF_SPELLS = {
    bronze = {
        DEATHKNIGHT = 381732,
        DEMONHUNTER = 381741,
        DRUID = 381746,
        EVOKER = 381748,
        HUNTER = 381749,
        MAGE = 381750,
        MONK = 381751,
        PALADIN = 381752,
        PRIEST = 381753,
        ROGUE = 381754,
        SHAMAN = 381756,
        WARLOCK = 381757,
        WARRIOR = 381758,
    },
}

-- Union of all spec IDs across SpecBeneficiaries tables.
-- Specs not in this set (starter specs, future specs) fall back to class-based filtering.
local knownSpecIds = {}
for _, specTable in pairs(SpecBeneficiaries) do
    for specId in pairs(specTable) do
        knownSpecIds[specId] = true
    end
end

-- LibSpecialization: provides ally spec IDs via addon comms. Optional.
local LibSpec = LibStub and LibStub("LibSpecialization", true)

-- Local aliases
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable
local UtilityBuffs = BUFF_TABLES.utility
local CustomBuffs = BUFF_TABLES.custom
local LoadoutRules = BUFF_TABLES.loadout

-- ============================================================================
-- MODULE STATE
-- ============================================================================

---@class BuffState
---@field entries table<string, BuffStateEntry>
---@field lastUpdate number
local BuffState = {
    entries = {},
    lastUpdate = 0,
}

-- Player class and name are constant for the session
local _, playerClass = UnitClass("player")
local playerName = GetUnitName("player", true)

-- Consumables dismissed state (transient, resets on instance change / reload).
-- "rest": the snooze started in a rest area and also ends when the player leaves it.
---@type boolean|"rest"
local consumablesDismissed = false

-- ============================================================================
-- CACHED VALUES (invalidated by specific events)
-- ============================================================================

-- Instance/content context cache: everything derived from the current zone lives
-- in ONE table because it all shares one lifecycle. Fields populate lazily and
-- InvalidateContentTypeCache clears the whole table with a single wipe, so a
-- newly added derived field can never be forgotten in the invalidator.
---@class InstanceCache
---@field contentType string?    -- "openWorld"|"dungeon"|"scenario"|"raid"|"housing"|"pvp"
---@field instanceType string?   -- raw WoW instanceType
---@field difficultyID number?   -- raw GetInstanceInfo difficultyID
---@field instanceName string?   -- GetInstanceInfo name
---@field instanceID number?     -- GetInstanceInfo instanceID
---@field activeChallenge number? -- active challenge map ID (keystone)
---@field difficultyKey string?  -- mapped difficulty key (only valid keys are cached)
---@field competitivePvP boolean? -- arena or rated BG
---@field legacyInstance boolean? -- legacy loot mode (populated with contentType)
local instanceCache = {}
local GetDifficultyIDCached -- forward declaration (defined next to GetCurrentContentType)

local CONTENT_DIFFICULTY_TABLES = BR.INSTANCE_CONTENT.difficultyIDs

-- Maps content type to the DB key holding its difficulty sub-filter. A content type
-- without a sub-row on this client ignores a saved filter, because no control can clear it.
local CONTENT_DIFF_DB_KEYS = {}
for contentType, diffDbKey in pairs({
    scenario = "scenarioDifficulty",
    dungeon = "dungeonDifficulty",
    raid = "raidDifficulty",
    pvp = "pvpType",
}) do
    if BR.INSTANCE_CONTENT.difficulties[contentType] then
        CONTENT_DIFF_DB_KEYS[contentType] = diffDbKey
    end
end

-- Talent/spell knowledge cache
local cachedSpellKnowledge = {}

-- Spec ID cache
local cachedSpecId = nil

-- Player role cache
local cachedPlayerRole = nil

-- Off-hand slot type cache (invalidated on equipment/spec change)
-- Populated together from a single GetInventoryItemID + GetItemInfoInstant call
local cachedOffHandType = nil -- nil = not yet checked, "weapon" | "shield" | "none"

-- Weapon subclass per hand slot, false for no weapon. Cleared with the off-hand cache.
---@type table<number, number|false>
local cachedWeaponSubclass = {}

-- Item ownership cache
---@type table<string, table<number, boolean>>
local cachedItemOwnership = {}

-- Lowest equipped-item durability ratio (0-1). The 18-slot scan is a read-only
-- lookup whose answer only changes on durability / equipment events, so it is
-- memoized and reused on the fallback ticker instead of re-scanned every refresh.
---@type number|nil
local cachedLowestDurability = nil

-- Resolved repair click sources (mount to summon / item to use). Mount collection
-- and bag contents only change on their own events, so the pair is resolved once.
-- Only ever holds a positive answer (see GetRepairSources).
---@type { mountSpellID: number?, mountID: number?, itemID: number? }|nil
local cachedRepairSources = nil

-- Loadout state cache: rule.key -> { satisfied, icon }. The detection calls
-- (IsSatisfied / GetRuleIcon) are read-only WoW lookups whose answers only change
-- on spec / talent / equipment / equipment-set events, so they are cached here and
-- reused on the 3s fallback ticker instead of re-queried every full refresh.
-- An unsettled answer stays out of the cache: no event announces the moment an
-- external loadout addon becomes able to answer.
---@type table<string, { satisfied: boolean, icon: number|string? }>
local cachedLoadoutState = {}

-- Shared verdict for a rule that needs no reminder. Only the unsatisfied path
-- reads an icon, so a satisfied rule must not pay to resolve one. Never mutated,
-- so every satisfied rule can hold this one table.
local SATISFIED_LOADOUT_STATE = { satisfied = true }

-- Creature family of the current pet (false = no pet, nil = unresolved).
---@type number|false|nil
local cachedPetFamily = nil

-- Happiness of the current pet (false = no pet or no value, nil = unresolved).
-- C_PetInfo.GetPetHappiness exists only on a client with pet happiness.
---@type number|false|nil
local cachedPetHappiness = nil
local GetPetHappiness = C_PetInfo and C_PetInfo.GetPetHappiness

-- Warrior stance and druid form rules of the client: the allowed stances and the
-- stance that the click casts.
local STANCE_RULES = BR.STANCE_RULES
local NO_STANCE = BR.NO_STANCE

-- Priest shadow forms. Shadowform is the only stance shadow priests can take;
-- Voidform is a temporary aura that visually replaces it. The stance bar API
-- works in restricted contexts (combat/encounter/M+) where aura queries fail
-- for non-whitelisted spells, so the stance bar is read directly.
local SHADOWFORM = BR.SHADOWFORM_SPELL_ID
local VOIDFORM = 194249

-- Travel-family shapeshift form IDs (GetShapeshiftFormID): ground Travel and
-- Mount Form both report 3, Aquatic reports 4, Flight reports 27. Every variant
-- shares spell 783 except Mount Form (210053), so this table keys off the engine
-- form category instead of the spell. That covers any Mount Form appearance
-- variant. None of these collide with combat forms (Cat 1, Bear 5, Dire Bear 8, Moonkin 31).
-- Used to suppress the wrong-form reminder during travel.
local DRUID_TRAVEL_FORM_IDS = {
    [3] = true, -- ground Travel Form + Mount Form
    [4] = true, -- Aquatic Form
    [27] = true, -- Flight Form
}

-- Shapeshift/stance cache: the active stance and the derived priest shadowform
-- and stance icon values, all invalidated together by InvalidateStanceCache.
-- `false` on a field = computed and absent; nil = not yet computed.
---@class StanceCache
---@field currentStanceIcon number|false|nil  -- false = unstanced
---@field shadowFormActive boolean|nil
---@field activeSpellID number|false|nil        -- false = unstanced; nil = not computed / transient
---@field barSpells table<number, true>|nil      -- spell IDs of the stance bar slots
---@type StanceCache
local stanceCache = {}

-- Weapon enchant info for current refresh cycle (set once per BuffState.Refresh())
local currentWeaponEnchants = {
    hasMainHand = false,
    mainHandID = nil,
    mainHandExpiration = nil,
    hasOffHand = false,
    offHandID = nil,
    offHandExpiration = nil,
    -- The temporary slot holds stones and oils. On a client with no separate imbue slot, it holds any enchant.
    mainHandTempID = nil,
    mainHandTempExpiration = nil,
    offHandTempID = nil,
    offHandTempExpiration = nil,
    -- The imbue slot holds poisons and shaman imbues, on a client that has it.
    mainHandImbueID = nil,
    mainHandImbueExpiration = nil,
    offHandImbueID = nil,
    offHandImbueExpiration = nil,
    permanentMH = nil, -- permanent enchant ID from item link (MH)
    permanentOH = nil, -- permanent enchant ID from item link (OH)
}

---@param enchantID number|table<number, true> One enchant ID, or a set of accepted IDs
---@param id number?
---@return boolean
local function EnchantMatches(enchantID, id)
    if type(enchantID) == "number" then
        return id == enchantID
    end
    return id ~= nil and enchantID[id] == true
end

---Seconds left on a temporary weapon enchant, from whichever hand carries it.
---Weapon enchant info is not an aura read, so it is safe in restricted contexts.
---@param enchantID number|table<number, true> One enchant ID, or a set of accepted IDs
---@return number? remaining nil when neither hand carries the enchant
local function GetWeaponEnchantRemaining(enchantID)
    local expiration
    if EnchantMatches(enchantID, currentWeaponEnchants.mainHandID) then
        expiration = currentWeaponEnchants.mainHandExpiration
    elseif EnchantMatches(enchantID, currentWeaponEnchants.offHandID) then
        expiration = currentWeaponEnchants.offHandExpiration
    end
    return expiration and expiration / 1000 or nil
end

-- Valid group members for current refresh cycle (set once per BuffState.Refresh()).
-- Includes phased / out-of-broadcast-range allies (tagged via `isPhased`) so an
-- already-active buff on an unreachable ally still registers as covered.
-- Counting paths apply a "phased + missing -> skip" rule to keep unfixable gaps
-- out of the missing math; presence/targeted scans just iterate everyone.
---@type {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean, inPlayerParty: boolean}[]
local currentValidUnits = {}

-- Solo snapshot from the most recent BuildValidUnitCache().
-- True when GetNumGroupMembers() <= 1: covers both open-world solo (reports 0) and
-- scenario solo such as rituals (reports 1 with only the player as the lone member).
-- Real groups (>= 2 members) set this to false.
local cachedIsAlone = true
-- Whether any group member is assigned HEALER (nil = not computed this session yet).
local cachedHealerInGroup = nil
-- Whether the player is a tank (nil = not read since the last role event).
---@type boolean?
local cachedPlayerTank = nil
-- Main Tank marks by unit token, cleared on role events.
---@type table<string, boolean>
local cachedMainTanks = {}

-- Spec cache: playerName -> specId (populated by LibSpecialization callbacks for allies,
-- and by BuildValidUnitCache for the local player via GetPlayerSpecId())
local allySpecCache = {}

-- Last class / role seen as a plain value, per group member name. UnitClass and
-- UnitGroupRolesAssigned return secrets once a unit's identity is secret, so these
-- carry the value across restricted contexts. Pruned with allySpecCache.
---@type table<string, string>
local allyClassCache = {}
---@type table<string, string>
local allyRoleCache = {}

-- Every name-keyed ally cache, so roster pruning walks one list. Holds references:
-- clear any of them with wipe(), never by reassigning.
local nameKeyedAllyCaches = { allySpecCache, allyClassCache, allyRoleCache }

-- Whether NPCs count toward buff coverage for the current refresh cycle.
-- True in follower dungeons and delves where NPC companions can receive buffs.
local includeNPCsInCounting = false

local IsAuraSpellTrackable = BR.Restrictions.IsAuraSpellTrackable
local CooldownsRestricted = BR.Restrictions.CooldownsRestricted

---Determine if a buff's detection method works in aura-restricted contexts (combat + M+ keystones).
---Non-aura detection (weapon enchants, inventory checks) is always safe.
---Aura-based detection requires every queried spell ID to classify as never secret.
---@param buff table Any buff table entry (RaidBuff, SelfBuff, ConsumableBuff, etc.)
---@return boolean
local function ComputeAuraTrackable(buff)
    if buff.checkWeaponEnchant or buff.checkWeaponEnchantOH then
        return true
    end
    if buff.itemID and not buff.spellID and not buff.buffIconID then
        return true
    end

    -- Enchant-only detection (no aura check needed)
    if buff.enchantID and not buff.requiresBuffWithEnchant then
        return true
    end

    -- buffIconID (GetAuraDataByIndex iteration) is not safe in restricted contexts
    if buff.buffIconID then
        return false
    end

    -- Determine which spell IDs actually get queried via UnitHasBuff
    local idsToCheck = buff.casterBuffId or buff.buffIdOverride or buff.spellID

    -- No aura spell IDs (e.g., pure customCheck pet buffs)
    if not idsToCheck then
        return true
    end

    if type(idsToCheck) == "number" then
        return IsAuraSpellTrackable(idsToCheck)
    end
    for _, id in ipairs(idsToCheck) do
        if not IsAuraSpellTrackable(id) then
            return false
        end
    end
    return true
end

-- Memoized ComputeAuraTrackable: a function of the buff def and the per-spell
-- secrecy classification, called 1-3x per buff on every refresh. Weak-keyed side
-- table rather than a field on the def - custom buff / loadout defs are the live
-- SavedVariables tables, so a cache field leaks into the user's DB. Edited
-- custom buffs are new table objects, so they miss the cache and recompute.
-- InvalidateAuraTrackableCache resets it together with the classification cache.
---@type table<table, boolean>
local auraTrackableCache = setmetatable({}, { __mode = "k" })

---@param buff table Any buff table entry (RaidBuff, SelfBuff, ConsumableBuff, etc.)
---@return boolean
local function IsAuraTrackable(buff)
    local cached = auraTrackableCache[buff]
    if cached ~= nil then
        return cached
    end
    local result = ComputeAuraTrackable(buff)
    auraTrackableCache[buff] = result
    return result
end

-- Secret-safe read helpers (see Core.lua). Aliased to file-scope locals so hot
-- loops pay only a local call, not a table lookup.
local Plain = BR.Secret.Plain
local AuraList = BR.Secret.AuraList
local AuraField = BR.Secret.AuraField
local AuraByIndex = BR.Secret.AuraByIndex
local AuraByInstanceID = BR.Secret.AuraByInstanceID

-- The per-slot enchant list exists only on a client where one weapon holds a
-- temporary enchant and an imbue together. The legacy GetWeaponEnchantInfo
-- reports only the imbue then. Nil on a client without the list.
---@type (fun(weaponSlot: number): number?, number?, number?, number?)?
local ReadWeaponEnchantSlots
do
    local GetWeaponEnchantList = C_Item.GetWeaponEnchantInfo
    local ENCHANT_TYPE_IMBUE = Enum.ItemEnchantType and Enum.ItemEnchantType.Imbue
    if GetWeaponEnchantList then
        ---@return number? tempID, number? tempExpirationMs, number? imbueID, number? imbueExpirationMs
        ReadWeaponEnchantSlots = function(weaponSlot)
            local tempID, tempExp, imbueID, imbueExp
            for _, info in ipairs(AuraList(GetWeaponEnchantList(weaponSlot))) do
                if AuraField(info, "hasEnchant") then
                    if AuraField(info, "enchantType") == ENCHANT_TYPE_IMBUE then
                        imbueID, imbueExp = AuraField(info, "enchantID"), AuraField(info, "timeLeft")
                    else
                        tempID, tempExp = AuraField(info, "enchantID"), AuraField(info, "timeLeft")
                    end
                end
            end
            return tempID, tempExp, imbueID, imbueExp
        end
    end
end

-- Set of spell IDs the addon queries on GROUP MEMBERS, per-class variants
-- included. Used to filter group-unit UNIT_AURA payloads: an aura change outside
-- this set cannot affect what the addon displays. Player/pet-only detection is
-- irrelevant here - player/pet UNIT_AURA always refreshes. Built once from the
-- built-in buff tables; custom buffs are only ever scanned on the player.
local groupTrackedSpells = {}
do
    local function addSpells(val)
        if type(val) == "table" then
            for _, id in ipairs(val) do
                groupTrackedSpells[id] = true
            end
        elseif val then
            groupTrackedSpells[val] = true
        end
    end
    for _, buff in ipairs(RaidBuffs) do
        addSpells(buff.spellID)
    end
    for _, buff in ipairs(PresenceBuffs) do
        addSpells(buff.spellID)
    end
    for _, buff in ipairs(TargetedBuffs) do
        addSpells(buff.spellID)
    end
    for _, perClass in pairs(UNIT_CLASS_BUFF_SPELLS) do
        for _, id in pairs(perClass) do
            groupTrackedSpells[id] = true
        end
    end
end

-- auraInstanceIDs of tracked auras found on group units during the most recent
-- scan (unit token -> instanceID set). Wiped at the start of every refresh and
-- repopulated by the scans, so removal/update payloads arriving between
-- refreshes can be matched against what the display actually reflects.
---@type table<string, table<number, true>>
local trackedAuraInstances = {}

---Record a found tracked aura's instance ID. A secret auraInstanceID (restricted
---context) reads as nil and is skipped - that aura's removal then falls back to
---the 3s ticker instead of the event fast path.
---@param unit string
---@param auraData table
local function RecordAuraInstance(unit, auraData)
    local inst = AuraField(auraData, "auraInstanceID")
    if inst == nil then
        return
    end
    local set = trackedAuraInstances[unit]
    if not set then
        set = {}
        trackedAuraInstances[unit] = set
    end
    set[inst] = true
end

-- Reusable set for target-memory pruning (avoids per-refresh allocation)
---@type table<string, true>
local activeNames = {}

-- Pool of reusable unit entry tables (avoids creating new tables each refresh)
---@type {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean, inPlayerParty: boolean}[]
local unitEntryPool = {}
local unitEntryPoolSize = 0

---Get a unit entry from the pool or create a new one
---@param unit string
---@param class string? nil when the class read came back secret with nothing cached
---@param isPlayer boolean
---@param name string?
---@param isPhased boolean True when the unit is in another phase or out of broadcast range
---@param inPlayerParty boolean True when the unit is in the player's raid subgroup, or not in a raid
---@return {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean, inPlayerParty: boolean}
local function AcquireUnitEntry(unit, class, isPlayer, name, isPhased, inPlayerParty)
    local entry
    if unitEntryPoolSize > 0 then
        entry = unitEntryPool[unitEntryPoolSize]
        unitEntryPool[unitEntryPoolSize] = nil
        unitEntryPoolSize = unitEntryPoolSize - 1
        entry.unit = unit
        entry.class = class
        entry.isPlayer = isPlayer
        entry.name = name
        entry.isPhased = isPhased
        entry.inPlayerParty = inPlayerParty
    else
        entry = {
            unit = unit,
            class = class,
            isPlayer = isPlayer,
            name = name,
            isPhased = isPhased,
            inPlayerParty = inPlayerParty,
        }
    end
    return entry
end

---Return all current unit entries to the pool for reuse
local function RecycleUnitEntries()
    for i = 1, #currentValidUnits do
        unitEntryPoolSize = unitEntryPoolSize + 1
        unitEntryPool[unitEntryPoolSize] = currentValidUnits[i]
        currentValidUnits[i] = nil
    end
end

-- Max level per class for current refresh cycle (players only, for caster availability checks)
---@type table<ClassName, number>
local classMaxLevels = {}
-- The same, for the members in the player's raid subgroup only
---@type table<ClassName, number>
local partyClassMaxLevels = {}

-- Raid subgroup per raid unit token, and the player's own subgroup under "player"
---@type table<string, number>
local raidSubgroups = {}
local raidSubgroupsValid = false

-- Only a party-reach buff reads raid subgroups, so a client without one skips the roster scan
local hasPartyReachBuff = false
for _, list in ipairs({ RaidBuffs, PresenceBuffs }) do
    for _, buff in ipairs(list) do
        if buff.reach == "party" then
            hasPartyReachBuff = true
        end
    end
end

---@return table<string, number>
local function GetRaidSubgroups()
    if raidSubgroupsValid then
        return raidSubgroups
    end
    wipe(raidSubgroups)
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local _, _, subgroup = GetRaidRosterInfo(i)
        subgroup = Plain(subgroup)
        raidSubgroups[unit] = subgroup
        if Plain(UnitIsUnit(unit, "player")) then
            raidSubgroups.player = subgroup
        end
    end
    -- A secret roster read leaves the player's subgroup unknown, so the next refresh reads again
    raidSubgroupsValid = raidSubgroups.player ~= nil
    return raidSubgroups
end

---Get the player's current spec ID (cached)
---@return number?
local function GetPlayerSpecId()
    if cachedSpecId then
        return cachedSpecId
    end
    cachedSpecId = BR.Client.GetSpecID()
    return cachedSpecId
end

---Get the player's current role (cached)
---@return RoleType?
local function GetPlayerRole()
    if cachedPlayerRole then
        return cachedPlayerRole
    end
    local _, specIndex = BR.Client.GetSpecID()
    if specIndex then
        cachedPlayerRole = GetSpecializationRole(specIndex)
    end
    return cachedPlayerRole
end

---Whether a raid marks the unit as Main Tank. A secret answer reads as false and stays uncached.
---@param unit string
---@return boolean
local function IsMainTank(unit)
    local known = cachedMainTanks[unit]
    if known ~= nil then
        return known
    end
    if not GetPartyAssignment then
        return false
    end
    local marked = Plain(GetPartyAssignment("MAINTANK", unit))
    if marked == nil then
        return false
    end
    known = marked == true or marked == 1
    cachedMainTanks[unit] = known
    return known
end

---A tank has the TANK role or a Main Tank mark. Classic groups often use only the mark.
---@return boolean
local function IsPlayerTank()
    if cachedPlayerTank == nil then
        cachedPlayerTank = Plain(UnitGroupRolesAssigned("player")) == "TANK" or IsMainTank("player")
    end
    return cachedPlayerTank
end

---Check if player knows a spell (cached version of C_SpellBook.IsSpellKnown)
---@param spellID number
---@return boolean
local function IsPlayerSpellCached(spellID)
    if cachedSpellKnowledge[spellID] ~= nil then
        return cachedSpellKnowledge[spellID]
    end
    local knows = IsSpellKnown(spellID)
    cachedSpellKnowledge[spellID] = knows
    return knows
end

---@param spellIDs SpellID
---@return boolean
local function KnowsAnySpell(spellIDs)
    for _, id in ipairs(AsSpellList(spellIDs)) do
        if IsPlayerSpellCached(id) then
            return true
        end
    end
    return false
end

---Check if player has an item equipped (slots 1-19)
---@param itemID number
---@return boolean
local function HasItemEquipped(itemID)
    for slot = 1, 19 do
        if GetInventoryItemID("player", slot) == itemID then
            return true
        end
    end
    return false
end

---Check if player has an item in bags (excludes equipped items)
---@param itemID number
---@return boolean
local function HasItemInBags(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    if not ok or not count or count <= 0 then
        return false
    end
    -- GetItemCount includes equipped items; subtract if equipped
    if HasItemEquipped(itemID) then
        count = count - 1
    end
    return count > 0
end

---Check if player has an item based on mode (cached)
---@param itemID number
---@param mode? "owned"|"equipped"|"bags" -- "owned" (default) = bags or equipped
---@return boolean
local function HasItemByMode(itemID, mode)
    mode = mode or "owned"
    local byItem = cachedItemOwnership[mode]
    if not byItem then
        byItem = {}
        cachedItemOwnership[mode] = byItem
    end
    local cached = byItem[itemID]
    if cached ~= nil then
        return cached
    end
    local result
    if mode == "equipped" then
        result = HasItemEquipped(itemID)
    elseif mode == "bags" then
        result = HasItemInBags(itemID)
    else -- "owned" (default)
        local ok, count = pcall(C_Item.GetItemCount, itemID)
        result = (ok and count ~= nil and count > 0) or HasItemEquipped(itemID)
    end
    byItem[itemID] = result
    return result
end

-- Item count cache (charges included), invalidated together with
-- cachedItemOwnership. Item counts only change on bag updates. Charge counts do
-- change without a bag event, so they stay out of this cache.
---@type table<number, number>
local cachedItemCounts = {}

---Get the player's item count including charges.
---No bag event fires when an item keeps its slot and only its charges change,
---so a charge-bearing item must read live (see `itemHasCharges` in Buffs.lua).
---@param itemID number
---@param live? boolean skip the cache
---@return number
local function GetItemCountCached(itemID, live)
    if not live then
        local count = cachedItemCounts[itemID]
        if count ~= nil then
            return count
        end
    end
    local ok, c = pcall(C_Item.GetItemCount, itemID, false, true)
    if ok and c then
        if not live then
            cachedItemCounts[itemID] = c
        end
        return c
    end
    -- Failed/nil read: do not cache, so the next refresh retries instead of
    -- freezing a false 0 until the next bag event.
    return 0
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---Check if an existing unit is a valid buff target for tracking.
---Caller must verify UnitExists first. Excludes: dead/ghost, disconnected,
---hostile (cross-faction in open world).
---Phased / out-of-broadcast-range allies still pass; their phase status is exposed via
---the `isPhased` flag on the cached entry so counting paths can apply the
---"phased + missing -> skip" rule without losing existing-buff coverage.
---@param unit string
---@return boolean
local function IsValidBuffTarget(unit)
    return not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) and UnitCanAssist("player", unit)
end

---Determine whether a unit is in a different phase from the player or out of
---broadcast range. Used to tag entries during cache rebuild; downstream consumers
---decide whether to include phased allies in their math.
---@param unit string
---@return boolean
local function IsUnitPhased(unit)
    -- A secret phase reason reads as "not phased": it is non-nil, so an unguarded
    -- compare marks every member phased and drops them from the missing math
    return not UnitIsVisible(unit) or Plain(UnitPhaseReason(unit)) ~= nil
end

---Check if a unit benefits from a buff using spec (preferred) or class (fallback)
---@param specBeneficiaries table? Spec-level beneficiary table for this buff key
---@param beneficiaries table? Class-level beneficiary table for this buff key
---@param specId number? Unit's spec ID (nil if unknown)
---@param class string? Unit's class
---@return boolean
local function UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, specId, class)
    if specBeneficiaries and specId and knownSpecIds[specId] then
        return specBeneficiaries[specId] or false
    end
    if beneficiaries then
        return beneficiaries[class] or false
    end
    return true -- no filter = everyone benefits
end

---Build the list of valid units for the current refresh cycle
---Called once at the start of BuffState.Refresh()
local function BuildValidUnitCache()
    RecycleUnitEntries()
    wipe(classMaxLevels)
    wipe(partyClassMaxLevels)
    wipe(activeNames)
    -- Reset per-unit tracked-aura instance sets; the scans this refresh performs
    -- repopulate them (sets are reused; stale unit keys stay empty)
    for _, set in pairs(trackedAuraInstances) do
        wipe(set)
    end

    -- Keep player spec in allySpecCache so CountMissingBuff can use a single
    -- lookup path (allySpecCache[name]) for both the player and allies.
    allySpecCache[playerName] = GetPlayerSpecId()

    -- Follower dungeons and delves (scenarios) have NPC companions that can
    -- receive player buffs. Other content (e.g. Legion artifact quests) has allied
    -- NPCs that cannot, so NPCs stay out of the count by default.
    do
        local difficultyID = GetDifficultyIDCached()
        includeNPCsInCounting = difficultyID == 205 or difficultyID == 208 -- Follower dungeon / Delves
    end

    local inRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()
    cachedIsAlone = groupSize <= 1

    -- Open-world solo (groupSize 0) has no roster but still needs the player in
    -- the unit cache. Treat it as a 1-unit "group of player" so dead/phased/etc.
    -- filtering via IsValidBuffTarget runs uniformly for solo and grouped paths.
    local memberCount = groupSize == 0 and 1 or groupSize

    -- An unknown player subgroup counts every raid member as the player's party
    local subgroups = inRaid and hasPartyReachBuff and GetRaidSubgroups()
    local playerSubgroup = subgroups and subgroups.player

    for i = 1, memberCount do
        local unit
        if inRaid then
            unit = "raid" .. i
        elseif i == 1 then
            unit = "player"
        else
            unit = "party" .. (i - 1)
        end

        if UnitExists(unit) then
            -- Roster names feed target-memory pruning: collected for EVERY existing
            -- member, dead/disconnected included - they have not left the group, so
            -- target memory must survive wipes and reconnects.
            local name = GetUnitName(unit, true)
            if name then
                activeNames[name] = true
            end
            if IsValidBuffTarget(unit) then
                -- class is used as a table key downstream (beneficiaries, per-class
                -- spell variants, classMaxLevels) and a secret key throws
                local _, class = UnitClass(unit)
                class = Plain(class)
                if name then
                    if class then
                        allyClassCache[name] = class
                    else
                        class = allyClassCache[name]
                    end
                end
                local isPlayer = UnitIsPlayer(unit)
                local isPhased = IsUnitPhased(unit)
                local inPlayerParty = not playerSubgroup or (subgroups and subgroups[unit]) == playerSubgroup
                currentValidUnits[#currentValidUnits + 1] =
                    AcquireUnitEntry(unit, class, isPlayer, name, isPhased, inPlayerParty)
                -- Track max level per class (players only, for buff caster checks).
                -- Skip phased / out-of-broadcast-range allies: they cannot reliably
                -- cast on the group now. The addon must not track a buff that no
                -- reachable member can provide (e.g. priest outside the dungeon).
                if isPlayer and class and not isPhased then
                    local level = UnitLevel(unit)
                    if not classMaxLevels[class] or level > classMaxLevels[class] then
                        classMaxLevels[class] = level
                    end
                    if inPlayerParty and (not partyClassMaxLevels[class] or level > partyClassMaxLevels[class]) then
                        partyClassMaxLevels[class] = level
                    end
                end
            end
        end
    end

    -- Prune target memory: forget targets who left the group (roster membership,
    -- NOT buff-target validity - a dead or offline member has not left)
    TargetMemory.PruneToRoster(activeNames)
end

---Check if any group member of the given class meets the level requirement
---Uses classMaxLevels cache built at start of refresh cycle
---@param requiredClass ClassName
---@param levelRequired? number
---@param reach? BuffReach "party" looks only in the player's raid subgroup
---@return boolean
local function HasCasterForBuff(requiredClass, levelRequired, reach)
    local maxLevel = (reach == "party" and partyClassMaxLevels or classMaxLevels)[requiredClass]
    if not maxLevel then
        return false
    end
    return not levelRequired or maxLevel >= levelRequired
end

-- The warning window of an aura copy (its lead), and the choice of the copy that a
-- multi-member scan reports.
local Lead = {}
-- Fraction of the full duration, set from the defaults on each settings read.
Lead.share = 0.25

---Seconds before the end of an aura when its warning starts: a share of its full
---duration, at most the threshold. An aura of 5 min or less shows only when missing.
---An unknown duration (nil, 0, or secret) uses the threshold.
---@param duration? number
---@param threshold number Seconds
---@param floor? number Seconds. Ignores the share cap, but stays a minute under the full duration
---@param share? number Fraction of the duration. Default Lead.share
---@return number? lead nil when the aura never warns
function Lead.Of(duration, threshold, floor, share)
    floor = floor or 0
    if not duration or duration <= 0 then
        return threshold > floor and threshold or floor
    end
    if duration <= 300 then
        return nil
    end
    local lead = duration * (share or Lead.share)
    if lead > threshold then
        lead = threshold
    end
    if floor > lead then
        lead = floor < duration - 60 and floor or duration - 60
    end
    return lead
end

---Fold one copy into the best copy of a scan. A copy in its window beats one outside
---it. Among copies in their window, the one that ends first wins. Among the others,
---the one that enters its window first wins. nextSlack is the earliest entry into a
---window, so a render can follow it.
---@param remaining number
---@param lead number
---@param bestRemaining? number
---@param bestLead? number
---@param nextSlack? number
---@return number bestRemaining
---@return number bestLead
---@return number? nextSlack
function Lead.Pick(remaining, lead, bestRemaining, bestLead, nextSlack)
    local slack = remaining - lead
    if slack >= 0 and (not nextSlack or slack < nextSlack) then
        nextSlack = slack
    end
    if not bestRemaining or not bestLead then
        return remaining, lead, nextSlack
    end
    local inWindow = slack < 0
    local better
    if inWindow ~= (bestRemaining < bestLead) then
        better = inWindow
    elseif inWindow then
        better = remaining < bestRemaining
    else
        better = slack < bestRemaining - bestLead
    end
    if better then
        return remaining, lead, nextSlack
    end
    return bestRemaining, bestLead, nextSlack
end

---Check if unit has a specific buff (handles single spellID or table of spellIDs)
---@param unit string
---@param spellIDs SpellID
---@return boolean hasBuff
---@return number? remainingTime
---@return string? sourceUnit
---@return number? duration Full duration of the aura, nil or 0 when it never expires
local function UnitHasBuff(unit, spellIDs)
    -- Fast path: single numeric spellID (most common case, avoids table allocation)
    if type(spellIDs) == "number" then
        local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, spellIDs)
        if auraData then
            if unit ~= "player" then
                RecordAuraInstance(unit, auraData)
            end
            local remaining
            local exp = AuraField(auraData, "expirationTime")
            if exp and exp > 0 then
                remaining = exp - GetTime()
            end
            return true, remaining, AuraField(auraData, "sourceUnit"), AuraField(auraData, "duration")
        end
        return false, nil, nil
    end

    -- Table path: multiple spellIDs
    for _, id in ipairs(spellIDs) do
        local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, id)
        if auraData then
            if unit ~= "player" then
                RecordAuraInstance(unit, auraData)
            end
            local remaining
            local exp = AuraField(auraData, "expirationTime")
            if exp and exp > 0 then
                remaining = exp - GetTime()
            end
            return true, remaining, AuraField(auraData, "sourceUnit"), AuraField(auraData, "duration")
        end
    end

    return false, nil, nil
end

---Resolve the specific spell ID(s) the addon queries for this unit.
---@param buffKey string?
---@param spellIDs SpellID
---@param class string?
---@return SpellID
local function GetUnitSpellIDs(buffKey, spellIDs, class)
    local perClass = buffKey and UNIT_CLASS_BUFF_SPELLS[buffKey]
    if perClass and class then
        return perClass[class] or spellIDs
    end
    return spellIDs
end

-- Per-aura match tests. Aura fields (spellId, icon) are secret values for
-- non-whitelisted auras in restricted contexts (combat, encounters, M+);
-- AuraField reads a secret as nil, so a secret aura never matches -
-- no pcall needed at the call site.
---@param auraData table
---@param singleId number?
---@param spellIDs SpellID
---@return boolean
local function AuraMatchesSpellIDs(auraData, singleId, spellIDs)
    local sid = AuraField(auraData, "spellId")
    if sid == nil then
        return false
    end
    if singleId then
        return sid == singleId
    end
    local idList = spellIDs --[[@as number[] ]]
    for _, id in ipairs(idList) do
        if sid == id then
            return true
        end
    end
    return false
end

---@param auraData table
---@param iconID number
---@return boolean
local function AuraMatchesIcon(auraData, iconID)
    return AuraField(auraData, "icon") == iconID
end

---Scan player-cast buffs on a unit looking for a spellID (or any of a list).
---Used as a fallback when GetUnitAuraBySpellID returns another player's instance
---(e.g., two Aug Evokers both casting Blistering Scales on the same tank).
---The "HELPFUL|PLAYER" filter narrows iteration to only the player's own buffs.
---@param unit string
---@param spellIDs SpellID
---@return boolean found
---@return number? remainingTime
---@return number? duration
local function UnitHasBuffFromPlayer(unit, spellIDs)
    local singleId = type(spellIDs) == "number" and spellIDs or nil ---@type number?
    local i = 1
    local auraData = AuraByIndex(unit, i, "HELPFUL|PLAYER")
    while auraData do
        if AuraMatchesSpellIDs(auraData, singleId, spellIDs) then
            if unit ~= "player" then
                RecordAuraInstance(unit, auraData)
            end
            local remaining
            local exp = AuraField(auraData, "expirationTime")
            if exp and exp > 0 then
                remaining = exp - GetTime()
            end
            return true, remaining, AuraField(auraData, "duration")
        end
        i = i + 1
        auraData = AuraByIndex(unit, i, "HELPFUL|PLAYER")
    end
    return false, nil
end

---Format remaining time in seconds to a short string (e.g., "5m" or "<1m")
---@param seconds number
---@return string
local function FormatRemainingTime(seconds)
    local mins = ceil(seconds / 60)
    if mins > 1 then
        return format(FMT_MINUTES, mins)
    else
        return FMT_LESS_THAN_ONE
    end
end

---Format remaining time for eating countdown (always shows real value, e.g., "5m" or "23s")
---@param seconds number
---@return string
local function FormatEatingTime(seconds)
    local mins = ceil(seconds / 60)
    if mins > 1 then
        return format(FMT_MINUTES, mins)
    else
        return format(FMT_SECONDS, ceil(seconds))
    end
end

---Get the effective setting key for a buff (groupId if present, otherwise individual key)
---@param buff RaidBuff|PresenceBuff|TargetedBuff|SelfBuff
---@return string
local function GetBuffSettingKey(buff)
    return buff.groupId or buff.key
end

-- Ship defaults for opt-in buffs. Built lazily from the buff definitions'
-- `defaultEnabled = false` field, keyed by setting key (groupId or key). A buff
-- absent here ships enabled. Resolving the default at read time (rather than
-- seeding `false` into every profile) keeps the buff def the single source of
-- truth and covers profiles created after install, which never run migrations.
---@type table<string, boolean>|nil
local defaultEnabledByKey = nil
local function GetDefaultEnabledLookup()
    local lookup = defaultEnabledByKey
    if not lookup then
        lookup = {}
        for _, category in pairs(BUFF_TABLES) do
            for _, buff in ipairs(category) do
                if buff.defaultEnabled == false then
                    lookup[buff.groupId or buff.key] = false
                end
            end
        end
        defaultEnabledByKey = lookup
    end
    return lookup
end

---Check if a buff is enabled. An explicit user choice wins; otherwise the buff's
---declared ship default applies (enabled unless the def sets defaultEnabled=false).
---@param key string setting key (groupId or individual key)
---@return boolean
local function IsBuffEnabled(key)
    local stored = BR.profile.enabledBuffs[key]
    if stored ~= nil then
        return stored
    end
    return GetDefaultEnabledLookup()[key] ~= false
end

---Get the current content type based on instance/zone (cached)
---@return string contentType One of "openWorld", "dungeon", "scenario", "raid", "housing", "pvp"
local function GetCurrentContentType()
    if instanceCache.contentType then
        return instanceCache.contentType
    end

    -- Stash the raw GetInstanceInfo identity for reuse - same lifecycle, cleared
    -- together in InvalidateContentTypeCache. The identity fields freeze with the
    -- content type: a transient nil name at populate time relies on the post-load
    -- invalidation events to repopulate.
    local instName, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    instanceCache.instanceName = instName
    instanceCache.instanceID = instanceID
    instanceCache.difficultyID = difficultyID
    instanceCache.activeChallenge = C_ChallengeMode
            and C_ChallengeMode.GetActiveChallengeMapID
            and C_ChallengeMode.GetActiveChallengeMapID()
        or nil

    -- Check housing before instance type (housing zones can report as instanced)
    if
        C_Housing
        and (
            (C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot())
            or (C_Housing.IsOnNeighborhoodMap and C_Housing.IsOnNeighborhoodMap())
        )
    then
        instanceCache.contentType = "housing"
        return "housing"
    end

    -- Delves report inInstance=false but instanceType="scenario" and difficultyID=208;
    -- check difficultyID first so they are correctly classified as scenarios.
    if difficultyID == 208 then
        instanceCache.contentType = "scenario"
        return "scenario"
    end

    local inInstance, instanceType = IsInInstance()
    instanceCache.instanceType = instanceType
    -- A difficultyID of 0 inside an instance is a transient loading-screen read
    -- (GetCurrentDifficultyKey relies on retrying until it resolves); leave it
    -- uncached so GetDifficultyIDCached re-reads live until real data arrives.
    -- Open world legitimately reports 0 and keeps the cached value.
    if inInstance and difficultyID == 0 then
        instanceCache.difficultyID = nil
    end
    local contentType
    if not inInstance then
        contentType = "openWorld"
    elseif instanceType == "raid" then
        contentType = "raid"
    elseif instanceType == "scenario" then
        contentType = "scenario"
    else
        if instanceType == "arena" or instanceType == "pvp" then
            contentType = "pvp"
        else
            contentType = "dungeon"
        end
    end
    instanceCache.contentType = contentType

    -- WoW Forever has no legacy loot mode API.
    instanceCache.legacyInstance = C_Loot.IsLegacyLootModeEnabled ~= nil and C_Loot.IsLegacyLootModeEnabled() or false
    return contentType
end

-- Content type -> row of a per-content grid setting. Other content uses the world row.
local CONTENT_GRID_ROWS = { dungeon = "dungeon", scenario = "dungeon", raid = "raid", pvp = "pvp" }

---Row of the per-content grid settings for the current content.
---@return string
local function GetContentRow()
    return CONTENT_GRID_ROWS[GetCurrentContentType()] or "world"
end

---Whether a per-content grid allows a choice. A saved row holds only the keys
---that the user toggled, and an unchecked choice is stored as false. A missing
---key follows the code default.
---@param setting string Key of the grid in profile.defaults
---@param row string
---@param key string
---@return boolean
local function IsContentChoiceAllowed(setting, row, key)
    local defaults = BR.profile.defaults
    local prefs = defaults and defaults[setting]
    local saved = type(prefs) == "table" and prefs[row]
    local allowed
    if type(saved) == "table" then
        allowed = saved[key]
    end
    if allowed == nil then
        local defaultGrid = BR.defaults.defaults[setting]
        local defaultRow = defaultGrid and defaultGrid[row]
        allowed = defaultRow and defaultRow[key]
    end
    return allowed == true
end

---Raw difficultyID from GetInstanceInfo, cached alongside the content type
---(nil cache = not yet computed, or a transient in-instance 0 left unresolved;
---GetInstanceInfo itself never returns nil here).
---@return number
function GetDifficultyIDCached()
    local id = instanceCache.difficultyID
    if id == nil then
        GetCurrentContentType() -- populates instanceCache.difficultyID (unless transient)
        id = instanceCache.difficultyID
        if id == nil then
            -- Content type already cached while the difficulty read was still
            -- transient: retry live until it resolves, then cache.
            id = select(3, GetInstanceInfo())
            if id ~= 0 then
                instanceCache.difficultyID = id
            end
        end
    end
    return id or 0
end

---Instance identity from GetInstanceInfo plus the active challenge map ID,
---cached alongside the content type (used by loadout instance filters).
---@return string? name
---@return number? instanceID
---@return number? activeChallengeMapID
function BuffState.GetInstanceContext()
    if instanceCache.contentType == nil then
        GetCurrentContentType() -- populates the instance identity fields
    end
    return instanceCache.instanceName, instanceCache.instanceID, instanceCache.activeChallenge
end

---Get the current difficulty key (cached)
---Only caches valid keys; returns nil (retried next call) if the API returns
---an unmapped difficultyID (e.g. 0 during a loading transition).
---@return string? difficultyKey or nil if not in a dungeon/raid or unknown difficulty
local function GetCurrentDifficultyKey()
    if instanceCache.difficultyKey ~= nil then
        return instanceCache.difficultyKey
    end
    local difficultyID = GetDifficultyIDCached()
    local contentType = GetCurrentContentType()
    local diffTable = CONTENT_DIFFICULTY_TABLES[contentType]
    if diffTable then
        local key = diffTable[difficultyID]
        if key then
            instanceCache.difficultyKey = key
        end
        return key
    elseif contentType == "scenario" then
        local key = difficultyID == 208 and "delves" or "others"
        instanceCache.difficultyKey = key
        return key
    elseif contentType == "pvp" then
        local key = instanceCache.instanceType == "arena" and "arena" or "bg"
        instanceCache.difficultyKey = key
        return key
    end
    return nil
end

---Whether a category is visible for the current content type
---@param category CategoryName
---@return boolean
local function IsCategoryVisibleForContent(category, skipReadyCheck)
    if GameContext.IsInVehicle() and category ~= "raid" and category ~= "presence" then
        return false
    end
    local db = BR.profile
    if not db.categoryVisibility then
        return true
    end
    local visibility = db.categoryVisibility[category]
    if not visibility then
        return true
    end
    local contentType = GetCurrentContentType()
    if visibility[contentType] == false then
        return false
    end
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and visibility[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end
    -- Hide category when PvP match is active (past prep phase)
    if contentType == "pvp" and not GameContext.IsPvPPrepPhase() and visibility.hideInPvPMatch then
        return false
    end
    -- Per-category ready check filter (skipped when caller handles ready check independently)
    if not skipReadyCheck then
        local catSettings = db.categorySettings and db.categorySettings[category]
        if catSettings and catSettings.showOnlyOnReadyCheck and not GameContext.IsInReadyCheck() then
            return false
        end
    end
    return true
end

---Whether a custom buff is visible under its per-buff loadConditions
---@param buff CustomBuff
---@return boolean
local function IsCustomBuffVisibleForContent(buff)
    if GameContext.IsInVehicle() then
        return false
    end
    local lc = buff.loadConditions
    if not lc then
        return true
    end -- nil = show everywhere

    local contentType = GetCurrentContentType()
    if lc[contentType] == false then
        return false
    end

    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and lc[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end

    if lc.readyCheckOnly and not GameContext.IsInReadyCheck() then
        return false
    end

    if lc.levelFilter then
        if lc.levelFilter == "maxLevel" and GameContext.GetPlayerLevel() < GameContext.GetMaxExpansionLevel() then
            return false
        elseif
            lc.levelFilter == "belowMaxLevel" and GameContext.GetPlayerLevel() >= GameContext.GetMaxExpansionLevel()
        then
            return false
        end
    end

    return true
end

-- Loadout rule "scope" -> the content type its content must equal. Gear/talents
-- lock once a key or match starts, so scope is just the content bucket (no
-- per-difficulty granularity). "dungeon" covers every dungeon difficulty incl.
-- Mythic+; arena/battleground both live under "pvp" and split on instance type;
-- "delve" lives under "scenario" and splits on difficulty key.
local LOADOUT_SCOPE_CONTENT = {
    openWorld = "openWorld",
    raid = "raid",
    dungeon = "dungeon",
    delve = "scenario",
    arena = "pvp",
    battleground = "pvp",
}

---Whether a loadout rule is visible for the current content. Rules store a
---player-facing `scope` (openWorld / dungeon / delve / raid / arena / battleground) plus an optional
---instance allow-list and a `readyCheckOnly` gate. Scope captures intent directly,
---so there is no deny-list to infer.
---@param rule LoadoutRule
---@return boolean
local function IsLoadoutRuleVisibleForContent(rule)
    if GameContext.IsInVehicle() then
        return false
    end
    local when = rule.when
    if not when then
        return true
    end

    local scope = when.scope
    if scope then
        local needContent = LOADOUT_SCOPE_CONTENT[scope]
        if not needContent then
            -- Unknown or retired scope: hide rather than show in the wrong content.
            return false
        end
        if GetCurrentContentType() ~= needContent then
            return false
        end
        -- Arena and battleground share the "pvp" content type; split on diff key.
        -- Delves share the "scenario" content type with Torghast etc.; split too.
        if scope == "arena" then
            if GetCurrentDifficultyKey() ~= "arena" then
                return false
            end
        elseif scope == "battleground" then
            if GetCurrentDifficultyKey() ~= "bg" then
                return false
            end
        elseif scope == "delve" then
            if GetCurrentDifficultyKey() ~= "delves" then
                return false
            end
        end
    end

    if when.readyCheckOnly and not GameContext.IsInReadyCheck() then
        return false
    end

    return true
end

-- Pre-allocated scope objects for GetTrackingScope (callers only read, never mutate)
local SCOPE_HIDDEN = { show = false, playerOnly = false }
local SCOPE_PLAYER_ONLY = { show = true, playerOnly = true }
local SCOPE_GROUP = { show = true, playerOnly = false }

---Modes that hide buffs from classes other than the player's.
---@param trackingMode string
---@return boolean
local function ModeHidesOtherClasses(trackingMode)
    return trackingMode == "my_buffs" or trackingMode == "self_only"
end

-- Restrictiveness ranking for tracking modes (higher = narrower scope). Drives
-- override resolution: among the base mode and every active context override,
-- the most restrictive (highest rank) wins.
local MODE_RANK = {
    all = 1,
    smart = 2,
    my_buffs = 3,
    personal = 4,
    self_only = 5,
}

---Apply a single context override, keeping whichever mode is more restrictive.
---A nil or "default" override leaves the current mode untouched.
---@param mode string
---@param rank number
---@param override string?
---@return string mode
---@return number rank
local function ApplyOverride(mode, rank, override)
    if override and override ~= "default" then
        local r = MODE_RANK[override]
        if r and r > rank then
            return override, r
        end
    end
    return mode, rank
end

---Resolve the active tracking mode, applying per-context overrides. Each context
---(outside instances, combat, leveling) can narrow the base mode; when several
---apply at once, the most restrictive wins. Overrides only ever narrow - one that
---is wider than the current mode is inert.
---@param db table
---@return string
local function GetEffectiveTrackingMode(db)
    local mode = db.buffTrackingMode or "all"
    local rank = MODE_RANK[mode] or 1

    local outside = db.outsideInstancesMode
    if outside and outside ~= "default" then
        local ct = GetCurrentContentType()
        if ct ~= "raid" and ct ~= "dungeon" and ct ~= "pvp" and ct ~= "scenario" then
            mode, rank = ApplyOverride(mode, rank, outside)
        end
    end
    if GameContext.IsInCombat() then
        mode, rank = ApplyOverride(mode, rank, db.combatMode)
    end
    if GameContext.GetPlayerLevel() < GameContext.GetMaxExpansionLevel() then
        mode = ApplyOverride(mode, rank, db.levelingMode)
    end

    return mode
end

-- Target and copies rules. One table, so that State.lua stays below the 200-local limit.
local BuffTargets = {
    ---@type table<string, BuffTarget>
    DEFAULT_TARGET = { raid = "group", presence = "anyone", targeted = "ally" },
    ---@type table<string, BuffCopies>
    DEFAULT_COPIES = { raid = "any", presence = "any", targeted = "own" },
}

---@param buff table
---@param category "raid"|"presence"|"targeted"
---@return BuffTarget
function BuffTargets.Resolve(buff, category)
    local target = buff.target
    if type(target) == "function" then
        target = target()
    end
    return target or BuffTargets.DEFAULT_TARGET[category]
end

---@param buff table
---@param category "raid"|"presence"|"targeted"
---@return BuffCopies
function BuffTargets.Copies(buff, category)
    return buff.copies or BuffTargets.DEFAULT_COPIES[category]
end

---Whether each cast goes on one unit that the caster picks, so target memory applies.
---@param target BuffTarget
---@return boolean
function BuffTargets.PicksUnit(target)
    return target == "ally" or target == "allyOrSelf" or target == "tankOrSelf"
end

---Whether the player is a valid receiver of the buff. "Just on me" modes show only these buffs.
---@param target BuffTarget
---@return boolean
function BuffTargets.IncludesPlayer(target)
    if target == "ally" then
        return false
    end
    if target == "allyOrSelf" then
        return cachedIsAlone
    end
    return true
end

---Determine visibility and scan scope for a buff based on tracking mode.
---"group" buffs go on everyone, so "scan group" means showing coverage numbers.
---"anyone" buffs need one copy, so "scan group" means finding if anyone has the aura.
---@param trackingMode string
---@param buffClass ClassName
---@param target BuffTarget
---@param hasCaster boolean
---@return { show: boolean, playerOnly: boolean }
local function GetTrackingScope(trackingMode, buffClass, target, hasCaster)
    if not hasCaster then
        return SCOPE_HIDDEN
    end
    if ModeHidesOtherClasses(trackingMode) and buffClass ~= playerClass then
        return SCOPE_HIDDEN
    end
    if target == "ally" and cachedIsAlone then
        return SCOPE_HIDDEN
    end
    if target == "self" then
        return SCOPE_PLAYER_ONLY
    end

    if trackingMode == "self_only" then
        return BuffTargets.IncludesPlayer(target) and SCOPE_PLAYER_ONLY or SCOPE_HIDDEN
    elseif trackingMode == "personal" then
        -- An "anyone" buff of another class sits on its caster, never on the player.
        if target == "anyone" and buffClass ~= playerClass then
            return SCOPE_HIDDEN
        end
        return BuffTargets.IncludesPlayer(target) and SCOPE_PLAYER_ONLY or SCOPE_HIDDEN
    elseif trackingMode == "smart" then
        local isMyClass = buffClass == playerClass
        if target == "group" then
            return isMyClass and SCOPE_GROUP or SCOPE_PLAYER_ONLY
        elseif target == "anyone" and isMyClass then
            return SCOPE_PLAYER_ONLY
        end
        return SCOPE_GROUP
    elseif trackingMode == "my_buffs" then
        return target == "anyone" and SCOPE_PLAYER_ONLY or SCOPE_GROUP
    end
    return SCOPE_GROUP
end

-- ============================================================================
-- BUFF CHECK FUNCTIONS
-- ============================================================================

---Count group members missing a buff
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellIDs SpellID
---@param buffKey? string Used for class benefit filtering
---@param playerOnly? boolean Only check the player, not the group
---@param playersOnly? boolean Exclude NPCs from the count (e.g. buffs NPCs provide themselves)
---@param partyOnly? boolean In a raid, count only the player's subgroup
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@param missingUnits? string[] Wiped, then filled with the unit of each counted member who lacks the buff
---@return number missing
---@return number total
---@return number? minRemaining Remaining time of the copy that Lead.Pick chose
---@return number? minLead Lead of that copy
---@return number? nextSlack Seconds until the next copy enters its window
local function CountMissingBuff(spellIDs, buffKey, playerOnly, playersOnly, partyOnly, threshold, floor, missingUnits)
    if missingUnits then
        wipe(missingUnits)
    end
    local missing = 0
    local total = 0
    local minRemaining, minLead, nextSlack = nil, nil, nil
    local beneficiaries = BuffBeneficiaries[buffKey]
    local specBeneficiaries = SpecBeneficiaries[buffKey]

    if playerOnly or #currentValidUnits <= 1 then
        -- Solo/player-only: check if player benefits (spec-aware)
        if not UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, GetPlayerSpecId(), playerClass) then
            return 0, 0, nil
        end
        total = 1
        local hasBuff, remaining, _, duration = UnitHasBuff("player", GetUnitSpellIDs(buffKey, spellIDs, playerClass))
        if not hasBuff then
            missing = 1
            if missingUnits then
                missingUnits[1] = "player"
            end
        elseif remaining then
            minLead = Lead.Of(duration, threshold, floor)
            minRemaining = minLead and remaining
        end
        return missing, total, minRemaining, minLead
    end

    local countNPCs = includeNPCsInCounting and not GameContext.IsInCombat() and not playersOnly
    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs unless in whitelisted content. During combat, also skip NPCs
        -- here: NPC-cast raid buff spell IDs (e.g. 432661) are not
        -- combat-whitelisted, so UnitHasBuff returns nil and the missing count is
        -- wrong. Targeted buffs use player-cast spell IDs that ARE whitelisted, so
        -- they still include NPCs.
        if (data.isPlayer or countNPCs) and (data.inPlayerParty or not partyOnly) then
            if UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, allySpecCache[data.name], data.class) then
                local hasBuff, remaining, _, duration =
                    UnitHasBuff(data.unit, GetUnitSpellIDs(buffKey, spellIDs, data.class))
                -- A phased ally counts only when the buff is already on them. A
                -- phased member without the buff is an unfixable gap - nobody can
                -- cast on them - so both totals omit them.
                if not (data.isPhased and not hasBuff) then
                    total = total + 1
                    if not hasBuff then
                        missing = missing + 1
                        if missingUnits then
                            -- In a raid the player is a raidN unit. The click target
                            -- picker looks for "player" to cast on the player first.
                            local isSelf = data.unit == "player" or Plain(UnitIsUnit(data.unit, "player")) == true
                            missingUnits[missing] = isSelf and "player" or data.unit
                        end
                    elseif remaining then
                        local lead = Lead.Of(duration, threshold, floor)
                        if lead then
                            minRemaining, minLead, nextSlack =
                                Lead.Pick(remaining, lead, minRemaining, minLead, nextSlack)
                        end
                    end
                end
            end
        end
    end

    return missing, total, minRemaining, minLead, nextSlack
end

---Check if anyone in the group has a presence buff active
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellIDs SpellID
---@param playerOnly? boolean Only check the player, not the group
---@param playerCastOnly? boolean Count only auras cast by the player (copies = "own" for the caster class)
---@param partyOnly? boolean In a raid, look only in the player's subgroup
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@return boolean hasBuff
---@return number? minRemaining Remaining time of the copy that Lead.Pick chose
---@return table? targetEntry First non-player unit entry that has the buff
---@return number? minLead Lead of that copy
---@return number? nextSlack Seconds until the next copy enters its window
local function HasPresenceBuff(spellIDs, playerOnly, playerCastOnly, partyOnly, threshold, floor)
    if playerOnly or #currentValidUnits <= 1 then
        local hasBuff, remaining, duration, _
        if playerCastOnly then
            hasBuff, remaining, duration = UnitHasBuffFromPlayer("player", spellIDs)
        else
            hasBuff, remaining, _, duration = UnitHasBuff("player", spellIDs)
        end
        local lead = remaining and Lead.Of(duration, threshold, floor)
        return hasBuff, lead and remaining, nil, lead
    end

    local minRemaining, minLead, nextSlack = nil, nil, nil
    local found = false
    local targetEntry = nil

    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they cannot receive player buffs
        if (data.isPlayer or includeNPCsInCounting) and (data.inPlayerParty or not partyOnly) then
            local hasBuff, remaining, sourceUnit, duration = UnitHasBuff(data.unit, spellIDs)
            -- With player-cast auras only, another player's cast can mask the
            -- player's own via GetUnitAuraBySpellID. Fall back to a HELPFUL|PLAYER
            -- scan.
            if playerCastOnly and hasBuff and not (sourceUnit and Plain(UnitIsUnit(sourceUnit, "player"))) then
                hasBuff, remaining, duration = UnitHasBuffFromPlayer(data.unit, spellIDs)
            end
            if hasBuff then
                found = true
                if not targetEntry and not Plain(UnitIsUnit(data.unit, "player")) then
                    targetEntry = data
                end
                if not remaining then
                    return true, nil, targetEntry -- no expiration, no need to keep scanning
                end
                local lead = Lead.Of(duration, threshold, floor)
                if lead then
                    minRemaining, minLead, nextSlack = Lead.Pick(remaining, lead, minRemaining, minLead, nextSlack)
                end
            end
        end
    end

    return found, minRemaining, targetEntry, minLead, nextSlack
end

---Assigned role of a group member, or nil when it does not resolve. A secret role
---(secret unit identity) throws on compare, so it reads through Plain and falls
---back to the last plain value seen for this name.
---@param data {unit: string, name: string?}
---@return string?
local function GetUnitRole(data)
    local role = Plain(UnitGroupRolesAssigned(data.unit))
    if not data.name then
        return role
    end
    if role then
        allyRoleCache[data.name] = role
    else
        role = allyRoleCache[data.name]
    end
    return role
end

---Check if player's buff is active on anyone in the group
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellID number
---@param role? RoleType Only check units with this role
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@return boolean
---@return number? minRemaining Remaining time of the copy that Lead.Pick chose
---@return table? targetEntry Unit entry of a non-player target with the buff (for last target cache)
---@return number? minLead Lead of that copy
---@return number? nextSlack Seconds until the next copy enters its window
local function IsPlayerBuffActive(spellID, role, threshold, floor)
    local minRemaining, minLead, nextSlack = nil, nil, nil
    local found = false
    local targetEntry = nil
    local hasBeneficiary = not role
    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they cannot receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            if not role or GetUnitRole(data) == role then
                hasBeneficiary = true
                local hasBuff, remaining, sourceUnit, duration = UnitHasBuff(data.unit, spellID)
                if hasBuff then
                    local isFromPlayer = sourceUnit and Plain(UnitIsUnit(sourceUnit, "player"))
                    if not isFromPlayer then
                        -- GetUnitAuraBySpellID returns one instance. If another
                        -- player cast the same spell (e.g. two Aug Evokers), that
                        -- instance can hide the player's own. Fall back to a full
                        -- aura scan.
                        isFromPlayer, remaining, duration = UnitHasBuffFromPlayer(data.unit, spellID)
                    end
                    if isFromPlayer then
                        found = true
                        if not targetEntry and not Plain(UnitIsUnit(data.unit, "player")) then
                            targetEntry = data
                        end
                        if not remaining then
                            return true, nil, targetEntry
                        end
                        local lead = Lead.Of(duration, threshold, floor)
                        if lead then
                            minRemaining, minLead, nextSlack =
                                Lead.Pick(remaining, lead, minRemaining, minLead, nextSlack)
                        end
                    end
                end
            end
        end
    end
    -- No alive beneficiary with this role -> treat as active (nothing to cast on)
    if not hasBeneficiary then
        return true
    end
    return found, minRemaining, targetEntry, minLead, nextSlack
end

---Reminder state of an "ally" or "allyOrSelf" buff: one copy of the player's cast on any member.
---@param buff TargetedBuff
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@return boolean? shouldShow Returns nil if player can't provide this buff
---@return number? remainingTime
---@return number? lead Lead of the copy that remainingTime reads
---@return number? nextSlack Seconds until the next copy enters its window
local function AllyTargetState(buff, threshold, floor)
    local spellIDs, buffKey, casterBuffId = buff.spellID, buff.key, buff.casterBuffId
    if playerClass ~= buff.class then
        return nil
    end
    if buff.requireSpecId and GetPlayerSpecId() ~= buff.requireSpecId then
        return nil
    end

    local spellID = (type(spellIDs) == "table" and spellIDs[1] or spellIDs) --[[@as number]]
    if not IsPlayerSpellCached(spellID) then
        return nil
    end

    if casterBuffId then
        local hasBuff, remaining, _, duration = UnitHasBuff("player", casterBuffId)
        -- Scan the group for the original buff and record only on a hit. The
        -- target-side spell can be unqueryable (off the aura whitelist in restricted
        -- contexts like M+, or the target is phased / out of range), so a miss is
        -- ambiguous and must NOT forget the memory. Roster pruning handles
        -- departures, and a retarget overwrites on the next successful scan.
        if not GameContext.IsInCombat() and hasBuff then
            for _, data in ipairs(currentValidUnits) do
                if not Plain(UnitIsUnit(data.unit, "player")) then
                    local targetHas = UnitHasBuff(data.unit, spellIDs)
                    if targetHas and data.name then
                        TargetMemory.Observe(buffKey, true, data.name, data.class)
                        break
                    end
                end
            end
        end
        local lead = remaining and Lead.Of(duration, threshold, floor)
        return not hasBuff, lead and remaining, lead
    end

    local isActive, remaining, targetEntry, lead, nextSlack =
        IsPlayerBuffActive(spellID, buff.beneficiaryRole, threshold, floor)

    -- Update target memory (records even in combat: this path only runs for
    -- whitelist-safe queries, gated by IsAuraTrackable at the call site)
    TargetMemory.Observe(buffKey, isActive, targetEntry and targetEntry.name, targetEntry and targetEntry.class)

    return not isActive, remaining, lead, nextSlack
end

---@param data {unit: string, name: string?}
---@return boolean
local function IsUnitTank(data)
    return GetUnitRole(data) == "TANK" or IsMainTank(data.unit)
end

---Reminder state of a "tankOrSelf" buff. The caster checks the first tank who
---lacks the buff, else the player when the group has no tank. A tank of another class
---checks themselves, if a caster who can cast the buff is in the group.
---@param buff TargetedBuff
---@param playerOnly boolean
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@return boolean? shouldShow nil when the player can neither cast nor request the buff
---@return number? remainingTime
---@return number? lead Lead of the copy that remainingTime reads
---@return number? nextSlack Seconds until the next tank copy enters its window
local function TankOrSelfState(buff, playerOnly, threshold, floor)
    local spellIDs = buff.spellID
    if playerClass ~= buff.class then
        if
            not buff.chatRequestable
            or playerOnly
            or cachedIsAlone
            or not IsPlayerTank()
            or not HasCasterForBuff(buff.class, buff.levelRequired)
        then
            return nil
        end
    else
        if not KnowsAnySpell(spellIDs) then
            return nil
        end
        local target, hasTank = nil, false
        local minRemaining, minLead, nextSlack
        if not playerOnly and not cachedIsAlone then
            for _, data in ipairs(currentValidUnits) do
                if (data.isPlayer or includeNPCsInCounting) and IsUnitTank(data) then
                    hasTank = true
                    -- A phased member cannot receive a cast.
                    if not data.isPhased then
                        local has, remaining, _, duration = UnitHasBuff(data.unit, spellIDs)
                        if not has then
                            target = data
                            break
                        end
                        local lead = remaining and Lead.Of(duration, threshold, floor)
                        if remaining and lead then
                            minRemaining, minLead, nextSlack =
                                Lead.Pick(remaining, lead, minRemaining, minLead, nextSlack)
                        end
                    end
                end
            end
        end
        local isSelf = target and (target.unit == "player" or Plain(UnitIsUnit(target.unit, "player")) == true)
        TargetMemory.Observe(buff.key, true, target and not isSelf and target.name or nil, target and target.class)
        if target then
            return true, nil
        end
        if hasTank then
            return false, minRemaining, minLead, nextSlack
        end
    end
    local hasBuff, remaining, _, duration = UnitHasBuff("player", spellIDs)
    local lead = remaining and Lead.Of(duration, threshold, floor)
    return not hasBuff, lead and remaining, lead
end

---Check if player should cast their self buff or weapon imbue (returns true if missing)
---@param buff SelfBuff|CustomBuff
---@param skipSpellKnownCheck? boolean Skip the "player knows spell" check (for custom buffs)
---@param isRestricted? boolean Passed to customCheck
---@return boolean? Returns nil if player can't/shouldn't use this buff
local function ShouldShowSelfBuff(buff, skipSpellKnownCheck, isRestricted)
    local spellID = buff.spellID --[[@as SpellID]]
    local requiredClass, requireSpecId = buff.class, buff.requireSpecId
    local enchantID, requiresSpell, excludeSpell = buff.enchantID, buff.requiresSpellID, buff.excludeSpellID
    local buffIdOverride, customCheck = buff.buffIdOverride, buff.customCheck
    local requiresBuffWithEnchant = buff.requiresBuffWithEnchant
    if requiredClass and playerClass ~= requiredClass then
        return nil
    end
    if requireSpecId and GetPlayerSpecId() ~= requireSpecId then
        return nil
    end

    -- Spell knowledge checks (before spell availability check for talent/ability-gated buffs)
    if requiresSpell and not IsPlayerSpellCached(requiresSpell) then
        return nil
    end
    if excludeSpell and IsPlayerSpellCached(excludeSpell) then
        return nil
    end

    if customCheck then
        return customCheck(isRestricted == true)
    end

    -- For buffs with multiple spellIDs (like shields), check if the player knows ANY of them
    if not skipSpellKnownCheck then
        if type(spellID) == "number" then
            if not IsPlayerSpellCached(spellID) then
                return nil
            end
        else
            local knowsAnySpell = false
            for _, id in ipairs(spellID) do
                if IsPlayerSpellCached(id) then
                    knowsAnySpell = true
                    break
                end
            end
            if not knowsAnySpell then
                return nil
            end
        end
    end

    -- Weapon imbue: check if an accepted enchant is on either weapon
    if enchantID then
        local hasEnchant = EnchantMatches(enchantID, currentWeaponEnchants.mainHandID)
            or EnchantMatches(enchantID, currentWeaponEnchants.offHandID)

        -- For Paladin Rites: require BOTH enchant AND buff (Blizzard bug workaround)
        if requiresBuffWithEnchant then
            local hasBuff, _ = UnitHasBuff("player", buffIdOverride or spellID)
            return not (hasEnchant and hasBuff)
        end

        return not hasEnchant
    end

    local hasBuff, _ = UnitHasBuff("player", buffIdOverride or spellID)
    return not hasBuff
end

local EATING_AURA_ICON = BR.EATING_AURA_ICON

-- Event-driven eating state: tracked via UNIT_AURA payload, no per-render scanning.
local eatingAuraInstanceID = nil

---Check if the player is currently eating (reads cached flag, O(1))
---@return boolean
local function IsPlayerEating()
    return eatingAuraInstanceID ~= nil
end

---Full aura scan to seed eating state (call once on init / reload)
local function ScanEatingState()
    eatingAuraInstanceID = nil
    local i = 1
    local auraData = AuraByIndex("player", i, "HELPFUL")
    while auraData do
        if AuraMatchesIcon(auraData, EATING_AURA_ICON) then
            eatingAuraInstanceID = AuraField(auraData, "auraInstanceID")
            return
        end
        i = i + 1
        auraData = AuraByIndex("player", i, "HELPFUL")
    end
end

---Update eating state from UNIT_AURA payload (called on every player UNIT_AURA)
---@param updateInfo table? The updateInfo payload from UNIT_AURA
local function UpdateEatingState(updateInfo)
    if not updateInfo then
        return
    end
    -- A UNIT_AURA list container can itself be a secret value in restricted
    -- contexts. AuraList yields an empty list then, so a secret payload is
    -- skipped. ScanEatingState re-syncs on combat end, and eating cannot start in
    -- combat, so a skip here loses nothing.
    for _, aura in ipairs(AuraList(updateInfo.addedAuras)) do
        if AuraField(aura, "icon") == EATING_AURA_ICON then
            eatingAuraInstanceID = AuraField(aura, "auraInstanceID")
            break
        end
    end
    if eatingAuraInstanceID then
        for _, id in ipairs(AuraList(updateInfo.removedAuraInstanceIDs)) do
            if Plain(id) == eatingAuraInstanceID then
                eatingAuraInstanceID = nil
                break
            end
        end
    end
end

---Get expiration time of the eating aura (O(1) lookup via cached instance ID).
---eatingAuraInstanceID is always a plain value (only ever assigned via AuraField).
---AuraByInstanceID guards the lookup (the call throws in restricted contexts); the
---returned struct's field can still be secret, hence AuraField.
---@return number? expirationTime GetTime()-based expiration, nil if not eating or no duration
local function GetEatingExpirationTime()
    if not eatingAuraInstanceID then
        return nil
    end
    local auraData = AuraByInstanceID("player", eatingAuraInstanceID)
    local exp = AuraField(auraData, "expirationTime")
    if not exp or exp == 0 then
        return nil
    end
    return exp
end

---Check if a consumable buff is free/reusable (freeConsumable flag, or a permanent item of its category in bags)
---@param buff ConsumableBuff
---@return boolean
local function IsFreeConsumable(buff)
    if buff.freeConsumable then
        return true
    end
    local items = buff.consumableCategory and BR.CONSUMABLE_ITEMS[buff.consumableCategory]
    if items then
        for itemID, entry in pairs(items) do
            if type(entry) == "table" and entry.permanent and HasItemByMode(itemID) then
                return true
            end
        end
    end
    return false
end

---Whether a free consumable is visible under its override visibility settings
---@param db table Database settings
---@return boolean
local function IsFreeConsumableVisible(db)
    if GameContext.IsInVehicle() then
        return false
    end
    local vis = db.defaults and db.defaults.freeConsumableVisibility
    if not vis then
        return true
    end
    local contentType = GetCurrentContentType()
    if vis[contentType] == false then
        return false
    end
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and vis[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end
    -- PvP match hiding follows the consumable category's setting
    if contentType == "pvp" and not GameContext.IsPvPPrepPhase() then
        local catVis = db.categoryVisibility and db.categoryVisibility.consumable
        if catVis and catVis.hideInPvPMatch then
            return false
        end
    end
    return true
end

---Check if the player is in competitive PvP (arena or rated battleground)
---Consumables flagged disabledInCompetitivePvP are hidden here.
---@return boolean
local function IsInCompetitivePvP()
    if instanceCache.competitivePvP ~= nil then
        return instanceCache.competitivePvP
    end
    local contentType = GetCurrentContentType()
    if contentType ~= "pvp" then
        instanceCache.competitivePvP = false
        return false
    end
    local result = instanceCache.instanceType == "arena" or C_PvP.IsRatedMap() == true
    instanceCache.competitivePvP = result
    return result
end

-- Aura spell of the consumable the player runs now, per consumable category. The
-- bag sort puts the matching item first, so a refresh drinks the same consumable.
---@type table<string, number>
local activeConsumableSpells = {}

local function SetActiveConsumableSpell(category, spellID)
    if activeConsumableSpells[category] == spellID then
        return
    end
    activeConsumableSpells[category] = spellID
    BR.CallbackRegistry:TriggerEvent("ActiveConsumableChanged", category, spellID)
end

---Check if player is missing a consumable buff, weapon enchant, or inventory item (returns true if missing)
---@param buff table Consumable buff definition
---@return boolean shouldShow
---@return number? remainingTime seconds remaining if buff is present and has a duration
---@return number? activeSpellID the specific spell ID that matched (for multi-spell consumables)
---@return number? itemCount total count of items in inventory (for item-based consumables)
---@return number? duration Full duration of the matched aura. A weapon enchant reports nil
local function ShouldShowConsumableBuff(buff)
    if buff.spellID then
        local category = buff.consumableCategory
        for _, id in ipairs(AsSpellList(buff.spellID)) do
            local hasBuff, remaining, _, duration = UnitHasBuff("player", id)
            if hasBuff then
                local CM = BR.ConsumableMemory
                -- A count-tracked category remembers the item use spell, which can
                -- differ from the aura (a food applies Well Fed).
                if CM and category and not CM.IsCountTracked(category) and not CM.IsUnrememberedSpell(id) then
                    CM.Remember(GetPlayerSpecId(), category, id, true)
                end
                if category then
                    SetActiveConsumableSpell(category, id)
                end
                return false, remaining, id, nil, duration -- Has at least one of the consumable buffs
            end
        end
        if category then
            SetActiveConsumableSpell(category, nil)
        end
    end

    -- Check buff auras by icon ID (e.g., food buffs all use icon 136000)
    if buff.buffIconID then
        local i = 1
        local auraData = AuraByIndex("player", i, "HELPFUL")
        while auraData do
            if AuraMatchesIcon(auraData, buff.buffIconID) then
                local remaining = nil
                local exp = AuraField(auraData, "expirationTime")
                if exp and exp > 0 then
                    remaining = exp - GetTime()
                end
                return false, remaining, nil, nil, AuraField(auraData, "duration") -- Has a buff with this icon
            end
            i = i + 1
            auraData = AuraByIndex("player", i, "HELPFUL")
        end
    end

    -- Check if any weapon enchant exists (oils, stones, shaman imbues, etc.)
    if buff.checkWeaponEnchant and currentWeaponEnchants.mainHandTempID then
        local exp = currentWeaponEnchants.mainHandTempExpiration
        return false, exp and exp / 1000 or nil
    end

    if buff.checkWeaponEnchantOH and currentWeaponEnchants.offHandTempID then
        local exp = currentWeaponEnchants.offHandTempExpiration
        return false, exp and exp / 1000 or nil
    end

    -- Check inventory for item (counts cached, invalidated on bag/equipment events)
    if buff.itemID then
        local itemID = buff.itemID
        local live = buff.itemHasCharges
        local totalCount
        if type(itemID) == "table" then
            totalCount = 0
            for _, id in ipairs(itemID) do
                totalCount = totalCount + GetItemCountCached(id, live)
            end
        else
            totalCount = GetItemCountCached(itemID, live)
        end
        if totalCount > 0 then
            return false, nil, nil, totalCount -- Has the item in inventory
        end
    end

    -- Nothing to check: report not missing.
    if
        not buff.spellID
        and not buff.buffIconID
        and not buff.checkWeaponEnchant
        and not buff.checkWeaponEnchantOH
        and not buff.itemID
    then
        return false, nil
    end

    return true, nil -- Missing all consumable buffs/enchants/items
end

---Check if buff passes common pre-conditions
---@param buff table Any buff type with optional pre-check fields
---@param presentClasses? table<ClassName, boolean>
---@param db table Database settings
---@param trackingMode string Effective tracking mode (already resolved once per refresh)
---@return boolean passes
local function PassesPreChecks(buff, presentClasses, db, trackingMode)
    if buff.visibilityCondition and not buff.visibilityCondition() then
        return false
    end

    -- Ready check gate (for readyCheckOnly buffs like presence buffs)
    if buff.readyCheckOnly and not GameContext.IsInReadyCheck() then
        local overrides = db.readyCheckOnlyOverrides
        local settingKey = buff.groupId or buff.key
        if not overrides or overrides[settingKey] ~= false then
            return false
        end
    end

    if buff.class then
        if ModeHidesOtherClasses(trackingMode) and buff.class ~= playerClass then
            return false
        end
        if presentClasses and not presentClasses[buff.class] then
            return false
        end
    end

    if buff.excludeSpellID and IsPlayerSpellCached(buff.excludeSpellID) then
        return false
    end

    if buff.excludeIfSpellKnown then
        for _, spellID in ipairs(buff.excludeIfSpellKnown) do
            if IsPlayerSpellCached(spellID) then
                return false
            end
        end
    end

    return true
end

-- ============================================================================
-- BUFF STATE API
-- ============================================================================

---Get a single entry by key
---@param key string
---@return BuffStateEntry?
function BuffState.GetEntry(key)
    return BuffState.entries[key]
end

---@class VisibleEntryList: { [integer]: BuffStateEntry }
---@field _sorted? boolean True when the entries are already in sortOrder

---Pre-built per-category lists of visible entries (populated by Refresh)
---@type table<CategoryName, VisibleEntryList>
BuffState.visibleByCategory = {}

---Create or update an entry
---@param key string
---@param category CategoryName
---@param sortOrder? number Position within category for display ordering
---@return BuffStateEntry
local function GetOrCreateEntry(key, category, sortOrder)
    if not BuffState.entries[key] then
        ---@type BuffStateEntry
        BuffState.entries[key] = {
            key = key,
            category = category,
            sortOrder = sortOrder or 0,
            visible = false,
            displayType = "text",
            shouldGlow = false,
        }
    end
    return BuffState.entries[key]
end

---Mark an entry as visible with overlay text and optional glow
---@param entry BuffStateEntry
---@param overlayText? string
---@param glowEnabled boolean
local function SetEntryText(entry, overlayText, glowEnabled)
    entry.visible = true
    entry.displayType = "text"
    entry.overlayText = overlayText
    entry.shouldGlow = glowEnabled
end

---Get glow settings for a category (hoisted to module level to avoid closure allocation)
---@param cat CategoryName
---@return boolean expiringGlow
---@return boolean missingGlow
---@return number threshold Seconds
---@return number floor Seconds of the pre-key threshold in an M0 dungeon, else 0
local function GetCategoryGlowSettings(cat)
    local expiringGlow = BR.Config.GetCategorySetting(cat, "showExpirationGlow") ~= false
    local missingGlow = BR.Config.GetCategorySetting(cat, "showMissingGlow") ~= false
    local threshold = (BR.Config.GetCategorySetting(cat, "expirationThreshold") or 15) * 60
    -- In an M0 dungeon (before a keystone goes in), the pre-key threshold forces a refresh.
    local defs = BR.profile and BR.profile.defaults
    Lead.share = (defs and defs.expirationShare or 25) / 100
    local preKey = defs and defs.preKeyThreshold or 0
    local floor = 0
    if preKey > 0 and GetCurrentContentType() == "dungeon" and GetCurrentDifficultyKey() == "mythic" then
        floor = preKey * 60
    end
    return expiringGlow, missingGlow, threshold, floor
end

-- Seconds until the earliest display change that no event announces: the countdown
-- text ticks a minute, remaining time crosses the warning lead, an
-- expiring buff runs out, or item charges change.
-- Accumulated per refresh; Display arms one timer for it instead of polling.
local nextTimedChangeIn = nil

---@param seconds number
local function NoteChangeIn(seconds)
    if not nextTimedChangeIn or seconds < nextTimedChangeIn then
        nextTimedChangeIn = seconds
    end
end

---@param remaining? number
---@param lead number
---@param nextSlack? number Seconds until another copy enters its window
local function NoteTimedChange(remaining, lead, nextSlack)
    if nextSlack and nextSlack > 0 then
        NoteChangeIn(nextSlack)
    end
    if not remaining or remaining <= 0 then
        return
    end
    local candidate
    if remaining >= lead then
        candidate = remaining - lead -- future crossing into "expiring"
    elseif remaining > 60 then
        candidate = remaining % 60 -- next minute tick of the countdown text
        if candidate == 0 then
            candidate = 60
        end
    else
        candidate = remaining -- "<1m": the expiry itself is the next change
    end
    NoteChangeIn(candidate)
end

-- Item charges change with no event of their own, so the low-stock warning looks
-- again on this cadence while it shows.
local CHARGE_RECHECK = 3

---Seconds until the earliest time-driven display change found by the last
---refresh, or nil when nothing tracked expires.
---@return number?
function BuffState.GetNextTimedChange()
    return nextTimedChangeIn
end

---If remaining time is below the lead, mark entry as visible+expiring with glow.
---@param entry BuffStateEntry
---@param remaining? number
---@param lead? number Lead.Of of the aura, nil when it never warns
---@param shouldGlow boolean
---@param nextSlack? number Seconds until another copy enters its window
---@return boolean wasSet true if the entry was marked as expiring
local function TrySetEntryExpiring(entry, remaining, lead, shouldGlow, nextSlack)
    if not lead then
        -- A weapon enchant ends with no event, so the expiry needs its own render.
        if remaining and remaining > 0 then
            NoteChangeIn(remaining)
        end
        return false
    end
    NoteTimedChange(remaining, lead, nextSlack)
    if remaining and remaining < lead then
        entry.visible = true
        entry.displayType = "expiring"
        entry.countText = FormatRemainingTime(remaining)
        entry.shouldGlow = shouldGlow
        return true
    end
    return false
end

---Check if any of a buff's spell IDs are glowing on the action bar.
---This path replaces ShouldShow* in restricted contexts, so it repeats the spec
---and spell-known gates. Without them a glow flag for an uncastable spell shows
---a reminder.
---@param buff table Buff entry with spellID field
---@return boolean
local function IsAnySpellGlowing(buff)
    if buff.requireSpecId and GetPlayerSpecId() ~= buff.requireSpecId then
        return false
    end
    local spellID = buff.spellID
    if not spellID then
        return false
    end
    if type(spellID) == "table" then
        for _, id in ipairs(spellID) do
            if IsPlayerSpellCached(id) and GameContext.IsSpellGlowing(id) then
                return true
            end
        end
        return false
    end
    return IsPlayerSpellCached(spellID) and GameContext.IsSpellGlowing(spellID)
end

-- The members who lack a castOnMissing buff, by buff key. The click picks its
-- target from this list, so only a buff that the player can cast fills one.
---@type table<string, string[]>
local missingUnitsByKey = {}

---@param buff RaidBuff
---@param isAuraRestricted boolean A restricted aura read returns nil, so every member reads as missing
---@return string[]? list Empty list to fill, or nil when the buff needs none
local function AcquireMissingUnits(buff, isAuraRestricted)
    if not buff.castOnMissing then
        return nil
    end
    local list = missingUnitsByKey[buff.key]
    if list then
        wipe(list)
    end
    if isAuraRestricted or buff.class ~= playerClass then
        return nil
    end
    local known = false
    local spellIDs = AsSpellList(buff.spellID)
    for i = 1, #spellIDs do
        if IsPlayerSpellCached(spellIDs[i]) then
            known = true
            break
        end
    end
    if not known then
        return nil
    end
    if not list then
        list = {}
        missingUnitsByKey[buff.key] = list
    end
    return list
end

---Units that lacked the buff at the last refresh. The player, if listed, is "player".
---@param key string
---@return string[]?
function BuffState.GetMissingUnits(key)
    return missingUnitsByKey[key]
end

---A secret or unchecked range reads as out of range.
---@param unit string
---@return boolean
local function IsMissingUnitInRange(unit)
    return unit == "player" or Plain(UnitInRange(unit)) == true
end

---@class ClassChoiceState
---@field missing number Members who lack their choice at the last refresh
---@field lists table<string, StanceChoice[]> Known choices of each class list, read once per refresh
---@field wanted table<string, StanceChoice> The choice that each listed member wants
---@field classes table<string, string> The class of each listed member
---@field classWant table<string, StanceChoice|false> The choice that every counted member of a class wants. false when they differ
---@field inRange table<string, boolean> Range of each listed member, read once per pick
---@field selfWanted StanceChoice? The choice that the player lacks
---@field renewUnits string[] Members whose choice from the player is in its warning window. Filled only when sources are read
---@field renewChoices table<string, StanceChoice>
---@field renewRemaining table<string, number>
---@field foreign table<string, table<string, table|false>> Foreign copies found by a scan, by unit, then choice key. Survives refreshes

-- By buff key. A classChoices buff fills its state with its missing-units list.
---@type table<string, ClassChoiceState>
local classChoiceStates = {}

---The first choice of the list that no other caster gives the unit. Without a
---source read, a choice on the unit counts as cast by the player.
---@param unit string
---@param choices StanceChoice[]
---@param readSources boolean Only out of combat, because source reads need plain aura data
---@param memo? table<string, table<string, table|false>> Scan results by unit, then choice key. nil = no scan, because no other caster is in the group
---@return StanceChoice? wanted nil when other casters give every choice
---@return boolean has The unit has the wanted choice from the player
---@return number? remaining
---@return number? duration
local function WantedChoice(unit, choices, readSources, memo)
    for i = 1, #choices do
        local choice = choices[i]
        local auraIDs = choice.auraIDs or choice.spellIDs
        local has, remaining, sourceUnit, duration = UnitHasBuff(unit, auraIDs)
        if not has then
            return choice, false
        end
        if not readSources then
            return choice, true, remaining, duration
        end
        -- The same choice from two casters does not stack, so a foreign instance
        -- covers the unit, also when the player's own instance is present.
        -- GetUnitAuraBySpellID returns one instance, so only a scan finds a second one.
        -- A caster outside the group reads as a nil source on that one instance.
        if sourceUnit and Plain(UnitIsUnit(sourceUnit, "player")) == true then
            local foreign = false ---@type table|false
            local unitMemo = memo and memo[unit]
            local known = unitMemo and unitMemo[choice.key]
            if known ~= nil then
                foreign = known
            elseif memo then
                local index = 1
                local aura = AuraByIndex(unit, index, "HELPFUL")
                while aura do
                    local source = AuraField(aura, "sourceUnit")
                    if
                        AuraMatchesSpellIDs(aura, nil, auraIDs)
                        and not (source and Plain(UnitIsUnit(source, "player")) == true)
                    then
                        foreign = aura
                        break
                    end
                    index = index + 1
                    aura = AuraByIndex(unit, index, "HELPFUL")
                end
                -- The player gets no group UNIT_AURA, which clears an entry, so the
                -- player is scanned on each refresh.
                if unit ~= "player" and Plain(UnitIsUnit(unit, "player")) ~= true then
                    if not unitMemo then
                        unitMemo = {}
                        memo[unit] = unitMemo
                    end
                    unitMemo[choice.key] = foreign
                end
            end
            if not foreign then
                return choice, true, remaining, duration
            end
            -- The removal of the foreign copy must refresh the group.
            if unit ~= "player" then
                RecordAuraInstance(unit, foreign)
            end
        end
    end
    return nil, false
end

---Count the group members who lack the choice that they want from the player.
---A member of a class with an empty list does not count.
---@param buff RaidBuff
---@param playerOnly boolean Only check the player, not the group
---@param threshold number Input of Lead.Of
---@param floor number Input of Lead.Of
---@param missingUnits? string[] Wiped, then filled with the unit of each counted member who lacks the choice
---@param readSources boolean Tell the choices of the player from the choices of other casters
---@return number missing
---@return number total
---@return number? minRemaining Remaining time of the copy that Lead.Pick chose
---@return StanceChoice? choice Wanted by the first missing member, else the choice closest to its warning
---@return number? minLead Lead of that copy
---@return number? nextSlack Seconds until the next copy enters its window
local function CountMissingClassChoice(buff, playerOnly, threshold, floor, missingUnits, readSources)
    local state = classChoiceStates[buff.key]
    if state then
        wipe(state.lists)
        wipe(state.wanted)
        wipe(state.classes)
        wipe(state.classWant)
        wipe(state.renewUnits)
        wipe(state.renewChoices)
        wipe(state.renewRemaining)
        state.selfWanted = nil
    else
        state = {
            missing = 0,
            lists = {},
            wanted = {},
            classes = {},
            classWant = {},
            inRange = {},
            renewUnits = {},
            renewChoices = {},
            renewRemaining = {},
            foreign = {},
        }
        classChoiceStates[buff.key] = state
    end
    if missingUnits then
        wipe(missingUnits)
    end

    local forClass = buff.classChoices.forClass
    local lists = state.lists
    local selfOnly = playerOnly or #currentValidUnits <= 1
    local partyOnly = buff.reach == "party"
    local countNPCs = includeNPCsInCounting and not GameContext.IsInCombat() and not buff.playersOnly
    local missing, total, minRemaining, firstWanted, minChoice, minLead, nextSlack = 0, 0, nil, nil, nil, nil, nil
    -- The roster includes the player, so a second member of the class is another caster.
    local casters = 0
    for _, data in ipairs(currentValidUnits) do
        if data.class == buff.class then
            casters = casters + 1
        end
    end
    local memo = readSources and casters > 1 and state.foreign or nil
    for _, data in ipairs(currentValidUnits) do
        local class = data.class
        local isSelf = data.unit == "player" or (selfOnly and Plain(UnitIsUnit(data.unit, "player")) == true)
        if
            class
            and (isSelf or not selfOnly)
            and (data.isPlayer or countNPCs)
            and (data.inPlayerParty or not partyOnly)
        then
            local choices = lists[class]
            if not choices then
                choices = forClass(class)
                lists[class] = choices
            end
            if #choices > 0 then
                local choice, has, remaining, duration = WantedChoice(data.unit, choices, readSources, memo)
                -- A phased member cannot receive a cast, so a gap on them does not count.
                if not (data.isPhased and choice and not has) then
                    total = total + 1
                    if choice then
                        local want = state.classWant[class]
                        if want == nil then
                            state.classWant[class] = choice
                        elseif want ~= choice then
                            state.classWant[class] = false
                        end
                    end
                    if choice and not has then
                        missing = missing + 1
                        firstWanted = firstWanted or choice
                        -- In a raid the player is a raidN unit. The range check reads "player" as in range.
                        local listed = data.unit
                        if isSelf or Plain(UnitIsUnit(listed, "player")) == true then
                            listed = "player"
                            state.selfWanted = choice
                        end
                        if missingUnits then
                            missingUnits[missing] = listed
                            state.wanted[listed] = choice
                            state.classes[listed] = class
                        end
                    elseif has and remaining and not data.isPhased then
                        local lead = Lead.Of(duration, threshold, floor)
                        if lead then
                            minRemaining, minLead, nextSlack =
                                Lead.Pick(remaining, lead, minRemaining, minLead, nextSlack)
                            if minRemaining == remaining and minLead == lead then
                                minChoice = choice
                            end
                        end
                        -- Without a source read, the copy can come from another caster.
                        if lead and readSources and remaining < lead then
                            state.renewUnits[#state.renewUnits + 1] = data.unit
                            state.renewChoices[data.unit] = choice
                            state.renewRemaining[data.unit] = remaining
                        end
                    end
                end
            end
        end
    end
    state.missing = missing
    return missing, total, minRemaining, firstWanted or minChoice, minLead, nextSlack
end

---A member of the largest set of listed members who share a class and want the same
---choice. Members in range come first. Runs on a click and on a refresh that shows the icon.
---@param key string
---@return string? unit
---@return StanceChoice? choice
---@return number count Members in the set
local function PickChoiceTarget(key)
    local units = missingUnitsByKey[key]
    local state = classChoiceStates[key]
    if not units or not units[1] or not state then
        return nil, nil, 0
    end
    local wanted, classes, inRange = state.wanted, state.classes, state.inRange
    wipe(inRange)
    local anyInRange = false
    for i = 1, #units do
        local unitInRange = IsMissingUnitInRange(units[i])
        inRange[units[i]] = unitInRange
        anyInRange = anyInRange or unitInRange
    end
    local bestUnit, bestCount = nil, 0
    for i = 1, #units do
        local unit = units[i]
        if inRange[unit] or not anyInRange then
            local count = 0
            for j = 1, #units do
                local other = units[j]
                if
                    (inRange[other] or not anyInRange)
                    and wanted[other] == wanted[unit]
                    and classes[other] == classes[unit]
                then
                    count = count + 1
                end
            end
            if count > bestCount then
                bestUnit, bestCount = unit, count
            end
        end
    end
    return bestUnit, bestUnit and wanted[bestUnit], bestCount
end

---Single-target cast of a click on a classChoices buff: the picked choice and its
---target. With no member missing, it renews the expiring choice that ends first on a
---member in range. If the target of a missing choice is unknown, only the choice
---that the player lacks is cast. nil = the click casts nothing.
---@param buff RaidBuff
---@return number? spellID
---@return string? unit
function BuffState.GetChoiceCast(buff)
    local state = classChoiceStates[buff.key]
    if not state then
        return nil
    end
    local unit, choice = PickChoiceTarget(buff.key)
    if unit and choice then
        return buff.classChoices.castID(choice), unit
    end
    if state.missing > 0 then
        if not state.selfWanted then
            return nil
        end
        return buff.classChoices.castID(state.selfWanted), "player"
    end
    local renewUnits, renewRemaining = state.renewUnits, state.renewRemaining
    for i = 1, #renewUnits do
        local candidate = renewUnits[i]
        if
            (not unit or renewRemaining[candidate] < renewRemaining[unit])
            and (IsMissingUnitInRange(candidate) or Plain(UnitIsUnit(candidate, "player")) == true)
        then
            unit = candidate
        end
    end
    if not unit then
        return nil
    end
    return buff.classChoices.castID(state.renewChoices[unit]), unit
end

---Members whose choice from the player expires soon. The list is reused.
---@param key string
---@return string[]?
function BuffState.GetChoiceRenewUnits(key)
    local state = classChoiceStates[key]
    return state and state.renewUnits
end

---Highest group rank of the buff that the player knows and has the reagent for, and
---its target, when the user turned on the group cast and enough members lack the buff.
---A group rank reaches only the party of its target. In a raid, each subgroup is a
---party. The rank goes on the player, so only the in-range members of the player's party count.
---A classChoices buff casts the group rank of the picked choice on a member of its
---class, because that rank reaches only the class of its target. Every counted member
---of that class must want the choice, because the group rank replaces the choice
---that the player gives each of them.
---@param buff RaidBuff
---@return number? spellID
---@return string? unit
function BuffState.GetGroupCastSpellID(buff)
    local enabled = BR.profile.groupCast
    local missingUnits = missingUnitsByKey[buff.key]
    local defaults = BR.profile.defaults
    local minCount = defaults and defaults.groupCastMin or 2
    if not (enabled and enabled[buff.key]) or not missingUnits or #missingUnits < minCount then
        return nil
    end
    local ranks = buff.groupCast
    local unit = "player" ---@type string?
    if buff.classChoices then
        local choice, count
        unit, choice, count = PickChoiceTarget(buff.key)
        local state = classChoiceStates[buff.key]
        if
            not unit
            or not choice
            or count < minCount
            or not state
            or state.classWant[state.classes[unit]] ~= choice
        then
            return nil
        end
        ranks = choice.groupCast
    else
        local subgroups = IsInRaid() and GetRaidSubgroups()
        local playerGroup = subgroups and subgroups.player
        if subgroups and not playerGroup then
            return nil
        end
        local count = 0
        for i = 1, #missingUnits do
            local member = missingUnits[i]
            if (not subgroups or subgroups[member] == playerGroup) and IsMissingUnitInRange(member) then
                count = count + 1
            end
        end
        if count < minCount then
            return nil
        end
    end
    if not ranks then
        return nil
    end
    local spellID = BuffState.GetGroupRank(ranks)
    if spellID then
        return spellID, unit
    end
    return nil
end

---Highest rank in the list that the player knows and has the reagent for.
---@param ranks GroupCastRank[]
---@return number? spellID nil when no known rank has its reagent in the bags
---@return boolean known The player knows a rank of the list
function BuffState.GetGroupRank(ranks)
    -- The spellbook reports only the highest learned rank as known. A lower rank is
    -- known when a higher one is.
    local known = false
    for i = 1, #ranks do
        local rank = ranks[i]
        known = known or IsPlayerSpellCached(rank.spellID)
        if known and GetItemCountCached(rank.reagent) > 0 then
            return rank.spellID, true
        end
    end
    return nil, known
end

-- Coverage category: the reminder counts how many group members miss the buff.
local function RefreshRaid(db, trackingMode, isAuraRestricted, hideExpiring, expiringClass, missingCountOnly)
    local raidVisible = IsCategoryVisibleForContent("raid")
    local raidExGlow, raidMissGlow, raidThreshold, raidFloor = GetCategoryGlowSettings("raid")
    local bronzeHiddenInCombat = GameContext.IsInCombat() and db.bronzeHideInCombat
    local readSources = not isAuraRestricted and not GameContext.IsInCombat()
    for i, buff in ipairs(RaidBuffs) do
        local entry = GetOrCreateEntry(buff.key, "raid", i)
        local missingUnits = AcquireMissingUnits(buff, isAuraRestricted)
        local scope = GetTrackingScope(
            trackingMode,
            buff.class,
            BuffTargets.Resolve(buff, "raid"),
            HasCasterForBuff(buff.class, buff.levelRequired, buff.reach)
        )
        local requester = buff.chatRequestSpell ~= nil and playerClass ~= buff.class
        local playerOnly = requester or scope.playerOnly

        if
            not (bronzeHiddenInCombat and buff.key == "bronze")
            and IsBuffEnabled(buff.key)
            and (not isAuraRestricted or IsAuraTrackable(buff))
            and raidVisible
            and scope.show
            and (not requester or (readSources and db.requestBuffInChat == true))
            and (not buff.requiresKnownSpell or requester or KnowsAnySpell(buff.castSpellID or buff.spellID))
            -- A caster who did not learn the buff yet cannot cast it.
            and (buff.class ~= playerClass or requester or KnowsAnySpell(buff.castSpellID or buff.spellID))
            and (not buff.visibilityCondition or buff.visibilityCondition())
        then
            local missing, total, minRemaining, choice, minLead, nextSlack
            if requester then
                -- Any copy of the buff covers the player, so only a missing buff shows.
                local spellID = buff.chatRequestSpell()
                missing, total = 0, 0
                if spellID then
                    missing, total = CountMissingBuff(
                        buff.spellID,
                        buff.key,
                        true,
                        buff.playersOnly,
                        false,
                        raidThreshold,
                        raidFloor,
                        missingUnits
                    )
                end
                if missing > 0 then
                    entry.dynamicIcon = BR.Icons.GetBuffTexture(spellID)
                end
            elseif buff.classChoices then
                missing, total, minRemaining, choice, minLead, nextSlack =
                    CountMissingClassChoice(buff, playerOnly, raidThreshold, raidFloor, missingUnits, readSources)
            else
                missing, total, minRemaining, minLead, nextSlack = CountMissingBuff(
                    buff.spellID,
                    buff.key,
                    playerOnly,
                    buff.playersOnly,
                    buff.reach == "party",
                    raidThreshold,
                    raidFloor,
                    missingUnits
                )
            end

            if missing > 0 then
                entry.visible = true
                entry.displayType = "count"
                local buffed = total - missing
                entry.countText = playerOnly and ""
                    or (missingCountOnly and tostring(missing) or (buffed .. "/" .. total))
                entry.shouldGlow = raidMissGlow
                if minLead then
                    NoteTimedChange(minRemaining, minLead, nextSlack)
                end
            elseif not hideExpiring and (not expiringClass or buff.class == expiringClass) then
                TrySetEntryExpiring(entry, minRemaining, minLead, raidExGlow, nextSlack)
            end
            -- If a click casts a choice, the icon shows that choice.
            if choice and entry.visible then
                local castID = BuffState.GetChoiceCast(buff) or buff.classChoices.castID(choice)
                if castID then
                    entry.dynamicIcon = BR.Icons.GetBuffTexture(castID)
                end
            end
        end
    end
end

-- The player's own buffs on themselves, weapon imbues included.
local function RefreshSelf(isAuraRestricted, hideExpiring)
    local selfVisible = IsCategoryVisibleForContent("self")
    local selfExGlow, selfMissGlow, selfThreshold, selfFloor = GetCategoryGlowSettings("self")
    for i, buff in ipairs(SelfBuffs) do
        local entry = GetOrCreateEntry(buff.key, "self", i)
        local settingKey = buff.groupId or buff.key

        if
            selfVisible
            and IsBuffEnabled(settingKey)
            and (not buff.visibilityCondition or buff.visibilityCondition())
        then
            local trackable = IsAuraTrackable(buff)
            local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
            if not isAuraRestricted or trackable or useGlowDet then
                if useGlowDet then
                    if IsAnySpellGlowing(buff) then
                        SetEntryText(entry, buff.overlayText, selfMissGlow)
                        BR.Icons.ApplyDynamicIcon(entry, buff)
                    end
                else
                    local shouldShow = ShouldShowSelfBuff(buff, false, isAuraRestricted)
                    -- showWhenPresent inverts the logic (e.g., Burning Rush: show when active)
                    local wantPresent = buff.showWhenPresent
                    local show = (wantPresent and shouldShow == false) or (not wantPresent and shouldShow)
                    if show then
                        SetEntryText(entry, buff.overlayText, selfMissGlow)
                        BR.Icons.ApplyDynamicIcon(entry, buff)
                    elseif
                        shouldShow == false
                        and not wantPresent
                        and not buff.noExpirationGlow
                        and not hideExpiring
                    then
                        -- Buff present: check whether it expires soon.
                        -- Weapon imbues (paladin rites, shaman imbues) time
                        -- out on the enchant, not an aura.
                        local remaining, expiringCastID, duration
                        if buff.enchantID then
                            remaining = GetWeaponEnchantRemaining(buff.enchantID)
                            duration = buff.enchantDuration
                        elseif buff.getExpirationInfo then
                            remaining, expiringCastID = buff.getExpirationInfo()
                            duration = buff.enchantDuration
                        elseif buff.buffIdOverride or buff.spellID then
                            _, remaining, _, duration =
                                UnitHasBuff("player", (buff.buffIdOverride or buff.spellID) --[[@as SpellID]])
                        end
                        if
                            TrySetEntryExpiring(
                                entry,
                                remaining,
                                Lead.Of(duration, selfThreshold, selfFloor),
                                selfExGlow
                            )
                        then
                            if expiringCastID then
                                entry.dynamicIcon = BR.Icons.GetBuffTexture(expiringCastID)
                            elseif buff.enchantID then
                                -- The icon shows the imbue that the click casts.
                                BR.Icons.ApplyDynamicIcon(entry, buff)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Chores (drop a table, repair gear), not auras: class-gated and driven by
-- customCheck. A showOnInstanceEntry chore surfaces only briefly on zone-in.
local function RefreshUtility(db, trackingMode, isAuraRestricted)
    local utilityVisible = IsCategoryVisibleForContent("utility")
    local _, utilityMissGlow = GetCategoryGlowSettings("utility")
    local repairHiddenInCombat = GameContext.IsInCombat() and db.defaults and db.defaults.repairHideInCombat ~= false
    for i, buff in ipairs(UtilityBuffs) do
        local entry = GetOrCreateEntry(buff.key, "utility", i)
        local settingKey = buff.groupId or buff.key
        local entryOk = not buff.showOnInstanceEntry or GameContext.IsInDungeonEntry()
        if
            entryOk
            and not (repairHiddenInCombat and buff.key == "repairGear")
            and utilityVisible
            and (not buff.class or buff.class == playerClass)
            and IsBuffEnabled(settingKey)
            and PassesPreChecks(buff, nil, db, trackingMode)
            and (not buff.customCheck or buff.customCheck(isAuraRestricted))
        then
            SetEntryText(entry, buff.overlayTextFn and buff.overlayTextFn() or buff.overlayText, utilityMissGlow)
            BR.Icons.ApplyDynamicIcon(entry, buff)
        end
    end
end

-- Presence category: one group member with the buff satisfies the reminder.
local function RefreshPresence(db, trackingMode, isAuraRestricted, hideExpiring, expiringClass)
    local presenceVisible = IsCategoryVisibleForContent("presence")
    local presExGlow, presMissGlow, presThreshold, presFloor = GetCategoryGlowSettings("presence")
    for i, buff in ipairs(PresenceBuffs) do
        local entry = GetOrCreateEntry(buff.key, "presence", i)
        -- If a self-buff entry already covers this, skip entirely
        local suppressed = false
        if buff.suppressedByEntry then
            local suppressor = BuffState.entries[buff.suppressedByEntry]
            suppressed = suppressor and suppressor.visible
        end
        if not suppressed then
            local target = BuffTargets.Resolve(buff, "presence")
            local scope = GetTrackingScope(
                trackingMode,
                buff.class,
                target,
                HasCasterForBuff(buff.class, buff.levelRequired, buff.reach)
            )
            local dungeonEntryOk = buff.showOnInstanceEntry and GameContext.IsInDungeonEntry()
            local readyCheckOk = not buff.readyCheckOnly or GameContext.IsInReadyCheck()
            -- Soulstone visibility mode overrides readyCheckOnly
            if buff.key == "soulstone" and not readyCheckOk then
                local ssMode = db.defaults and db.defaults.soulstoneVisibility or "readyCheck"
                if ssMode == "always" then
                    readyCheckOk = true
                elseif ssMode == "casterOnly" then
                    readyCheckOk = playerClass == "WARLOCK"
                end
            end
            if not readyCheckOk and not dungeonEntryOk then
                local overrides = db.readyCheckOnlyOverrides
                local overrideKey = buff.groupId or buff.key
                readyCheckOk = overrides and overrides[overrideKey] == false
            end
            local showBuff = presenceVisible
                and (readyCheckOk or dungeonEntryOk)
                and scope.show
                and (not buff.groupOnly or #currentValidUnits > 1) -- solo = 1 entry (player only)
            -- Target memory of a one-unit buff (e.g. Soulstone) updates on every refresh
            -- the aura API allows, independent of reminder visibility: Soulstone's
            -- display is ready-check-gated, but the click macro needs current memory
            -- at all times. The display branch below reuses this scan result, so the
            -- buff is never scanned twice in one refresh.
            local isOwnCaster = BuffTargets.Copies(buff, "presence") == "own" and buff.class == playerClass
            local hasBuff, minRemaining, targetEntry, minLead, nextSlack
            local scanned = false
            if
                isOwnCaster
                and BuffTargets.PicksUnit(target)
                and not GameContext.IsInCombat()
                and #currentValidUnits > 1
                and IsBuffEnabled(buff.key)
                and (not isAuraRestricted or IsAuraTrackable(buff))
            then
                -- Full-group sweep (playerOnly=false): the buff lives on the target,
                -- so a player-only scan never finds it.
                hasBuff, minRemaining, targetEntry, minLead, nextSlack =
                    HasPresenceBuff(buff.spellID, false, true, false, presThreshold, presFloor)
                scanned = true
                TargetMemory.Observe(
                    buff.key,
                    hasBuff,
                    targetEntry and targetEntry.name,
                    targetEntry and targetEntry.class
                )
            end
            if showBuff and buff.casterCheck and buff.class == playerClass and IsBuffEnabled(buff.key) then
                local text, noClick = buff.casterCheck(isAuraRestricted)
                if text then
                    SetEntryText(entry, text, presMissGlow)
                    entry.noClick = noClick
                    BR.Icons.ApplyDynamicIcon(entry, buff)
                end
            elseif showBuff and IsBuffEnabled(buff.key) then
                local trackable = IsAuraTrackable(buff)
                local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
                if not isAuraRestricted or trackable or useGlowDet then
                    if useGlowDet then
                        if IsAnySpellGlowing(buff) then
                            SetEntryText(entry, buff.overlayText, presMissGlow)
                        end
                    else
                        -- copies = "own": for the caster class, count only the player's
                        -- own cast. That resolves the right target and keeps another
                        -- caster's coverage from hiding the icon.
                        if not scanned then
                            local _
                            hasBuff, minRemaining, _, minLead, nextSlack = HasPresenceBuff(
                                buff.spellID,
                                scope.playerOnly,
                                isOwnCaster,
                                buff.reach == "party",
                                presThreshold,
                                presFloor
                            )
                        end
                        local canCast = hasBuff or not buff.castReady or buff.castReady(isAuraRestricted) ~= false
                        if not hasBuff and canCast then
                            SetEntryText(entry, buff.overlayText, presMissGlow)
                        elseif
                            not buff.noExpirationGlow
                            and not hideExpiring
                            and (not expiringClass or buff.class == expiringClass)
                        then
                            TrySetEntryExpiring(entry, minRemaining, minLead, presExGlow, nextSlack)
                        end
                    end
                end
            end
        end
    end
end

-- Buffs the player keeps on units that the player picks.
local function RefreshTargeted(db, trackingMode, isAuraRestricted, hideExpiring, expiringClass)
    local targetedVisible = IsCategoryVisibleForContent("targeted")
    -- Targeted buffs sit on other units, so personal mode keeps the group scope.
    local scopeMode = trackingMode == "personal" and "all" or trackingMode
    local targExGlow, targMissGlow, targThreshold, targFloor = GetCategoryGlowSettings("targeted")
    for i, buff in ipairs(TargetedBuffs) do
        local entry = GetOrCreateEntry(buff.key, "targeted", i)
        local settingKey = GetBuffSettingKey(buff)
        local target = BuffTargets.Resolve(buff, "targeted")
        local scope = GetTrackingScope(scopeMode, buff.class, target, true)

        if targetedVisible and scope.show and IsBuffEnabled(settingKey) then
            local trackable = IsAuraTrackable(buff)
            local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
            if (not isAuraRestricted or trackable or useGlowDet) and PassesPreChecks(buff, nil, db, trackingMode) then
                if useGlowDet then
                    if IsAnySpellGlowing(buff) then
                        SetEntryText(entry, buff.overlayText, targMissGlow)
                    end
                else
                    local shouldShow, remaining, lead, nextSlack
                    if target == "tankOrSelf" then
                        shouldShow, remaining, lead, nextSlack =
                            TankOrSelfState(buff, scope.playerOnly, targThreshold, targFloor)
                    else
                        shouldShow, remaining, lead, nextSlack = AllyTargetState(buff, targThreshold, targFloor)
                    end

                    if shouldShow then
                        SetEntryText(entry, buff.overlayText, targMissGlow)
                    elseif
                        shouldShow == false
                        and not buff.noExpirationGlow
                        and not hideExpiring
                        and (not expiringClass or buff.class == expiringClass)
                    then
                        TrySetEntryExpiring(entry, remaining, lead, targExGlow, nextSlack)
                    end
                end
            end
        end
    end
end

---@param sacrifice PetSacrifice
---@param isAuraRestricted boolean
---@return boolean
local function IsPetSacrificed(sacrifice, isAuraRestricted)
    if not IsPlayerSpellCached(sacrifice.spellID) then
        return false
    end
    if isAuraRestricted then
        for _, id in ipairs(sacrifice.auraIDs) do
            if not IsAuraSpellTrackable(id) then
                return true
            end
        end
    end
    return (UnitHasBuff("player", sacrifice.auraIDs))
end

-- Pet summon reminders. A summon has no duration, so nothing tracks expiration.
---@param isAuraRestricted boolean
local function RefreshPet(isAuraRestricted)
    local petVisible = IsCategoryVisibleForContent("pet")
    if IsMounted() or GameContext.IsPetDismountSuppressed() then
        petVisible = false
    end
    local petPassiveHidden = BR.profile.petPassiveOnlyInCombat and not UnitAffectingCombat("player")
    local _, petMissGlow = GetCategoryGlowSettings("pet")
    for i, buff in ipairs(PetBuffs) do
        local entry = GetOrCreateEntry(buff.key, "pet", i)
        local settingKey = buff.groupId or buff.key

        if
            IsBuffEnabled(settingKey)
            and petVisible
            and not (buff.key == "petPassive" and petPassiveHidden)
            and (not buff.visibilityCondition or buff.visibilityCondition())
            and not (buff.petSacrifice and IsPetSacrificed(buff.petSacrifice, isAuraRestricted))
        then
            local shouldShow = ShouldShowSelfBuff(buff, false, isAuraRestricted)
            if shouldShow then
                SetEntryText(entry, buff.overlayText, petMissGlow)
                BR.Icons.ApplyDynamicIcon(entry, buff)
                if buff.getPetActions then
                    local actions = buff.getPetActions()
                    if actions and #actions > 0 then
                        entry.petActions = actions
                    end
                elseif buff.groupId == "pets" and BR.PetHelpers then
                    local actions = BR.PetHelpers.GetPetActions(playerClass)
                    if actions and #actions > 0 then
                        entry.petActions = actions
                    end
                end
            end
        end
    end
end

local function RefreshConsumables(db, trackingMode, isAuraRestricted, hideExpiring)
    local consumableVisible = IsCategoryVisibleForContent("consumable")
    -- Delve food ignores the consumable ready-check-only filter (still respects content gates)
    local consumableVisibleNoReadyCheck = IsCategoryVisibleForContent("consumable", true)
    local consExGlow, consMissGlow, consThreshold, consFloor = GetCategoryGlowSettings("consumable")
    local delveFoodOnly = db.defaults and db.defaults.delveFoodOnly and BR.IsInDelve()
    local freeMode = db.defaults and db.defaults.freeConsumableMode or "override"
    local freeVisible = freeMode == "override" and IsFreeConsumableVisible(db) or false
    -- In follow mode, healthstones use consumable category content gates (without ready check)
    local consumableContentVisible = freeMode == "follow" and IsCategoryVisibleForContent("consumable", true) or false
    -- Dismiss overrides all consumable visibility (transient, resets on instance change)
    if BuffState.GetConsumablesDismissed() then
        consumableVisible = false
        consumableVisibleNoReadyCheck = false
        freeVisible = false
        consumableContentVisible = false
    end
    local freeRcMode = db.defaults and db.defaults.healthstoneVisibility or "readyCheck"
    local competitivePvP = IsInCompetitivePvP()
    for i, buff in ipairs(Consumables) do
        local entry = GetOrCreateEntry(buff.key, "consumable", i)
        local settingKey = buff.groupId or buff.key
        local catVisible = buff.ignoresReadyCheckFilter and consumableVisibleNoReadyCheck or consumableVisible

        if buff.showOnInstanceEntry and (db.defaults and db.defaults.delveFoodTimer) then
            -- Instance-entry-only consumable (e.g. delve food): shows for 30s after
            -- entry, then hides. GameContext ends the window when combat starts.
            if
                GameContext.IsInDelveEntry()
                and catVisible
                and IsBuffEnabled(settingKey)
                and PassesPreChecks(buff, nil, db, trackingMode)
            then
                local shouldShow = ShouldShowConsumableBuff(buff)
                if shouldShow then
                    SetEntryText(entry, buff.overlayText, consMissGlow)
                end
            end
        else
            local requiredClass = buff.casterClass
            local hasCaster = not requiredClass or HasCasterForBuff(requiredClass)
            local isFreeConsumable = freeVisible and IsFreeConsumable(buff)
            -- Healthstone ready check mode (independent of follow/override content gates)
            local freeReadyCheckOk = true
            if buff.freeConsumable and not GameContext.IsInReadyCheck() then
                if freeRcMode == "readyCheck" then
                    freeReadyCheckOk = false
                elseif freeRcMode == "casterOnly" then
                    freeReadyCheckOk = not buff.casterClass or buff.casterClass == playerClass
                end
            end
            -- Boolean gates run first; IsAuraTrackable and PassesPreChecks come later.
            if
                IsBuffEnabled(settingKey)
                and (catVisible or isFreeConsumable or (buff.freeConsumable and consumableContentVisible))
                and not (competitivePvP and buff.disabledInCompetitivePvP)
                and freeReadyCheckOk
                and hasCaster
            then
                local trackable = IsAuraTrackable(buff)
                local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
                if
                    (not isAuraRestricted or trackable or useGlowDet)
                    and PassesPreChecks(buff, nil, db, trackingMode)
                    and not (buff.key ~= "delveFood" and delveFoodOnly)
                then
                    if useGlowDet then
                        if IsAnySpellGlowing(buff) then
                            SetEntryText(entry, buff.overlayText, consMissGlow)
                        end
                    else
                        local shouldShow, remainingTime, activeSpellID, itemCount, auraDuration =
                            ShouldShowConsumableBuff(buff)
                        if shouldShow then
                            SetEntryText(entry, buff.overlayText, consMissGlow)
                        elseif
                            buff.key == "healthstone"
                            and buff.itemMaxCharges
                            and itemCount
                            and db.defaults
                            and db.defaults.healthstoneLowStock
                        then
                            -- Healthstone low-stock check: charges left over a full
                            -- stone, with the expiring glow, when at or below threshold
                            local hsThreshold = db.defaults.healthstoneThreshold or 1
                            if itemCount <= hsThreshold then
                                entry.visible = true
                                entry.displayType = "count"
                                entry.countText = itemCount .. "/" .. buff.itemMaxCharges
                                entry.shouldGlow = consMissGlow
                                entry.glowKindOverride = "expiring"
                                -- A refill keeps the stone in its slot, so no bag event fires.
                                NoteChangeIn(CHARGE_RECHECK)
                            end
                        elseif not buff.noExpirationGlow and not hideExpiring then
                            if
                                TrySetEntryExpiring(
                                    entry,
                                    remainingTime,
                                    Lead.Of(auraDuration or buff.enchantDuration, consThreshold, consFloor),
                                    consExGlow
                                )
                            then
                                if activeSpellID and type(buff.spellID) == "table" then
                                    entry.dynamicIcon = BR.Icons.GetBuffTexture(activeSpellID)
                                end
                            end
                        end
                        -- Eating state for food entries (display uses this for icon override + countdown)
                        if entry.visible and buff.key == "food" then
                            entry.isEating = IsPlayerEating()
                            if entry.isEating then
                                entry.eatingExpirationTime = GetEatingExpirationTime()
                            end
                        end
                    end
                end
            end
        end
    end
end

-- User-defined buffs. They take the same path as self and pet buffs.
local function RefreshCustom(isAuraRestricted, hideExpiring)
    local _, customMissGlow = GetCategoryGlowSettings("custom")
    for i, buff in ipairs(CustomBuffs) do
        local entry = GetOrCreateEntry(buff.key, "custom", i)

        local trackable = IsAuraTrackable(buff)
        local useGlowFallback = isAuraRestricted and not trackable and buff.glowMode ~= "disabled"
        local shouldProcess = (not isAuraRestricted or trackable or useGlowFallback)
            and IsBuffEnabled(buff.key)
            and IsCustomBuffVisibleForContent(buff)

        if shouldProcess and buff.requireSpellKnown then
            local spellIDs = AsSpellList(buff.spellID)
            local knowsAnySpell = false
            for _, spellID in ipairs(spellIDs) do
                if IsPlayerSpellCached(spellID) then
                    knowsAnySpell = true
                    break
                end
            end
            if not knowsAnySpell then
                shouldProcess = false
            end
        end

        if shouldProcess then
            local gateItemID = buff.requireItemID or buff.castItemID
            if gateItemID and not HasItemByMode(gateItemID, buff.requireItemMode) then
                shouldProcess = false
            end
            if shouldProcess and gateItemID and buff.itemCooldownCondition and not CooldownsRestricted() then
                -- pcall: gateItemID is user-entered and an invalid ID can throw.
                local ok, _, duration = pcall(C_Item.GetItemCooldown, gateItemID)
                duration = ok and Plain(duration) or nil
                if duration then
                    local isReady = duration == 0
                    if
                        (buff.itemCooldownCondition == "offCooldown" and not isReady)
                        or (buff.itemCooldownCondition == "onCooldown" and isReady)
                    then
                        shouldProcess = false
                    end
                end
            end
        end

        if shouldProcess and useGlowFallback then
            -- Aura API restricted: detect via action bar glow instead
            local mode = buff.glowMode or "whenGlowing"
            local anyGlowing = IsAnySpellGlowing(buff)
            local show = (mode == "whenGlowing" and anyGlowing) or (mode == "whenNotGlowing" and not anyGlowing)
            if show then
                SetEntryText(entry, buff.overlayText, customMissGlow)
            end
        elseif shouldProcess then
            -- Custom buffs track buffs the player receives, not casts.
            local shouldShow = ShouldShowSelfBuff(buff, true)
            local wantPresent = buff.showWhenPresent
            local show = (wantPresent and shouldShow == false) or (not wantPresent and shouldShow)
            if show then
                SetEntryText(entry, buff.overlayText, customMissGlow)
            elseif
                shouldShow == false
                and buff.expirationThreshold
                and buff.expirationThreshold > 0
                and not hideExpiring
                and buff.spellID
            then
                -- Buff is present (not missing), check if expiring (per-buff threshold)
                local _, remaining, _, duration = UnitHasBuff("player", buff.spellID)
                -- No proportional lead: the per-buff threshold is exact. An aura that
                -- fits in it never warns.
                local lead = buff.expirationThreshold * 60 ---@type number?
                if duration and duration > 0 and duration <= lead then
                    lead = nil
                end
                TrySetEntryExpiring(entry, remaining, lead, true)
            end
        end
    end
end

local function RefreshLoadout()
    local _, loadoutMissGlow = GetCategoryGlowSettings("loadout")
    local Loadouts = BR.Loadouts
    for i, rule in ipairs(LoadoutRules) do
        local entry = GetOrCreateEntry(rule.key, "loadout", i)
        -- The gating predicates stay live: they are DB and flag reads whose spec,
        -- content and character inputs already resolve through caches. Only the
        -- read-only API detection (satisfied + icon) is memoized per rule.
        if
            IsBuffEnabled(rule.key)
            and Loadouts.AppliesToCurrentCharacter(rule)
            and IsLoadoutRuleVisibleForContent(rule)
            and Loadouts.CurrentInstanceMatches(rule.when and rule.when.instances)
        then
            local state = cachedLoadoutState[rule.key]
            if not state then
                local satisfied, known = Loadouts.IsSatisfied(rule)
                state = satisfied and SATISFIED_LOADOUT_STATE
                    or { satisfied = false, icon = Loadouts.GetRuleIcon(rule) }
                if known then
                    cachedLoadoutState[rule.key] = state
                end
            end
            if not state.satisfied then
                entry.dynamicIcon = state.icon
                entry.subLabel = rule.name
                SetEntryText(entry, LOADOUT_TAGS[rule.require] or rule.overlayText, loadoutMissGlow)
            end
        end
    end
end

---Recompute buff states.
---@param refreshMode? "full"|"group" "group" only updates entries that depend on group-member state.
function BuffState.Refresh(refreshMode)
    local db = BR.profile
    if not db then
        return
    end
    refreshMode = refreshMode or "full"
    local groupOnly = refreshMode == "group"
    nextTimedChangeIn = nil

    -- Reset entries that will be recomputed this cycle.
    for _, entry in pairs(BuffState.entries) do
        if
            not groupOnly
            or entry.category == "raid"
            or entry.category == "presence"
            or entry.category == "targeted"
        then
            entry.visible = false
            entry.shouldGlow = false
            entry.countText = nil
            entry.overlayText = nil
            entry.rebuffWarning = nil -- legacy field, still cleared for safety
            entry.isEating = nil
            entry.eatingExpirationTime = nil
            entry.petActions = nil
            entry.dynamicIcon = nil
            entry.glowKindOverride = nil
            entry.subLabel = nil
            entry.noClick = nil
        end
    end

    BuildValidUnitCache()

    if not groupOnly then
        -- Fetch weapon enchant info once per refresh cycle
        local we = currentWeaponEnchants
        if ReadWeaponEnchantSlots then
            local mhTemp, mhTempExp, mhImbue, mhImbueExp = ReadWeaponEnchantSlots(Enum.WeaponSlot.MainHand)
            local ohTemp, ohTempExp, ohImbue, ohImbueExp = ReadWeaponEnchantSlots(Enum.WeaponSlot.OffHand)
            we.mainHandTempID, we.mainHandTempExpiration = mhTemp, mhTempExp
            we.mainHandImbueID, we.mainHandImbueExpiration = mhImbue, mhImbueExp
            we.offHandTempID, we.offHandTempExpiration = ohTemp, ohTempExp
            we.offHandImbueID, we.offHandImbueExpiration = ohImbue, ohImbueExp
            -- The combined fields report the imbue first, as the legacy API does.
            we.mainHandID = mhImbue or mhTemp
            we.mainHandExpiration = mhImbue and mhImbueExp or mhTempExp
            we.offHandID = ohImbue or ohTemp
            we.offHandExpiration = ohImbue and ohImbueExp or ohTempExp
            we.hasMainHand = we.mainHandID ~= nil
            we.hasOffHand = we.offHandID ~= nil
        else
            local hasMain, mainExp, _, mainID, hasOff, offExp, _, offID = GetWeaponEnchantInfo()
            we.hasMainHand = hasMain or false
            we.mainHandID = mainID
            we.mainHandExpiration = mainExp
            we.hasOffHand = hasOff or false
            we.offHandID = offID
            we.offHandExpiration = offExp
            we.mainHandTempID = hasMain and (mainID or 0) or nil
            we.mainHandTempExpiration = mainExp
            we.offHandTempID = hasOff and (offID or 0) or nil
            we.offHandTempExpiration = offExp
        end

        -- Fetch permanent enchant IDs from item links once per refresh cycle
        local mhLink = GetInventoryItemLink("player", 16)
        currentWeaponEnchants.permanentMH = mhLink and tonumber(mhLink:match("item:%d+:(%d+)")) or nil
        local ohLink = GetInventoryItemLink("player", 17)
        currentWeaponEnchants.permanentOH = ohLink and tonumber(ohLink:match("item:%d+:(%d+)")) or nil
    end

    local trackingMode = GetEffectiveTrackingMode(db)
    local missingCountOnly = db.showMissingCountOnly
    local isAuraRestricted = BuffState.IsRestricted()
    local hideExpiring = isAuraRestricted and db.hideExpiringInCombat ~= false
    -- Below max level, levelingExpiring narrows the expiring state. Custom buffs keep their own threshold.
    local levelingExpiring = GameContext.GetPlayerLevel() < GameContext.GetMaxExpansionLevel() and db.levelingExpiring
        or "all"
    local hideBuffExpiring = hideExpiring or levelingExpiring == "off"
    local expiringClass = levelingExpiring == "own" and playerClass or nil
    local hideConsumableExpiring = hideExpiring or levelingExpiring == "own" or levelingExpiring == "off"

    RefreshRaid(db, trackingMode, isAuraRestricted, hideBuffExpiring, expiringClass, missingCountOnly)
    if not groupOnly then
        -- Self buffs run before presence so suppressedByEntry can read self entries.
        -- ShouldShowSelfBuff gates every self buff on the player class, so expiringClass does not apply.
        RefreshSelf(isAuraRestricted, hideBuffExpiring)
        -- Chores never depend on group state, so a group refresh skips them.
        RefreshUtility(db, trackingMode, isAuraRestricted)
    end
    RefreshPresence(db, trackingMode, isAuraRestricted, hideBuffExpiring, expiringClass)
    RefreshTargeted(db, trackingMode, isAuraRestricted, hideBuffExpiring, expiringClass)
    if not groupOnly then
        RefreshPet(isAuraRestricted)
        RefreshConsumables(db, trackingMode, isAuraRestricted, hideConsumableExpiring)
        RefreshCustom(isAuraRestricted, hideExpiring)
        -- Loadout detection is aura-agnostic, but a gear or talent swap is blocked
        -- in every restricted context, so the reminder there is unactionable noise.
        if not isAuraRestricted then
            RefreshLoadout()
        end
    end

    -- Build visibleByCategory in one pass from entries (reuse sub-tables)
    for _, list in pairs(BuffState.visibleByCategory) do
        wipe(list)
    end
    for _, entry in pairs(BuffState.entries) do
        if entry.visible then
            local cat = entry.category
            if not BuffState.visibleByCategory[cat] then
                BuffState.visibleByCategory[cat] = {}
            end
            tinsert(BuffState.visibleByCategory[cat], entry)
        end
    end

    for _, list in pairs(BuffState.visibleByCategory) do
        local sorted = true
        for j = 2, #list do
            if list[j].sortOrder < list[j - 1].sortOrder then
                sorted = false
                break
            end
        end
        ---@diagnostic disable-next-line: inject-field
        list._sorted = sorted
    end

    BuffState.lastUpdate = GetTime()
end

---Check if the current zone qualifies for dungeon entry triggers
---(grouped dungeons only, excluding M+ and follower dungeons)
---@return boolean
function BuffState.ShouldTriggerDungeonEntry()
    if BuffState.IsAlone() then
        return false
    end
    if GetCurrentContentType() ~= "dungeon" then
        return false
    end
    local diffKey = GetCurrentDifficultyKey()
    return diffKey ~= "mythicPlus" and diffKey ~= "follower"
end

---Check if the current zone qualifies for delve entry triggers
---@return boolean
function BuffState.ShouldTriggerDelveEntry()
    return BR.IsInDelve()
end

---Check if the current instance is legacy content (cached alongside content type)
---@return boolean
function BuffState.IsLegacyInstance()
    if instanceCache.legacyInstance == nil then
        GetCurrentContentType() -- populates instanceCache.legacyInstance
    end
    return instanceCache.legacyInstance or false
end

---Set whether consumable reminders are dismissed (transient, resets on instance change)
---@param state boolean
function BuffState.SetConsumablesDismissed(state)
    consumablesDismissed = state and GameContext.IsResting() and "rest" or state
end

---Get whether consumable reminders are dismissed
---@return boolean
function BuffState.GetConsumablesDismissed()
    if consumablesDismissed == "rest" and not GameContext.IsResting() then
        consumablesDismissed = false
    end
    return consumablesDismissed ~= false
end

---Raw difficultyID from GetInstanceInfo (cached; invalidated with content type)
BuffState.GetDifficultyID = GetDifficultyIDCached

---Whether the player is in a restricted context: aura queries return secret
---values. Measured through C_Secrets.ShouldAurasBeSecret.
---@type fun(): boolean
BuffState.IsRestricted = BR.Restrictions.AurasRestricted

---Whether the player has no allies in the group (open-world solo or scenario solo).
---Live check: covers both open-world solo (groupSize 0) and scenario solo such as
---rituals (groupSize 1, player only). Internal hot paths in Refresh() must read
---cachedIsAlone instead of this function.
---@return boolean
function BuffState.IsAlone()
    return GetNumGroupMembers() <= 1
end

-- The "Decor Duel" brawl is hide-and-seek as furniture. Only its difficulty ID identifies it.
local DECOR_DUEL_DIFFICULTY_ID = 253

---@alias HideAllReason "dead"|"decorDuel"|"solo"|"resting"|"combat"|"vehicle"|"mounted"|"legacyInstance"|"leveling"

---The reason to hide every display frame, or nil to show them. Safe to call every render pass.
---@param db table The active profile
---@return HideAllReason?
function BuffState.GetHideAllReason(db)
    if UnitIsDeadOrGhost("player") then
        return "dead"
    end
    if GetDifficultyIDCached() == DECOR_DUEL_DIFFICULTY_ID then
        return "decorDuel"
    end
    if db.showOnlyInGroup and BuffState.IsAlone() then
        return "solo"
    end
    if db.hideWhileResting and GameContext.IsResting() then
        return "resting"
    end
    if db.hideInCombat and GameContext.IsInCombat() then
        return "combat"
    end
    if db.hideAllInVehicle and GameContext.IsInVehicle() then
        return "vehicle"
    end
    if db.hideWhileMounted and IsMounted() then
        return "mounted"
    end
    if db.hideInLegacyInstances and BuffState.IsLegacyInstance() then
        return "legacyInstance"
    end
    if db.hideWhileLeveling and GameContext.GetPlayerLevel() < GameContext.GetMaxExpansionLevel() then
        return "leveling"
    end
    return nil
end

---Whether any group member is assigned the HEALER role (cached; invalidated on
---roster / role-assignment events). The scan only runs outside restricted
---contexts, where roles read as plain values. The Plain guard covers a future
---caller that runs inside one.
---@return boolean
function BuffState.HasHealerInGroup()
    if cachedHealerInGroup ~= nil then
        return cachedHealerInGroup
    end
    local result = false
    local num = GetNumGroupMembers()
    if num > 1 then
        local inRaid = IsInRaid()
        for i = 1, num do
            local unit = inRaid and ("raid" .. i) or (i == 1 and "player" or "party" .. (i - 1))
            if UnitExists(unit) and Plain(UnitGroupRolesAssigned(unit)) == "HEALER" then
                result = true
                break
            end
        end
    end
    cachedHealerInGroup = result
    return result
end

---Whether an added aura is one the addon tracks on group members. A secret
---spellId (non-whitelisted aura in a restricted context) reads as nil and is
---treated as not-tracked - fail-closed (a secret spellId cannot be a whitelisted
---spell, and only whitelisted spells are queried on group members there).
---@param aura table
---@return boolean
local function IsTrackedAddedAura(aura)
    local sid = AuraField(aura, "spellId")
    return sid ~= nil and groupTrackedSpells[sid] == true
end

---Whether a removal/update instance ID matches one recorded in the last scan. A
---secret ID reads as nil and never matches - fail-closed. Recorded IDs are
---readable values from successful scans, so a secret ID cannot equal one.
---@param set table<number, true>
---@param id number
---@return boolean
local function IsRecordedInstance(set, id)
    id = Plain(id)
    return id ~= nil and set[id] == true
end

---Decide whether a group unit's UNIT_AURA payload can affect tracked buff state,
---so irrelevant aura churn (HoTs, procs, debuffs) skips the group rescan.
---Fail-open on ambiguous payloads (nil updateInfo, isFullUpdate) that carry no
---incremental info to filter on. Everything else fails CLOSED via AuraList: a
---secret list container reads as empty, contributes no match, and the payload is
---skipped. In combat nearly every group payload container is secret. Individual
---secret entries read as absent. The 3s ticker bounds anything skipped. In restricted
---contexts this makes group refresh ticker-driven on purpose - a fail-open on a
---secret container rescans on every combat payload.
---@param unit string
---@param updateInfo table?
---@return boolean
function BuffState.GroupAuraUpdateMatters(unit, updateInfo)
    -- Any aura change can add or remove a foreign copy, so the scan result of the unit is stale.
    for _, state in pairs(classChoiceStates) do
        state.foreign[unit] = nil
    end
    if not updateInfo then
        return true
    end
    -- isFullUpdate can be a SECRET BOOLEAN in restricted contexts, and a boolean test
    -- on a secret boolean THROWS (unlike a secret number/table, whose truthiness is
    -- constant and safe to branch on). Plain() reads a secret as nil, so a secret
    -- isFullUpdate reads as "not a full update" and falls through to the
    -- fail-closed container checks below.
    if Plain(updateInfo.isFullUpdate) then
        return true
    end
    for _, aura in ipairs(AuraList(updateInfo.addedAuras)) do
        if IsTrackedAddedAura(aura) then
            return true
        end
    end
    local set = trackedAuraInstances[unit]
    if set and next(set) then
        for _, id in ipairs(AuraList(updateInfo.removedAuraInstanceIDs)) do
            if IsRecordedInstance(set, id) then
                return true
            end
        end
        for _, id in ipairs(AuraList(updateInfo.updatedAuraInstanceIDs)) do
            if IsRecordedInstance(set, id) then
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- CACHE INVALIDATION
-- ============================================================================

---Invalidate content type cache
function BuffState.InvalidateContentTypeCache()
    wipe(instanceCache)
end

---Invalidate the scan results of foreign classChoices copies.
function BuffState.InvalidateForeignAuraCache()
    for _, state in pairs(classChoiceStates) do
        wipe(state.foreign)
    end
end

---Invalidate the aura-trackable caches.
---Blizzard can reclassify a spell's secrecy in a mid-session hotfix.
function BuffState.InvalidateAuraTrackableCache()
    auraTrackableCache = setmetatable({}, { __mode = "k" })
    BR.Restrictions.InvalidateSpellSecrecyCache()
end

---Invalidate spec ID cache
function BuffState.InvalidateSpecCache()
    cachedSpecId = nil
    cachedPlayerRole = nil
end

---Invalidate group-healer cache
function BuffState.InvalidateHealerCache()
    cachedHealerInGroup = nil
    wipe(cachedMainTanks)
    local wasTank = cachedPlayerTank
    cachedPlayerTank = nil
    -- A group refresh skips the self category, so a tank change asks for a full render.
    if wasTank ~= nil and IsPlayerTank() ~= wasTank then
        BR.CallbackRegistry:TriggerEvent("RenderRequested", false)
    end
end

function BuffState.InvalidateSubgroupCache()
    raidSubgroupsValid = false
end

---Get the player's current role (cached, invalidated on spec change)
---@return RoleType?
BuffState.GetPlayerRole = GetPlayerRole

---Invalidate spell knowledge cache
function BuffState.InvalidateSpellCache()
    cachedSpellKnowledge = {}
    cachedSpecId = nil
    cachedPlayerRole = nil
end

local function ResolveOffHandType()
    if cachedOffHandType ~= nil then
        return
    end
    local offhandItemID = GetInventoryItemID("player", 17) -- INVSLOT_OFFHAND
    if not offhandItemID then
        -- Trust an empty off-hand only when inventory data is loaded. Right after
        -- a loading screen or an equipment swap, slot 17 can transiently read nil
        -- for a real dual-wielder. A cached "none" then poisons the rest of the
        -- session (dual-wielder read as two-handed -> wrong rune bucket). The main
        -- hand is always equipped, so a readable MH means inventory is loaded and a
        -- nil off-hand is truly empty. If MH is also nil, leave the cache unset so
        -- the next refresh retries.
        if GetInventoryItemID("player", 16) then -- INVSLOT_MAINHAND
            cachedOffHandType = "none"
        end
        return
    end
    local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(offhandItemID)
    if not itemClassID then
        -- Item data is not available yet (intermittent right after login/reload).
        -- Leave the cache unset so the next refresh retries. A stale "none" here
        -- poisons the session and makes a dual-wielder read as two-handed.
        return
    end
    if itemClassID == 2 then -- Enum.ItemClass.Weapon
        cachedOffHandType = "weapon"
    elseif itemClassID == 4 and itemSubClassID == 6 then -- Armor + Shield
        cachedOffHandType = "shield"
    else
        cachedOffHandType = "none"
    end
end

---Check if off-hand slot has a weapon (cached)
---@return boolean
function BuffState.HasOffHandWeapon()
    ResolveOffHandType()
    return cachedOffHandType == "weapon"
end

---Check if off-hand slot has a shield (cached)
---@return boolean
function BuffState.HasShield()
    ResolveOffHandType()
    return cachedOffHandType == "shield"
end

---Weapon subclass (Enum.ItemWeaponSubclass) of the item in a weapon slot (cached).
---@param slot number 16 (main hand), 17 (off hand) or 18 (ranged)
---@return number? subclassID nil when the slot holds no weapon or the item data is not loaded
function BuffState.GetWeaponSubclass(slot)
    local cached = cachedWeaponSubclass[slot]
    if cached ~= nil then
        return cached or nil
    end
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then
        return nil
    end
    local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(itemID)
    if not itemClassID then
        return nil
    end
    cachedWeaponSubclass[slot] = itemClassID == 2 and itemSubClassID or false
    return cachedWeaponSubclass[slot] or nil
end

---Get the cached off-hand enchant ID from the current refresh cycle
---@return number|nil
function BuffState.GetOffHandEnchantID()
    return currentWeaponEnchants.offHandID
end

---The imbue on a weapon slot, from the current refresh cycle. Always nil on a client with no imbue slot.
---@param slot number Inventory slot ID (16 = MH, 17 = OH)
---@return number? imbueID
---@return number? remaining seconds
function BuffState.GetWeaponImbue(slot)
    local we = currentWeaponEnchants
    local id, exp
    if slot == 16 then
        id, exp = we.mainHandImbueID, we.mainHandImbueExpiration
    else
        id, exp = we.offHandImbueID, we.offHandImbueExpiration
    end
    return id, exp and exp / 1000 or nil
end

---Get the permanent enchant ID on a weapon slot (cached per refresh cycle)
---@param slot number Inventory slot ID (16 = MH, 17 = OH)
---@return number|nil
function BuffState.GetPermanentWeaponEnchantID(slot)
    if slot == 16 then
        return currentWeaponEnchants.permanentMH
    end
    return currentWeaponEnchants.permanentOH
end

---Invalidate the off-hand weapon/shield and weapon subclass caches
function BuffState.InvalidateOffHandCache()
    cachedOffHandType = nil
    wipe(cachedWeaponSubclass)
end

---Invalidate item ownership + count caches
function BuffState.InvalidateItemCache()
    cachedItemOwnership = {}
    cachedItemCounts = {}
end

---Lowest equipped-item durability ratio (0-1; 1 when nothing is damaged), cached.
---Slots without durability (neck/rings/trinkets/shirt/tabard) return nil and are skipped.
---@return number
function BuffState.GetLowestDurability()
    if cachedLowestDurability ~= nil then
        return cachedLowestDurability
    end
    local lowest = 1
    local readable = false
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            readable = true
            local pct = cur / max
            if pct < lowest then
                lowest = pct
            end
        end
    end
    -- Only a readable answer is cached: a zone change answers nil for every slot
    -- while the inventory resolves, and a frozen "nothing is damaged" hides the
    -- repair reminder until the next durability event.
    if readable then
        cachedLowestDurability = lowest
    end
    return lowest
end

---Invalidate the durability cache
function BuffState.InvalidateDurabilityCache()
    cachedLowestDurability = nil
end

---Best repair sources for the repair reminder's click action: a collected repair
---mount and/or a usable repair item. Both answers only change on collection and
---bag events, so the resolved pair is memoized.
---@return { mountSpellID: number?, mountID: number?, itemID: number? }
function BuffState.GetRepairSources()
    if cachedRepairSources then
        return cachedRepairSources
    end
    local sources = {}
    for _, spellID in ipairs(REPAIR_SOURCES.mounts) do
        local mountID = C_MountJournal.GetMountFromSpell(spellID)
        if mountID then
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then
                sources.mountSpellID = spellID
                sources.mountID = mountID
                break
            end
        end
    end
    for _, itemID in ipairs(REPAIR_SOURCES.items) do
        if HasItemInBags(itemID) then
            -- A retired use effect must not arm a dead click, so ownership is not
            -- enough. An unreadable verdict means the item info is not cached yet;
            -- ownership decides then.
            local ok, usable = pcall(C_Item.IsUsableItem, itemID)
            if not ok or usable ~= false then
                sources.itemID = itemID
                break
            end
        end
    end
    -- Only a positive resolution is cached: the mount journal is not always
    -- populated at login, and a frozen "owns nothing" leaves the icon inert for the
    -- whole session. An empty answer resolves again on the next arming pass.
    if sources.mountSpellID or sources.itemID then
        cachedRepairSources = sources
    end
    return sources
end

---Whether the collected repair mount can be summoned where the player stands.
---The `[outdoors]` macro conditional cannot answer this: an outdoor area that
---blocks mounts still reads as outdoors, so the click spends nothing. The mount
---journal knows the real restriction. The answer follows the subzone, so it is
---never cached - the macro that reads it is rebuilt on every zone change.
---@return boolean
function BuffState.IsRepairMountUsable()
    local mountID = BuffState.GetRepairSources().mountID
    if not mountID then
        return false
    end
    return C_MountJournal.GetMountUsabilityByID(mountID, IsIndoors()) == true
end

---Invalidate the repair source cache
function BuffState.InvalidateRepairSourceCache()
    cachedRepairSources = nil
end

---Aura spell of the consumable the player runs now, or nil when none is up.
---@param category string Consumable category
---@return number? spellID
function BuffState.GetActiveConsumableSpell(category)
    return activeConsumableSpells[category]
end

---Invalidate loadout state cache
function BuffState.InvalidateLoadoutCache()
    cachedLoadoutState = {}
end

---Check whether the player's current pet is not an allowed demon. Returns false
---when there is no pet or no desired demon. If the family read hits a secret
---value, the result stays uncached so later refreshes retry.
---@return boolean
function BuffState.IsWrongDemonPet()
    if not BR.PetHelpers.GetDesiredWarlockDemon() then
        return false
    end
    if cachedPetFamily == nil then
        if not UnitExists("pet") then
            cachedPetFamily = false
        else
            local _, familyID = UnitCreatureFamily("pet")
            familyID = Plain(familyID)
            if type(familyID) ~= "number" then
                -- Pet data is not resolved yet, or is a secret value. Do not cache, so the
                -- next Refresh retries.
                return false
            end
            cachedPetFamily = familyID
        end
    end
    return cachedPetFamily ~= false and not BR.PetHelpers.IsAllowedWarlockFamily(cachedPetFamily)
end

---Invalidate wrong-pet cache
function BuffState.InvalidatePetCache()
    cachedPetFamily = nil
end

do
    local ammoID, ammoCount -- false = read and empty, nil = not read

    ---Equipped ammo item and its count (cached). nil when the client has no ammo slot or it is empty.
    ---@return number? itemID
    ---@return number count
    function BuffState.GetEquippedAmmo()
        if not INVSLOT_AMMO then
            return nil, 0
        end
        if ammoID == nil then
            ammoID = Plain(GetInventoryItemID("player", INVSLOT_AMMO)) or false
            ammoCount = ammoID and Plain(GetInventoryItemCount("player", INVSLOT_AMMO)) or 0
        end
        return ammoID or nil, ammoCount or 0
    end

    function BuffState.InvalidateAmmoCache()
        ammoID, ammoCount = nil, nil
    end
end

do
    local GetNumTrackingTypes = C_Minimap and C_Minimap.GetNumTrackingTypes
    local GetTrackingInfo = C_Minimap and C_Minimap.GetTrackingInfo
    local GetTrackingTexture = GetTrackingTexture
    local trackingActive ---@type boolean? nil = not read

    -- A town type (banker, flight master) is not a spell and can stay on, so only a
    -- spell type counts. A secret flag counts as active, so the reminder fails closed.
    ---@return boolean
    local function ReadTrackingActive()
        if GetNumTrackingTypes and GetTrackingInfo then
            local count = Plain(GetNumTrackingTypes())
            -- An unreadable or empty list (before the minimap loads) is not proof of no tracking.
            if not count or count == 0 then
                return true
            end
            for i = 1, count do
                -- Some builds return a table, others return name, texture, active, type, subType, spellID.
                local info, _, active, trackingType, _, spellID = GetTrackingInfo(i)
                if type(info) == "table" then
                    active, trackingType, spellID = info.active, info.type, info.spellID
                end
                trackingType = Plain(trackingType)
                local isSpell = trackingType == "spell" or (trackingType == nil and Plain(spellID) ~= nil)
                if Plain(active) ~= false and isSpell then
                    return true
                end
            end
            return false
        end
        if GetTrackingTexture then
            return GetTrackingTexture() ~= nil
        end
        return true
    end

    ---Whether a tracking spell is active (cached). true on a client with no tracking API.
    ---@return boolean
    function BuffState.IsTrackingActive()
        if trackingActive == nil then
            trackingActive = ReadTrackingActive()
        end
        return trackingActive
    end

    function BuffState.InvalidateTrackingCache()
        trackingActive = nil
    end
end

---Happiness of the current pet (cached): 1 unhappy, 2 content, 3 happy.
---@return number? happiness nil without a pet or on a client without pet happiness
function BuffState.GetPetHappiness()
    if not GetPetHappiness then
        return nil
    end
    if cachedPetHappiness == nil then
        if not UnitExists("pet") then
            cachedPetHappiness = false
        else
            local happiness = Plain(GetPetHappiness())
            if type(happiness) ~= "number" then
                -- Pet data is not resolved yet. Do not cache, so the next Refresh retries.
                return nil
            end
            cachedPetHappiness = happiness
        end
    end
    return cachedPetHappiness or nil
end

function BuffState.InvalidatePetHappinessCache()
    cachedPetHappiness = nil
end

---Resolve the active stance's spell ID, or nil if unstanced/unresolved (cached).
---Unstanced (form 0) is a stable result and cached as `false`; a form set but
---with unresolved spell data is a transient load state left uncached to retry.
---@return number?
local function GetActiveStanceSpellID()
    if stanceCache.activeSpellID ~= nil then
        return stanceCache.activeSpellID or nil
    end
    local active = GetShapeshiftForm()
    if not active or active == 0 then
        stanceCache.activeSpellID = false
        return nil
    end
    local _, _, _, spellID = GetShapeshiftFormInfo(active)
    if type(spellID) == "number" then
        stanceCache.activeSpellID = spellID
        return spellID
    end
    return nil
end

---Active stance spell ID, and true as second value when the stance bar has no active
---form. Both values are nil while the spell data of an active form is unresolved.
---@return number? spellID
---@return boolean? unstanced
function BuffState.GetActiveStance()
    local spellID = GetActiveStanceSpellID()
    return spellID, stanceCache.activeSpellID == false or nil
end

---Set of the spell IDs on the stance bar. Cached. A slot with unresolved spell data is
---a transient load state, so that set stays uncached to retry.
---@return table<number, true>
function BuffState.GetStanceBarSpells()
    local spells = stanceCache.barSpells
    if spells then
        return spells
    end
    spells = {}
    local resolved = true
    for i = 1, GetNumShapeshiftForms() do
        local _, _, _, spellID = GetShapeshiftFormInfo(i)
        if type(spellID) == "number" then
            spells[spellID] = true
        else
            resolved = false
        end
    end
    if resolved then
        stanceCache.barSpells = spells
    end
    return spells
end

---Whether the active stance is outside the allowed stances of the rule. A form
---set with unresolved spell data is a transient load state and reads as allowed.
---The verdict reads live, because the allowed set can follow the content type.
---@param rule StanceRule
---@return boolean
local function IsOutsideAllowedStances(rule)
    local allowed = rule.allowed()
    if not allowed then
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if activeSpellID then
        return not allowed[activeSpellID]
    end
    if stanceCache.activeSpellID == false then
        return not allowed[NO_STANCE]
    end
    return false
end

---Whether a warrior is unstanced or in a stance that the rule does not allow.
---@return boolean
function BuffState.IsWrongWarriorStance()
    return playerClass == "WARRIOR" and IsOutsideAllowedStances(STANCE_RULES.WARRIOR)
end

---Stance spell ID that the warrior click casts, or nil for non-warriors.
---@return number?
function BuffState.GetExpectedWarriorStanceID()
    if playerClass ~= "WARRIOR" then
        return nil
    end
    return STANCE_RULES.WARRIOR.castID()
end

---Texture of the active stance or form, or nil if unstanced. Cached.
---@return number?
function BuffState.GetCurrentStanceIcon()
    if stanceCache.currentStanceIcon ~= nil then
        return stanceCache.currentStanceIcon or nil
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        stanceCache.currentStanceIcon = false
        return nil
    end
    stanceCache.currentStanceIcon = C_Spell.GetSpellTexture(activeSpellID) or false
    return stanceCache.currentStanceIcon or nil
end

---Whether the priest is currently in Shadowform (or Voidform, which lives in
---the same stance bar slot). Cached. Reliable in restricted contexts because
---the stance API is unaffected by combat/encounter/M+ aura restrictions.
---@return boolean
function BuffState.IsShadowFormActive()
    if stanceCache.shadowFormActive ~= nil then
        return stanceCache.shadowFormActive
    end
    if playerClass ~= "PRIEST" then
        stanceCache.shadowFormActive = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Form 0 = no shadowform (cache). A non-zero form with unresolved spell
        -- data is a transient load state: return the safe default and retry.
        if GetShapeshiftForm() == 0 then
            stanceCache.shadowFormActive = false
            return false
        end
        return true
    end
    stanceCache.shadowFormActive = activeSpellID == SHADOWFORM or activeSpellID == VOIDFORM
    return stanceCache.shadowFormActive
end

---Whether a druid is in a form that the rule does not allow. With
---druidIgnoreTravelForm, any travel-family form or a mount reads as allowed.
---@return boolean
function BuffState.IsWrongDruidForm()
    if playerClass ~= "DRUID" then
        return false
    end
    if BR.profile.druidIgnoreTravelForm ~= false and (DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or IsMounted()) then
        return false
    end
    return IsOutsideAllowedStances(STANCE_RULES.DRUID)
end

---Form spell ID that the druid click casts (0 = cancel the form), or nil.
---@return number?
function BuffState.GetExpectedDruidFormID()
    if playerClass ~= "DRUID" then
        return nil
    end
    return STANCE_RULES.DRUID.castID()
end

---Invalidate all stance caches (active stance, stance icon, priest shadowform).
function BuffState.InvalidateStanceCache()
    wipe(stanceCache)
end

do
    local IsSpellUsable = C_Spell.IsSpellUsable
    ---@type table<number, boolean>
    local cachedSpellUsable = {}

    ---@param spellID number
    ---@return boolean
    function BuffState.IsSpellUsable(spellID)
        local usable = cachedSpellUsable[spellID]
        if usable == nil then
            usable = IsSpellUsable(spellID) == true
            cachedSpellUsable[spellID] = usable
        end
        return usable
    end

    ---@return boolean
    function BuffState.HasSpellUsableCache()
        return next(cachedSpellUsable) ~= nil
    end

    function BuffState.InvalidateSpellUsableCache()
        wipe(cachedSpellUsable)
    end
end

do
    local GetItemCooldown = C_Item.GetItemCooldown
    ---@type table<number, number> Item ID -> GetTime() at which the item is ready
    local cachedItemReadyAt = {}

    ---false while cooldowns are secret, so a reminder fails closed.
    ---@param itemID number
    ---@return boolean
    function BuffState.IsItemOffCooldown(itemID)
        if CooldownsRestricted() then
            return false
        end
        local readyAt = cachedItemReadyAt[itemID]
        if readyAt == nil then
            local ok, start, duration = pcall(GetItemCooldown, itemID)
            start, duration = ok and Plain(start) or nil, ok and Plain(duration) or nil
            if not start or not duration then
                return false
            end
            readyAt = duration > 0 and start + duration or 0
            cachedItemReadyAt[itemID] = readyAt
        end
        return readyAt <= GetTime()
    end

    ---@return boolean
    function BuffState.HasItemCooldownCache()
        return next(cachedItemReadyAt) ~= nil
    end

    function BuffState.InvalidateItemCooldownCache()
        wipe(cachedItemReadyAt)
    end
end

-- ============================================================================
-- ALLY CACHE PRUNING
-- ============================================================================
-- Drops spec / class / role for players who left the group. Pruning on the roster
-- event rather than per refresh keeps it out of combat, where a transiently
-- unresolved name can evict a member the class/role fallback still needs.

do
    local rosterFrame = CreateFrame("Frame")
    BR.Client.RegisterEvent(rosterFrame, "GROUP_ROSTER_UPDATE")
    rosterFrame:SetScript("OnEvent", function()
        local currentNames = {}
        currentNames[playerName] = true
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name = GetUnitName("raid" .. i, true)
                if name then
                    currentNames[name] = true
                end
            end
        else
            for i = 1, GetNumGroupMembers() - 1 do
                local name = GetUnitName("party" .. i, true)
                if name then
                    currentNames[name] = true
                end
            end
        end
        for _, cache in ipairs(nameKeyedAllyCaches) do
            for name in pairs(cache) do
                if not currentNames[name] then
                    cache[name] = nil
                end
            end
        end
    end)
end

-- ============================================================================
-- LIBSPECIALIZATION INTEGRATION
-- ============================================================================
-- Caches ally spec IDs received via LibSpecialization addon comms.
-- When data is unavailable (lib missing, ally not broadcasting), CountMissingBuff
-- falls back to class-based BuffBeneficiaries.

if LibSpec then
    local callbackTable = {}
    LibSpec.RegisterGroup(callbackTable, function(specId, _role, _position, sender, _talentString)
        if not sender then
            return
        end
        local oldSpec = allySpecCache[sender]
        if oldSpec == specId then
            return -- no change
        end
        allySpecCache[sender] = specId
        -- A known ally's spec change alters beneficiary counts, so ask for a render.
        if oldSpec then
            BR.CallbackRegistry:TriggerEvent("RenderRequested", false)
        end
    end)
end

-- Utility functions the display layer uses.
BR.StateHelpers = {
    GetPlayerSpecId = GetPlayerSpecId,
    FormatRemainingTime = FormatRemainingTime,
    AuraLead = Lead.Of,
    FormatEatingTime = FormatEatingTime,
    IsPlayerEating = IsPlayerEating,
    UpdateEatingState = UpdateEatingState,
    ScanEatingState = ScanEatingState,
    GetEatingExpirationTime = GetEatingExpirationTime,
    GetCurrentContentType = GetCurrentContentType,
    GetContentRow = GetContentRow,
    IsContentChoiceAllowed = IsContentChoiceAllowed,
    IsCategoryVisibleForContent = IsCategoryVisibleForContent,
    GetBuffSettingKey = GetBuffSettingKey,
    IsBuffEnabled = IsBuffEnabled,
    IsPlayerSpellCached = IsPlayerSpellCached,
    GetItemCountCached = GetItemCountCached,
    IsPlayerTank = IsPlayerTank,
    AsSpellList = AsSpellList,
    BuffTargets = BuffTargets,
}

BR.BuffState = BuffState

BR.GameContext.RegisterCache("contentType", BuffState.InvalidateContentTypeCache)
BR.GameContext.RegisterCache("auraTrackable", BuffState.InvalidateAuraTrackableCache)
BR.GameContext.RegisterCache("spell", BuffState.InvalidateSpellCache)
BR.GameContext.RegisterCache("spec", BuffState.InvalidateSpecCache)
BR.GameContext.RegisterCache("healer", BuffState.InvalidateHealerCache)
BR.GameContext.RegisterCache("subgroup", BuffState.InvalidateSubgroupCache)
BR.GameContext.RegisterCache("offHand", BuffState.InvalidateOffHandCache)
BR.GameContext.RegisterCache("item", BuffState.InvalidateItemCache)
BR.GameContext.RegisterCache("durability", BuffState.InvalidateDurabilityCache)
BR.GameContext.RegisterCache("repairSource", BuffState.InvalidateRepairSourceCache)
BR.GameContext.RegisterCache("loadout", BuffState.InvalidateLoadoutCache)
BR.GameContext.RegisterCache("pet", BuffState.InvalidatePetCache)
BR.GameContext.RegisterCache("ammo", BuffState.InvalidateAmmoCache)
BR.GameContext.RegisterCache("tracking", BuffState.InvalidateTrackingCache)
BR.GameContext.RegisterCache("petHappiness", BuffState.InvalidatePetHappinessCache)
BR.GameContext.RegisterCache("stance", BuffState.InvalidateStanceCache)
BR.GameContext.RegisterCache("spellUsable", BuffState.InvalidateSpellUsableCache)
BR.GameContext.RegisterCache("itemCooldown", BuffState.InvalidateItemCooldownCache)
BR.GameContext.RegisterCache("foreignAura", BuffState.InvalidateForeignAuraCache)
