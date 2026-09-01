local _, BR = ...

-- ============================================================================
-- BUFF STATE MODULE
-- ============================================================================
-- Pure data layer: computes "what buffs are missing" without any UI concerns.
-- Display layer subscribes to BuffStateChanged events to render.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class BuffStateEntry
---@field key string                         -- "intellect", "devotionAura", etc.
---@field category CategoryName              -- "raid", "presence", "targeted", "self", "pet", "consumable", "custom"
---@field sortOrder number                   -- Position within category for display ordering
---@field visible boolean                    -- Should show?
---@field displayType "count"|"text"|"expiring"
---@field countText string?                  -- "17/20" for raid buffs, "5m" for expiring consumables
---@field overlayText string?                -- "NO\nAURA" for non-raid
---@field expiringTime number?               -- Seconds remaining if expiring
---@field shouldGlow boolean                 -- Expiration glow?
---@field iconByRole table<RoleType,number>? -- Role-based icon override
---@field rebuffWarning boolean?             -- Consumable rebuff pulsing border?
---@field isEating boolean?                 -- Food entry: player is currently eating
---@field eatingExpirationTime number?      -- GetTime()-based expiration of eating aura
---@field petActions PetActionList?           -- Expanded pet summon actions
---@field dynamicIcon number|string|nil      -- Dynamic icon texture override (e.g. next poison to cast)
---@field glowKindOverride "expiring"|"missing"|nil -- Override glow kind (e.g. healthstone low stock uses expiring glow)
---@field subLabel string?                    -- Wrapping label rendered below the icon (loadout reminders: the set/talent name)

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local ceil = math.ceil
local format = string.format
local tinsert = table.insert
local tostring = tostring

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

-- Player level and max expansion level (updated via SetPlayerLevel on PLAYER_LEVEL_UP)
local playerLevel = UnitLevel("player")
local maxExpansionLevel = GetMaxLevelForPlayerExpansion()

-- Ready check state (set via SetReadyCheckState)
local inReadyCheck = false

-- Instance entry state (set via SetInstanceEntryState)
-- Briefly shows buffs with showOnInstanceEntry when zoning into a dungeon/raid
local inInstanceEntry = false

-- Delve entry state (set via SetDelveEntryState)
-- Briefly shows consumables with showOnInstanceEntry when zoning into a delve
local inDelveEntry = false

-- Vehicle state (set via SetInVehicle)
local inVehicle = false

-- Consumables dismissed state (transient, resets on instance change / reload)
local consumablesDismissed = false

-- Combat/encounter state (set via SetInCombat by the Display layer). It covers
-- both combat lockdown and boss encounters (ENCOUNTER_START fires before
-- InCombatLockdown() turns true). The flag gates fighting-dependent behavior
-- only; restriction detection is measured in IsRestricted().
local inCombat = false

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

-- True in the PvP prep phase (before gates open). The `hideInPvPMatch` setting
-- gates buff display once the match starts.
-- Deliberately NOT part of instanceCache: SetPvPPrepPhase manages it explicitly
-- and it must survive the cache invalidation.
-- The aura API is restricted for the entire BG/arena, prep included, so this
-- flag does NOT affect IsRestricted().
local inPvPPrepPhase = false

local DUNGEON_DIFFICULTY_KEYS = {
    [1] = "normal", -- Normal
    [2] = "heroic", -- Heroic
    [23] = "mythic", -- Mythic
    [8] = "mythicPlus", -- Mythic Keystone
    [24] = "timewalking", -- Timewalking
    [205] = "follower", -- Follower Dungeon
}

local RAID_DIFFICULTY_KEYS = {
    [17] = "lfr", -- Looking for Raid
    [14] = "normal", -- Normal
    [15] = "heroic", -- Heroic
    [16] = "mythic", -- Mythic
}

-- Maps content type to its difficulty-key lookup table
local CONTENT_DIFFICULTY_TABLES = {
    dungeon = DUNGEON_DIFFICULTY_KEYS,
    raid = RAID_DIFFICULTY_KEYS,
}

-- Maps content type to the DB key holding its difficulty sub-filter
local CONTENT_DIFF_DB_KEYS = {
    scenario = "scenarioDifficulty",
    dungeon = "dungeonDifficulty",
    raid = "raidDifficulty",
    pvp = "pvpType",
}

-- Talent/spell knowledge cache
local cachedSpellKnowledge = {}

-- Spec ID cache
local cachedSpecId = nil

-- Player role cache
local cachedPlayerRole = nil

-- Off-hand slot type cache (invalidated on equipment/spec change)
-- Populated together from a single GetInventoryItemID + GetItemInfoInstant call
local cachedOffHandType = nil -- nil = not yet checked, "weapon" | "shield" | "none"

-- Item ownership cache
---@type table<number, boolean>
local cachedItemOwnership = {}

-- Lowest equipped-item durability ratio (0-1). The 18-slot scan is a read-only
-- lookup whose answer only changes on durability / equipment events, so it is
-- memoized and reused on the fallback ticker instead of re-scanned every refresh.
---@type number|nil
local cachedLowestDurability = nil

-- Resolved repair click sources (mount to summon / item to use). Mount collection
-- and bag contents only change on their own events, so the pair is resolved once.
-- Only ever holds a positive answer (see GetRepairSources).
---@type { mountSpellID: number?, itemID: number? }|nil
local cachedRepairSources = nil

-- Loadout state cache: rule.key -> { satisfied, icon }. The detection calls
-- (IsSatisfied / GetRuleIcon) are read-only WoW lookups whose answers only change
-- on spec / talent / equipment / equipment-set events, so they are cached here and
-- reused on the 3s fallback ticker instead of re-queried every full refresh.
---@type table<string, { satisfied: boolean, icon: number|string }>
local cachedLoadoutState = {}

-- Wrong-demon-pet cache (nil = unknown/unresolved, recomputed next Refresh).
---@type boolean|nil
local cachedWrongPetStatus = nil

-- Warrior stance spell IDs (single source of truth).
local STANCE_BATTLE = 386164
local STANCE_BERSERKER = 386196
local STANCE_DEFENSIVE = 386208

-- Spec -> set of acceptable stances. Arms: Battle. Fury: Battle or Berserker
-- (Berserker talent replaces Battle). Protection: Defensive.
local WARRIOR_EXPECTED_STANCES = {
    [71] = { [STANCE_BATTLE] = true },
    [72] = { [STANCE_BATTLE] = true, [STANCE_BERSERKER] = true },
    [73] = { [STANCE_DEFENSIVE] = true },
}

-- Priest shadow forms. Shadowform is the only stance shadow priests can take;
-- Voidform is a temporary aura that visually replaces it. The stance bar API
-- works in restricted contexts (combat/encounter/M+) where aura queries fail
-- for non-whitelisted spells, so the stance bar is read directly.
local SHADOWFORM = 232698
local VOIDFORM = 194249

-- Druid forms. Only Feral (Cat) and Balance (Moonkin) are spec-required forms;
-- Guardian uses Bear Form but it is not enforced here, and Restoration has no
-- mandatory form. Incarnation talents (King of the Jungle / Chosen of Elune)
-- empower the existing form and do not swap the stance bar slot, so the
-- spec's base form ID still matches.
local DRUID_CAT_FORM = 768
local DRUID_MOONKIN_FORM = 24858
local DRUID_EXPECTED_FORMS = {
    [102] = DRUID_MOONKIN_FORM, -- Balance
    [103] = DRUID_CAT_FORM, -- Feral
}

