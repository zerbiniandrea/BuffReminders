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

-- LibSpecialization: provides ally spec IDs via addon comms (graceful if missing)
local LibSpec = LibStub and LibStub("LibSpecialization", true)

-- Local aliases
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable
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

-- Combat/encounter state (set via SetInCombat by the Display layer)
-- IMPORTANT: This flag is the single source of truth for "are aura queries restricted?"
-- within State.lua. It covers BOTH combat lockdown AND boss encounters.
--
-- Why not just call InCombatLockdown()? Because ENCOUNTER_START fires BEFORE
-- InCombatLockdown() returns true - the player isn't in combat until their first hostile
-- action lands on the boss. During that window (potentially hundreds of ms while a spell
-- is traveling), the aura API is already restricted but InCombatLockdown() still returns
-- false. Non-whitelisted spells (e.g. Devotion Aura 465) silently return nil from
-- C_UnitAuras.GetUnitAuraBySpellID, causing false "missing" flashes.
--
-- The Display layer sets this flag on ENCOUNTER_START, PLAYER_REGEN_DISABLED, etc.,
-- ensuring State.lua sees the restricted state as early as possible.
local inCombat = false

-- ============================================================================
-- CACHED VALUES (invalidated by specific events)
-- ============================================================================

-- Content type cache (invalidated on PLAYER_ENTERING_WORLD)
local cachedContentType = nil
local cachedInstanceType = nil -- raw WoW instanceType, stashed alongside content type
local cachedDifficultyID = nil -- raw GetInstanceInfo difficultyID, stashed alongside content type
local GetDifficultyIDCached -- forward declaration (defined next to GetCurrentContentType)

-- Whether we are in the PvP prep phase (before gates open). Used by the
-- `hideInPvPMatch` visibility setting to gate buff display once the match starts.
-- Note: aura API is restricted for the entire BG/arena (prep included), so this
-- does NOT affect IsRestricted() - see that function for details.
local inPvPPrepPhase = false

-- Difficulty cache (invalidated alongside content type)
local cachedDifficultyKey = nil
local cachedCompetitivePvP = nil -- arena or rated BG

-- Legacy loot cache (populated alongside content type, invalidated together)
local cachedIsLegacyInstance = nil

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

-- Talent/spell knowledge cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedSpellKnowledge = {}

-- Spec ID cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedSpecId = nil

-- Player role cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedPlayerRole = nil

-- Off-hand slot type cache (invalidated on equipment/spec change)
-- Populated together from a single GetInventoryItemID + GetItemInfoInstant call
local cachedOffHandType = nil -- nil = not yet checked, "weapon" | "shield" | "none"

-- Item ownership cache (invalidated on BAG_UPDATE_DELAYED, PLAYER_EQUIPMENT_CHANGED)
---@type table<number, boolean>
local cachedItemOwnership = {}

-- Loadout state cache: rule.key -> { satisfied, icon }. The detection calls
-- (IsSatisfied / GetRuleIcon) are read-only WoW lookups whose answers only change
-- on spec / talent / equipment / equipment-set events, so they're cached here and
-- reused on the 3s fallback ticker instead of re-queried every full refresh.
-- Invalidated on PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED,
-- SPELLS_CHANGED, PLAYER_EQUIPMENT_CHANGED, EQUIPMENT_SETS_CHANGED.
---@type table<string, { satisfied: boolean, icon: number|string }>
local cachedLoadoutState = {}

-- Wrong-demon-pet cache. UnitCreatureFamily can return secret-value familyIDs
-- under 12.0.5 taint rules, so the compare is pcall-guarded - a secret value
-- becomes "unknown" (not cached, retried) instead of crashing Refresh.
---@type boolean|nil
local cachedWrongPetStatus = nil

-- Warrior stance spell IDs (single source of truth for wrong-stance detection,
-- expected-stance lookup, and dynamic icon resolution).
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
-- for non-whitelisted spells, so we read it directly.
local SHADOWFORM = 232698
local VOIDFORM = 194249

-- Druid forms. Only Feral (Cat) and Balance (Moonkin) are spec-required forms;
-- Guardian uses Bear Form but it's not enforced here, and Restoration has no
-- mandatory form. Incarnation talents (King of the Jungle / Chosen of Elune)
-- empower the existing form rather than swapping the stance bar slot, so the
-- spec's base form ID still matches.
local DRUID_CAT_FORM = 768
local DRUID_MOONKIN_FORM = 24858
local DRUID_EXPECTED_FORMS = {
    [102] = DRUID_MOONKIN_FORM, -- Balance
    [103] = DRUID_CAT_FORM, -- Feral
}

-- Travel-family shapeshift form IDs (GetShapeshiftFormID): ground Travel and
-- Mount Form both report 3, Aquatic reports 4, Flight reports 27. Every variant
-- shares spell 783 except Mount Form (210053), so we key off the engine form
-- category instead of the spell - it's spell-agnostic and covers any Mount Form
-- appearance variant. None of these collide with combat forms (Cat 1, Bear 5,
-- Moonkin 31). Used to suppress the wrong-form reminder while traveling.
local DRUID_TRAVEL_FORM_IDS = {
    [3] = true, -- ground Travel Form + Mount Form
    [4] = true, -- Aquatic Form
    [27] = true, -- Flight Form
}

