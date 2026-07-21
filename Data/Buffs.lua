local _, BR = ...

local L = BR.L

-- Lua stdlib locals
local min = math.min

-- WoW API locals
local GetSpellTexture = C_Spell.GetSpellTexture
local _, playerClass = UnitClass("player")

-- Secret-safe read helper (see Core.lua / docs/SecretValues.md)
local AuraField = BR.Secret.AuraField

-- ============================================================================
-- BUFF DATA TABLES
-- ============================================================================
-- This file contains all buff definition tables.
-- Loaded after Core.lua so BR namespace is available.

-- ============================================================================
-- DK RUNEFORGE DATA
-- ============================================================================
-- Permanent enchant IDs parsed from item links (GetInventoryItemLink).

---@class DKRuneforge
---@field enchantID number Permanent enchant ID from item link
---@field spellID number Spell ID for icon resolution
---@field key string Internal identifier

---@type DKRuneforge[]
local DK_RUNEFORGES = {
    { enchantID = 3368, spellID = 53344, key = "fallenCrusader" },
    { enchantID = 3370, spellID = 53343, key = "razorice" },
    { enchantID = 3847, spellID = 62158, key = "stoneskinGargoyle" },
    { enchantID = 6241, spellID = 326805, key = "sanguination" },
    { enchantID = 6242, spellID = 326855, key = "spellwarding" },
    { enchantID = 6244, spellID = 326977, key = "unendingThirst" },
    { enchantID = 6245, spellID = 327082, key = "apocalypse" },
}

BR.DK_RUNEFORGES = DK_RUNEFORGES

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---Buff icons spec. Sibling-keyed: pick exactly one of `textures`/`spells` for the static
---side, and at most one of `dynamic`/`byRole` for the runtime side.
---@class IconSpec
---@field textures? number[]                       Static texture IDs (raw artwork).
---@field spells?   number[]                       Static spell IDs resolved to textures.
---@field dynamic?  fun(): number?                 Runtime override: computed each render.
---@field byRole?   table<RoleType, number>        Runtime override: role -> spell ID. Also drives click-to-cast spell selection.

---@class RaidBuff
---@field spellID SpellID
---@field castSpellID? number Spell ID used for click-to-cast when different from the buff aura IDs
---@field key string
---@field name string
---@field class ClassName
---@field levelRequired? number
---@field playersOnly? boolean Exclude NPCs from the count (e.g. buffs NPCs provide themselves)
---@field chatRequestable? boolean Offer "request this buff in chat" on click for players who can't provide it

---@class PresenceBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field class ClassName
---@field levelRequired? number
---@field overlayText string
---@field groupId? string
---@field excludeSpellID? number
---@field icons? IconSpec See "Icon fields" comment at end of self[]
---@field infoTooltip? TooltipText
---@field noExpirationGlow? boolean
---@field readyCheckOnly? boolean Only show during ready checks
---@field showOnInstanceEntry? boolean Also show when entering an instance (not M+)
---@field castOnOthers? boolean Buff exists on the target, not the caster (e.g., Soulstone)
---@field pinnedTarget? fun(): string? User-assigned hard target name, nil when unset (e.g., Soulstone pin)
---@field glowDetectable? boolean Use action bar glow as fallback detection when aura API is restricted
---@field groupOnly? boolean Only show when in a group (hide when solo)
---@field suppressedByEntry? string Hide when this entry key is already visible (e.g., self buff covers it)
---@field chatRequestable? boolean Offer "request this buff in chat" on click for players who can't provide it

---@class TargetedBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field class ClassName
---@field overlayText string
---@field groupId? string
---@field beneficiaryRole? RoleType
---@field excludeSpellID? number
---@field icons? IconSpec See "Icon fields" comment at end of self[]
---@field requireSpecId? number
---@field infoTooltip? TooltipText
---@field defaultEnabled? boolean Ships disabled when false (opt-in); enabled otherwise. Resolved at read time by IsBuffEnabled.
---@field clickMacro? fun(spellID: number?): string
---@field casterBuffId? number Check this buff on the caster instead of scanning group
---@field glowDetectable? boolean Use action bar glow as fallback detection when aura API is restricted