-- Travel-family shapeshift form IDs (GetShapeshiftFormID): ground Travel and
-- Mount Form both report 3, Aquatic reports 4, Flight reports 27. Every variant
-- shares spell 783 except Mount Form (210053), so this table keys off the engine
-- form category instead of the spell. That covers any Mount Form appearance
-- variant. None of these collide with combat forms (Cat 1, Bear 5, Moonkin 31).
-- Used to suppress the wrong-form reminder during travel.
local DRUID_TRAVEL_FORM_IDS = {
    [3] = true, -- ground Travel Form + Mount Form
    [4] = true, -- Aquatic Form
    [27] = true, -- Flight Form
}

-- Shapeshift/stance cache: warrior wrong-stance + priest shadowform + druid
-- wrong-form derived values, all read off the same active-stance source and all
-- invalidated together by InvalidateStanceCache. `false` on a field = computed
-- and absent; nil = not yet computed. `activeSpellID` memoizes
-- GetActiveStanceSpellID, so a warrior/druid refresh resolves the active stance
-- once, not per derived value.
---@class StanceCache
---@field wrongStance boolean|nil
---@field expectedStanceID number|false|nil     -- false = non-warrior
---@field currentStanceIcon number|string|false|nil  -- false = unstanced
---@field shadowFormActive boolean|nil
---@field wrongDruidForm boolean|nil
---@field expectedDruidFormID number|false|nil  -- false = non-druid or non-feral/balance
---@field activeSpellID number|false|nil        -- false = unstanced; nil = not computed / transient
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
    permanentMH = nil, -- permanent enchant ID from item link (MH)
    permanentOH = nil, -- permanent enchant ID from item link (OH)
}

-- Valid group members for current refresh cycle (set once per BuffState.Refresh()).
-- Includes phased / out-of-broadcast-range allies (tagged via `isPhased`) so an
-- already-active buff on an unreachable ally still registers as covered.
-- Counting paths apply a "phased + missing -> skip" rule to keep unfixable gaps
-- out of the missing math; presence/targeted scans just iterate everyone.
---@type {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean}[]
local currentValidUnits = {}

-- Solo snapshot from the most recent BuildValidUnitCache().
-- True when GetNumGroupMembers() <= 1: covers both open-world solo (reports 0) and
-- scenario solo such as rituals (reports 1 with only the player as the lone member).
-- Real groups (>= 2 members) set this to false.
local cachedIsAlone = true
-- Whether any group member is assigned HEALER (nil = not computed this session yet).
local cachedHealerInGroup = nil

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
---@type {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean}[]
local unitEntryPool = {}
local unitEntryPoolSize = 0

---Get a unit entry from the pool or create a new one
---@param unit string
---@param class string? nil when the class read came back secret with nothing cached
---@param isPlayer boolean
---@param name string?
---@param isPhased boolean True when the unit is in another phase or out of broadcast range
---@return {unit: string, class: string?, isPlayer: boolean, name: string?, isPhased: boolean}
local function AcquireUnitEntry(unit, class, isPlayer, name, isPhased)
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
    else
        entry = { unit = unit, class = class, isPlayer = isPlayer, name = name, isPhased = isPhased }
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

---Get the player's current spec ID (cached)
---@return number?
local function GetPlayerSpecId()
    if cachedSpecId then
        return cachedSpecId
    end
    local specIndex = GetSpecialization()
    if specIndex then
        cachedSpecId = GetSpecializationInfo(specIndex)
    end
    return cachedSpecId
end

---Get the player's current role (cached)
---@return RoleType?
local function GetPlayerRole()
    if cachedPlayerRole then
        return cachedPlayerRole
    end
    local specIndex = GetSpecialization()
    if specIndex then
        cachedPlayerRole = GetSpecializationRole(specIndex)
    end
    return cachedPlayerRole
end