-- Wrong-warrior-stance cache + derived values (all invalidated together on
-- UPDATE_SHAPESHIFT_FORM(S), PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED,
-- SPELLS_CHANGED, PLAYER_ENTERING_WORLD).
---@type boolean|nil
local cachedWrongStanceStatus = nil
---@type number|false|nil  -- false = computed and absent (non-warrior)
local cachedExpectedStanceID = nil
---@type number|string|false|nil  -- false = computed and absent (unstanced)
local cachedCurrentStanceIcon = nil
---@type boolean|nil
local cachedShadowFormActive = nil
---@type boolean|nil
local cachedWrongDruidFormStatus = nil
---@type number|false|nil  -- false = computed and absent (non-druid or non-feral/balance)
local cachedExpectedDruidFormID = nil

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
---@type {unit: string, class: string, isPlayer: boolean, name: string?, isPhased: boolean}[]
local currentValidUnits = {}

-- "Are we effectively alone?" snapshot from the most recent BuildValidUnitCache().
-- True when GetNumGroupMembers() <= 1: covers both open-world solo (reports 0) and
-- scenario solo such as rituals (reports 1 with only the player as the lone member).
-- Real groups (>= 2 members) set this to false.
local cachedIsAlone = true

-- Spec cache: playerName -> specId (populated by LibSpecialization callbacks for allies,
-- and by BuildValidUnitCache for the local player via GetPlayerSpecId())
local allySpecCache = {}

-- Whether NPCs should be included in buff counting for the current refresh cycle.
-- True in follower dungeons and delves where NPC companions can receive buffs.
local includeNPCsInCounting = false

-- Note: inCombat (set via SetInCombat) is used by CountMissingBuff to skip NPCs during
-- combat/encounters - NPC buff spell IDs aren't on the Blizzard aura whitelist.

-- Aura-safe spell whitelist loaded from Data/AuraWhitelist.lua
local AURA_WHITELIST = BR.AURA_WHITELIST

---Determine if a buff's detection method works in aura-restricted contexts (combat + M+ keystones).
---Non-aura detection (weapon enchants, inventory checks) is always safe.
---Aura-based detection requires all queried spell IDs to be in the Blizzard whitelist.
---@param buff table Any buff table entry (RaidBuff, SelfBuff, ConsumableBuff, etc.)
---@return boolean
local function ComputeAuraTrackable(buff)
    -- Non-aura detection is always safe in restricted contexts
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

    -- All queried spell IDs must be in the whitelist
    if type(idsToCheck) == "number" then
        return AURA_WHITELIST[idsToCheck] ~= nil
    end
    for _, id in ipairs(idsToCheck) do
        if not AURA_WHITELIST[id] then
            return false
        end
    end
    return true
end

-- Memoized ComputeAuraTrackable: pure function of the (static) buff def and the
-- static whitelist, but called 1-3x per buff on every refresh. Weak-keyed side
-- table rather than a field on the def - custom buff / loadout defs are the live
-- SavedVariables tables, so a cache field would leak into the user's DB. Edited
-- custom buffs are new table objects, so they miss the cache and recompute.
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

-- Reusable set for target-memory pruning (avoids per-refresh allocation)
---@type table<string, true>
local activeNames = {}

-- Pool of reusable unit entry tables (avoids creating new tables each refresh)
---@type {unit: string, class: string, isPlayer: boolean, name: string?, isPhased: boolean}[]
local unitEntryPool = {}
local unitEntryPoolSize = 0

---Get a unit entry from the pool or create a new one
---@param unit string
---@param class string
---@param isPlayer boolean
---@param name string?
---@param isPhased boolean True when the unit is in another phase or out of broadcast range
---@return {unit: string, class: string, isPlayer: boolean, name: string?, isPhased: boolean}
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

-- Item count cache (charges included), invalidated together with cachedItemOwnership
-- on BAG_UPDATE_DELAYED / PLAYER_EQUIPMENT_CHANGED. Counts only change on bag
-- updates, so re-querying C_Item.GetItemCount every refresh is wasted work.
---@type table<number, number>
local cachedItemCounts = {}

---Get the player's item count including charges (cached)
---@param itemID number
---@return number
local function GetItemCountCached(itemID)
    local count = cachedItemCounts[itemID]
    if count ~= nil then
        return count
    end
    local ok, c = pcall(C_Item.GetItemCount, itemID, false, true)
    count = (ok and c) or 0
    cachedItemCounts[itemID] = count
    return count
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
    return not UnitIsVisible(unit) or UnitPhaseReason(unit) ~= nil
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

    -- Keep player spec in allySpecCache so CountMissingBuff can use a single
    -- lookup path (allySpecCache[name]) for both the player and allies.
    allySpecCache[playerName] = GetPlayerSpecId()

    -- Determine if NPCs should count for buff tracking this refresh.
    -- Follower dungeons and delves (scenarios) have NPC companions that can receive buffs.
    -- Other content (e.g., Legion artifact quests) has allied NPCs that cannot.
    do
        -- Default: exclude NPCs from buff counting.
        -- Only whitelist specific content where NPC companions can receive player buffs.
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
            -- member, dead/disconnected included - they haven't left the group, so
            -- target memory must survive wipes and reconnects.
            local name = GetUnitName(unit, true)
            if name then
                activeNames[name] = true
            end
            if IsValidBuffTarget(unit) then
                local _, class = UnitClass(unit)
                local isPlayer = UnitIsPlayer(unit)
                local isPhased = IsUnitPhased(unit)
                currentValidUnits[#currentValidUnits + 1] = AcquireUnitEntry(unit, class, isPlayer, name, isPhased)
                -- Track max level per class (players only, for buff caster checks).
                -- Skip phased / out-of-broadcast-range allies: they can't reliably
                -- cast on the group right now, so they shouldn't make us track buffs
                -- no one reachable can provide (e.g. priest outside the dungeon).
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
    -- NOT buff-target validity - a dead or offline member hasn't left)
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
            local remaining
            if auraData.expirationTime and auraData.expirationTime > 0 then
                remaining = auraData.expirationTime - GetTime()
            end
            return true, remaining, auraData.sourceUnit
        end
        return false, nil, nil
    end

    -- Table path: multiple spellIDs
    for _, id in ipairs(spellIDs) do
        local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, id)
        if auraData then
            local remaining
            if auraData.expirationTime and auraData.expirationTime > 0 then
                remaining = auraData.expirationTime - GetTime()
            end
            return true, remaining, auraData.sourceUnit
        end
    end

    return false, nil, nil
