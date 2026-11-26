local _, ns = ...
---@class BR
local BR = ns

-- Maps game events to the caches that each event makes stale, and owns the player flags
-- (combat, rest, level, vehicle), the instance context (content type, difficulty, instance
-- identity), the context windows (ready check, dungeon and delve entry, PvP prep), the dismount
-- pause for pet checks and the action-bar glow state.
-- The Display event dispatcher calls HandleEvent before the Display handler runs, so each
-- handler reads fresh values.
-- RenderRequested asks for the render that a change needs. urgent = true asks for it now.

---@alias CacheId "ammo"|"auraTrackable"|"consumables"|"contentType"|"durability"|"foreignAura"|"healer"|"item"|"itemCooldown"|"loadout"|"offHand"|"pet"|"petActions"|"petHappiness"|"repairSource"|"spec"|"spell"|"spellNameMisses"|"spellTextureMisses"|"spellUsable"|"stance"|"subgroup"|"tracking"

---@class GameContextEventSpec
---@field caches? CacheId[] Cache ids to clear, in order
---@field playerOnly? boolean The event applies only when arg1 is "player"
---@field handle? fun(...) Runs after the cache clears, with the event payload

-- The combat flag tracks events, because InCombatLockdown() can lag behind PLAYER_REGEN_DISABLED
-- and ENCOUNTER_START. It gates fighting-dependent behavior, not restriction detection.
local inCombat = false
local inEncounter = false
local isResting = false
local inVehicle = false
local playerLevel = UnitLevel("player")
local maxExpansionLevel = GetMaxLevelForPlayerExpansion()

-- The aura API stays restricted for the whole match, prep phase included, so this flag
-- gates only the hideInPvPMatch setting.
local inPvPPrepPhase = false

-- A pet respawns with a delay after a dismount, so pet checks pause for a short time.
local wasMounted = IsMounted()
local petDismountSuppressed = false

-- Each window is open while its timer exists.
local readyCheckTimer
local dungeonEntryTimer
local delveEntryTimer

local READY_CHECK_SECONDS = 15
local ENTRY_WINDOW_SECONDS = 30
local DISMOUNT_SUPPRESS_SECONDS = 1.5
local SOULWELL_SPELL_IDS = { [29893] = true, [6201] = true } -- Create Soulwell, Create Healthstone

local _, playerClass = UnitClass("player")
local IsSpellOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed

---@class GlowRegistryEntry
---@field buff table
---@field category CategoryName

-- Spell IDs whose action-bar overlay glow is up. The overlay events set any spell ID,
-- so this set does not depend on the registry.
---@type table<number, true>
local glowingSpells = {}
---@type table<number, GlowRegistryEntry>
local glowSpellToBuff = {}

local GameContext = {}

-- ============================================================================
-- INSTANCE CONTEXT
-- ============================================================================

-- Instance/content context cache: everything derived from the current zone lives
-- in ONE table because it all shares one lifecycle. Fields populate lazily and
-- InvalidateInstanceCache clears the whole table with a single wipe, so a
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

local CONTENT_DIFFICULTY_TABLES = BR.BuffData.instanceContent.difficultyIDs

---Get the current content type based on instance/zone (cached)
---@return string contentType One of "openWorld", "dungeon", "scenario", "raid", "housing", "pvp"
local function GetContentType()
    if instanceCache.contentType then
        return instanceCache.contentType
    end

    -- Stash the raw GetInstanceInfo identity for reuse - same lifecycle, cleared
    -- together in InvalidateInstanceCache. The identity fields freeze with the
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
    -- (GetDifficultyKey relies on retrying until it resolves); leave it
    -- uncached so GetDifficultyID re-reads live until real data arrives.
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

---Raw difficultyID from GetInstanceInfo, cached alongside the content type
---(nil cache = not yet computed, or a transient in-instance 0 left unresolved;
---GetInstanceInfo itself never returns nil here).
---@return number
local function GetDifficultyID()
    local id = instanceCache.difficultyID
    if id == nil then
        GetContentType() -- populates instanceCache.difficultyID (unless transient)
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
function GameContext.GetInstanceContext()
    if instanceCache.contentType == nil then
        GetContentType() -- populates the instance identity fields
    end
    return instanceCache.instanceName, instanceCache.instanceID, instanceCache.activeChallenge
end

---Get the current difficulty key (cached)
---Only caches valid keys; returns nil (retried next call) if the API returns
---an unmapped difficultyID (e.g. 0 during a loading transition).
---@return string? difficultyKey or nil if not in a dungeon/raid or unknown difficulty
local function GetDifficultyKey()
    if instanceCache.difficultyKey ~= nil then
        return instanceCache.difficultyKey
    end
    local difficultyID = GetDifficultyID()
    local contentType = GetContentType()
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