---Check if player knows a spell (cached version of IsPlayerSpell)
---@param spellID number
---@return boolean
local function IsPlayerSpellCached(spellID)
    if cachedSpellKnowledge[spellID] ~= nil then
        return cachedSpellKnowledge[spellID]
    end
    local knows = IsPlayerSpell(spellID)
    cachedSpellKnowledge[spellID] = knows
    return knows
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
    if cachedItemOwnership[itemID] ~= nil then
        return cachedItemOwnership[itemID]
    end
    local result
    if mode == "equipped" then
        result = HasItemEquipped(itemID)
    elseif mode == "bags" then
        result = HasItemInBags(itemID)
    else -- "owned" or nil (default)
        local ok, count = pcall(C_Item.GetItemCount, itemID)
        result = (ok and count ~= nil and count > 0) or HasItemEquipped(itemID)
    end
    cachedItemOwnership[itemID] = result
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
                currentValidUnits[#currentValidUnits + 1] = AcquireUnitEntry(unit, class, isPlayer, name, isPhased)
                -- Track max level per class (players only, for buff caster checks).
                -- Skip phased / out-of-broadcast-range allies: they cannot reliably
                -- cast on the group now. The addon must not track a buff that no
                -- reachable member can provide (e.g. priest outside the dungeon).
                if isPlayer and class and not isPhased then
                    local level = UnitLevel(unit)
                    if not classMaxLevels[class] or level > classMaxLevels[class] then
                        classMaxLevels[class] = level
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
---@return boolean
local function HasCasterForBuff(requiredClass, levelRequired)
    local maxLevel = classMaxLevels[requiredClass]
    if not maxLevel then
        return false
    end
    return not levelRequired or maxLevel >= levelRequired
end

---Check if unit has a specific buff (handles single spellID or table of spellIDs)
---@param unit string
---@param spellIDs SpellID
---@return boolean hasBuff
---@return number? remainingTime
---@return string? sourceUnit
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
            return true, remaining, AuraField(auraData, "sourceUnit")
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
            return true, remaining, AuraField(auraData, "sourceUnit")
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
            return true, remaining
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
    instanceCache.activeChallenge = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID() or nil

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

    instanceCache.legacyInstance = C_Loot.IsLegacyLootModeEnabled()
    return contentType
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
    if inVehicle and category ~= "raid" and category ~= "presence" then
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
    if contentType == "pvp" and not inPvPPrepPhase and visibility.hideInPvPMatch then
        return false
    end
    -- Per-category ready check filter (skipped when caller handles ready check independently)
    if not skipReadyCheck then
        local catSettings = db.categorySettings and db.categorySettings[category]
        if catSettings and catSettings.showOnlyOnReadyCheck and not inReadyCheck then
            return false
        end
    end
    return true
end

---Whether a custom buff is visible under its per-buff loadConditions
---@param buff CustomBuff
---@return boolean
local function IsCustomBuffVisibleForContent(buff)
    if inVehicle then
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

    if lc.readyCheckOnly and not inReadyCheck then
        return false
    end

    if lc.levelFilter then
        if lc.levelFilter == "maxLevel" and playerLevel < maxExpansionLevel then
            return false
        elseif lc.levelFilter == "belowMaxLevel" and playerLevel >= maxExpansionLevel then
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
    if inVehicle then
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

    if when.readyCheckOnly and not inReadyCheck then
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
    if inCombat then
        mode, rank = ApplyOverride(mode, rank, db.combatMode)
    end
    if playerLevel < maxExpansionLevel then
        mode = ApplyOverride(mode, rank, db.levelingMode)
    end

    return mode
end

---Determine visibility and scan scope for a buff based on tracking mode.
---Raid buffs go on everyone, so "scan group" means showing coverage numbers.
---Presence buffs live on the caster, so "scan group" means finding if anyone has the aura.
---@param trackingMode string
---@param buffClass ClassName
---@param category "raid"|"presence"
---@param hasCaster boolean
---@param castOnOthers? boolean Buff exists on the target, not the caster (e.g., Soulstone)
---@return { show: boolean, playerOnly: boolean }
local function GetTrackingScope(trackingMode, buffClass, category, hasCaster, castOnOthers)
    if not hasCaster then
        return SCOPE_HIDDEN
    end
    if ModeHidesOtherClasses(trackingMode) and buffClass ~= playerClass then
        return SCOPE_HIDDEN
    end

    if trackingMode == "self_only" then
        -- Only the player's own class buffs, on the player. A castOnOthers buff
        -- (e.g. Soulstone) lives on the target, not on the player.
        if category == "presence" and castOnOthers then
            return SCOPE_HIDDEN
        end
        return SCOPE_PLAYER_ONLY
    elseif trackingMode == "personal" then
        -- Presence buffs from other classes exist only on the caster, not on the
        -- player. In personal mode, a castOnOthers buff (Soulstone) belongs to
        -- another player.
        if category == "presence" and (buffClass ~= playerClass or castOnOthers) then
            return SCOPE_HIDDEN
        end
        return SCOPE_PLAYER_ONLY
    elseif trackingMode == "smart" then
        local isMyClass = buffClass == playerClass
        -- Raid: scan the group when the player is the caster (show coverage),
        -- otherwise check the player only.
        -- Presence: check the player only when the player is the caster, scan the
        -- group to find other casters.
        --   castOnOthers: always scan the group (the buff is on the target).
        if category == "raid" then
            if isMyClass then
                return SCOPE_GROUP
            else
                return SCOPE_PLAYER_ONLY
            end
        else
            if isMyClass and not castOnOthers then
                return SCOPE_PLAYER_ONLY
            else
                return SCOPE_GROUP
            end
        end
    elseif trackingMode == "my_buffs" then
        -- Raid: scan the group to show coverage numbers.
        -- Presence: check the player's own aura only.
        --   castOnOthers: scan the group (the buff is on another unit).
        if category == "presence" and not castOnOthers then
            return SCOPE_PLAYER_ONLY
        else
            return SCOPE_GROUP
        end
    else
        -- "all" mode: always scan the full group
        return SCOPE_GROUP
    end
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
---@return number missing
---@return number total
---@return number? minRemaining
local function CountMissingBuff(spellIDs, buffKey, playerOnly, playersOnly)
    local missing = 0
    local total = 0
    local minRemaining = nil
    local beneficiaries = BuffBeneficiaries[buffKey]
    local specBeneficiaries = SpecBeneficiaries[buffKey]

    if playerOnly or #currentValidUnits <= 1 then
        -- Solo/player-only: check if player benefits (spec-aware)
        if not UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, GetPlayerSpecId(), playerClass) then
            return 0, 0, nil
        end
        total = 1
        local hasBuff, remaining = UnitHasBuff("player", GetUnitSpellIDs(buffKey, spellIDs, playerClass))
        if not hasBuff then
            missing = 1
        elseif remaining then
            minRemaining = remaining
        end
        return missing, total, minRemaining
    end

    local countNPCs = includeNPCsInCounting and not inCombat and not playersOnly
    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs unless in whitelisted content. During combat, also skip NPCs
        -- here: NPC-cast raid buff spell IDs (e.g. 432661) are not
        -- combat-whitelisted, so UnitHasBuff returns nil and the missing count is
        -- wrong. Targeted buffs use player-cast spell IDs that ARE whitelisted, so
        -- they still include NPCs.
        if data.isPlayer or countNPCs then
            if UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, allySpecCache[data.name], data.class) then
                local hasBuff, remaining = UnitHasBuff(data.unit, GetUnitSpellIDs(buffKey, spellIDs, data.class))
                -- A phased ally counts only when the buff is already on them. A
                -- phased member without the buff is an unfixable gap - nobody can
                -- cast on them - so both totals omit them.
                if not (data.isPhased and not hasBuff) then
                    total = total + 1
                    if not hasBuff then
                        missing = missing + 1
                    elseif remaining then
                        if not minRemaining or remaining < minRemaining then
                            minRemaining = remaining
                        end
                    end
                end
            end
        end
    end

    return missing, total, minRemaining
end

---Check if anyone in the group has a presence buff active
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellIDs SpellID
---@param playerOnly? boolean Only check the player, not the group
---@param playerCastOnly? boolean Count only auras cast by the player (e.g. castOnOthers for the caster class)
---@return boolean hasBuff
---@return number? minRemaining
---@return table? targetEntry First non-player unit entry that has the buff
local function HasPresenceBuff(spellIDs, playerOnly, playerCastOnly)
    if playerOnly or #currentValidUnits <= 1 then
        if playerCastOnly then
            local hasBuff, remaining = UnitHasBuffFromPlayer("player", spellIDs)
            return hasBuff, remaining, nil
        end
        local hasBuff, remaining = UnitHasBuff("player", spellIDs)
        return hasBuff, remaining, nil
    end

    local minRemaining = nil
    local found = false
    local targetEntry = nil

    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they cannot receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            local hasBuff, remaining, sourceUnit = UnitHasBuff(data.unit, spellIDs)
            -- With player-cast auras only, another player's cast can mask the
            -- player's own via GetUnitAuraBySpellID. Fall back to a HELPFUL|PLAYER
            -- scan.
            if playerCastOnly and hasBuff and not (sourceUnit and Plain(UnitIsUnit(sourceUnit, "player"))) then
                hasBuff, remaining = UnitHasBuffFromPlayer(data.unit, spellIDs)
            end
            if hasBuff then
                found = true
                if not targetEntry and not Plain(UnitIsUnit(data.unit, "player")) then
                    targetEntry = data
                end
                if remaining then
                    if not minRemaining or remaining < minRemaining then
                        minRemaining = remaining
                    end
                else
                    return true, nil, targetEntry -- no expiration, no need to keep scanning
                end
            end
        end
    end

    return found, minRemaining, targetEntry
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
---@return boolean
---@return number? minRemaining
---@return table? targetEntry Unit entry of a non-player target with the buff (for last target cache)
local function IsPlayerBuffActive(spellID, role)
    local minRemaining = nil
    local targetEntry = nil
    local hasBeneficiary = not role
    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they cannot receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            if not role or GetUnitRole(data) == role then
                hasBeneficiary = true
                local hasBuff, remaining, sourceUnit = UnitHasBuff(data.unit, spellID)
                if hasBuff then
                    local isFromPlayer = sourceUnit and Plain(UnitIsUnit(sourceUnit, "player"))
                    if not isFromPlayer then
                        -- GetUnitAuraBySpellID returns one instance. If another
                        -- player cast the same spell (e.g. two Aug Evokers), that
                        -- instance can hide the player's own. Fall back to a full
                        -- aura scan.
                        isFromPlayer, remaining = UnitHasBuffFromPlayer(data.unit, spellID)
                    end
                    if isFromPlayer then
                        if not targetEntry and not Plain(UnitIsUnit(data.unit, "player")) then
                            targetEntry = data
                        end
                        if not remaining then
                            return true, nil, targetEntry
                        end
                        if not minRemaining or remaining < minRemaining then
                            minRemaining = remaining
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
    return minRemaining ~= nil, minRemaining, targetEntry
end