end

---Resolve the specific spell ID(s) that should be queried for this unit.
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

-- pcall bodies for per-aura scans, hoisted to named functions so hot loops don't
-- allocate a closure per aura. Aura fields (spellId, icon) are tainted secret
-- values for non-whitelisted auras in restricted contexts (combat, encounters,
-- M+); the pcall turns the throwing compare into a non-match.
---@param auraData table
---@param singleId number?
---@param spellIDs SpellID
---@return boolean
local function AuraMatchesSpellIDs(auraData, singleId, spellIDs)
    local sid = auraData.spellId
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
    return auraData.icon == iconID
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
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
    while auraData do
        local ok, match = pcall(AuraMatchesSpellIDs, auraData, singleId, spellIDs)
        if ok and match then
            local remaining
            if auraData.expirationTime and auraData.expirationTime > 0 then
                remaining = auraData.expirationTime - GetTime()
            end
            return true, remaining
        end
        i = i + 1
        auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
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

---Check if a buff is enabled (defaults to true if not explicitly set to false)
---@param key string
---@return boolean
local function IsBuffEnabled(key)
    local db = BR.profile
    return db.enabledBuffs[key] ~= false
end

---Get the current content type based on instance/zone (cached)
---@return string contentType One of "openWorld", "dungeon", "scenario", "raid", "housing", "pvp"
local function GetCurrentContentType()
    if cachedContentType then
        return cachedContentType
    end

    -- Stash the raw difficultyID for cheap reuse (delve check below, difficulty
    -- key, NPC-counting gate, Decor Duel check in Display) - same lifecycle as
    -- the content type cache, cleared together in InvalidateContentTypeCache.
    local difficultyID = select(3, GetInstanceInfo())
    cachedDifficultyID = difficultyID

    -- Check housing before instance type (housing zones may report as instanced)
    if
        C_Housing
        and (
            (C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot())
            or (C_Housing.IsOnNeighborhoodMap and C_Housing.IsOnNeighborhoodMap())
        )
    then
        cachedContentType = "housing"
        return cachedContentType
    end

    -- Delves report inInstance=false but instanceType="scenario" and difficultyID=208;
    -- check difficultyID first so they are correctly classified as scenarios.
    if difficultyID == 208 then
        cachedContentType = "scenario"
        return cachedContentType
    end

    local inInstance, instanceType = IsInInstance()
    cachedInstanceType = instanceType
    if not inInstance then
        cachedContentType = "openWorld"
    elseif instanceType == "raid" then
        cachedContentType = "raid"
    elseif instanceType == "scenario" then
        cachedContentType = "scenario"
    else
        if instanceType == "arena" or instanceType == "pvp" then
            cachedContentType = "pvp"
        else
            cachedContentType = "dungeon"
        end
    end

    cachedIsLegacyInstance = C_Loot.IsLegacyLootModeEnabled()
    return cachedContentType
end

---Raw difficultyID from GetInstanceInfo, cached alongside the content type
---(nil cache = not yet computed; GetInstanceInfo itself never returns nil here).
---@return number
function GetDifficultyIDCached()
    if cachedDifficultyID == nil then
        GetCurrentContentType() -- populates cachedDifficultyID
    end
    return cachedDifficultyID or 0
end

---Get the current difficulty key (cached)
---Only caches valid keys; returns nil (retried next call) if the API returns
---an unmapped difficultyID (e.g. 0 during a loading transition).
---@return string? difficultyKey or nil if not in a dungeon/raid or unknown difficulty
local function GetCurrentDifficultyKey()
    if cachedDifficultyKey ~= nil then
        return cachedDifficultyKey
    end
    local difficultyID = GetDifficultyIDCached()
    local contentType = GetCurrentContentType()
    local diffTable = CONTENT_DIFFICULTY_TABLES[contentType]
    if diffTable then
        local key = diffTable[difficultyID]
        if key then
            cachedDifficultyKey = key
        end
        return key
    elseif contentType == "scenario" then
        local key = difficultyID == 208 and "delves" or "others"
        cachedDifficultyKey = key
        return key
    elseif contentType == "pvp" then
        local key = cachedInstanceType == "arena" and "arena" or "bg"
        cachedDifficultyKey = key
        return key
    end
    return nil
end

---Check if a category should be visible for the current content type
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
    -- Check difficulty sub-filter
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

