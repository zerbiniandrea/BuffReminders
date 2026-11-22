local _, ns = ...
---@class BR
local BR = ns

-- Maps game events to the caches that each event makes stale, and owns the player flags
-- (combat, rest, level, vehicle), the context windows (ready check, dungeon and delve
-- entry, PvP prep), the dismount pause for pet checks and the action-bar glow state.
-- The Display event dispatcher calls HandleEvent before the Display handler runs, so each
-- handler reads fresh values.
-- RenderRequested asks for the render that a change needs. urgent = true asks for it now.

---@alias CacheId "auraTrackable"|"consumables"|"contentType"|"durability"|"healer"|"item"|"loadout"|"offHand"|"pet"|"petActions"|"petHappiness"|"repairSource"|"spec"|"spell"|"spellNameMisses"|"spellTextureMisses"|"stance"|"subgroup"

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
    if not BR.BuffState.ShouldTriggerDelveEntry() then
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
    if BR.BuffState.ShouldTriggerDungeonEntry() then
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
local ROSTER = { caches = { "healer", "subgroup" } }
---@type GameContextEventSpec
local STANCE = { caches = { "stance" } }
---@type GameContextEventSpec
local PET_HAPPINESS = {
    caches = { "petHappiness" },
    handle = function()
        NotifyChanged(false)
    end,
}

---@type table<string, GameContextEventSpec>
local EVENT_CACHES = {
    PLAYER_ENTERING_WORLD = {
        caches = {
            "contentType",
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
    PLAYER_REGEN_DISABLED = { handle = OnCombatStart },
    PLAYER_REGEN_ENABLED = {
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
        caches = { "spell", "pet", "stance", "loadout", "petActions", "spellTextureMisses", "spellNameMisses" },
    },
    PLAYER_EQUIPMENT_CHANGED = { caches = { "item", "offHand", "loadout", "durability" } },
    UPDATE_INVENTORY_DURABILITY = { caches = { "durability" } },
    -- A temporary weapon enchant starts and ends with no aura event.
    UNIT_INVENTORY_CHANGED = {
        playerOnly = true,
        handle = function()
            NotifyChanged(false)
        end,
    },
    BAG_UPDATE_DELAYED = { caches = { "item", "repairSource", "consumables" } },
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

---Clear one cache. An unknown id is a programming error.
---@param id CacheId
function GameContext.Invalidate(id)
    local fn = invalidators[id]
    if not fn then
        error("GameContext: unknown cache id '" .. tostring(id) .. "'", 2)
    end
    fn()
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
    local buffTables = BR.BUFF_TABLES
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