---Check if player should cast their targeted buff (returns true if a beneficiary needs it)
---@param spellIDs SpellID
---@param requiredClass ClassName
---@param beneficiaryRole? RoleType
---@param requireSpecId? number
---@param buffKey? string Used for last target cache
---@return boolean? shouldShow Returns nil if player can't provide this buff
---@return number? remainingTime
local function ShouldShowTargetedBuff(spellIDs, requiredClass, beneficiaryRole, requireSpecId, buffKey, casterBuffId)
    if playerClass ~= requiredClass then
        return nil
    end
    if requireSpecId and GetPlayerSpecId() ~= requireSpecId then
        return nil
    end

    local spellID = (type(spellIDs) == "table" and spellIDs[1] or spellIDs) --[[@as number]]
    if not IsPlayerSpellCached(spellID) then
        return nil
    end

    -- Targeted buffs require an ally to cast on. cachedIsAlone covers both
    -- open-world solo (groupSize 0) and scenario solo (groupSize 1, player only).
    if cachedIsAlone then
        return nil
    end

    if casterBuffId then
        -- Shortcut: check if the caster has this buff on themselves (combat-safe spell ID)
        local hasBuff, remaining = UnitHasBuff("player", casterBuffId)
        -- Scan the group for the original buff and record only on a hit. The
        -- target-side spell can be unqueryable (off the aura whitelist in restricted
        -- contexts like M+, or the target is phased / out of range), so a miss is
        -- ambiguous and must NOT forget the memory. Roster pruning handles
        -- departures, and a retarget overwrites on the next successful scan.
        if buffKey and not inCombat and hasBuff then
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
        return not hasBuff, remaining
    end

    local isActive, remaining, targetEntry = IsPlayerBuffActive(spellID, beneficiaryRole)

    -- Update target memory (records even in combat: this path only runs for
    -- whitelist-safe queries, gated by IsAuraTrackable at the call site)
    if buffKey then
        TargetMemory.Observe(buffKey, isActive, targetEntry and targetEntry.name, targetEntry and targetEntry.class)
    end

    return not isActive, remaining
end

-- Categories that skip the "player knows this spell" check.
-- Custom buffs track buffs the user *receives*, not necessarily casts.
local SKIP_SPELL_KNOWN_CATEGORIES = { custom = true }

---Check if player should cast their self buff or weapon imbue (returns true if missing)
---@param spellID SpellID
---@param requiredClass ClassName
---@param enchantID? number For weapon imbues, checks if this enchant is on either weapon
---@param requiresSpell? number Only show if player knows this spell
---@param excludeSpell? number Hide if player knows this spell
---@param buffIdOverride? number|number[] Separate buff ID(s) to check (if different from spellID)
---@param customCheck? fun(): boolean? Custom check function for complex buff logic
---@param requireSpecId? number Only show if player's current spec matches (WoW spec ID)
---@param skipSpellKnownCheck? boolean Skip the "player knows spell" check (for custom buffs)
---@param requiresBuffWithEnchant? boolean When true, require both enchant AND buff (for Paladin Rites)
---@return boolean? Returns nil if player can't/shouldn't use this buff
local function ShouldShowSelfBuff(
    spellID,
    requiredClass,
    enchantID,
    requiresSpell,
    excludeSpell,
    buffIdOverride,
    customCheck,
    requireSpecId,
    skipSpellKnownCheck,
    requiresBuffWithEnchant
)
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
        return customCheck()
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

    -- Weapon imbue: check if this specific enchant is on either weapon
    if enchantID then
        local hasEnchant = currentWeaponEnchants.mainHandID == enchantID or currentWeaponEnchants.offHandID == enchantID

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

-- Icon ID for the eating channel aura (the same for all food types)
BR.EATING_AURA_ICON = 133950
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
    if inVehicle then
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
    if contentType == "pvp" and not inPvPPrepPhase then
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

---Check if player is missing a consumable buff, weapon enchant, or inventory item (returns true if missing)
---@param buff table Consumable buff definition
---@return boolean shouldShow
---@return number? remainingTime seconds remaining if buff is present and has a duration
---@return number? activeSpellID the specific spell ID that matched (for multi-spell consumables)
---@return number? itemCount total count of items in inventory (for item-based consumables)
local function ShouldShowConsumableBuff(buff)
    if buff.spellID then
        local spellList = AsSpellList(buff.spellID)
        for _, id in ipairs(spellList) do
            local hasBuff, remaining = UnitHasBuff("player", id)
            if hasBuff then
                local CM = BR.ConsumableMemory
                if CM and buff.consumableCategory and not CM.IsFleetingSpell(id) then
                    CM.Remember(GetPlayerSpecId(), buff.consumableCategory, id, true)
                end
                return false, remaining, id -- Has at least one of the consumable buffs
            end
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
                return false, remaining -- Has a buff with this icon
            end
            i = i + 1
            auraData = AuraByIndex("player", i, "HELPFUL")
        end
    end

    -- Check if any weapon enchant exists (oils, stones, shaman imbues, etc.)
    if buff.checkWeaponEnchant then
        if currentWeaponEnchants.hasMainHand then
            local remaining = currentWeaponEnchants.mainHandExpiration
                    and (currentWeaponEnchants.mainHandExpiration / 1000)
                or nil
            return false, remaining -- Has a weapon enchant
        end
    end

    if buff.checkWeaponEnchantOH then
        if currentWeaponEnchants.hasOffHand then
            local remaining = currentWeaponEnchants.offHandExpiration
                    and (currentWeaponEnchants.offHandExpiration / 1000)
                or nil
            return false, remaining
        end
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
    if buff.readyCheckOnly and not inReadyCheck then
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

---Pre-built per-category lists of visible entries (populated by Refresh)
---@type table<CategoryName, BuffStateEntry[]>
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
---@return number threshold
local function GetCategoryGlowSettings(cat)
    local expiringGlow = BR.Config.GetCategorySetting(cat, "showExpirationGlow") ~= false
    local missingGlow = BR.Config.GetCategorySetting(cat, "showMissingGlow") ~= false
    local threshold = (BR.Config.GetCategorySetting(cat, "expirationThreshold") or 15) * 60
    -- In M0 dungeons (before inserting a keystone), use pre-key threshold if higher
    local defs = BR.profile and BR.profile.defaults
    local preKey = defs and defs.preKeyThreshold or 0
    if preKey > 0 and GetCurrentContentType() == "dungeon" and GetCurrentDifficultyKey() == "mythic" then
        local preKeySec = preKey * 60
        if preKeySec > threshold then
            threshold = preKeySec
        end
    end
    return expiringGlow, missingGlow, threshold
end

-- Seconds until the earliest display change that no event announces: the countdown
-- text ticks a minute, remaining time crosses the expiration threshold, an
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
---@param threshold number
local function NoteTimedChange(remaining, threshold)
    if not remaining or remaining <= 0 then
        return
    end
    local candidate
    if remaining >= threshold then
        candidate = remaining - threshold -- future crossing into "expiring"
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

---If remaining time is below threshold, mark entry as visible+expiring with glow.
---@param entry BuffStateEntry
---@param remaining? number
---@param threshold number
---@param shouldGlow boolean
---@return boolean wasSet true if the entry was marked as expiring
local function TrySetEntryExpiring(entry, remaining, threshold, shouldGlow)
    NoteTimedChange(remaining, threshold)
    if remaining and remaining < threshold then
        entry.visible = true
        entry.displayType = "expiring"
        entry.expiringTime = remaining
        entry.countText = FormatRemainingTime(remaining)
        entry.shouldGlow = shouldGlow
        return true
    end
    return false
end

-- Cached reference to Display.IsSpellGlowing (resolved once per Refresh cycle)
local cachedIsSpellGlowing = nil