---@class SelfBuff
---@field spellID? SpellID
---@field key string
---@field name string
---@field class? ClassName
---@field overlayText string
---@field groupId? string
---@field defaultEnabled? boolean Ships disabled when false (opt-in); enabled otherwise. Resolved at read time by IsBuffEnabled.
---@field enchantID? number
---@field requiresBuffWithEnchant? boolean -- When true, require both enchant AND buff to be present (for Paladin Rites)
---@field castSpellID? number           -- Spell ID used for click-to-cast when different from spellID
---@field clickMacro? fun(spellID: number?): string -- Macro text override for click-to-cast, receives castable spell ID
---@field buffIdOverride? number|number[]
---@field requireSpecId? number        -- Only show if player's current spec matches (WoW spec ID)
---@field requiresSpellID? number
---@field excludeSpellID? number
---@field icons? IconSpec See "Icon fields" comment at end of self[]
---@field infoTooltip? TooltipText
---@field customCheck? fun(isRestricted?: boolean): boolean?
---@field getPetActions? fun(): PetAction[]?  -- Override pet actions (e.g., wrong pet -> Felguard only)
---@field glowDetectable? boolean Use action bar glow as fallback detection when aura API is restricted
---@field showOnInstanceEntry? boolean Only show when entering an instance (not M+), skip normal buff checks
---@field showWhenPresent? boolean Show when buff IS active (inverts normal "show when missing" logic)
---@field noClickToCast? boolean Suppress click-to-cast overlay (e.g., CastSpellByID can't toggle this spell)
---@field noExpirationGlow? boolean Suppress expiration glow (for permanent enchants or intentionally short buffs)
---@field skipSpellKnownCheck? boolean Skip the "player knows spell" check (for custom/dynamic entries)

---@class ConsumableBuff
---@field spellID? SpellID
---@field key string
---@field name string
---@field overlayText string
---@field groupId? string
---@field checkWeaponEnchant? boolean Check if any weapon enchant exists (oils, stones, imbues)
---@field checkWeaponEnchantOH? boolean Check if off-hand weapon enchant exists
---@field excludeIfSpellKnown? number[] Don't show if player knows any of these spells
---@field buffIconID? number Detection-only: any aura whose icon matches counts as the buff (e.g., 136000 for food). Does not affect displayed icon.
---@field icons? IconSpec See "Icon fields" comment at end of self[]
---@field itemID? number|number[] Check if player has this item in inventory
---@field readyCheckOnly? boolean Only show during ready checks
---@field casterClass? ClassName Require this class in group, but show reminder to everyone
---@field infoTooltip? TooltipText
---@field visibilityCondition? fun(): boolean Custom function that gates visibility (return false to hide)
---@field glowDetectable? boolean Use action bar glow as fallback detection when aura API is restricted
---@field consumableCategory? string Category key in BR.CONSUMABLE_ITEMS for bag scanning (only set when items exist)
---@field freeConsumable? boolean Bypass content gates (always show when enabled)
---@field permanentRuneItemIDs? number[] Item IDs that, if in bags, make this a free consumable (bypass content gates)
---@field showOnInstanceEntry? boolean Only show briefly when entering an instance
---@field disabledInCompetitivePvP? boolean Unusable in arenas and rated BGs
---@field ignoresReadyCheckFilter? boolean Ignore the consumable category ready-check-only filter (still respects content gates)
---@field chatRequestable? boolean Offer "request this buff in chat" on click for players who can't provide it (e.g. non-warlock requesting a Healthstone)

---@class BuffGroup
---@field displayName string

---@class CustomBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field overlayText? string
---@field class? ClassName
---@field requireSpecId? number
---@field requireSpellKnown? boolean -- Only show if player knows at least one of the tracked spells
---@field showWhenPresent? boolean  -- Show icon when buff IS on player (default: show when missing)
---@field glowMode? "whenGlowing"|"whenNotGlowing"|"disabled"  -- Action bar glow fallback mode: nil/"whenGlowing" = detect when glowing (default), "whenNotGlowing" = detect when NOT glowing, "disabled" = don't track glow
---@field castSpellID? number       -- Spell to cast on click (separate from tracked aura)
---@field castItemID? number        -- Item to use on click
---@field castMacro? string         -- Raw macro text for click action
---@field requireItemID? number    -- Only show if this item is owned/equipped/in bags (see requireItemMode)
---@field requireItemMode? "owned"|"equipped"|"bags" -- How to check requireItemID: "owned" (default) = bags or equipped, "equipped" = equipped only, "bags" = bags only
---@field itemCooldownCondition? "offCooldown"|"onCooldown" -- Gate visibility on item cooldown state (nil = ignore cooldown)
---@field expirationThreshold? number  -- Per-buff expiration threshold in minutes (0 = off)
---@field loadConditions? LoadConditions  -- Per-buff content visibility (nil = show everywhere)

---User-defined loadout reminder: shows when the player's setup doesn't match the
---rule's expectation for the current content. Stored in BR.profile.loadoutReminders
---and mirrored into BR.BUFF_TABLES.loadout at runtime.
---@class LoadoutRule
---@field key string
---@field name string
---@field require "gear"|"talent"|"loadout"  -- which kind of expectation this rule checks
---@field overlayText? string                -- text shown on the reminder icon
---@field icon? number                        -- fileID fallback for the icon (live icon resolved via Loadouts.GetRuleIcon)
---@field gear? { setID: number, name?: string }            -- require == "gear"
---@field spellID? number                                    -- require == "talent" (talent spell)
---@field specID? number                                     -- spec binding: require == "talent" or "loadout"
---@field character? string                                  -- character binding ("Name - Realm"): require == "gear" or "loadout"
---@field class? string                                      -- class token ("PALADIN") of the creating character; drives binding-label color
---@field loadout? { name: string, configID?: number, source?: "tlex" }  -- require == "loadout"; source == "tlex" for Talent Loadout Ex entries
---@field when? LoadoutWhen                    -- content scope + instances; nil = everywhere
---@field clickToFix? boolean                 -- click the icon to equip the set / load the loadout / open the talent UI

---Content scope for a loadout rule. `scope` is a player-facing content tier
---(openWorld/dungeon/delve/raid/arena/battleground); `instances` narrows to
---specific dungeons/raids by name (nil/empty = any).
---@class LoadoutWhen
---@field scope? string
---@field readyCheckOnly? boolean
---@field instances? { id: number, mapID: number?, name: string, kind: string }[]

---Check if the player is NOT an Earthen dwarf (they have permanent Well Fed from Ingest Minerals)
---@return boolean
local function IsNotEarthen()
    if not BR.playerRace then
        local _, raceToken = UnitRace("player")
        BR.playerRace = raceToken
    end
    return BR.playerRace ~= "EarthenDwarf"
end

---Check if the player is inside a delve (difficultyID 208)
---@return boolean
local function IsInDelve()
    local difficultyID = select(3, GetInstanceInfo())
    return difficultyID == 208
end
BR.IsInDelve = IsInDelve

---Check if the player's pet is on passive stance
---@return boolean? true if pet exists and is on passive, nil otherwise
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

---Build a clickMacro function for targeted buffs that remembers the last target (last target re-casting).
---Macro priority: last target > mouseover > current target > no target (self-cast or error).
---@param buffKey string The buff's key, used to look up the last target
---@return fun(spellID: number): string
local function TargetedClickMacro(buffKey)
    return function(spellID)
        local name = BR.GetSpellName(spellID) or ""
        local lastTarget = BR.TargetMemory and BR.TargetMemory.Get(buffKey)
        if lastTarget then
            return "/cast [@" .. lastTarget .. ",help,nodead][@mouseover,help,nodead][@target,help,nodead][] " .. name
        end
        return "/cast [@mouseover,help,nodead][@target,help,nodead][] " .. name
    end
end

-- Rogue poison state: unified cache for customCheck, icon, clickMacro, and expiration.
-- Scans all poisons once per frame and stores active/missing/expiration/required counts.
-- Priority comes from BR.profile.roguePoisonPreferences (ordered, per-entry enabled flag).
-- The table below is the single source of truth for default poison ordering and is also
-- referenced by Display/Display.lua (defaults table) and Options/Options.lua (reset).
BR.DEFAULT_POISON_PREFERENCES = {
    lethal = {
        { spellID = 381664, enabled = true }, -- Amplifying
        { spellID = 2823, enabled = true }, -- Deadly
        { spellID = 315584, enabled = true }, -- Instant
        { spellID = 8679, enabled = true }, -- Wound
    },
    nonLethal = {
        { spellID = 381637, enabled = true }, -- Atrophic
        { spellID = 5761, enabled = true }, -- Numbing
        { spellID = 3408, enabled = true }, -- Crippling
    },
}

-- Cached poison state (refreshed once per frame via GetTime)
local poisonCache = {
    time = -1,
    activeL = 0,
    activeNL = 0,
    requiredL = 0,
    requiredNL = 0,
    knownL = 0,
    knownNL = 0,
    missingL = nil, ---@type number|nil First missing lethal spell ID (by priority)
    missingNL = nil, ---@type number|nil First missing non-lethal spell ID (by priority)
    minRemaining = nil, ---@type number|nil Seconds until soonest-expiring poison
    expiringID = nil, ---@type number|nil Spell ID of the soonest-expiring poison
    nextCastID = nil, ---@type number|nil Spell ID of the next poison to apply
}

-- Reusable scratch arrays: avoid per-frame allocation in the cache refresh path.
local poisonScratch = { lethal = {}, nonLethal = {} }

---Resolve the ordered list of enabled spell IDs for a category from the user's preferences.
---Falls back to the default order if prefs are missing or empty (early load, fresh install).
---Writes into a shared scratch buffer - do not cache the result across calls.
---@param category "lethal"|"nonLethal"
---@return number[] orderedSpellIDs
local function GetEnabledPoisons(category)
    local out = poisonScratch[category]
    local prefs = BR.profile and BR.profile.roguePoisonPreferences
    local list = prefs and prefs[category]
    if not list or #list == 0 then
        list = BR.DEFAULT_POISON_PREFERENCES[category]
    end
    local count = 0
    for _, entry in ipairs(list) do
        if entry and entry.enabled and entry.spellID then
            count = count + 1
            out[count] = entry.spellID
        end
    end
    for i = #out, count + 1, -1 do
        out[i] = nil
    end
    return out
end

---Single pass over a poison category: counts known/active, finds first missing, tracks min remaining.
---@param poisons number[] Spell ID list in priority order (already filtered to enabled)
---@param now number Current GetTime() value
---@return number active, number known, number|nil missing, number|nil minRemaining, number|nil expiringID
local function ScanPoisonCategory(poisons, now)
    local active, known, missing = 0, 0, nil
    local minRem, expID = nil, nil
    for _, id in ipairs(poisons) do
        local isKnown = IsPlayerSpell(id)
        if isKnown then
            known = known + 1
        end
        local auraData = C_UnitAuras.GetUnitAuraBySpellID("player", id)
        if auraData then
            -- Truthy means the poison is applied (count it) even if the struct is
            -- a secret value in a restricted context; AuraField yields the timer
            -- only when the struct and its field are plain.
            active = active + 1
            local exp = AuraField(auraData, "expirationTime")
            if exp and exp > 0 then
                local rem = exp - now
                if not minRem or rem < minRem then
                    minRem = rem
                    expID = id
                end
            end
        elseif isKnown and not missing then
            missing = id
        end
    end
    return active, known, missing, minRem, expID
end

---Refresh the poison cache if stale (once per frame).
local function RefreshPoisonCache()
    local now = GetTime()
    if poisonCache.time == now then
        return
    end
    poisonCache.time = now

    local lethalList = GetEnabledPoisons("lethal")
    local nonLethalList = GetEnabledPoisons("nonLethal")

    local activeL, knownL, missingL, minRemL, expIDL = ScanPoisonCategory(lethalList, now)
    local activeNL, knownNL, missingNL, minRemNL, expIDNL = ScanPoisonCategory(nonLethalList, now)

    poisonCache.activeL = activeL
    poisonCache.activeNL = activeNL
    poisonCache.knownL = knownL
    poisonCache.knownNL = knownNL
    poisonCache.missingL = missingL
    poisonCache.missingNL = missingNL

    -- Dragon-Tempered Blades (381801): can have 2 of each, otherwise 1
    local hasDTB = IsPlayerSpell(381801)
    poisonCache.requiredL = min(knownL, hasDTB and 2 or 1)
    poisonCache.requiredNL = min(knownNL, hasDTB and 2 or 1)

    -- Min remaining across both categories
    if minRemL and minRemNL then
        if minRemL <= minRemNL then
            poisonCache.minRemaining = minRemL
            poisonCache.expiringID = expIDL
        else
            poisonCache.minRemaining = minRemNL
            poisonCache.expiringID = expIDNL
        end
    elseif minRemL then
        poisonCache.minRemaining = minRemL
        poisonCache.expiringID = expIDL
    elseif minRemNL then
        poisonCache.minRemaining = minRemNL
        poisonCache.expiringID = expIDNL
    else
        poisonCache.minRemaining = nil
        poisonCache.expiringID = nil
    end

    -- Next poison to cast: only when active count is genuinely below required
    local needL = missingL and activeL < poisonCache.requiredL
    local needNL = missingNL and activeNL < poisonCache.requiredNL

    if needL and activeL <= activeNL then
        poisonCache.nextCastID = missingL
    elseif needNL then
        poisonCache.nextCastID = missingNL
    elseif needL then
        poisonCache.nextCastID = missingL
    else
        poisonCache.nextCastID = nil
    end
end

---@return number|nil castID Spell ID of the next poison to apply, or nil if none needed
local function GetNextPoisonCastID()
    RefreshPoisonCache()
    return poisonCache.nextCastID
end

---@return number|nil remaining Seconds until the soonest-expiring poison expires
---@return number|nil expiringID Spell ID of the soonest-expiring poison
local function GetPoisonExpirationInfo()
    RefreshPoisonCache()
    return poisonCache.minRemaining, poisonCache.expiringID
end

---Force the poison cache to recompute on next access. Call after preference changes.
function BR.InvalidatePoisonCache()
    poisonCache.time = -1
end

-- Utility reminders are chores (drop a table/well, repair), not auras: the utility
-- loop in State.lua gates them on class + customCheck + showOnInstanceEntry +
-- visibilityCondition only, and never aura-tracks or expiration-glows them. Fields
-- are limited to what that loop, the icon resolver, and click-to-cast actually read.
---@class UtilityBuff
---@field key string
---@field name string
---@field spellID? SpellID              -- Icon resolution (and click-to-cast fallback)
---@field groupId? string               -- Shared enable/setting key (falls back to key)
---@field class? ClassName              -- Only show to this class
---@field overlayText? string
---@field icons? IconSpec
---@field infoTooltip? TooltipText
---@field castSpellID? number           -- Spell ID used for click-to-cast (else spellID)
---@field noClickToCast? boolean        -- Suppress the click-to-cast overlay
---@field showOnInstanceEntry? boolean  -- Only show briefly on dungeon entry (grouped, non-M+)
---@field visibilityCondition? fun(): boolean?
---@field customCheck? fun(isRestricted?: boolean): boolean?

---@type table<string, RaidBuff[]|PresenceBuff[]|TargetedBuff[]|SelfBuff[]|ConsumableBuff[]|UtilityBuff[]|CustomBuff[]|LoadoutRule[]>
BR.BUFF_TABLES = {
    ---@type RaidBuff[]
    raid = {
        {
            spellID = { 1459, 432778 },
            key = "intellect",
            name = L["Buff.ArcaneIntellect"],
            class = "MAGE",
            levelRequired = 8,
            chatRequestable = true,
        }, -- 432778 = NPC version
        {
            spellID = 6673,
            key = "attackPower",
            name = L["Buff.BattleShout"],
            class = "WARRIOR",
            levelRequired = 10,
            chatRequestable = true,
        },
        {
            spellID = {
                381732,
                381741,
                381746,
                381748,
                381749,
                381750,
                381751,
                381752,
                381753,
                381754,
                381756,
                381757,
                381758,
            },
            castSpellID = 364342,
            key = "bronze",
            name = L["Buff.BlessingOfTheBronze"],
            class = "EVOKER",
            levelRequired = 30,
            playersOnly = true, -- NPCs have their own bronze variant (e.g. 432658)
            chatRequestable = true,
        },
        {
            spellID = { 1126, 432661 },
            key = "versatility",
            name = L["Buff.MarkOfTheWild"],
            class = "DRUID",
            levelRequired = 10,
            chatRequestable = true,
        }, -- 432661 = NPC version
        {
            spellID = 21562,
            key = "stamina",
            name = L["Buff.PowerWordFortitude"],
            class = "PRIEST",
            levelRequired = 10,
            chatRequestable = true,
        },
        {
            spellID = 462854,
            key = "skyfury",
            name = L["Buff.Skyfury"],
            class = "SHAMAN",
            levelRequired = 16,
            chatRequestable = true,
        },
    },
    ---@type PresenceBuff[]
    presence = {
        {
            -- Intentionally ignores per-rogue BR.profile.roguePoisonPreferences: this is the
            -- raid-wide slow-coverage signal, not a personal-apply reminder. Even rogues who
            -- disabled atrophic/numbing locally should see this when the group lacks coverage.
            spellID = { 381637, 5761 },
            key = "atrophicNumbingPoison",
            name = L["Buff.AtrophicNumbingPoison"],
            class = "ROGUE",
            levelRequired = 80,
            overlayText = L["Overlay.NoDrPoison"],
            groupOnly = true, -- self-buff "roguePoisons" already covers solo
            suppressedByEntry = "roguePoisons", -- hide when self poison icon is already showing
            chatRequestable = true,
        },
        {
            spellID = 465,
            key = "devotionAura",
            name = L["Buff.DevotionAura"],
            class = "PALADIN",
            levelRequired = 10,
            overlayText = L["Overlay.NoAura"],
            chatRequestable = true,
        },
        {
            spellID = 20707,
            key = "soulstone",
            name = L["Buff.Soulstone"],
            class = "WARLOCK",
            levelRequired = 13,
            overlayText = L["Overlay.NoSoulstone"],
            chatRequestable = true,
            readyCheckOnly = true,
            castOnOthers = true,
            noExpirationGlow = true,
            customCheck = function(isRestricted)
                -- CD tracking for warlocks only, gated by setting
                if playerClass ~= "WARLOCK" then
                    return nil
                end
                local db = BR.profile
                if not (db.defaults and db.defaults.soulstoneHideCooldown) then
                    return nil -- Setting off: no opinion, rely on aura presence
                end
                if isRestricted then
                    return false
                end
                local ok, result = pcall(function()
                    local info = C_Spell.GetSpellCooldown(20707)
                    return not info or info.duration == 0
                end)
                return not ok or result
            end,
            pinnedTarget = function()
                local db = BR.profile
                local pinned = db.defaults and db.defaults.soulstonePinnedTarget
                if pinned and pinned ~= "" then
                    return pinned
                end
                return nil
            end,
            clickMacro = function(spellID)
                local name = BR.GetSpellName(spellID) or ""
                -- Hard-assigned target: cast ONLY on them - alive (pre-emptive stone)
                -- or dead (offers them a res). Deliberately no fallback: if the pin
                -- is absent or out of group the click is a safe no-op, so the stone
                -- can never silently land on the wrong person.
                local db = BR.profile
                local pinned = db.defaults and db.defaults.soulstonePinnedTarget
                if pinned and pinned ~= "" then
                    -- Re-sanitize at use: imported profiles bypass the options input,
                    -- and this string must never break out of the macro conditional
                    return "/cast [@" .. pinned:gsub("[%[%]\r\n]", "") .. ",help] " .. name
                end
                -- Priority: sticky last target > first living healer > mouseover > target > self
                local lastTarget = BR.TargetMemory and BR.TargetMemory.Get("soulstone")
                if lastTarget then
                    return "/cast [@"
                        .. lastTarget
                        .. ",help,nodead][@mouseover,help,nodead][@target,help,nodead][@player] "
                        .. name
                end
                local numMembers = GetNumGroupMembers()
                if numMembers > 0 then
                    local prefix = IsInRaid() and "raid" or "party"
                    for i = 1, numMembers do
                        local unitId = prefix .. i
                        if UnitExists(unitId) and not UnitIsDeadOrGhost(unitId) then
                            if UnitGroupRolesAssigned(unitId) == "HEALER" then
                                local healerName = GetUnitName(unitId, true)
                                if healerName then
                                    return "/cast [@"
                                        .. healerName
                                        .. ",help,nodead][@mouseover,help,nodead][@target,help,nodead][@player] "
                                        .. name
                                end
                            end
                        end
                    end
                end
                return "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. name
            end,
        },
    },
    ---@type TargetedBuff[]
    targeted = {
        -- Beacons
        {
            spellID = 53563,
            key = "beaconOfLight",
            name = L["Buff.BeaconOfLight"],
            class = "PALADIN",
            overlayText = L["Overlay.NoLight"],
            groupId = "beacons",
            requireSpecId = 65, -- Holy only
            glowDetectable = true,
            excludeSpellID = 200025, -- Hide when Beacon of Virtue is known
            icons = { textures = { 236247 } }, -- Force original icon (talents replace the texture)
            clickMacro = TargetedClickMacro("beaconOfLight"),
        },
        {
            spellID = 156910,
            key = "beaconOfFaith",
            name = L["Buff.BeaconOfFaith"],
            class = "PALADIN",
            overlayText = L["Overlay.NoFaith"],
            groupId = "beacons",
            requireSpecId = 65, -- Holy only
            glowDetectable = true,
            clickMacro = TargetedClickMacro("beaconOfFaith"),
        },
        {
            spellID = 360827,
            key = "blisteringScales",
            name = L["Buff.BlisteringScales"],
            class = "EVOKER",
            overlayText = L["Overlay.NoScales"],
            requireSpecId = 1473, -- Augmentation
            requiresSpellID = 360827,
            clickMacro = TargetedClickMacro("blisteringScales"),
        },
        {
            spellID = 974,
            key = "earthShieldOthers",
            name = L["Buff.EarthShield"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoES"],
            infoTooltip = {
                title = L["Tooltip.MayShowExtraIcon"],
                desc = L["Tooltip.MayShowExtraIcon.Desc"],
            },
            clickMacro = TargetedClickMacro("earthShieldOthers"),
        },
        {
            spellID = 369459,
            key = "sourceOfMagic",
            name = L["Buff.SourceOfMagic"],
            class = "EVOKER",
            beneficiaryRole = "HEALER",
            overlayText = L["Overlay.NoSource"],
            clickMacro = TargetedClickMacro("sourceOfMagic"),
        },
        {
            spellID = 474750,
            casterBuffId = 474754, -- Check this combat-whitelisted buff on the caster instead of scanning group
            key = "symbioticRelationship",
            name = L["Buff.SymbioticRelationship"],
            class = "DRUID",
            overlayText = L["Overlay.NoLink"],
            clickMacro = TargetedClickMacro("symbioticRelationship"),
        },
        {
            spellID = 412710,
            key = "timelessness",
            name = L["Buff.Timelessness"],
            class = "EVOKER",
            overlayText = L["Overlay.NoTimeless"],
            requireSpecId = 1473, -- Augmentation
            requiresSpellID = 412710,
            clickMacro = TargetedClickMacro("timelessness"),
        },
        {
            -- 408233 is the cast spell (known by the player); 410318 is the link aura applied
            -- to both the caster and the recipient. The first ID gates IsPlayerSpellCached
            -- and click-to-cast; the second lets the last-target scan pick up the linked ally.
            spellID = { 408233, 410318 },
            casterBuffId = 410318,
            key = "weyrnstone",
            name = L["Buff.Weyrnstone"],
            class = "EVOKER",
            overlayText = L["Overlay.NoWeyrnstone"],
            icons = { spells = { 408233 } }, -- Force the cast-spell icon (avoid duplicate icons from spellID list)
            clickMacro = TargetedClickMacro("weyrnstone"),
        },
    },
    ---@type SelfBuff[]
    self = {
        -- Mage Arcane Familiar
        {
            spellID = 205022,
            buffIdOverride = 210126,
            castSpellID = 1459,
            key = "arcaneFamiliar",
            name = L["Buff.ArcaneFamiliar"],
            class = "MAGE",
            overlayText = L["Overlay.NoFamiliar"],
        },
        -- Evoker Augmentation attunement (Black 403264 / Bronze 403265, player picks one)
        {
            spellID = { 403264, 403265 },
            key = "evokerAttunement",
            name = L["Buff.Attunement"],
            class = "EVOKER",
            overlayText = L["Overlay.NoAttune"],
            requireSpecId = 1473, -- Augmentation
            requiresSpellID = 403208, -- Attunements talent
        },
        -- Warlock Burning Rush
        {
            spellID = 111400,
            key = "burningRush",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.BurningRush"],
            class = "WARLOCK",
            overlayText = L["Overlay.BurningRush"],
            showWhenPresent = true,
            noClickToCast = true,
            glowDetectable = true, -- Action bar glow fallback when aura API is restricted
        },
        -- Detected via the stance bar so it works in M+/encounters/combat where
        -- aura queries are restricted.
        {
            key = "druidWrongForm",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.DruidForm"],
            class = "DRUID",
            overlayText = L["Overlay.WrongForm"],
            -- icons.spells drives the options panel row; icons.dynamic always wins on the
            -- frame (customCheck gates display, so the dynamic resolver is always called).
            icons = {
                spells = { 768, 5487, 24858 }, -- Cat, Bear, Moonkin
                dynamic = function()
                    local expected = BR.BuffState.GetExpectedDruidFormID()
                    return expected and C_Spell.GetSpellTexture(expected)
                end,
            },
            castSpellID = 768, -- Cat Form: baseline-known by all druids, just gates click-to-cast (clickMacro casts the right form)
            customCheck = function()
                return BR.BuffState.IsWrongDruidForm()
            end,
            clickMacro = function()
                local expected = BR.BuffState.GetExpectedDruidFormID()
                local name = expected and BR.GetSpellName(expected) or ""
                return "/cast " .. name
            end,
        },
        -- Warlock Grimoire of Sacrifice
        {
            spellID = 108503,
            buffIdOverride = 196099,
            key = "grimoireOfSacrifice",
            name = L["Buff.GrimoireOfSacrifice"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoGrim"],
        },
        -- Paladin weapon rites (alphabetical: Adjuration, Sanctification)
        -- NOTE: Due to a Blizzard bug, when changing talents the buff drops but enchant remains.
        -- The effect doesn't work without the buff, so we check for BOTH enchant AND buff.
        {
            spellID = 433583,
            key = "riteOfAdjuration",
            name = L["Buff.RiteOfAdjuration"],
            class = "PALADIN",
            overlayText = L["Overlay.NoRite"],
            enchantID = 7144,
            buffIdOverride = 433584, -- Actual buff ID on player
            requiresBuffWithEnchant = true,
            clickMacro = function(spellID)
                return "/cast " .. (BR.GetSpellName(spellID) or "") .. "\n/use 16"
            end,
            groupId = "paladinRites",
        },
        {
            spellID = 433568,
            key = "riteOfSanctification",
            name = L["Buff.RiteOfSanctification"],
            class = "PALADIN",
            overlayText = L["Overlay.NoRite"],
            enchantID = 7143,
            buffIdOverride = 433550, -- Actual buff ID on player
            requiresBuffWithEnchant = true,
            clickMacro = function(spellID)
                return "/cast " .. (BR.GetSpellName(spellID) or "") .. "\n/use 16"
            end,
            groupId = "paladinRites",
        },
        -- Rogue poisons: lethal (Instant, Wound, Deadly, Amplifying) and non-lethal (Numbing, Atrophic, Crippling)
        -- With Dragon-Tempered Blades (381801): need 2 lethal + 2 non-lethal
        -- Without talent: need 1 lethal + 1 non-lethal
        {
            icons = {
                textures = { 136242 }, -- Deadly Poison (menu fallback)
                dynamic = function()
                    local castID = GetNextPoisonCastID()
                    return castID and C_Spell.GetSpellTexture(castID)
                end,
            },
            castSpellID = 315584, -- Instant Poison (baseline, ensures click-to-cast overlay is created)
            key = "roguePoisons",
            name = L["Buff.RoguePoisons"],
            class = "ROGUE",
            overlayText = L["Overlay.ApplyPoison"],
            customCheck = function()
                RefreshPoisonCache()
                -- Don't show if the player hasn't learned any poisons yet (e.g. low-level rogue)
                if poisonCache.knownL == 0 and poisonCache.knownNL == 0 then
                    return nil
                end
                return poisonCache.activeL < poisonCache.requiredL or poisonCache.activeNL < poisonCache.requiredNL
            end,
            getExpirationInfo = GetPoisonExpirationInfo,
            clickMacro = function()
                local castID = GetNextPoisonCastID()
                if not castID then
                    -- Nothing missing - fall back to soonest-expiring poison for re-application
                    local _, expiringID = GetPoisonExpirationInfo()
                    castID = expiringID
                end
                if castID then
                    return "/cast " .. (BR.GetSpellName(castID) or "")
                end
                return ""
            end,
        },
        -- DK Runeforge (Main Hand) - reminder when MH enchant doesn't match configured preference
        {
            icons = {
                textures = { 237523 }, -- Runeforging icon (menu fallback)
                dynamic = function()
                    local specId = BR.StateHelpers.GetPlayerSpecId()
                    local prefs = BR.profile.dkRunePreferences
                    local specPrefs = prefs and prefs[specId]
                    if not specPrefs then
                        return nil
                    end
                    local isDW = BR.BuffState.HasOffHandWeapon()
                    local accepted = specPrefs[isDW and "dw_mainhand" or "mainhand"]
                    if accepted then
                        -- Iterate in DK_RUNEFORGES order for deterministic icon
                        for _, rune in ipairs(DK_RUNEFORGES) do
                            if accepted[rune.enchantID] then
                                return GetSpellTexture(rune.spellID)
                            end
                        end
                    end
                end,
            },
            key = "dkRuneMH",
            name = L["Buff.RuneforgeMH"],
            class = "DEATHKNIGHT",
            overlayText = L["Overlay.DKWrongRune"],
            noExpirationGlow = true,
            groupId = "dkRunes",
            customCheck = function()
                if BR.BuffState.IsRestricted() then
                    return nil
                end
                local specId = BR.StateHelpers.GetPlayerSpecId()
                local prefs = BR.profile.dkRunePreferences
                local specPrefs = prefs and prefs[specId]
                if not specPrefs then
                    return nil
                end
                local isDW = BR.BuffState.HasOffHandWeapon()
                local accepted = specPrefs[isDW and "dw_mainhand" or "mainhand"]
                if not accepted or not next(accepted) then
                    return nil
                end
                local current = BR.BuffState.GetPermanentWeaponEnchantID(16)
                return not accepted[current]
            end,
        },
        -- DK Runeforge (Off Hand) - only relevant for dual-wield
        {
            icons = {
                textures = { 237523 }, -- Runeforging icon (same as MH, deduped in options)
                dynamic = function()
                    local specId = BR.StateHelpers.GetPlayerSpecId()
                    local prefs = BR.profile.dkRunePreferences
                    local specPrefs = prefs and prefs[specId]
                    local accepted = specPrefs and specPrefs.dw_offhand
                    if accepted then
                        for _, rune in ipairs(DK_RUNEFORGES) do
                            if accepted[rune.enchantID] then
                                return GetSpellTexture(rune.spellID)
                            end
                        end
                    end
                end,
            },
            key = "dkRuneOH",
            name = L["Buff.RuneforgeOH"],
            class = "DEATHKNIGHT",
            overlayText = L["Overlay.DKWrongRuneOH"],
            noExpirationGlow = true,
            groupId = "dkRunes",
            customCheck = function()
                if BR.BuffState.IsRestricted() or not BR.BuffState.HasOffHandWeapon() then
                    return nil
                end
                local specId = BR.StateHelpers.GetPlayerSpecId()
                local prefs = BR.profile.dkRunePreferences
                local specPrefs = prefs and prefs[specId]
                if not specPrefs then
                    return nil
                end
                local accepted = specPrefs.dw_offhand
                if not accepted or not next(accepted) then
                    return nil
                end
                local current = BR.BuffState.GetPermanentWeaponEnchantID(17)
                return not accepted[current]
            end,
        },
        -- Shadowform: detected via the stance bar (works in M+/encounters/combat
        -- where the aura API is restricted for non-whitelisted spells). Voidform
        -- shares the same stance slot, so the stance check covers both forms.
        {
            key = "shadowform",
            name = L["Buff.Shadowform"],
            class = "PRIEST",
            overlayText = L["Overlay.NoForm"],
            icons = { textures = { 136200 } }, -- spell_shadow_shadowform
            requiresSpellID = 232698,
            castSpellID = 232698,
            noExpirationGlow = true, -- Voidform (short duration) replaces Shadowform; don't warn
            customCheck = function()
                return not BR.BuffState.IsShadowFormActive()
            end,
        },
        -- Shaman weapon imbues (alphabetical: Earthliving, Flametongue, Tidecaller's Guard, Windfury)
        {
            spellID = 382021,
            key = "earthlivingWeapon",
            name = L["Buff.EarthlivingWeapon"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoEL"],
            enchantID = 6498,
            groupId = "shamanImbues",
        },
        {
            spellID = 318038,
            key = "flametongueWeapon",
            name = L["Buff.FlametongueWeapon"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoFT"],
            enchantID = 5400,
            groupId = "shamanImbues",
        },
        {
            spellID = 457481,
            key = "tidecallersGuard",
            name = L["Buff.TidecallersGuard"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoTG"],
            enchantID = 7528,
            requireSpecId = 264, -- Restoration
            groupId = "shamanImbues",
            customCheck = function()
                if not IsPlayerSpell(457481) then
                    return nil
                end
                -- Only relevant when a shield is equipped
                if not BR.BuffState.HasShield() then
                    return nil
                end
                return BR.BuffState.GetOffHandEnchantID() ~= 7528
            end,
        },
        {
            spellID = 33757,
            key = "windfuryWeapon",
            name = L["Buff.WindfuryWeapon"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoWF"],
            enchantID = 5401,
            groupId = "shamanImbues",
        },
        -- Icon fields (sibling keys under `icons`; pick what fits):
        --   Static side -- shown in menus + the frame's default texture (one of):
        --     icons.textures = { tex, ... }   -- raw texture IDs
        --     icons.spells   = { id, ... }    -- spell IDs resolved to textures
        --   Runtime side -- replaces the frame icon at render time (at most one of):
        --     icons.dynamic  = function() return tex end   -- computed each render (forms,
        --                                                     runes, soonest-expiring poison)
        --     icons.byRole   = { HEALER = id, DAMAGER = id, TANK = id }
        --                                                  -- role-keyed spell IDs; also drives
        --                                                     click-to-cast spell selection
        --
        -- If `icons` is omitted entirely, `spellID` is the free fallback (resolved via
        -- C_Spell.GetSpellTexture).
        --
        -- buffIconID is NOT an icon field. It's detection-only (counts any aura whose icon
        -- matches). Buffs that detect by icon still need icons.textures if they want that
        -- icon shown.
        --
        -- Shaman shields (alphabetical: Earth, Lightning, Water)
        -- With Elemental Orbit: need Earth Shield (passive self-buff)
        {
            spellID = 974, -- Earth Shield (icon comes free from spellID fallback)
            buffIdOverride = 383648, -- The passive buff to check for
            key = "earthShieldSelfEO",
            name = L["Buff.EarthShieldSelf"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoSelfES"],
            requiresSpellID = 383010,
            groupId = "shamanShields",
        },
        -- With Elemental Orbit: need Lightning Shield or Water Shield
        {
            spellID = { 192106, 52127 },
            key = "waterLightningShieldEO",
            name = L["Buff.WaterLightningShield"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoShield"],
            requiresSpellID = 383010,
            groupId = "shamanShields",
            icons = {
                spells = { 192106 }, -- Lightning Shield (menu fallback)
                byRole = { HEALER = 52127, DAMAGER = 192106, TANK = 192106 },
            },
        },
        -- Without Elemental Orbit: need either Earth Shield, Lightning Shield, or Water Shield on self
        {
            spellID = { 974, 192106, 52127 },
            key = "shamanShieldBasic",
            name = L["Buff.ShieldNoTalent"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoShield"],
            excludeSpellID = 383010,
            groupId = "shamanShields",
            icons = {
                spells = { 52127 }, -- Water Shield (menu fallback)
                byRole = { HEALER = 52127, DAMAGER = 192106, TANK = 192106 },
            },
        },
        -- Warrior wrong stance for spec (Defensive for Prot, Battle/Berserker for Arms/Fury).
        -- clickMacro dispatches the spec-correct cast at click time.
        {
            key = "warriorWrongStance",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.WarriorStance"],
            class = "WARRIOR",
            overlayText = L["Overlay.WrongStance"],
            -- icons.spells drives the options panel row; icons.dynamic always wins on the
            -- frame (customCheck gates display, so the dynamic resolver is always called).
            icons = {
                spells = { 386164, 386208, 386196 }, -- Battle, Defensive, Berserker
                dynamic = function()
                    -- Show the stance the player is currently in (the wrong one); when
                    -- unstanced, fall back to the expected-for-spec icon as a hint.
                    local current = BR.BuffState.GetCurrentWarriorStanceIcon()
                    if current then
                        return current
                    end
                    local expected = BR.BuffState.GetExpectedWarriorStanceID()
                    return expected and C_Spell.GetSpellTexture(expected)
                end,
            },
            castSpellID = 386208, -- Defensive Stance: baseline-known by all warriors, just gates click-to-cast (clickMacro casts the right stance)
            customCheck = function()
                return BR.BuffState.IsWrongWarriorStance()
            end,
            clickMacro = function()
                local expected = BR.BuffState.GetExpectedWarriorStanceID()
                local name = expected and BR.GetSpellName(expected) or ""
                return "/cast " .. name
            end,
        },
    },
    ---@type SelfBuff[]
    pet = {
        {
            key = "petPassive",
            name = L["Buff.PetPassive"],
            -- No class: applies to any class with a pet
            overlayText = L["Overlay.PassivePet"],
            icons = { textures = { 132311 } },
            customCheck = IsPetOnPassive,
        },
        -- Pet reminders (alphabetical: Hunter, Unholy DK, Warlock Demon, Water Elemental, Wrong Demon)
        {
            key = "hunterPet",
            name = L["Buff.HunterPet"],
            class = "HUNTER",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 132161 } },
            groupId = "pets",
            customCheck = function()
                -- MM Hunters don't use pets unless they have Unbreakable Bond
                if BR.StateHelpers.GetPlayerSpecId() == 254 and not IsPlayerSpell(1223323) then
                    return nil
                end
                return not UnitExists("pet") or UnitIsDead("pet") or nil
            end,
        },
        {
            icons = { textures = { 1100170 } }, -- Raise Dead
            key = "unholyPet",
            name = L["Buff.UnholyGhoul"],
            class = "DEATHKNIGHT",
            overlayText = L["Overlay.NoPet"],
            requireSpecId = 252, -- Unholy
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "warlockPet",
            name = L["Buff.WarlockDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 136082 } }, -- Summon Demon flyout icon
            excludeSpellID = 108503, -- Grimoire of Sacrifice: pet intentionally sacrificed
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            icons = { textures = { 135862 } }, -- Summon Water Elemental
            key = "frostMagePet",
            name = L["Buff.WaterElemental"],
            class = "MAGE",
            overlayText = L["Overlay.NoPet"],
            requireSpecId = 64, -- Frost
            requiresSpellID = 31687,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "warlockWrongPet",
            name = L["Buff.WrongDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.WrongPet"],
            icons = { textures = { 136216 } }, -- Felguard icon
            excludeSpellID = 108503, -- Grimoire of Sacrifice: pet intentionally sacrificed
            requireSpecId = 266, -- Demonology only
            requiresSpellID = 30146, -- Summon Felguard must be known
            groupId = "pets",
            customCheck = function()
                return BR.BuffState.IsWrongDemonPet()
            end,
            getPetActions = function()
                return BR.PetHelpers.GetFelguardAction()
            end,
        },
    },
    ---@type CustomBuff[]
    custom = {},
    -- User-defined loadout reminders (talent / loadout / equipment set mismatch).
    -- Populated at runtime from BR.profile.loadoutReminders (see Display BuildLoadoutRulesArray).
    ---@type LoadoutRule[]
    loadout = {},
    -- Consumables are disabled in arenas and rated BGs (disabledInCompetitivePvP = true)
    -- unless explicitly allowed (e.g. healthstone). See IsInCompetitivePvP() in State.lua.
    ---@type ConsumableBuff[]
    consumable = {
        -- Augment Rune (The War Within + Midnight)
        {
            spellID = {
                1234969, -- Ethereal Augment Rune (TWW permanent) - highest priority
                1242347, -- Soulgorged Augment Rune (TWW raid drop) - persists through death
                453250, -- Crystallized Augment Rune (TWW) - single use
                393438, -- Draconic Augment Rune (Dragonflight) - legacy
                1264426, -- Void-Touched Augment Rune (Midnight)
                347901, -- Veiled Augment Rune (Shadowlands) - legacy
            },
            icons = { spells = { 1264426, 1234969 } }, -- Void-Touched (Midnight), Ethereal (TWW permanent)
            key = "rune",
            name = L["Buff.AugmentRune"],
            overlayText = L["Overlay.NoRune"],
            permanentRuneItemIDs = { 243191, 259085 }, -- Ethereal (TWW), Void-Touched (Midnight)
            groupId = "rune",
            consumableCategory = "rune",
            disabledInCompetitivePvP = true,
        },
        -- Flasks (The War Within + Midnight)
        {
            spellID = {
                -- The War Within
                432021, -- Flask of Alchemical Chaos
                431971, -- Flask of Tempered Aggression
                431972, -- Flask of Tempered Swiftness
                431973, -- Flask of Tempered Versatility
                431974, -- Flask of Tempered Mastery
                432473, -- Flask of Saving Graces
                -- Midnight
                1235057, -- Flask of Thalassian Resistance (Versatility)
                1235108, -- Flask of the Magisters (Mastery)
                1235110, -- Flask of the Blood Knights (Haste)
                1235111, -- Flask of the Shattered Sun (Critical Strike)
                1239355, -- Vicious Thalassian Flask of Honor
            },
            icons = {
                spells = {
                    -- Show Midnight flask icons in UI
                    1235111, -- Flask of the Shattered Sun (Critical Strike)
                    1235110, -- Flask of the Blood Knights (Haste)
                    1235108, -- Flask of the Magisters (Mastery)
                    1235057, -- Flask of Thalassian Resistance (Versatility)
                    1239355, -- Vicious Thalassian Flask of Honor
                },
            },
            key = "flask",
            name = L["Buff.Flask"],
            overlayText = L["Overlay.NoFlask"],
            groupId = "flask",
            consumableCategory = "flask",
            disabledInCompetitivePvP = true,
        },
        -- Delve Food (only when inside a delve with Brann or Valeera)
        {
            spellID = 442522,
            key = "delveFood",
            name = L["Buff.DelveFood"],
            overlayText = L["Overlay.NoFood"],
            groupId = "delveFood",
            showOnInstanceEntry = true, -- When delveFoodTimer is enabled, only show for 30s on delve entry
            noExpirationGlow = true, -- 10-min duration makes standard thresholds meaningless
            visibilityCondition = BR.IsInDelve,
            disabledInCompetitivePvP = true,
            ignoresReadyCheckFilter = true, -- always shows in a delve, even with consumable ready-check-only on
        },
        -- Food (all expansions - any aura whose icon is 136000 counts as food)
        {
            buffIconID = 136000, -- detection: any aura with this icon
            icons = { textures = { 136000 } }, -- display: same texture, separate concern
            key = "food",
            name = L["Buff.Food"],
            overlayText = L["Overlay.NoFood"],
            groupId = "food",
            consumableCategory = "food",
            visibilityCondition = IsNotEarthen,
            disabledInCompetitivePvP = true,
        },
        -- Healthstone (checks inventory, free consumable for warlocks)
        {
            itemID = { 5512, 224464 }, -- Healthstone, Demonic Healthstone
            castSpellID = 29893, -- Create Soulwell
            key = "healthstone",
            name = L["Buff.Healthstone"],
            casterClass = "WARLOCK",
            overlayText = L["Overlay.NoStone"],
            groupId = "healthstone",
            icons = { textures = { 538745 } }, -- Healthstone icon
            freeConsumable = true,
            -- Non-warlocks (no creation spell, none in bag) click to ask a warlock in chat
            chatRequestable = true,
            clickMacro = function()
                local spellID = (GetNumGroupMembers() > 0 and IsInInstance()) and 29893 or 6201
                local name = BR.GetSpellName(spellID)
                return "/cast " .. (name or "")
            end,
        },
        -- Mage food (healers only): remind to grab conjured food when a mage is in
        -- the group and you're inside an instance without any in your bags. Click
        -- asks the mage in chat (healers can't conjure their own). Its own per-buff
        -- ready-check gate (readyCheckOnly, on by default; the drawer's Show toggle
        -- switches it to Always) - so it opts out of the shared consumable category
        -- ready-check filter (ignoresReadyCheckFilter) to keep that toggle the sole
        -- control. `mageFoodContent` narrows it to dungeons or raids only.
        {
            itemID = { 113509 }, -- Conjured Mana Bun
            key = "mageFood",
            defaultEnabled = false, -- opt-in: ships disabled
            addedIn = "6.3.0",
            name = L["Buff.MageFood"],
            casterClass = "MAGE",
            overlayText = L["Overlay.NoMageFood"],
            icons = { spells = { 190336 } }, -- Conjure Refreshment icon (the bun)
            infoTooltip = {
                title = L["Tooltip.MageFood"],
                desc = L["Tooltip.MageFood.Desc"],
            },
            chatRequestable = true,
            readyCheckOnly = true,
            ignoresReadyCheckFilter = true,
            visibilityCondition = function()
                local ct = BR.StateHelpers.GetCurrentContentType()
                if ct == "openWorld" or ct == "housing" then
                    return false
                end
                local filter = BR.Config.Get("defaults.mageFoodContent", "all")
                if filter == "dungeon" and ct ~= "dungeon" then
                    return false
                elseif filter == "raid" and ct ~= "raid" then
                    return false
                end
                return BR.BuffState.GetPlayerRole() == "HEALER"
            end,
        },
        -- Weapon Buffs (oils, stones - but not for classes with imbues)
        {
            checkWeaponEnchant = true, -- Check if any weapon enchant exists
            key = "weaponBuff",
            name = L["Buff.Weapon"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 7548987, 7548941, 7548938 } }, -- Thalassian Phoenix Oil, Refulgent Whetstone, Refulgent Weightstone
            consumableCategory = "weapon",
            excludeIfSpellKnown = {
                -- Shaman imbues
                382021, -- Earthliving Weapon
                318038, -- Flametongue Weapon
                33757, -- Windfury Weapon
                -- Paladin rites
                433583, -- Rite of Adjuration
                433568, -- Rite of Sanctification
            },
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted()
            end,
            disabledInCompetitivePvP = true,
        },
        -- Weapon Buff (Off-Hand) - only shown when off-hand slot has a weapon
        {
            checkWeaponEnchantOH = true,
            key = "weaponBuffOH",
            name = L["Buff.WeaponOH"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 7548987, 7548941, 7548938 } }, -- Thalassian Phoenix Oil, Refulgent Whetstone, Refulgent Weightstone
            consumableCategory = "weapon",
            excludeIfSpellKnown = {
                -- Shaman imbues
                382021, -- Earthliving Weapon
                318038, -- Flametongue Weapon
                33757, -- Windfury Weapon
                -- Paladin rites
                433583, -- Rite of Adjuration
                433568, -- Rite of Sanctification
            },
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted() and BR.BuffState.HasOffHandWeapon()
            end,
            disabledInCompetitivePvP = true,
        },
    },
    ---@type UtilityBuff[]
    utility = {
        -- Soulwell reminder (warlock only, instance entry only)
        {
            spellID = 29893, -- Create Soulwell (used for icon resolution)
            castSpellID = 29893, -- Click-to-cast: Create Soulwell
            key = "soulwell",
            name = L["Buff.CreateSoulwell"],
            class = "WARLOCK",
            overlayText = L["Overlay.DropWell"],
            showOnInstanceEntry = true, -- Only shows on instance entry
            infoTooltip = {
                title = L["Tooltip.InstanceEntryReminder"],
                desc = L["Tooltip.InstanceEntryReminder.Desc"],
            },
            customCheck = function(isRestricted)
                -- Cooldown API returns tainted values during combat/encounters/M+
                if isRestricted then
                    return false
                end
                local ok, result = pcall(function()
                    local info = C_Spell.GetSpellCooldown(29893)
                    return not info or info.duration == 0
                end)
                return not ok or result
            end,
        },
        -- Refreshment table reminder (mage only, instance entry only). Spell 190336
        -- is smart-cast: it drops a group table in a party/instance and conjures a
        -- personal stack when solo, so it doubles as both the icon and the click.
        {
            spellID = 190336, -- Conjure Refreshment (used for icon resolution)
            castSpellID = 190336, -- Click-to-cast: smart-drops the refreshment table
            key = "refreshmentTable",
            addedIn = "6.3.0",
            name = L["Buff.RefreshmentTable"],
            class = "MAGE",
            overlayText = L["Overlay.DropTable"],
            showOnInstanceEntry = true, -- Only shows on instance entry
            infoTooltip = {
                title = L["Tooltip.InstanceEntryReminder"],
                desc = L["Tooltip.InstanceEntryReminder.Desc"],
            },
            customCheck = function(isRestricted)
                -- Cooldown API returns tainted values during combat/encounters/M+
                if isRestricted then
                    return false
                end
                -- Only nag the mage when someone actually drinks: a healer in the
                -- party. Mirrors the mage-food reminder that only nags healers when
                -- a mage is present. Scanned here (post-isRestricted) so the role
                -- read is always plain. Soulwell has no such gate - everyone wants a
                -- healthstone, but only mana users want a table.
                if not BR.BuffState.HasHealerInGroup() then
                    return false
                end
                local ok, result = pcall(function()
                    local info = C_Spell.GetSpellCooldown(190336)
                    return not info or info.duration == 0
                end)
                return not ok or result
            end,
        },
        -- Repair reminder: shows when any equipped item drops below the configured
        -- durability threshold. Durability is not a tainted read, so no restricted
        -- gate; the 18-slot scan is memoized in State.lua (cachedLowestDurability).
        {
            key = "repairGear",
            defaultEnabled = false, -- opt-in: ships disabled
            addedIn = "6.3.0",
            name = L["Buff.RepairGear"],
            icons = { textures = { 1405803 } },
            overlayText = L["Overlay.Repair"],
            noClickToCast = true, -- nothing to cast; the action is visiting a merchant
            customCheck = function()
                return BR.BuffState.GetLowestDurability() < (BR.Config.Get("defaults.repairThreshold", 20) / 100)
            end,
        },
    },
}

-- Derive buff key -> consumable category mapping from data
local buffKeyToCategory = {}
for _, buff in ipairs(BR.BUFF_TABLES.consumable) do
    if buff.consumableCategory then
        buffKeyToCategory[buff.key] = buff.consumableCategory
    end
end
BR.BUFF_KEY_TO_CATEGORY = buffKeyToCategory

---@type table<string, BuffGroup>
BR.BuffGroups = {
    beacons = { displayName = L["Group.Beacons"] },
    dkRunes = { displayName = L["Group.DKRunes"] },
    shamanImbues = { displayName = L["Group.ShamanImbues"] },
    paladinRites = { displayName = L["Group.PaladinRites"] },
    pets = { displayName = L["Group.Pets"] },
    shamanShields = { displayName = L["Group.ShamanShields"] },
    -- Consumable groups
    flask = { displayName = L["Group.Flask"] },
    food = { displayName = L["Group.Food"] },
    delveFood = { displayName = L["Group.DelveFood"] },
    healthstone = { displayName = L["Group.Healthstone"] },
    rune = { displayName = L["Group.AugmentRune"] },
    weaponBuff = { displayName = L["Group.WeaponBuff"] },
}