---Check if the player is in competitive PvP (arena or rated battleground)
---Consumables flagged disabledInCompetitivePvP are hidden here.
---@return boolean
local function IsInCompetitivePvP()
    if instanceCache.competitivePvP ~= nil then
        return instanceCache.competitivePvP
    end
    local contentType = GetContentType()
    if contentType ~= "pvp" then
        instanceCache.competitivePvP = false
        return false
    end
    local result = instanceCache.instanceType == "arena" or C_PvP.IsRatedMap() == true
    instanceCache.competitivePvP = result
    return result
end

---Check if the current zone qualifies for dungeon entry triggers
---(grouped dungeons only, excluding M+ and follower dungeons)
---@return boolean
local function ShouldTriggerDungeonEntry()
    if BR.BuffState.IsAlone() then
        return false
    end
    if GetContentType() ~= "dungeon" then
        return false
    end
    local diffKey = GetDifficultyKey()
    return diffKey ~= "mythicPlus" and diffKey ~= "follower"
end

---Check if the current instance is legacy content (cached alongside content type)
---@return boolean
function GameContext.IsLegacyInstance()
    if instanceCache.legacyInstance == nil then
        GetContentType() -- populates instanceCache.legacyInstance
    end
    return instanceCache.legacyInstance or false
end

---Delves use difficultyID 208. WoW Forever has no delves, so it never reports it.
---@return boolean
function GameContext.IsInDelve()
    return GetDifficultyID() == 208
end

local function InvalidateInstanceCache()
    wipe(instanceCache)
end

GameContext.GetContentType = GetContentType
GameContext.GetDifficultyID = GetDifficultyID
GameContext.GetDifficultyKey = GetDifficultyKey
GameContext.IsInCompetitivePvP = IsInCompetitivePvP

---@param urgent boolean
---@param reason? "zoneSettled" Lets a subscriber run work for one transition
local function NotifyChanged(urgent, reason)
    BR.CallbackRegistry:TriggerEvent("RenderRequested", urgent, reason)
end

local spellcastFrame = CreateFrame("Frame")

local function ClearDungeonEntry()
    if dungeonEntryTimer then
        dungeonEntryTimer:Cancel()
        dungeonEntryTimer = nil
    end
    spellcastFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    spellcastFrame:UnregisterEvent("UNIT_SPELLCAST_START")
end

spellcastFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    if SOULWELL_SPELL_IDS[spellID] then
        ClearDungeonEntry()
        NotifyChanged(true)
    end
end)