---Check if any of a buff's spell IDs are glowing on the action bar (via Display layer)
---This path replaces ShouldShow* in restricted contexts, so it repeats the spec
---and spell-known gates. Without them a glow flag for an uncastable spell shows
---a reminder.
---@param buff table Buff entry with spellID field
---@return boolean
local function IsAnySpellGlowing(buff)
    if not cachedIsSpellGlowing then
        return false
    end
    if buff.requireSpecId and GetPlayerSpecId() ~= buff.requireSpecId then
        return false
    end
    local spellID = buff.spellID
    if not spellID then
        return false
    end
    if type(spellID) == "table" then
        for _, id in ipairs(spellID) do
            if IsPlayerSpellCached(id) and cachedIsSpellGlowing(id) then
                return true
            end
        end
        return false
    end
    return IsPlayerSpellCached(spellID) and cachedIsSpellGlowing(spellID)
end

-- Coverage category: the reminder counts how many group members miss the buff.
local function RefreshRaid(db, trackingMode, hideExpiring, missingCountOnly)
    local raidVisible = IsCategoryVisibleForContent("raid")
    local raidExGlow, raidMissGlow, raidThreshold = GetCategoryGlowSettings("raid")
    local bronzeHiddenInCombat = inCombat and db.bronzeHideInCombat
    for i, buff in ipairs(RaidBuffs) do
        local entry = GetOrCreateEntry(buff.key, "raid", i)
        local scope =
            GetTrackingScope(trackingMode, buff.class, "raid", HasCasterForBuff(buff.class, buff.levelRequired))

        if
            not (bronzeHiddenInCombat and buff.key == "bronze")
            and IsBuffEnabled(buff.key)
            and raidVisible
            and scope.show
        then
            local missing, total, minRemaining =
                CountMissingBuff(buff.spellID, buff.key, scope.playerOnly, buff.playersOnly)

            if missing > 0 then
                entry.visible = true
                entry.displayType = "count"
                local buffed = total - missing
                entry.countText = scope.playerOnly and ""
                    or (missingCountOnly and tostring(missing) or (buffed .. "/" .. total))
                entry.shouldGlow = raidMissGlow
                NoteTimedChange(minRemaining, raidThreshold)
                if minRemaining and minRemaining < raidThreshold then
                    entry.expiringTime = minRemaining
                end
            elseif not hideExpiring then
                TrySetEntryExpiring(entry, minRemaining, raidThreshold, raidExGlow)
            end
        end
    end
end

-- The player's own buffs on themselves, weapon imbues included.
local function RefreshSelf(isAuraRestricted, hideExpiring)
    local selfVisible = IsCategoryVisibleForContent("self")
    local selfExGlow, selfMissGlow, selfThreshold = GetCategoryGlowSettings("self")
    for i, buff in ipairs(SelfBuffs) do
        local entry = GetOrCreateEntry(buff.key, "self", i)
        local settingKey = buff.groupId or buff.key

        if buff.showOnInstanceEntry then
            -- Self buff shown only briefly on zone-in - no normal buff checks.
            -- customCheck makes an API call, so it runs after every other gate.
            if
                inInstanceEntry
                and selfVisible
                and (not buff.class or buff.class == playerClass)
                and IsBuffEnabled(settingKey)
                and (not buff.customCheck or buff.customCheck(isAuraRestricted))
            then
                SetEntryText(entry, buff.overlayText, selfMissGlow)
            end
        else
            if selfVisible and IsBuffEnabled(settingKey) then
                local trackable = IsAuraTrackable(buff)
                local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
                if not isAuraRestricted or trackable or useGlowDet then
                    if useGlowDet then
                        if IsAnySpellGlowing(buff) then
                            SetEntryText(entry, buff.overlayText, selfMissGlow)
                            BR.Helpers.ApplyDynamicIcon(entry, buff)
                        end
                    else
                        local shouldShow = ShouldShowSelfBuff(
                            buff.spellID,
                            buff.class,
                            buff.enchantID,
                            buff.requiresSpellID,
                            buff.excludeSpellID,
                            buff.buffIdOverride,
                            buff.customCheck,
                            buff.requireSpecId,
                            nil, -- skipSpellKnownCheck
                            buff.requiresBuffWithEnchant
                        )
                        -- showWhenPresent inverts the logic (e.g., Burning Rush: show when active)
                        local wantPresent = buff.showWhenPresent
                        local show = (wantPresent and shouldShow == false) or (not wantPresent and shouldShow)
                        if show then
                            SetEntryText(entry, buff.overlayText, selfMissGlow)
                            BR.Helpers.ApplyDynamicIcon(entry, buff)
                        elseif
                            shouldShow == false
                            and not wantPresent
                            and not buff.enchantID
                            and not buff.noExpirationGlow
                            and not hideExpiring
                        then
                            -- Buff present: check whether it expires soon.
                            local remaining, expiringCastID
                            if buff.getExpirationInfo then
                                remaining, expiringCastID = buff.getExpirationInfo()
                            elseif buff.buffIdOverride or buff.spellID then
                                _, remaining = UnitHasBuff("player", buff.buffIdOverride or buff.spellID)
                            end
                            if TrySetEntryExpiring(entry, remaining, selfThreshold, selfExGlow) then
                                if expiringCastID then
                                    entry.dynamicIcon = C_Spell.GetSpellTexture(expiringCastID)
                                end
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
    local repairHiddenInCombat = inCombat and db.defaults and db.defaults.repairHideInCombat ~= false
    for i, buff in ipairs(UtilityBuffs) do
        local entry = GetOrCreateEntry(buff.key, "utility", i)
        local settingKey = buff.groupId or buff.key
        local entryOk = not buff.showOnInstanceEntry or inInstanceEntry
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
            BR.Helpers.ApplyDynamicIcon(entry, buff)
        end
    end
end