---Check if a custom buff should be visible based on its per-buff loadConditions
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

    -- Difficulty sub-filter
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and lc[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end

    -- Per-buff ready check filter
    if lc.readyCheckOnly and not inReadyCheck then
        return false
    end

    -- Level filter
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

---Check if a loadout rule should be visible for the current content. Rules store a
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
            -- Unknown / retired scope (e.g. a pre-simplification test rule): hide
            -- rather than show in the wrong content.
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
        -- Only my class's buffs on me. castOnOthers (e.g., Soulstone) lives on the target, not me.
        if category == "presence" and castOnOthers then
            return SCOPE_HIDDEN
        end
        return SCOPE_PLAYER_ONLY
    elseif trackingMode == "personal" then
        -- Presence buffs from other classes exist only on the caster, not on you.
        -- castOnOthers buffs (Soulstone) are someone else's responsibility in personal mode.
        if category == "presence" and (buffClass ~= playerClass or castOnOthers) then
            return SCOPE_HIDDEN
        end
        return SCOPE_PLAYER_ONLY
    elseif trackingMode == "smart" then
        local isMyClass = buffClass == playerClass
        -- Raid: scan group if I'm the caster (show coverage), just check me otherwise
        -- Presence: just check me if I'm the caster, scan group to find other casters
        --   castOnOthers: always scan group (the buff is on the target, not on me)
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
        -- Raid: scan group to show coverage numbers
        -- Presence: just check if my own aura is active
        --   castOnOthers: scan group (the buff is on someone else)
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
        -- Skip NPCs unless in whitelisted content. During combat, also skip NPCs here:
        -- NPC-cast raid buff spell IDs (e.g., 432661) aren't combat-whitelisted, so
        -- UnitHasBuff returns nil causing false missing counts. Targeted buffs (HasPresenceBuff,
        -- IsPlayerBuffActive) use player-cast spell IDs that ARE whitelisted, so they
        -- still include NPCs via the unchanged includeNPCsInCounting check.
        if data.isPlayer or countNPCs then
            if UnitBenefitsFromBuff(specBeneficiaries, beneficiaries, allySpecCache[data.name], data.class) then
                local hasBuff, remaining = UnitHasBuff(data.unit, GetUnitSpellIDs(buffKey, spellIDs, data.class))
                -- Phased / unreachable allies count only when their having the buff
                -- contributes to coverage. A phased member who is missing the buff
                -- would be an unfixable gap (we can't cast on them), so omit them
                -- from both totals to keep the math actionable.
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
        -- Skip NPCs in content where they can't receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            local hasBuff, remaining, sourceUnit = UnitHasBuff(data.unit, spellIDs)
            -- When restricted to player-cast auras, another player's cast may mask ours via
            -- GetUnitAuraBySpellID. Fall back to a HELPFUL|PLAYER scan to find our own.
            if playerCastOnly and hasBuff and not (sourceUnit and UnitIsUnit(sourceUnit, "player")) then
                hasBuff, remaining = UnitHasBuffFromPlayer(data.unit, spellIDs)
            end
            if hasBuff then
                found = true
                if not targetEntry and not UnitIsUnit(data.unit, "player") then
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
        -- Skip NPCs in content where they can't receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            if not role or UnitGroupRolesAssigned(data.unit) == role then
                hasBeneficiary = true
                local hasBuff, remaining, sourceUnit = UnitHasBuff(data.unit, spellID)
                if hasBuff then
                    local isFromPlayer = sourceUnit and UnitIsUnit(sourceUnit, "player")
                    if not isFromPlayer then
                        -- GetUnitAuraBySpellID returns one instance; if another player cast the
                        -- same spell (e.g. two Aug Evokers), our instance may be hidden behind
                        -- theirs. Fall back to a full aura scan to find our own cast.
                        isFromPlayer, remaining = UnitHasBuffFromPlayer(data.unit, spellID)
                    end
                    if isFromPlayer then
                        -- Track first non-player target for last target cache
                        if not targetEntry and not UnitIsUnit(data.unit, "player") then
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
        -- Update target memory by scanning group for the original buff, record-only-on-found:
        -- the target-side spell may not be queryable (not on the aura whitelist in restricted
        -- contexts like M+, or the target is phased/out of range), so a miss is ambiguous and
        -- must NOT forget the memory. Departures are handled by roster pruning, and a retarget
        -- overwrites on the next successful scan.
        if buffKey and not inCombat and hasBuff then
            for _, data in ipairs(currentValidUnits) do
                if not UnitIsUnit(data.unit, "player") then
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

-- Categories where the "player knows this spell" check should be skipped.
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

    -- Custom check function takes precedence over standard checks
    if customCheck then
        return customCheck()
    end

    -- For buffs with multiple spellIDs (like shields), check if player knows ANY of them
    -- Skip for custom buffs (they track received buffs, not cast buffs)
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

        -- Standard enchant-only check
        return not hasEnchant
    end

    -- Regular buff check - use buffIdOverride if provided, otherwise use spellID
    local hasBuff, _ = UnitHasBuff("player", buffIdOverride or spellID)
    return not hasBuff
end

-- Icon ID for the eating channel aura (consistent across all food types)
-- Shared via BR namespace: also used by Display.lua for the display icon
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
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    while auraData do
        local ok, match = pcall(AuraMatchesIcon, auraData, EATING_AURA_ICON)
        if ok and match then
            eatingAuraInstanceID = auraData.auraInstanceID
            return
        end
        i = i + 1
        auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    end
end

---Update eating state from UNIT_AURA payload (called on every player UNIT_AURA)
---@param updateInfo table? The updateInfo payload from UNIT_AURA
local function UpdateEatingState(updateInfo)
    if not updateInfo then
        return
    end
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            local ok, match = pcall(AuraMatchesIcon, aura, EATING_AURA_ICON)
            if ok and match then
                eatingAuraInstanceID = aura.auraInstanceID
                break
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs and eatingAuraInstanceID then
        for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
            if id == eatingAuraInstanceID then
                eatingAuraInstanceID = nil
                break
            end
        end
    end
end

---Get expiration time of the eating aura (O(1) lookup via cached instance ID)
---@return number? expirationTime GetTime()-based expiration, nil if not eating or no duration
local function GetEatingExpirationTime()
    if not eatingAuraInstanceID then
        return nil
    end
    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", eatingAuraInstanceID)
    if not ok or not auraData or not auraData.expirationTime or auraData.expirationTime == 0 then
        return nil
    end
    return auraData.expirationTime
end

---Check if a consumable buff is free/reusable (freeConsumable flag or permanent rune in bags)
---@param buff ConsumableBuff
---@return boolean
local function IsFreeConsumable(buff)
    if buff.freeConsumable then
        return true
    end
    if buff.permanentRuneItemIDs then
        for _, itemID in ipairs(buff.permanentRuneItemIDs) do
            if HasItemByMode(itemID) then
                return true
            end
        end
    end
    return false
end

---Check if a free consumable should be visible based on its override visibility settings
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
    -- Check difficulty sub-filter
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
    if cachedCompetitivePvP ~= nil then
        return cachedCompetitivePvP
    end
    local contentType = GetCurrentContentType()
    if contentType ~= "pvp" then
        cachedCompetitivePvP = false
        return false
    end
    local result = cachedInstanceType == "arena" or C_PvP.IsRatedMap() == true
    cachedCompetitivePvP = result
    return result
end

---Check if player is missing a consumable buff, weapon enchant, or inventory item (returns true if missing)
---@param buff table Consumable buff definition
---@return boolean shouldShow
---@return number? remainingTime seconds remaining if buff is present and has a duration
---@return number? activeSpellID the specific spell ID that matched (for multi-spell consumables)
---@return number? itemCount total count of items in inventory (for item-based consumables)
local function ShouldShowConsumableBuff(buff)
    -- Check buff auras by spell ID
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
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        while auraData do
            local success, iconMatches = pcall(AuraMatchesIcon, auraData, buff.buffIconID)
            if success and iconMatches then
                local remaining = nil
                if auraData.expirationTime and auraData.expirationTime > 0 then
                    remaining = auraData.expirationTime - GetTime()
                end
                return false, remaining -- Has a buff with this icon
            end
            i = i + 1
            auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
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

    -- Check if off-hand weapon enchant exists
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
        local totalCount
        if type(itemID) == "table" then
            totalCount = 0
            for _, id in ipairs(itemID) do
                totalCount = totalCount + GetItemCountCached(id)
            end
        else
            totalCount = GetItemCountCached(itemID)
        end
        if totalCount > 0 then
            return false, nil, nil, totalCount -- Has the item in inventory
        end
    end

    -- If we have nothing to check, return false
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
    -- Custom visibility condition
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

    -- Class filtering
    if buff.class then
        if ModeHidesOtherClasses(trackingMode) and buff.class ~= playerClass then
            return false
        end
        if presentClasses and not presentClasses[buff.class] then
            return false
        end
    end

    -- Talent exclusion
    if buff.excludeSpellID and IsPlayerSpellCached(buff.excludeSpellID) then
        return false
    end

    -- Spell knowledge exclusion
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

---If remaining time is below threshold, mark entry as visible+expiring with glow.
---@param entry BuffStateEntry
---@param remaining? number
---@param threshold number
---@param shouldGlow boolean
---@return boolean wasSet true if the entry was marked as expiring
local function TrySetEntryExpiring(entry, remaining, threshold, shouldGlow)
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
---@param buff table Buff entry with spellID field
---@return boolean
local function IsAnySpellGlowing(buff)
    if not cachedIsSpellGlowing then
        return false
    end
    local spellID = buff.spellID
    if type(spellID) == "table" then
        for _, id in ipairs(spellID) do
            if cachedIsSpellGlowing(id) then
                return true
            end
        end
        return false
    end
    return cachedIsSpellGlowing(spellID)
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

    -- Build valid unit cache once per refresh cycle
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
    -- Aura API is restricted in combat/encounters (inCombat set by Display layer),
    -- during M+ keystones, and in any PvP instance (battlegrounds and arenas, including prep).
    local isAuraRestricted = BuffState.IsRestricted()
    local hideExpiring = isAuraRestricted and db.hideExpiringInCombat ~= false

    -- Process raid buffs (coverage - need everyone to have them)
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
                if minRemaining and minRemaining < raidThreshold then
                    entry.expiringTime = minRemaining
                end
            elseif not hideExpiring then
                TrySetEntryExpiring(entry, minRemaining, raidThreshold, raidExGlow)
            end
        end
    end

    -- Process self buffs (player's own buff on themselves, including weapon imbues)
    -- Evaluated before presence so suppressedByEntry can reference self entries.
    if not groupOnly then
        local selfVisible = IsCategoryVisibleForContent("self")
        local selfExGlow, selfMissGlow, selfThreshold = GetCategoryGlowSettings("self")
        for i, buff in ipairs(SelfBuffs) do
            local entry = GetOrCreateEntry(buff.key, "self", i)
            local settingKey = buff.groupId or buff.key

            if buff.showOnInstanceEntry then
                -- Instance entry only buff (e.g., soulwell reminder) - no normal buff checks
                -- Gate on cheap checks first; customCheck (API call) only when everything else passes
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
                                -- Buff present but maybe expiring
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

    -- Process presence buffs (need at least 1 person to have them)
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
            -- castOnOthers target memory (e.g. Soulstone): maintained on every refresh
            -- the aura API allows, independent of reminder visibility - Soulstone's
            -- display is ready-check-gated, but the click macro needs the memory kept
            -- current all the time. The scan result is shared with the display branch
            -- below so the buff is never scanned twice in one refresh.
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
                -- so a player-only scan could never find them.
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
                        -- castOnOthers: only count our own cast for the caster class so we get
                        -- the right target (and don't hide the icon because another caster covered it).
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

    -- Process targeted buffs (player's own buff responsibility)
    -- self_only mode tracks only buffs on the player; targeted buffs live on other units.
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

    -- Process pet buffs (pet summon reminders - no expiration tracking)
    if not groupOnly then
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
                    -- Expanded pet actions (individual summon spell icons)
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

    -- Process consumable buffs
    if not groupOnly then
        local consumableVisible = IsCategoryVisibleForContent("consumable")
        local consExGlow, consMissGlow, consThreshold = GetCategoryGlowSettings("consumable")
        local delveFoodOnly = db.defaults and db.defaults.delveFoodOnly and BR.IsInDelve()
        local freeMode = db.defaults and db.defaults.freeConsumableMode or "override"
        local freeVisible = freeMode == "override" and IsFreeConsumableVisible(db) or false
        -- In follow mode, healthstones use consumable category content gates (without ready check)
        local consumableContentVisible = freeMode == "follow" and IsCategoryVisibleForContent("consumable", true)
            or false
        -- Dismiss overrides all consumable visibility (transient, resets on instance change)
        if consumablesDismissed then
            consumableVisible = false
            freeVisible = false
            consumableContentVisible = false
        end
        local freeRcMode = db.defaults and db.defaults.healthstoneVisibility or "readyCheck"
        local competitivePvP = IsInCompetitivePvP()
        for i, buff in ipairs(Consumables) do
            local entry = GetOrCreateEntry(buff.key, "consumable", i)
            local settingKey = buff.groupId or buff.key

            if buff.showOnInstanceEntry and (db.defaults and db.defaults.delveFoodTimer) then
                -- Instance entry only consumable (e.g., delve food) - show for 30s on entry then auto-hide
                -- Combat safety handled by Display layer clearing entry state on PLAYER_REGEN_DISABLED
                if
                    inDelveEntry
                    and consumableVisible
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
                -- Gate on cheap boolean checks first; defer IsAuraTrackable and PassesPreChecks
                if
                    IsBuffEnabled(settingKey)
                    and (consumableVisible or isFreeConsumable or (buff.freeConsumable and consumableContentVisible))
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
                                -- Healthstone low-stock check: show with expiring glow when at or below threshold
                                local hsThreshold = db.defaults.healthstoneThreshold or 1
                                if itemCount <= hsThreshold then
                                    SetEntryText(entry, tostring(itemCount), consMissGlow)
                                    entry.glowKindOverride = "expiring"
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

    -- Process custom buffs (user-defined, flows through ShouldShowSelfBuff like self/pet)
    if not groupOnly then
        local _, customMissGlow = GetCategoryGlowSettings("custom")
        local skipSpellKnown = SKIP_SPELL_KNOWN_CATEGORIES["custom"]
        for i, buff in ipairs(CustomBuffs) do
            local entry = GetOrCreateEntry(buff.key, "custom", i)
            local settingKey = buff.groupId or buff.key

            -- Custom buffs with glow detection use action bar glow as fallback when aura-restricted
            local trackable = IsAuraTrackable(buff)
            local useGlowFallback = isAuraRestricted and not trackable and buff.glowMode ~= "disabled"
            local shouldProcess = (not isAuraRestricted or trackable or useGlowFallback)
                and IsBuffEnabled(settingKey)
                and IsCustomBuffVisibleForContent(buff)

            -- If requireSpellKnown is true, check if player knows at least one spell
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
                if shouldProcess and gateItemID and buff.itemCooldownCondition then
                    local ok, _, duration = pcall(C_Item.GetItemCooldown, gateItemID)
                    if ok and duration then
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

    -- Process loadout reminders (talent / loadout / equipment-set mismatch).
    -- Detection is aura-agnostic, but gear/talent swaps are blocked in every
    -- restricted context (combat, the whole M+ keystone, PvP instances), so a
    -- reminder there is unactionable noise -- suppress it until the player can
    -- actually fix the loadout. (isAuraRestricted == BuffState.IsRestricted().)
    if not groupOnly and not isAuraRestricted then
        local _, loadoutMissGlow = GetCategoryGlowSettings("loadout")
        local Loadouts = BR.Loadouts
        for i, rule in ipairs(LoadoutRules) do
            local entry = GetOrCreateEntry(rule.key, "loadout", i)
            -- Gating predicates (enabled / binding / content / instance) stay live:
            -- they're cheap DB/flag reads, and their spec/content/character inputs
            -- already resolve through caches (GetCurrentSpecID -> StateHelpers cache,
            -- GetCurrentContentType -> content cache, character key memoized once).
            -- Only the read-only API detection (satisfied + icon) is memoized per rule.
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

    -- Check if each category's entries are already sorted by sortOrder
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

    -- Fire event so display can update
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
    if cachedIsLegacyInstance == nil then
        GetCurrentContentType() -- populates cachedIsLegacyInstance
    end
    return cachedIsLegacyInstance or false
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

---Set the combat/encounter state (single source of truth for aura restrictions)
---Called by the Display layer on ENCOUNTER_START, PLAYER_REGEN_DISABLED, etc.
---@param state boolean
function BuffState.SetInCombat(state)
    inCombat = state
end

---Set whether we are in the PvP prep phase (before gates open).
---@param state boolean
function BuffState.SetPvPPrepPhase(state)
    inPvPPrepPhase = state
end

---Raw difficultyID from GetInstanceInfo (cached; invalidated with content type)
BuffState.GetDifficultyID = GetDifficultyIDCached

---Whether the player is in a restricted context (combat, M+ keystone, or any PvP instance).
---PvP instances are treated as restricted for their entire duration (prep included), since
---Blizzard now gates the aura API the whole time the player is inside the BG/arena.
---@return boolean
function BuffState.IsRestricted()
    return inCombat or GetCurrentDifficultyKey() == "mythicPlus" or GetCurrentContentType() == "pvp"
end

---Whether the player has no allies in the group (open-world solo or scenario solo).
---Live check: covers both open-world solo (groupSize 0) and scenario solo such as
---rituals (groupSize 1, player only). Internal hot paths in Refresh() should read
---cachedIsAlone instead of calling this.
---@return boolean
function BuffState.IsAlone()
    return GetNumGroupMembers() <= 1
end

-- ============================================================================
-- CACHE INVALIDATION
-- ============================================================================

---Invalidate content type cache (call on PLAYER_ENTERING_WORLD)
function BuffState.InvalidateContentTypeCache()
    cachedContentType = nil
    cachedInstanceType = nil
    cachedDifficultyID = nil
    cachedDifficultyKey = nil
    cachedCompetitivePvP = nil
    cachedIsLegacyInstance = nil
    -- Note: inPvPPrepPhase is NOT reset here - it's managed explicitly by
    -- SetPvPPrepPhase() calls from PLAYER_ENTERING_WORLD and PVP_MATCH_STATE_CHANGED.
    -- Resetting it here would clobber the prep state when ZONE_CHANGED_NEW_AREA's
    -- deferred invalidation fires 0.5s after entering a PvP instance.
end

---Invalidate spec ID cache (call on PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateSpecCache()
    cachedSpecId = nil
    cachedPlayerRole = nil
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
        -- Only trust an empty off-hand if inventory data is actually loaded. Right
        -- after a loading screen / equipment swap, slot 17 can transiently read nil
        -- for a real dual-wielder; caching "none" then would poison the rest of the
        -- session (dual-wielder read as two-handed -> wrong rune bucket). The main
        -- hand is always equipped, so a readable MH means inventory is loaded and a
        -- nil off-hand is genuinely empty. If MH is also nil, leave the cache unset
        -- so the next refresh retries (mirrors the itemClassID branch below).
        if GetInventoryItemID("player", 16) then -- INVSLOT_MAINHAND
            cachedOffHandType = "none"
        end
        return
    end
    local _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfoInstant(offhandItemID)
    if not itemClassID then
        -- Item data not yet available (intermittent right after login/reload).
        -- Leave the cache unset so the next refresh retries, rather than poisoning
        -- it with a stale "none" for the rest of the session (which would make a
        -- dual-wielder read as two-handed and mismatch their configured runes).
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

---Invalidate loadout state cache (call on PLAYER_SPECIALIZATION_CHANGED,
---TRAIT_CONFIG_UPDATED, SPELLS_CHANGED, PLAYER_EQUIPMENT_CHANGED, EQUIPMENT_SETS_CHANGED)
function BuffState.InvalidateLoadoutCache()
    cachedLoadoutState = {}
end

---Check whether the player's current pet is not a Felguard (cached).
---Returns false when there is no pet or the pet is a Felguard. If the compare
---hits a secret value, the result is left uncached so later refreshes retry
---(worst case: same cost as an uncached compare, but without the crash).
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
    if type(familyID) ~= "number" then
        -- Pet data not resolved yet; don't cache so next Refresh retries.
        return false
    end
    local ok, isWrong = pcall(function()
        return familyID ~= 29 and name ~= "Felguard"
    end)
    if not ok then
        return false
    end
    cachedWrongPetStatus = isWrong == true
    return cachedWrongPetStatus
end

---Invalidate wrong-pet cache (call on UNIT_PET, PLAYER_ENTERING_WORLD,
---PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, SPELLS_CHANGED)
function BuffState.InvalidatePetCache()
    cachedWrongPetStatus = nil
end

---Resolve the active stance's spell ID, or nil if unstanced/unresolved.
---@return number?
local function GetActiveStanceSpellID()
    local active = GetShapeshiftForm()
    if not active or active == 0 then
        return nil
    end
    local _, _, _, spellID = GetShapeshiftFormInfo(active)
    return type(spellID) == "number" and spellID or nil
end

---Check whether a warrior's active stance does not match their spec's
---expected stance(s) (cached). Returns true when the player is unstanced
---or in a stance that doesn't fit the current spec.
---@return boolean
function BuffState.IsWrongWarriorStance()
    if cachedWrongStanceStatus ~= nil then
        return cachedWrongStanceStatus
    end
    if playerClass ~= "WARRIOR" then
        cachedWrongStanceStatus = false
        return false
    end
    local expected = WARRIOR_EXPECTED_STANCES[GetPlayerSpecId()]
    if not expected then
        cachedWrongStanceStatus = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Unstanced (form 0) is wrong; unresolved form data leaves cache nil to retry.
        if GetShapeshiftForm() == 0 then
            cachedWrongStanceStatus = true
            return true
        end
        return false
    end
    cachedWrongStanceStatus = not expected[activeSpellID]
    return cachedWrongStanceStatus
end

---Preferred stance spell ID for the current warrior spec (Defensive for Protection,
---Berserker for Fury when talented, else Battle). Used for click-to-cast and the
---fallback icon when unstanced. Returns nil for non-warriors. Cached.
---@return number?
function BuffState.GetExpectedWarriorStanceID()
    if cachedExpectedStanceID ~= nil then
        return cachedExpectedStanceID or nil
    end
    if playerClass ~= "WARRIOR" then
        cachedExpectedStanceID = false
        return nil
    end
    local specId = GetPlayerSpecId()
    if specId == 73 then
        cachedExpectedStanceID = STANCE_DEFENSIVE
    elseif specId == 72 and IsPlayerSpell(STANCE_BERSERKER) then
        cachedExpectedStanceID = STANCE_BERSERKER
    else
        cachedExpectedStanceID = STANCE_BATTLE
    end
    return cachedExpectedStanceID
end

---Texture for the warrior's currently active stance, or nil if unstanced. Cached.
---@return number|string|nil
function BuffState.GetCurrentWarriorStanceIcon()
    if cachedCurrentStanceIcon ~= nil then
        return cachedCurrentStanceIcon or nil
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        cachedCurrentStanceIcon = false
        return nil
    end
    cachedCurrentStanceIcon = C_Spell.GetSpellTexture(activeSpellID) or false
    return cachedCurrentStanceIcon or nil
end

---Whether the priest is currently in Shadowform (or Voidform, which lives in
---the same stance bar slot). Cached. Reliable in restricted contexts because
---the stance API is unaffected by combat/encounter/M+ aura restrictions.
---@return boolean
function BuffState.IsShadowFormActive()
    if cachedShadowFormActive ~= nil then
        return cachedShadowFormActive
    end
    if playerClass ~= "PRIEST" then
        cachedShadowFormActive = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Form 0 = no shadowform (cache); non-zero with unresolved spell data
        -- happens transiently on load - return safe default and retry next call.
        if GetShapeshiftForm() == 0 then
            cachedShadowFormActive = false
            return false
        end
        return true
    end
    cachedShadowFormActive = activeSpellID == SHADOWFORM or activeSpellID == VOIDFORM
    return cachedShadowFormActive
end

---Whether a Feral or Balance druid is in any form other than their spec's
---expected form (Cat for Feral, Moonkin for Balance). Returns false for other
---specs/classes, and (when druidIgnoreTravelForm is enabled) while the player is
---intentionally traveling - any travel-family form or on a mount. Cached, except
---the travel/mount gate which is evaluated live so it reacts without cache wiring.
---@return boolean
function BuffState.IsWrongDruidForm()
    if playerClass ~= "DRUID" then
        cachedWrongDruidFormStatus = false
        return false
    end
    -- Suppress while intentionally traveling: any travel-family form
    -- (ground/aquatic/flight/Mount Form) or riding a regular/skyriding mount.
    -- Checked before the cache and read live so the toggle and mount/dismount
    -- take effect on the next refresh without extra cache invalidation.
    if BR.profile.druidIgnoreTravelForm ~= false and (DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or IsMounted()) then
        return false
    end
    if cachedWrongDruidFormStatus ~= nil then
        return cachedWrongDruidFormStatus
    end
    local expected = DRUID_EXPECTED_FORMS[GetPlayerSpecId()]
    if not expected then
        cachedWrongDruidFormStatus = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Unshifted (form 0) is wrong; non-zero with unresolved spell data is
        -- a transient load state - return safe default and retry next call.
        if GetShapeshiftForm() == 0 then
            cachedWrongDruidFormStatus = true
            return true
        end
        return false
    end
    cachedWrongDruidFormStatus = activeSpellID ~= expected
    return cachedWrongDruidFormStatus
end

---Expected form spell ID for the current druid spec (Cat Form for Feral,
---Moonkin Form for Balance). Returns nil for non-druids and other specs. Cached.
---@return number?
function BuffState.GetExpectedDruidFormID()
    if cachedExpectedDruidFormID ~= nil then
        return cachedExpectedDruidFormID or nil
    end
    if playerClass ~= "DRUID" then
        cachedExpectedDruidFormID = false
        return nil
    end
    cachedExpectedDruidFormID = DRUID_EXPECTED_FORMS[GetPlayerSpecId()] or false
    return cachedExpectedDruidFormID or nil
end

---Invalidate all stance caches (warrior wrong-stance + priest shadowform +
---druid wrong-form). Call on UPDATE_SHAPESHIFT_FORM, UPDATE_SHAPESHIFT_FORMS,
---PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, SPELLS_CHANGED,
---PLAYER_ENTERING_WORLD.
function BuffState.InvalidateStanceCache()
    cachedWrongStanceStatus = nil
    cachedExpectedStanceID = nil
    cachedCurrentStanceIcon = nil
    cachedShadowFormActive = nil
    cachedWrongDruidFormStatus = nil
    cachedExpectedDruidFormID = nil
end

-- ============================================================================
-- LIBSPECIALIZATION INTEGRATION
-- ============================================================================
-- Caches ally spec IDs received via LibSpecialization addon comms.
-- When data is unavailable (lib missing, ally not broadcasting), CountMissingBuff
-- falls back to class-based BuffBeneficiaries automatically.

if LibSpec then
    local GetUnitName = GetUnitName
    local IsInRaid = IsInRaid
    local GetNumGroupMembers = GetNumGroupMembers

    -- Prune stale entries when group roster changes
    local specFrame = CreateFrame("Frame")
    specFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    specFrame:SetScript("OnEvent", function()
        -- Build set of current group member names
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
        -- Remove specs for players no longer in group
        for name in pairs(allySpecCache) do
            if not currentNames[name] then
                allySpecCache[name] = nil
            end
        end
    end)

    -- Register for group spec broadcasts
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

-- Export utility functions that display layer still needs
BR.StateHelpers = {
    GetPlayerSpecId = GetPlayerSpecId,
    FormatRemainingTime = FormatRemainingTime,
    FormatEatingTime = FormatEatingTime,
    IsPlayerEating = IsPlayerEating, -- used by ConsumableMemory at runtime
    UpdateEatingState = UpdateEatingState,
    ScanEatingState = ScanEatingState,
    GetEatingExpirationTime = GetEatingExpirationTime,
    GetCurrentContentType = GetCurrentContentType,
    IsCategoryVisibleForContent = IsCategoryVisibleForContent,
    GetBuffSettingKey = GetBuffSettingKey,
    IsBuffEnabled = IsBuffEnabled,
}

-- Export the module
BR.BuffState = BuffState