local function StartDungeonEntry()
    if dungeonEntryTimer then
        dungeonEntryTimer:Cancel()
    end
    BR.Client.RegisterEvent(spellcastFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
    BR.Client.RegisterEvent(spellcastFrame, "UNIT_SPELLCAST_START", "player")
    dungeonEntryTimer = C_Timer.NewTimer(ENTRY_WINDOW_SECONDS, function()
        ClearDungeonEntry()
        NotifyChanged(true)
    end)
    NotifyChanged(true)
end

local function ClearDelveEntry()
    if delveEntryTimer then
        delveEntryTimer:Cancel()
        delveEntryTimer = nil
    end
end

-- One entry can fire both PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA, so an open
-- window is never restarted.
local function UpdateDelveEntry()
    if not GameContext.IsInDelve() then
        ClearDelveEntry()
        return
    end
    if delveEntryTimer then
        return
    end
    delveEntryTimer = C_Timer.NewTimer(ENTRY_WINDOW_SECONDS, function()
        ClearDelveEntry()
        NotifyChanged(true)
    end)
    NotifyChanged(true)
end

local function ComputePvPPrep()
    local _, instanceType = IsInInstance()
    local inPvPZone = instanceType == "pvp" or instanceType == "arena"
    inPvPPrepPhase = inPvPZone and C_PvP.GetActiveMatchState() ~= Enum.PvPMatchState.Engaged
end

local function OnCombatStart()
    inCombat = true
    ClearDelveEntry()
end

local function OnEnteredWorldSettled()
    if ShouldTriggerDungeonEntry() then
        StartDungeonEntry()
    else
        ClearDungeonEntry()
    end
    UpdateDelveEntry()
end

-- A delve has no loading screen, so ZONE_CHANGED_NEW_AREA is its only entry signal.
-- GetInstanceInfo() still answers for the old zone when that event fires.
local function OnZoneSettled()
    GameContext.Invalidate("contentType")
    NotifyChanged(false, "zoneSettled")
    UpdateDelveEntry()
end

local function ExpireReadyCheck()
    readyCheckTimer = nil
    NotifyChanged(true)
end

-- A second dismount inside the window does not restart it, so the first timer ends it.
local function EndDismountSuppression()
    petDismountSuppressed = false
    NotifyChanged(false)
end

-- Catches glows that were up before the overlay events were registered.
local function SeedGlowingSpells()
    if not IsSpellOverlayed then
        return
    end
    for spellID, entry in pairs(glowSpellToBuff) do
        if (not entry.buff.class or entry.buff.class == playerClass) and IsSpellOverlayed(spellID) then
            glowingSpells[spellID] = true
        end
    end
end

-- A talent swap can drop a spell while its glow is up. The matching
-- SPELL_ACTIVATION_OVERLAY_GLOW_HIDE never arrives, so the flag outlives the
-- spell and fires again when the talent returns.
local function PruneGlowingSpells()
    for spellID in pairs(glowingSpells) do
        if not C_SpellBook.IsSpellKnown(spellID) then
            glowingSpells[spellID] = nil
        end
    end
end

---@type CacheId[]
local SPELL_SET = { "spell", "pet", "stance", "loadout", "petActions" }
---@type GameContextEventSpec
local CONTENT_TYPE = { caches = { "contentType" } }
---@type GameContextEventSpec
local HEALER = { caches = { "healer" } }
---@type GameContextEventSpec
local ROSTER = { caches = { "healer", "subgroup", "foreignAura" } }
---@type GameContextEventSpec
local STANCE = { caches = { "stance" } }
---@type GameContextEventSpec
local PET_HAPPINESS = {
    caches = { "petHappiness" },
    handle = function()
        NotifyChanged(false)
    end,
}
---@type GameContextEventSpec
local TRACKING = {
    caches = { "tracking" },
    handle = function()
        NotifyChanged(false)
    end,
}

---@type table<string, GameContextEventSpec>
local EVENT_CACHES = {
    PLAYER_ENTERING_WORLD = {
        caches = {
            "contentType",
            "ammo",
            "tracking",
            "auraTrackable",
            "spell",
            "spec",
            "offHand",
            "pet",
            "stance",
            "loadout",
            "repairSource",
            "durability",
            "petActions",
            "petHappiness",
            "spellTextureMisses",
            "spellNameMisses",
            "subgroup",
            "spellUsable",
            "itemCooldown",
            "foreignAura",
        },
        handle = function()
            inCombat = InCombatLockdown()
            isResting = IsResting()
            playerLevel = UnitLevel("player")
            maxExpansionLevel = GetMaxLevelForPlayerExpansion()
            inVehicle = UnitInVehicle("player") == true
            ComputePvPPrep()
            C_Timer.After(1, OnEnteredWorldSettled)
            SeedGlowingSpells()
            BR.BuffState.EndSnoozes("all")
        end,
    },
    ZONE_CHANGED_NEW_AREA = {
        handle = function()
            C_Timer.After(0.5, OnZoneSettled)
        end,
    },
    PVP_MATCH_STATE_CHANGED = { handle = ComputePvPPrep },
    READY_CHECK = {
        handle = function()
            if readyCheckTimer then
                readyCheckTimer:Cancel()
            end
            readyCheckTimer = C_Timer.NewTimer(READY_CHECK_SECONDS, ExpireReadyCheck)
            NotifyChanged(true)
        end,
    },
    PLAYER_REGEN_DISABLED = { caches = { "spellUsable" }, handle = OnCombatStart },
    PLAYER_REGEN_ENABLED = {
        caches = { "spellUsable", "foreignAura" },
        handle = function()
            inCombat = inEncounter
        end,
    },
    ENCOUNTER_START = {
        handle = function()
            inEncounter = true
            OnCombatStart()
        end,
    },
    ENCOUNTER_END = {
        caches = { "foreignAura" },
        handle = function()
            inEncounter = false
            inCombat = inCombat and InCombatLockdown()
        end,
    },
    PLAYER_UPDATE_RESTING = {
        handle = function()
            isResting = IsResting()
        end,
    },
    PLAYER_LEVEL_UP = {
        handle = function(level)
            playerLevel = level
        end,
    },
    UPDATE_EXPANSION_LEVEL = {
        handle = function()
            maxExpansionLevel = GetMaxLevelForPlayerExpansion()
        end,
    },
    UNIT_ENTERED_VEHICLE = {
        playerOnly = true,
        handle = function()
            inVehicle = true
        end,
    },
    UNIT_EXITED_VEHICLE = {
        playerOnly = true,
        handle = function()
            inVehicle = false
        end,
    },
    GROUP_ROSTER_UPDATE = ROSTER,
    GROUP_FORMED = ROSTER,
    PLAYER_ROLES_ASSIGNED = HEALER,
    UNIT_PET = { playerOnly = true, caches = { "pet", "petHappiness" } },
    UNIT_HAPPINESS = PET_HAPPINESS,
    MINIMAP_UPDATE_TRACKING = TRACKING,
    -- Death ends the active tracking.
    PLAYER_DEAD = TRACKING,
    PLAYER_ALIVE = TRACKING,
    PLAYER_UNGHOST = TRACKING,
    UPDATE_SHAPESHIFT_FORM = STANCE,
    UPDATE_SHAPESHIFT_FORMS = STANCE,
    PET_STABLE_UPDATE = { caches = { "petActions" } },
    PLAYER_DIFFICULTY_CHANGED = CONTENT_TYPE,
    CHALLENGE_MODE_START = CONTENT_TYPE,
    CHALLENGE_MODE_COMPLETED = CONTENT_TYPE,
    CHALLENGE_MODE_RESET = CONTENT_TYPE,
    PLAYER_SPECIALIZATION_CHANGED = {
        playerOnly = true,
        caches = { "spell", "spec", "offHand", "pet", "stance", "loadout", "petActions", "consumables" },
        handle = PruneGlowingSpells,
    },
    TRAIT_CONFIG_UPDATED = { caches = SPELL_SET, handle = PruneGlowingSpells },
    ACTIVE_TALENT_GROUP_CHANGED = { caches = { "spec" } },
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = {
        handle = function(spellID)
            glowingSpells[spellID] = true
        end,
    },
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = {
        handle = function(spellID)
            glowingSpells[spellID] = nil
        end,
    },
    SPELLS_CHANGED = {
        caches = {
            "spell",
            "pet",
            "stance",
            "loadout",
            "petActions",
            "spellTextureMisses",
            "spellNameMisses",
            "spellUsable",
        },
    },
    -- Fires often, for example on each power change that crosses a spell cost.
    -- An empty cache holds no stale value, so the event then requests no render.
    SPELL_UPDATE_USABLE = {
        handle = function()
            if BR.BuffState.HasSpellUsableCache() then
                GameContext.Invalidate("spellUsable")
                NotifyChanged(false)
            end
        end,
    },
    PLAYER_EQUIPMENT_CHANGED = { caches = { "item", "offHand", "loadout", "durability", "ammo" } },
    UPDATE_INVENTORY_DURABILITY = { caches = { "durability" } },
    -- A temporary weapon enchant starts and ends with no aura event.
    UNIT_INVENTORY_CHANGED = {
        playerOnly = true,
        handle = function()
            NotifyChanged(false)
        end,
    },
    BAG_UPDATE_DELAYED = { caches = { "item", "repairSource", "consumables", "ammo" } },
    -- Can fire on each spell cast. An empty cache holds no stale value, so the event
    -- then requests no render.
    BAG_UPDATE_COOLDOWN = {
        handle = function()
            if BR.BuffState.HasItemCooldownCache() then
                GameContext.Invalidate("itemCooldown")
                NotifyChanged(false)
            end
        end,
    },
    NEW_MOUNT_ADDED = { caches = { "repairSource" } },
    PLAYER_MOUNT_DISPLAY_CHANGED = {
        handle = function()
            local mounted = IsMounted()
            if wasMounted and not mounted then
                petDismountSuppressed = true
                C_Timer.After(DISMOUNT_SUPPRESS_SECONDS, EndDismountSuppression)
            end
            wasMounted = mounted
        end,
    },
}

---@type table<CacheId, fun()>
local invalidators = {}

---Bind a cache id to the function that clears the cache.
---@param id CacheId
---@param fn fun()
function GameContext.RegisterCache(id, fn)
    if invalidators[id] then
        error("GameContext: cache id '" .. id .. "' is already registered", 2)
    end
    invalidators[id] = fn
end

-- Core.lua loads before this file, so its spell name cache registers here.
GameContext.RegisterCache("spellNameMisses", BR.ClearSpellNameMisses)
GameContext.RegisterCache("contentType", InvalidateInstanceCache)

---Clear one cache. An unknown id is a programming error.
---@param id CacheId
function GameContext.Invalidate(id)
    local fn = invalidators[id]
    if not fn then
        error("GameContext: unknown cache id '" .. tostring(id) .. "'", 2)
    end
    fn()
end

---Raise an error for each cache id that an event clears but no module registered.
---Call it after every file loads: Invalidate reports a missing id only when its event fires.
function GameContext.AssertCachesRegistered()
    for event, entry in pairs(EVENT_CACHES) do
        for _, id in ipairs(entry.caches or {}) do
            if not invalidators[id] then
                error("GameContext: event '" .. event .. "' clears unregistered cache '" .. id .. "'")
            end
        end
    end
end

---@param ids CacheId[]
local function InvalidateAll(ids)
    for i = 1, #ids do
        GameContext.Invalidate(ids[i])
    end
end

---Apply the EVENT_CACHES entry for the event. Safe to call for every event.
---@param event string
---@param ... any The event payload
function GameContext.HandleEvent(event, ...)
    local entry = EVENT_CACHES[event]
    if not entry then
        return
    end
    if entry.playerOnly and (...) ~= "player" then
        return
    end
    if entry.caches then
        InvalidateAll(entry.caches)
    end
    if entry.handle then
        entry.handle(...)
    end
end

---Each event that HandleEvent reacts to. The caller must register them.
---@return fun(table: table<string, table>, key?: string): string, table
---@return table<string, table>
function GameContext.EachEvent()
    return pairs(EVENT_CACHES)
end

---@return boolean inCombat True in combat or in a boss encounter
function GameContext.IsInCombat()
    return inCombat
end

---@return boolean isResting
function GameContext.IsResting()
    return isResting
end

---@return boolean inVehicle True when the player is in a vehicle
function GameContext.IsInVehicle()
    return inVehicle
end

---@return number playerLevel
function GameContext.GetPlayerLevel()
    return playerLevel
end

---@return number maxExpansionLevel The max level of the player's expansion
function GameContext.GetMaxExpansionLevel()
    return maxExpansionLevel
end

---@return boolean inReadyCheck True for 15 seconds after a ready check starts
function GameContext.IsInReadyCheck()
    return readyCheckTimer ~= nil
end

---@return boolean inDungeonEntry True for 30 seconds after a grouped dungeon entry, until a soulwell cast
function GameContext.IsInDungeonEntry()
    return dungeonEntryTimer ~= nil
end

---@return boolean inDelveEntry True for 30 seconds after a delve entry, until combat starts
function GameContext.IsInDelveEntry()
    return delveEntryTimer ~= nil
end

---@return boolean inPvPPrepPhase True in a battleground or arena before the match starts
function GameContext.IsPvPPrepPhase()
    return inPvPPrepPhase
end

---@return boolean suppressed True for 1.5 seconds after a dismount
function GameContext.IsPetDismountSuppressed()
    return petDismountSuppressed
end

---The refresh path calls this for each tracked spell, so it stays a plain table read.
---@param spellID number
---@return boolean
function GameContext.IsSpellGlowing(spellID)
    return glowingSpells[spellID] == true
end

---@param buff table
---@return boolean
local function IsGlowTracked(buff)
    if buff.enchantID or buff.customCheck or buff.glowMode == "disabled" then
        return false
    end
    if buff.readyCheckOnly then
        local db = BR.profile
        local overrides = db and db.readyCheckOnlyOverrides
        return overrides ~= nil and overrides[buff.groupId or buff.key] == false
    end
    return true
end

---Add the spell IDs of the buff to the glow registry, if the buff qualifies.
---@param buff table
---@param category string
local function RegisterGlowBuff(buff, category)
    if not IsGlowTracked(buff) then
        return
    end
    for _, id in ipairs(BR.StateHelpers.AsSpellList(buff.spellID)) do
        if id and id ~= 0 then
            glowSpellToBuff[id] = { buff = buff, category = category }
        end
    end
end

---Wipe the glow registry and fill it from the buff tables and the active profile.
function GameContext.RebuildGlowRegistry()
    wipe(glowSpellToBuff)
    local buffTables = BR.BuffData.buffTables
    -- A loadout rule checks a talent, not an aura, so it never joins.
    for category, buffs in pairs(buffTables) do
        if category ~= "custom" and category ~= "loadout" then
            for _, buff in ipairs(buffs) do
                RegisterGlowBuff(buff, category)
            end
        end
    end
    -- Custom buffs register last, so a custom buff keeps a spell ID that a built-in buff also uses.
    for _, buff in ipairs(buffTables.custom) do
        RegisterGlowBuff(buff, "custom")
    end
end

BR.CallbackRegistry:RegisterCallback("SettingChanged", function(_, path)
    if path == "readyCheckOnlyOverrides" or path:find("^readyCheckOnlyOverrides%.") then
        GameContext.RebuildGlowRegistry()
    end
end)

BR.GameContext = GameContext