-- Presence category: one group member with the buff satisfies the reminder.
local function RefreshPresence(db, trackingMode, isAuraRestricted, hideExpiring)
    local presenceVisible = IsCategoryVisibleForContent("presence")
    local presExGlow, presMissGlow, presThreshold = GetCategoryGlowSettings("presence")
    for i, buff in ipairs(PresenceBuffs) do
        local entry = GetOrCreateEntry(buff.key, "presence", i)
        -- If a self-buff entry already covers this, skip entirely
        local suppressed = false
        if buff.suppressedByEntry then
            local suppressor = BuffState.entries[buff.suppressedByEntry]
            suppressed = suppressor and suppressor.visible
        end
        if not suppressed then
            local scope = GetTrackingScope(
                trackingMode,
                buff.class,
                "presence",
                HasCasterForBuff(buff.class, buff.levelRequired),
                buff.castOnOthers
            )
            local instanceEntryOk = buff.showOnInstanceEntry
                and inInstanceEntry
                and (not buff.casterClass or buff.casterClass == playerClass)
            local readyCheckOk = not buff.readyCheckOnly or inReadyCheck
            -- Soulstone visibility mode overrides readyCheckOnly
            if buff.key == "soulstone" and not readyCheckOk then
                local ssMode = db.defaults and db.defaults.soulstoneVisibility or "readyCheck"
                if ssMode == "always" then
                    readyCheckOk = true
                elseif ssMode == "casterOnly" then
                    readyCheckOk = playerClass == "WARLOCK"
                end
            end
            if not readyCheckOk and not instanceEntryOk then
                local overrides = db.readyCheckOnlyOverrides
                local overrideKey = buff.groupId or buff.key
                readyCheckOk = overrides and overrides[overrideKey] == false
            end
            local showBuff = presenceVisible
                and (readyCheckOk or instanceEntryOk)
                and scope.show
                and (not buff.groupOnly or #currentValidUnits > 1) -- solo = 1 entry (player only)
            -- castOnOthers target memory (e.g. Soulstone) updates on every refresh
            -- the aura API allows, independent of reminder visibility: Soulstone's
            -- display is ready-check-gated, but the click macro needs current memory
            -- at all times. The display branch below reuses this scan result, so the
            -- buff is never scanned twice in one refresh.
            local isOwnCaster = buff.castOnOthers and buff.class == playerClass
            local hasBuff, minRemaining, targetEntry
            local scanned = false
            if
                isOwnCaster
                and not inCombat
                and #currentValidUnits > 1
                and IsBuffEnabled(buff.key)
                and (not isAuraRestricted or IsAuraTrackable(buff))
            then
                -- Full-group sweep (playerOnly=false): the buff lives on the target,
                -- so a player-only scan never finds it.
                hasBuff, minRemaining, targetEntry = HasPresenceBuff(buff.spellID, false, true)
                scanned = true
                TargetMemory.Observe(
                    buff.key,
                    hasBuff,
                    targetEntry and targetEntry.name,
                    targetEntry and targetEntry.class
                )
            end
            if showBuff and IsBuffEnabled(buff.key) then
                local trackable = IsAuraTrackable(buff)
                local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
                if not isAuraRestricted or trackable or useGlowDet then
                    if useGlowDet then
                        if IsAnySpellGlowing(buff) then
                            SetEntryText(entry, buff.overlayText, presMissGlow)
                        end
                    else
                        -- castOnOthers: for the caster class, count only the player's
                        -- own cast. That resolves the right target and keeps another
                        -- caster's coverage from hiding the icon.
                        if not scanned then
                            hasBuff, minRemaining = HasPresenceBuff(buff.spellID, scope.playerOnly, isOwnCaster)
                        end
                        -- customCheck gates display (e.g., soulstone CD tracking for warlocks)
                        local customOk = true
                        if not hasBuff and buff.customCheck then
                            local result = buff.customCheck(isAuraRestricted)
                            if result == false then
                                customOk = false
                            end
                        end
                        if not hasBuff and customOk then
                            SetEntryText(entry, buff.overlayText, presMissGlow)
                        elseif not buff.noExpirationGlow and not hideExpiring then
                            TrySetEntryExpiring(entry, minRemaining, presThreshold, presExGlow)
                        end
                    end
                end
            end
        end
    end
end

-- Buffs the player must keep on other units. self_only mode tracks only buffs
-- on the player, so it hides this category.
local function RefreshTargeted(db, trackingMode, isAuraRestricted, hideExpiring)
    local targetedVisible = IsCategoryVisibleForContent("targeted") and trackingMode ~= "self_only"
    local targExGlow, targMissGlow, targThreshold = GetCategoryGlowSettings("targeted")
    for i, buff in ipairs(TargetedBuffs) do
        local entry = GetOrCreateEntry(buff.key, "targeted", i)
        local settingKey = GetBuffSettingKey(buff)

        if targetedVisible and IsBuffEnabled(settingKey) then
            local trackable = IsAuraTrackable(buff)
            local useGlowDet = isAuraRestricted and not trackable and buff.glowDetectable
            if (not isAuraRestricted or trackable or useGlowDet) and PassesPreChecks(buff, nil, db, trackingMode) then
                if useGlowDet then
                    if IsAnySpellGlowing(buff) then
                        SetEntryText(entry, buff.overlayText, targMissGlow)
                    end
                else
                    local shouldShow, remaining = ShouldShowTargetedBuff(
                        buff.spellID,
                        buff.class,
                        buff.beneficiaryRole,
                        buff.requireSpecId,
                        buff.key,
                        buff.casterBuffId
                    )

                    if shouldShow then
                        SetEntryText(entry, buff.overlayText, targMissGlow)
                    elseif shouldShow == false and not hideExpiring then
                        TrySetEntryExpiring(entry, remaining, targThreshold, targExGlow)
                    end
                end
            end
        end
    end
end

-- Pet summon reminders. A summon has no duration, so nothing tracks expiration.
local function RefreshPet()
    local petVisible = IsCategoryVisibleForContent("pet")
    if IsMounted() or BR.Display.IsPetDismountSuppressed() then
        petVisible = false
    end
    local petPassiveHidden = BR.profile.petPassiveOnlyInCombat and not UnitAffectingCombat("player")
    local _, petMissGlow = GetCategoryGlowSettings("pet")
    for i, buff in ipairs(PetBuffs) do
        local entry = GetOrCreateEntry(buff.key, "pet", i)
        local settingKey = buff.groupId or buff.key

        if IsBuffEnabled(settingKey) and petVisible and not (buff.key == "petPassive" and petPassiveHidden) then
            local shouldShow = ShouldShowSelfBuff(
                buff.spellID,
                buff.class,
                buff.enchantID,
                buff.requiresSpellID,
                buff.excludeSpellID,
                buff.buffIdOverride,
                buff.customCheck,
                buff.requireSpecId,
                nil, -- skipSpellKnownCheck
                buff.requiresBuffWithEnchant
            )
            if shouldShow then
                SetEntryText(entry, buff.overlayText, petMissGlow)
                BR.Helpers.ApplyDynamicIcon(entry, buff)
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
    local consExGlow, consMissGlow, consThreshold = GetCategoryGlowSettings("consumable")
    local delveFoodOnly = db.defaults and db.defaults.delveFoodOnly and BR.IsInDelve()
    local freeMode = db.defaults and db.defaults.freeConsumableMode or "override"
    local freeVisible = freeMode == "override" and IsFreeConsumableVisible(db) or false
    -- In follow mode, healthstones use consumable category content gates (without ready check)
    local consumableContentVisible = freeMode == "follow" and IsCategoryVisibleForContent("consumable", true) or false
    -- Dismiss overrides all consumable visibility (transient, resets on instance change)
    if consumablesDismissed then
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
            -- entry, then hides. The Display layer clears the entry state on combat
            -- start.
            if
                inDelveEntry
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
            local requiredClass = buff.class or buff.casterClass
            local hasCaster = not requiredClass or HasCasterForBuff(requiredClass, buff.levelRequired)
            local isFreeConsumable = freeVisible and IsFreeConsumable(buff)
            -- Healthstone ready check mode (independent of follow/override content gates)
            local freeReadyCheckOk = true
            if buff.freeConsumable and not inReadyCheck then
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
                        local shouldShow, remainingTime, activeSpellID, itemCount = ShouldShowConsumableBuff(buff)
                        if shouldShow then
                            SetEntryText(entry, buff.overlayText, consMissGlow)
                        elseif
                            buff.key == "healthstone"
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
                                entry.countText = buff.itemMaxCharges and (itemCount .. "/" .. buff.itemMaxCharges)
                                    or tostring(itemCount)
                                entry.shouldGlow = consMissGlow
                                entry.glowKindOverride = "expiring"
                                -- A refill keeps the stone in its slot, so no bag event fires.
                                NoteChangeIn(CHARGE_RECHECK)
                            end
                        elseif not buff.noExpirationGlow and not hideExpiring then
                            if TrySetEntryExpiring(entry, remainingTime, consThreshold, consExGlow) then
                                if activeSpellID and type(buff.spellID) == "table" then
                                    local ok, tex = pcall(C_Spell.GetSpellTexture, activeSpellID)
                                    entry.dynamicIcon = ok and tex or nil
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
    local skipSpellKnown = SKIP_SPELL_KNOWN_CATEGORIES["custom"]
    for i, buff in ipairs(CustomBuffs) do
        local entry = GetOrCreateEntry(buff.key, "custom", i)
        local settingKey = buff.groupId or buff.key

        local trackable = IsAuraTrackable(buff)
        local useGlowFallback = isAuraRestricted and not trackable and buff.glowMode ~= "disabled"
        local shouldProcess = (not isAuraRestricted or trackable or useGlowFallback)
            and IsBuffEnabled(settingKey)
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
            local shouldShow = ShouldShowSelfBuff(
                buff.spellID,
                buff.class,
                buff.enchantID,
                buff.requiresSpellID,
                buff.excludeSpellID,
                buff.buffIdOverride,
                buff.customCheck,
                buff.requireSpecId,
                skipSpellKnown,
                buff.requiresBuffWithEnchant
            )
            local wantPresent = buff.showWhenPresent
            local show = (wantPresent and shouldShow == false) or (not wantPresent and shouldShow)
            if show then
                SetEntryText(entry, buff.overlayText, customMissGlow)
            elseif
                shouldShow == false
                and buff.expirationThreshold
                and buff.expirationThreshold > 0
                and not buff.enchantID
                and not hideExpiring
                and (buff.buffIdOverride or buff.spellID)
            then
                -- Buff is present (not missing), check if expiring (per-buff threshold)
                local _, remaining = UnitHasBuff("player", buff.buffIdOverride or buff.spellID)
                TrySetEntryExpiring(entry, remaining, buff.expirationThreshold * 60, true)
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
                state = { satisfied = Loadouts.IsSatisfied(rule), icon = Loadouts.GetRuleIcon(rule) }
                cachedLoadoutState[rule.key] = state
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

    -- Cache Display.IsSpellGlowing once per refresh cycle (State.lua loads before Display)
    cachedIsSpellGlowing = BR.Display and BR.Display.IsSpellGlowing

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
            entry.expiringTime = nil
            entry.rebuffWarning = nil -- legacy field, still cleared for safety
            entry.isEating = nil
            entry.eatingExpirationTime = nil
            entry.petActions = nil
            entry.dynamicIcon = nil
            entry.glowKindOverride = nil
            entry.subLabel = nil
        end
    end

    BuildValidUnitCache()

    if not groupOnly then
        -- Fetch weapon enchant info once per refresh cycle
        local hasMain, mainExp, _, mainID, hasOff, offExp, _, offID = GetWeaponEnchantInfo()
        currentWeaponEnchants.hasMainHand = hasMain or false
        currentWeaponEnchants.mainHandID = mainID
        currentWeaponEnchants.mainHandExpiration = mainExp
        currentWeaponEnchants.hasOffHand = hasOff or false
        currentWeaponEnchants.offHandID = offID
        currentWeaponEnchants.offHandExpiration = offExp

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

    RefreshRaid(db, trackingMode, hideExpiring, missingCountOnly)
    if not groupOnly then
        -- Self buffs run before presence so suppressedByEntry can read self entries.
        RefreshSelf(isAuraRestricted, hideExpiring)
        -- Chores never depend on group state, so a group refresh skips them.
        RefreshUtility(db, trackingMode, isAuraRestricted)
    end
    RefreshPresence(db, trackingMode, isAuraRestricted, hideExpiring)
    RefreshTargeted(db, trackingMode, isAuraRestricted, hideExpiring)
    if not groupOnly then
        RefreshPet()
        RefreshConsumables(db, trackingMode, isAuraRestricted, hideExpiring)
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

    BR.CallbackRegistry:TriggerEvent("BuffStateChanged")
end

---Set the player level (called on PLAYER_LEVEL_UP)
---@param level number
function BuffState.SetPlayerLevel(level)
    playerLevel = level
end

---Set the max expansion level (called on UPDATE_EXPANSION_LEVEL)
---@param level number
function BuffState.SetMaxExpansionLevel(level)
    maxExpansionLevel = level
end

---@return number playerLevel
---@return number maxExpansionLevel
function BuffState.GetLevelInfo()
    return playerLevel, maxExpansionLevel
end

---Set the ready check state
---@param state boolean
function BuffState.SetReadyCheckState(state)
    inReadyCheck = state
end

---Get the ready check state
---@return boolean
function BuffState.GetReadyCheckState()
    return inReadyCheck
end

---Set the instance entry state (briefly shows showOnInstanceEntry buffs)
---@param state boolean
function BuffState.SetInstanceEntryState(state)
    inInstanceEntry = state
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

---Set the delve entry state (briefly shows consumables with showOnInstanceEntry)
---@param state boolean
function BuffState.SetDelveEntryState(state)
    inDelveEntry = state
end

---Check if the current zone qualifies for delve entry triggers
---@return boolean
function BuffState.ShouldTriggerDelveEntry()
    return BR.IsInDelve()
end

---Set the vehicle state
---@param state boolean
function BuffState.SetInVehicle(state)
    inVehicle = state
end

---Get the vehicle state
---@return boolean
function BuffState.GetInVehicle()
    return inVehicle
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
    consumablesDismissed = state
end

---Get whether consumable reminders are dismissed
---@return boolean
function BuffState.GetConsumablesDismissed()
    return consumablesDismissed
end

---Set the combat/encounter state.
---Called by the Display layer on ENCOUNTER_START, PLAYER_REGEN_DISABLED, etc.
---@param state boolean
function BuffState.SetInCombat(state)
    inCombat = state
end

---Set the PvP prep phase flag (true before the gates open).
---@param state boolean
function BuffState.SetPvPPrepPhase(state)
    inPvPPrepPhase = state
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

---Invalidate content type cache (call on PLAYER_ENTERING_WORLD)
function BuffState.InvalidateContentTypeCache()
    wipe(instanceCache)
    -- inPvPPrepPhase is NOT reset here - SetPvPPrepPhase() manages it explicitly.
    -- A reset here clobbers the prep state when the deferred
    -- ZONE_CHANGED_NEW_AREA invalidation fires 0.5s after entry to a PvP instance.
end

---Invalidate the aura-trackable caches (call on PLAYER_ENTERING_WORLD).
---Blizzard can reclassify a spell's secrecy in a mid-session hotfix.
function BuffState.InvalidateAuraTrackableCache()
    auraTrackableCache = setmetatable({}, { __mode = "k" })
    BR.Restrictions.InvalidateSpellSecrecyCache()
end

---Invalidate spec ID cache (call on PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateSpecCache()
    cachedSpecId = nil
    cachedPlayerRole = nil
end

---Invalidate group-healer cache (call on GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED)
function BuffState.InvalidateHealerCache()
    cachedHealerInGroup = nil
end

---Get the player's current role (cached, invalidated on spec change)
---@return RoleType?
BuffState.GetPlayerRole = GetPlayerRole

---Invalidate spell knowledge cache (call on PLAYER_SPECIALIZATION_CHANGED)
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
    local _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfoInstant(offhandItemID)
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

---Get the cached off-hand enchant ID from the current refresh cycle
---@return number|nil
function BuffState.GetOffHandEnchantID()
    return currentWeaponEnchants.offHandID
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

---Invalidate off-hand weapon/shield cache (call on PLAYER_EQUIPMENT_CHANGED, PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateOffHandCache()
    cachedOffHandType = nil
end

---Invalidate item ownership + count caches (call on BAG_UPDATE_DELAYED, PLAYER_EQUIPMENT_CHANGED)
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
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = cur / max
            if pct < lowest then
                lowest = pct
            end
        end
    end
    cachedLowestDurability = lowest
    return lowest
end

---Invalidate the durability cache (call on UPDATE_INVENTORY_DURABILITY, PLAYER_EQUIPMENT_CHANGED)
function BuffState.InvalidateDurabilityCache()
    cachedLowestDurability = nil
end

---Best repair sources for the repair reminder's click action: a collected repair
---mount and/or a usable repair item. Both answers only change on collection and
---bag events, so the resolved pair is memoized.
---@return { mountSpellID: number?, itemID: number? }
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

---Invalidate the repair source cache (call on BAG_UPDATE_DELAYED, NEW_MOUNT_ADDED,
---PLAYER_ENTERING_WORLD)
function BuffState.InvalidateRepairSourceCache()
    cachedRepairSources = nil
end

---Invalidate loadout state cache (call on PLAYER_SPECIALIZATION_CHANGED,
---TRAIT_CONFIG_UPDATED, SPELLS_CHANGED, PLAYER_EQUIPMENT_CHANGED, EQUIPMENT_SETS_CHANGED)
function BuffState.InvalidateLoadoutCache()
    cachedLoadoutState = {}
end

---Check whether the player's current pet is not a Felguard (cached).
---Returns false when there is no pet or the pet is a Felguard. If the compare
---hits a secret value, the result stays uncached so later refreshes retry.
---@return boolean
function BuffState.IsWrongDemonPet()
    if cachedWrongPetStatus ~= nil then
        return cachedWrongPetStatus
    end
    if not UnitExists("pet") then
        cachedWrongPetStatus = false
        return false
    end
    local name, familyID = UnitCreatureFamily("pet")
    familyID = Plain(familyID)
    if type(familyID) ~= "number" then
        -- Pet data is not resolved yet, or is a secret value. Do not cache, so the
        -- next Refresh retries.
        return false
    end
    name = Plain(name)
    if name == nil then
        -- The name resolved to a secret. Leave it uncached and treat the pet as
        -- "not wrong" this pass (fail-closed).
        return false
    end
    cachedWrongPetStatus = familyID ~= 29 and name ~= "Felguard"
    return cachedWrongPetStatus
end

---Invalidate wrong-pet cache (call on UNIT_PET, PLAYER_ENTERING_WORLD,
---PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, SPELLS_CHANGED)
function BuffState.InvalidatePetCache()
    cachedWrongPetStatus = nil
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

---Check whether a warrior's active stance does not match their spec's
---expected stance(s) (cached). Returns true when the player is unstanced
---or in a stance that does not fit the current spec.
---@return boolean
function BuffState.IsWrongWarriorStance()
    if stanceCache.wrongStance ~= nil then
        return stanceCache.wrongStance
    end
    if playerClass ~= "WARRIOR" then
        stanceCache.wrongStance = false
        return false
    end
    local expected = WARRIOR_EXPECTED_STANCES[GetPlayerSpecId()]
    if not expected then
        stanceCache.wrongStance = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Unstanced (form 0) is wrong; unresolved form data leaves cache nil to retry.
        if GetShapeshiftForm() == 0 then
            stanceCache.wrongStance = true
            return true
        end
        return false
    end
    stanceCache.wrongStance = not expected[activeSpellID]
    return stanceCache.wrongStance
end

---Preferred stance spell ID for the current warrior spec (Defensive for Protection,
---Berserker for Fury when talented, else Battle). Returns nil for non-warriors.
---Cached.
---@return number?
function BuffState.GetExpectedWarriorStanceID()
    if stanceCache.expectedStanceID ~= nil then
        return stanceCache.expectedStanceID or nil
    end
    if playerClass ~= "WARRIOR" then
        stanceCache.expectedStanceID = false
        return nil
    end
    local specId = GetPlayerSpecId()
    if specId == 73 then
        stanceCache.expectedStanceID = STANCE_DEFENSIVE
    elseif specId == 72 and IsPlayerSpell(STANCE_BERSERKER) then
        stanceCache.expectedStanceID = STANCE_BERSERKER
    else
        stanceCache.expectedStanceID = STANCE_BATTLE
    end
    return stanceCache.expectedStanceID or nil
end

---Texture for the warrior's currently active stance, or nil if unstanced. Cached.
---@return number|string|nil
function BuffState.GetCurrentWarriorStanceIcon()
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

---Whether a Feral or Balance druid is in any form other than their spec's
---expected form (Cat for Feral, Moonkin for Balance). Returns false for other
---specs/classes, and (when druidIgnoreTravelForm is enabled) during deliberate
---travel - any travel-family form, or on a mount. Cached, except the travel/mount
---gate, which reads live so it needs no cache wiring.
---@return boolean
function BuffState.IsWrongDruidForm()
    if playerClass ~= "DRUID" then
        stanceCache.wrongDruidForm = false
        return false
    end
    -- Suppress during deliberate travel: any travel-family form, or a mount.
    -- Checked before the cache and read live, so the toggle and a mount or dismount
    -- take effect on the next refresh with no extra cache invalidation.
    if BR.profile.druidIgnoreTravelForm ~= false and (DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or IsMounted()) then
        return false
    end
    if stanceCache.wrongDruidForm ~= nil then
        return stanceCache.wrongDruidForm
    end
    local expected = DRUID_EXPECTED_FORMS[GetPlayerSpecId()]
    if not expected then
        stanceCache.wrongDruidForm = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Unshifted (form 0) is wrong. A non-zero form with unresolved spell data
        -- is a transient load state: return the safe default and retry.
        if GetShapeshiftForm() == 0 then
            stanceCache.wrongDruidForm = true
            return true
        end
        return false
    end
    stanceCache.wrongDruidForm = activeSpellID ~= expected
    return stanceCache.wrongDruidForm
end

---Expected form spell ID for the current druid spec (Cat Form for Feral,
---Moonkin Form for Balance). Returns nil for non-druids and other specs. Cached.
---@return number?
function BuffState.GetExpectedDruidFormID()
    if stanceCache.expectedDruidFormID ~= nil then
        return stanceCache.expectedDruidFormID or nil
    end
    if playerClass ~= "DRUID" then
        stanceCache.expectedDruidFormID = false
        return nil
    end
    stanceCache.expectedDruidFormID = DRUID_EXPECTED_FORMS[GetPlayerSpecId()] or false
    return stanceCache.expectedDruidFormID or nil
end

---Invalidate all stance caches (warrior wrong-stance + priest shadowform +
---druid wrong-form). Call on UPDATE_SHAPESHIFT_FORM, UPDATE_SHAPESHIFT_FORMS,
---PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, SPELLS_CHANGED,
---PLAYER_ENTERING_WORLD.
function BuffState.InvalidateStanceCache()
    wipe(stanceCache)
end

-- ============================================================================
-- ALLY CACHE PRUNING
-- ============================================================================
-- Drops spec / class / role for players who left the group. Pruning on the roster
-- event rather than per refresh keeps it out of combat, where a transiently
-- unresolved name can evict a member the class/role fallback still needs.

do
    local GetUnitName = GetUnitName
    local IsInRaid = IsInRaid
    local GetNumGroupMembers = GetNumGroupMembers

    local rosterFrame = CreateFrame("Frame")
    rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
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
        -- Trigger display refresh when a known ally changes spec (affects beneficiary counts)
        if oldSpec and BuffState.Refresh then
            BuffState.Refresh()
        end
    end)
end

-- Utility functions the display layer uses.
BR.StateHelpers = {
    GetPlayerSpecId = GetPlayerSpecId,
    FormatRemainingTime = FormatRemainingTime,
    FormatEatingTime = FormatEatingTime,
    IsPlayerEating = IsPlayerEating,
    UpdateEatingState = UpdateEatingState,
    ScanEatingState = ScanEatingState,
    GetEatingExpirationTime = GetEatingExpirationTime,
    GetCurrentContentType = GetCurrentContentType,
    IsCategoryVisibleForContent = IsCategoryVisibleForContent,
    GetBuffSettingKey = GetBuffSettingKey,
    IsBuffEnabled = IsBuffEnabled,
}

BR.BuffState = BuffState
