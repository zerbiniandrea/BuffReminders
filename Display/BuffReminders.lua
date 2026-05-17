local addonName, BR = ...

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class DefaultSettings
---@field iconSize number
---@field iconWidth? number
---@field textSize number
---@field iconAlpha number
---@field textAlpha number
---@field textColor number[]
---@field spacing number
---@field iconZoom number
---@field borderSize number
---@field growDirection string
---@field showExpirationGlow boolean
---@field showMissingGlow boolean
---@field expirationThreshold number
---@field preKeyThreshold number
---@field glowType number
---@field glowColor? number[]
---@field glowSize number
---@field glowPixelLines? number
---@field glowPixelFrequency? number
---@field glowPixelLength? number
---@field glowAutocastParticles? number
---@field glowAutocastFrequency? number
---@field glowAutocastScale? number
---@field glowBorderFrequency? number
---@field glowProcDuration? number
---@field glowProcStartAnim? boolean
---@field glowProcUseCustomColor? boolean
---@field glowXOffset? number
---@field glowYOffset? number
---@field missingGlowType? number
---@field missingGlowColor? number[]
---@field missingGlowSize? number
---@field missingGlowPixelLines? number
---@field missingGlowPixelFrequency? number
---@field missingGlowPixelLength? number
---@field missingGlowAutocastParticles? number
---@field missingGlowAutocastFrequency? number
---@field missingGlowAutocastScale? number
---@field missingGlowBorderFrequency? number
---@field missingGlowProcDuration? number
---@field missingGlowProcStartAnim? boolean
---@field missingGlowProcUseCustomColor? boolean
---@field missingGlowXOffset? number
---@field missingGlowYOffset? number
---@field fontFace? string
---@field textOutline? "NONE"|"OUTLINE"|"THICKOUTLINE"|"MONOCHROME"|"OUTLINE, MONOCHROME"|"THICKOUTLINE, MONOCHROME"
---@field showConsumablesWithoutItems? boolean
---@field showWithoutItemsOnlyOnReadyCheck? boolean
---@field delveFoodOnly? boolean
---@field delveFoodTimer? boolean
---@field freeConsumableMode? "follow"|"override"
---@field freeConsumableVisibility? table
---@field healthstoneVisibility? "readyCheck"|"always"|"casterOnly"
---@field consumableRebuffWarning? boolean
---@field consumableRebuffThreshold? number
---@field consumableRebuffColor? number[]
---@field consumableDisplayMode? "icon_only"|"sub_icons"|"expanded"
---@field consumableTextScale? number
---@field hideConsumableLabels? boolean
---@field hideLegacyConsumables? boolean
---@field petDisplayMode? "generic"|"expanded"
---@field petLabels? boolean
---@field petLabelScale? number
---@field petSpecIconOnHover? boolean
---@field textPositions? table<string, {zone: string, offsetX: number, offsetY: number}>

---@class CategorySetting
---@field position CategoryPosition
---@field iconSize? number
---@field iconWidth? number
---@field textSize? number
---@field iconAlpha? number
---@field textAlpha? number
---@field textColor? number[]
---@field spacing? number
---@field growDirection? string
---@field iconZoom? number
---@field borderSize? number
---@field showExpirationGlow? boolean
---@field showMissingGlow? boolean
---@field expirationThreshold? number
---@field showBuffReminder? boolean
---@field buffTextSize? number
---@field showText? boolean
---@field useCustomAppearance? boolean
---@field useCustomGlow? boolean
---@field glowType? number
---@field glowColor? number[]
---@field glowSize? number
---@field glowPixelLines? number
---@field glowPixelFrequency? number
---@field glowPixelLength? number
---@field glowAutocastParticles? number
---@field glowAutocastFrequency? number
---@field glowAutocastScale? number
---@field glowBorderFrequency? number
---@field glowProcDuration? number
---@field glowProcStartAnim? boolean
---@field glowProcUseCustomColor? boolean
---@field glowXOffset? number
---@field glowYOffset? number
---@field missingGlowType? number
---@field missingGlowColor? number[]
---@field missingGlowSize? number
---@field missingGlowPixelLines? number
---@field missingGlowPixelFrequency? number
---@field missingGlowPixelLength? number
---@field missingGlowAutocastParticles? number
---@field missingGlowAutocastFrequency? number
---@field missingGlowAutocastScale? number
---@field missingGlowBorderFrequency? number
---@field missingGlowProcDuration? number
---@field missingGlowProcStartAnim? boolean
---@field missingGlowProcUseCustomColor? boolean
---@field missingGlowXOffset? number
---@field missingGlowYOffset? number
---@field split? boolean
---@field clickable? boolean
---@field clickableHighlight? boolean
---@field subIconSide? string
---@field showOnlyOnReadyCheck? boolean
---@field priority? number

--- All category settings must be defined here. When adding a new category:
--- 1. Add it to CategoryName alias in Core.lua
--- 2. Add a field here with the same name
---@class AllCategorySettings
---@field main CategorySetting
---@field raid CategorySetting
---@field presence CategorySetting
---@field targeted CategorySetting
---@field self CategorySetting
---@field pet CategorySetting
---@field consumable CategorySetting
---@field custom CategorySetting

---@class CategoryFrame: Frame
---@field category CategoryName

---@alias SplitCategories table<CategoryName, boolean>

---@class DetachedIconEntry
---@field position {x: number, y: number}

---@alias DetachedIcons table<string, DetachedIconEntry>

---@class BuffFrame: Button
---@field GetFrameLevel fun(self: BuffFrame): number
---@field key string
---@field spellIDs SpellID
---@field displayName string
---@field buffDef table
---@field icon Texture
---@field border Texture
---@field count FontString
---@field stackCount FontString
---@field buffText? FontString
---@field statLabel? FontString                  -- Consumable stat label (top-left)
---@field badgeLabel? FontString                  -- Consumable badge (bottom-left): hearty "H" text
---@field qualityIcon? Texture                    -- Consumable crafted quality icon (bottom-left atlas)
---@field isPlayerBuff? boolean
---@field buffCategory? CategoryName
---@field glowTexture? Texture
---@field glowAnim? AnimationGroup
---@field glowShowing? boolean
---@field currentGlowStyle? number
---@field clickOverlay? Button
---@field actionButtons? Button[]
---@field extraFrames? table[]
---@field isExtraFrame? boolean
---@field mainFrame? BuffFrame
---@field _br_pet_spell? string             -- Localized spell name for pet click-to-cast
---@field _br_pet_spec_icon? number        -- Pet spec ability icon texture for hover swap
---@field _br_pet_label_key? string        -- Cache key for pet label updates
---@field _br_pet_name_text? FontString    -- Pet name label below icon
---@field _br_pet_family_text? FontString  -- Pet spec label below name
---@field _br_pet_extra_text? FontString   -- Spirit Beast label below spec
---@field _cachedItems? table|false         -- Per-cycle cache for GetConsumableActionItems result

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor, max, min = math.floor, math.max, math.min
local format = string.format
local random = math.random
local tinsert, tremove, tsort, tconcat = table.insert, table.remove, table.sort, table.concat

-- Localization
local L = BR.L

-- Shared constants (from Core.lua)
local DEFAULT_BORDER_SIZE = BR.DEFAULT_BORDER_SIZE
local DEFAULT_ICON_ZOOM = BR.DEFAULT_ICON_ZOOM
local TEXCOORD_INSET = BR.TEXCOORD_INSET

-- WoW API locals
local PlaySoundFile = PlaySoundFile
local GetInstanceInfo = GetInstanceInfo

-- LibSharedMedia for font resolution
local LSM = LibStub("LibSharedMedia-3.0")

-- Masque integration (optional)
local Masque = LibStub("Masque", true)
local masqueGroup = Masque and Masque:Group("BuffReminders")

local function IsMasqueActive()
    return masqueGroup ~= nil and not masqueGroup.db.Disabled
end

-- Cached font path - resolved once on load and updated when the setting changes (via VisualsRefresh).
-- All SetFont calls read this local directly instead of calling LSM:Fetch() every time.
local fontPath = STANDARD_TEXT_FONT

-- LSM can register fonts whose file assets can't be loaded (e.g. another addon points to
-- a missing TTF). We probe each path with a hidden FontString + pcall so we never hand a
-- broken path to SetFont, which would hard-error and break the display / options panel.
local fontProbe = UIParent:CreateFontString(nil, "BACKGROUND")
fontProbe:Hide()
local fontPathValidCache = {}

---Check whether a font file path is loadable by the WoW client
---@param path string? LSM-resolved font file path
---@return boolean valid true if path is non-nil and SetFont succeeds
local function IsFontPathValid(path)
    if not path then
        return false
    end
    local cached = fontPathValidCache[path]
    if cached ~= nil then
        return cached
    end
    local ok = pcall(fontProbe.SetFont, fontProbe, path, 12, "")
    fontPathValidCache[path] = ok
    return ok
end

---Resolve the font path from saved settings and update the cache
local function ResolveFontPath()
    local fontName = BR.profile and BR.profile.defaults and BR.profile.defaults.fontFace
    if fontName then
        local path = LSM:Fetch("font", fontName)
        if IsFontPathValid(path) then
            fontPath = path
            return
        end
    end
    fontPath = STANDARD_TEXT_FONT
end

-- Cached outline flag - resolved on load and updated when the setting changes (via VisualsRefresh).
-- "NONE" in saved settings is translated to "" at the WoW API level.
local outlineFlag = "OUTLINE"

---Resolve the text outline flag from saved settings and update the cache
local function ResolveOutline()
    local value = BR.profile and BR.profile.defaults and BR.profile.defaults.textOutline
    if value == "NONE" then
        outlineFlag = ""
    elseif value == nil then
        outlineFlag = "OUTLINE"
    else
        outlineFlag = value
    end
end

-- Global API table for external addon integration
BuffReminders = {}

-- Buff tables from Buffs.lua (via BR namespace)
local BUFF_TABLES = BR.BUFF_TABLES

-- Local aliases for direct access
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local CustomBuffs = BUFF_TABLES.custom

-- Build buff key -> setting key mapping (resolves individual keys to groupId when grouped)
local buffKeyToSettingKey = {}
for _, buffArray in ipairs({ RaidBuffs, PresenceBuffs, TargetedBuffs, SelfBuffs, PetBuffs, BUFF_TABLES.consumable }) do
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            buffKeyToSettingKey[buff.key] = buff.groupId
        end
    end
end

-- ============================================================================
-- BUFF HELPER FUNCTIONS
-- ============================================================================

---Generate a unique key for a custom buff
---@param spellID SpellID
---@return string
local function GenerateCustomBuffKey(spellID)
    local id = type(spellID) == "table" and spellID[1] or spellID
    return "custom_" .. id .. "_" .. time()
end

---Validate a spell ID exists via GetSpellInfo
---@param spellID number
---@return boolean valid
---@return string? name
---@return number? iconID
local function ValidateSpellID(spellID)
    local name, _, iconID
    pcall(function()
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            name = info.name
            iconID = info.iconID
        end
    end)
    return name ~= nil, name, iconID
end

local function ValidateItemID(itemID)
    local name, iconID
    pcall(function()
        name = C_Item.GetItemNameByID(itemID)
        iconID = C_Item.GetItemIconByID(itemID)
    end)
    return name ~= nil, name, iconID
end

---Rebuild BUFF_TABLES.custom from db.customBuffs (preserves table identity via wipe)
local function BuildCustomBuffArray()
    local db = BR.profile
    wipe(CustomBuffs)
    if not db or not db.customBuffs then
        return
    end
    local sortedKeys = {}
    for k in pairs(db.customBuffs) do
        sortedKeys[#sortedKeys + 1] = k
    end
    tsort(sortedKeys)
    for _, k in ipairs(sortedKeys) do
        CustomBuffs[#CustomBuffs + 1] = db.customBuffs[k]
    end
end

-- Get helpers from State.lua
local GetBuffSettingKey = function(buff)
    return BR.StateHelpers.GetBuffSettingKey(buff)
end
local IsBuffEnabled = function(key)
    return BR.StateHelpers.IsBuffEnabled(key)
end

-- Default settings
-- Note: enabledBuffs defaults to all enabled - only set false to disable by default
local defaults = {
    locked = true,
    enabledBuffs = {},
    showOnlyInGroup = false,
    hideWhileResting = false,
    hideInCombat = false,
    hideExpiringInCombat = true,
    buffTrackingMode = "all",
    selfOnlyOutsideInstances = true,
    hideAllInVehicle = false,
    hideWhileMounted = false,
    hideInLegacyInstances = true,
    hideWhileLeveling = false,
    showMissingCountOnly = false,
    petPassiveOnlyInCombat = false,
    bronzeHideInCombat = false,
    optionsPanelScale = 1.2, -- base scale (displayed as 100%)
    showLoginMessages = true,
    requestBuffInChat = true,
    chatRequestCooldown = true,
    chatRequestMessages = {},

    -- DK runeforge preferences: [specId] = { mainhand, dw_mainhand, dw_offhand }
    -- No runes selected = no reminder for that spec (implicit disable)
    dkRunePreferences = {
        [250] = { mainhand = { [6241] = true } }, -- Blood: Sanguination
        [251] = {
            mainhand = { [3368] = true }, -- 2H: Fallen Crusader
            dw_mainhand = { [3370] = true }, -- DW MH: Razorice
            dw_offhand = { [3368] = true }, -- DW OH: Fallen Crusader
        },
        [252] = { mainhand = { [6245] = true } }, -- Unholy: Apocalypse
    },

    -- Rogue poison preferences: ordered list per category, array index = priority (1 = highest).
    -- Shared with Data/Buffs.lua; DeepCopyDefault produces an independent per-profile copy.
    roguePoisonPreferences = BR.DEFAULT_POISON_PREFERENCES,

    minimap = {
        hide = true,
    },

    -- Global defaults (inherited by categories unless overridden)
    ---@type DefaultSettings
    defaults = {
        -- Appearance
        iconSize = 64,
        -- iconWidth: nil = same as iconSize (square). Set explicitly for non-square icons.
        textSize = 20,
        textOutline = "OUTLINE",
        iconAlpha = 1,
        textAlpha = 1,
        textColor = { 1, 1, 1 },
        spacing = 0.2, -- multiplier of iconSize
        iconZoom = 0, -- percentage (additional zoom on top of base TEXCOORD_INSET crop)
        borderSize = 2,
        growDirection = "CENTER", -- "LEFT", "CENTER", "RIGHT", "UP", "DOWN"
        -- Behavior (glow settings)
        showExpirationGlow = true,
        showMissingGlow = true,
        expirationThreshold = 15, -- minutes
        preKeyThreshold = 0, -- minutes (0 = off); used in M0 before inserting a keystone
        glowType = 2, -- BR.Glow.Type: Pixel=1, AutoCast=2, Border=3, Proc=4 (expiring default)
        glowSize = 2,
        showConsumablesWithoutItems = true,
        showWithoutItemsOnlyOnReadyCheck = true,
        delveFoodOnly = true,
        delveFoodTimer = false,
        freeConsumableMode = "override",
        freeConsumableVisibility = {
            openWorld = false,
            scenario = true,
            dungeon = true,
            raid = true,
            housing = false,
            pvp = true,
        },
        healthstoneVisibility = "readyCheck",
        healthstoneThreshold = 1,
        soulstoneVisibility = "readyCheck",
        consumableDisplayMode = "sub_icons",
        consumableTextScale = 25,
        hideConsumableLabels = false,
        showConsumableTooltips = false,
        showBuffTooltips = false,
        hideLegacyConsumables = true,
        petDisplayMode = "generic", -- "generic" or "expanded"
        petLabels = true,
        petSpecIconOnHover = true,
        petLabelClasses = {
            HUNTER = true,
            WARLOCK = true,
            DEATHKNIGHT = true,
            MAGE = true,
        },
        useFelDomination = false,
        -- Per-text-item placement (zone + pixel nudge). See Core/TextPositions.lua
        -- for zone constants. Defaults preserve the prior hard-coded anchors so
        -- existing users see no visual change until they edit a value.
        textPositions = {
            count = { zone = "INSIDE_C", offsetX = 0, offsetY = 0 },
            stackCount = { zone = "INSIDE_BR", offsetX = 0, offsetY = 0 },
            statLabel = { zone = "INSIDE_TL", offsetX = 0, offsetY = 0 },
            badge = { zone = "INSIDE_L", offsetX = 0, offsetY = 0 },
            buffReminder = { zone = "BELOW_C", offsetX = 0, offsetY = 0 },
        },
    },

    ---@type CategoryVisibility
    categoryVisibility = { -- Which content types each category shows in
        raid = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            raidDifficulty = {
                lfr = false,
            },
        },
        presence = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            raidDifficulty = {
                lfr = false,
            },
        },
        targeted = {
            openWorld = false,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
        },
        self = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
        },
        pet = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = false,
        },
        consumable = {
            openWorld = false,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            pvpType = { arena = true, bg = true },
            scenarioDifficulty = {
                delves = true,
                others = false,
            },
            dungeonDifficulty = {
                normal = false,
                heroic = false,
                mythic = true,
                mythicPlus = false,
                timewalking = false,
                follower = false,
            },
            raidDifficulty = {
                lfr = false,
                normal = true,
                heroic = true,
                mythic = true,
            },
        },
    },

    ---@type AllCategorySettings
    categorySettings = { -- Per-category settings
        main = {
            position = { point = "CENTER", x = 0, y = 200 },
            -- main frame always uses defaults for appearance/behavior
        },
        raid = {
            position = { point = "CENTER", x = 0, y = 260 },
            useCustomAppearance = false,
            showBuffReminder = true,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 1,
        },
        presence = {
            position = { point = "CENTER", x = 0, y = 220 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 2,
        },
        targeted = {
            position = { point = "CENTER", x = 0, y = 180 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 3,
        },
        self = {
            position = { point = "CENTER", x = 0, y = 140 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 4,
        },
        pet = {
            position = { point = "CENTER", x = 0, y = 100 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 5,
        },
        consumable = {
            position = { point = "CENTER", x = 0, y = 60 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            subIconSide = "BOTTOM",
            priority = 6,
        },
        custom = {
            position = { point = "CENTER", x = 0, y = 20 },
            useCustomAppearance = false,
            split = false,
            clickable = false,
            clickableHighlight = true,
            priority = 7,
        },
    },
}

-- Constants
local CODE_DEFAULTS = defaults.defaults
local OVERLAY_TEXT_SCALE = 0.6 -- scale for "NO X" warning text

-- Locals
local mainFrame
local buffFrames = {}
local updateTicker
local readyCheckTimer = nil
local instanceEntryTimer = nil
local delveEntryTimer = nil
local SOULWELL_SPELL_IDS = { [29893] = true, [6201] = true } -- Create Soulwell, Create Healthstone

-- "Decor Duel" prop-hunt brawl: hide-and-seek as furniture, buff reminders are
-- meaningless and visually defeat the purpose. Identified by its unique difficulty ID.
local DECOR_DUEL_DIFFICULTY_ID = 253
local ClearInstanceEntryState -- forward declaration
local ClearDelveEntryState -- forward declaration
local HideDismissFrames -- forward declaration
local testMode = false
local eventFrame -- forward declaration; created later in file, referenced by StartUpdates

---@class TestModeData
---@field fakeTotal number Total group size for fake counts
---@field fakeRemaining number Fake time remaining for expiration glow test
---@field fakeMissing table<number, number> Fake missing counts per raid buff index

---@type TestModeData?
local testModeData = nil -- Stores seeded fake values for consistent test display
local playerClass = nil -- Cached player class, set once on init
local glowingSpells = {} -- Track which spell IDs are currently glowing (for action bar glow fallback)

-- Dirty flag system: events set dirty=true, OnUpdate checks flag with throttle
local dirty = false
local dirtyMode = "full"
local lastUpdateTime = 0
local MIN_UPDATE_INTERVAL = 0.5 -- seconds between actual updates

---@param mode? "full"|"group"
local function SetDirty(mode)
    dirty = true
    if mode == "full" or dirtyMode ~= "full" then
        dirtyMode = mode or "full"
    end
end

-- Buff state only depends on the player, their pet, and real group-member units.
-- Ignore raidpet/partypet/nameplate aura traffic; pet-heavy specs can generate a lot of it.
---@param unit string?
---@return boolean
local function IsTrackedDisplayUnit(unit)
    if not unit then
        return false
    end
    return unit == "player" or unit == "pet" or unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil
end

-- Track combat state via events (InCombatLockdown() can lag behind PLAYER_REGEN_DISABLED)
-- inCombat reflects both player regen AND boss encounter state for early detection
local inCombat = false
local inEncounter = false
local isResting = false
local petDismountSuppressed = false -- Suppress pet eval briefly after dismount (pet respawn delay)
local wasMounted = IsMounted()

-- Category frame system
local categoryFrames = {}
local detachedFrames = {} -- Per-icon detached container frames (shown when an icon is detached)
local CATEGORIES = { "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }

-- Track previously visible frame keys for selective hiding (Phase 3 optimization)
local previouslyVisibleKeys = {} ---@type table<string, boolean>

-- Sound alert state: suppress on first cycle after load/test-toggle to avoid login spam
local suppressSound = true
local soundPlayedThisCycle = {} ---@type table<string, boolean>

-- Layout signature tracking for skip-redundant-positioning (Phase 4 optimization)
-- Signatures are concatenated visible frame keys; if unchanged, skip repositioning
local lastMainSignature = ""
local lastSplitSignatures = {} ---@type table<string, string>
local CATEGORY_LABELS = {
    raid = L["Category.Raid"],
    presence = L["Category.Presence"],
    targeted = L["Category.Targeted"],
    self = L["Category.Self"],
    pet = L["Category.Pet"],
    consumable = L["Category.Consumable"],
    custom = L["Category.Custom"],
}

-- Export for Options.lua and split modules
BR.defaults = defaults
BR.CATEGORIES = CATEGORIES
BR.CATEGORY_LABELS = CATEGORY_LABELS

-- Early init of BR.Display for split modules (populated further below and in InitializeFrames)
BR.Display = BR.Display or {}
BR.Display.defaults = defaults
BR.Display.GetFontPath = function()
    return fontPath
end
BR.Display.GetOutline = function()
    return outlineFlag
end

---Check if a category is split into its own frame
---@param category string
---@return boolean
local function IsCategorySplit(category)
    local db = BR.profile
    -- Check new location first (categorySettings.{cat}.split)
    if db.categorySettings and db.categorySettings[category] then
        if db.categorySettings[category].split ~= nil then
            return db.categorySettings[category].split == true
        end
    end
    -- Fall back to legacy location (splitCategories.{cat})
    return db.splitCategories and db.splitCategories[category] == true
end

---Check if an individual icon is detached from its container
---@param key string Buff key
---@return boolean
local function IsIconDetached(key)
    local db = BR.profile
    return db.detachedIcons ~= nil and db.detachedIcons[key] ~= nil
end

local DETACHED_DEFAULT_POS = { x = 0, y = 0 }

---Get the saved position for a detached icon
---@param key string Buff key
---@return table position {x, y}
local function GetDetachedPosition(key)
    local db = BR.profile
    if db.detachedIcons and db.detachedIcons[key] then
        return db.detachedIcons[key].position or DETACHED_DEFAULT_POS
    end
    return DETACHED_DEFAULT_POS
end

---Get settings for a category with inheritance from defaults
---Uses BR.Config.GetCategorySetting for inherited values when applicable
---@param category string
---@return table A table with all effective settings for this category
local function GetCategorySettings(category)
    local db = BR.profile
    local catSettings = db.categorySettings and db.categorySettings[category]
    local globalDefaults = db.defaults or defaults.defaults

    -- For main frame, always use global defaults
    if category == "main" then
        return {
            position = catSettings and catSettings.position or { point = "CENTER", x = 0, y = 0 },
            iconSize = globalDefaults.iconSize or 64,
            iconWidth = globalDefaults.iconWidth,
            textSize = globalDefaults.textSize or CODE_DEFAULTS.textSize,
            iconAlpha = globalDefaults.iconAlpha or 1,
            textAlpha = globalDefaults.textAlpha or 1,
            textColor = globalDefaults.textColor or { 1, 1, 1 },
            spacing = globalDefaults.spacing or 0.2,
            iconZoom = globalDefaults.iconZoom or 0,
            borderSize = globalDefaults.borderSize or 2,
            growDirection = globalDefaults.growDirection or "CENTER",
            showBuffReminder = false, -- main uses per-frame logic based on buff's actual category
        }
    end

    -- For other categories, use inheritance
    local result = {}
    local defaultCatSettings = defaults.categorySettings[category] or {}

    -- Position is always category-specific
    result.position = catSettings and catSettings.position
        or defaultCatSettings.position
        or { point = "CENTER", x = 0, y = 0 }
    result.split = catSettings and catSettings.split or false
    result.subIconSide = (catSettings and catSettings.subIconSide) or defaultCatSettings.subIconSide

    -- Appearance: inherit from defaults unless useCustomAppearance is true
    local useCustomAppearance = catSettings and catSettings.useCustomAppearance
    if useCustomAppearance then
        -- Custom appearance: use category values, fall back to code defaults (NOT user's global defaults)
        -- This ensures custom-appearance categories are fully independent from Global Defaults changes.
        -- Values are snapshotted from current defaults when useCustomAppearance is first enabled.
        result.iconSize = (catSettings and catSettings.iconSize) or 64
        result.iconWidth = catSettings and catSettings.iconWidth
        result.textSize = (catSettings and catSettings.textSize) or CODE_DEFAULTS.textSize
        result.iconAlpha = (catSettings and catSettings.iconAlpha) or 1
        result.textAlpha = (catSettings and catSettings.textAlpha) or 1
        result.textColor = (catSettings and catSettings.textColor) or { 1, 1, 1 }
        result.spacing = (catSettings and catSettings.spacing) or 0.2
        result.iconZoom = (catSettings and catSettings.iconZoom) or 0
        result.borderSize = (catSettings and catSettings.borderSize) or 2
        result.growDirection = (catSettings and catSettings.growDirection) or "CENTER"
        result.showExpirationGlow = catSettings and catSettings.showExpirationGlow
        result.expirationThreshold = (catSettings and catSettings.expirationThreshold)
    else
        result.iconSize = globalDefaults.iconSize or 64
        result.iconWidth = globalDefaults.iconWidth
        result.textSize = globalDefaults.textSize or CODE_DEFAULTS.textSize
        result.iconAlpha = globalDefaults.iconAlpha or 1
        result.textAlpha = globalDefaults.textAlpha or 1
        result.textColor = globalDefaults.textColor or { 1, 1, 1 }
        result.spacing = globalDefaults.spacing or 0.2
        result.iconZoom = globalDefaults.iconZoom or 0
        result.borderSize = globalDefaults.borderSize or 2
        result.growDirection = globalDefaults.growDirection or "CENTER"
        result.showExpirationGlow = globalDefaults.showExpirationGlow
        result.expirationThreshold = globalDefaults.expirationThreshold
    end

    -- BUFF! text: direct per-category for raid only
    if category == "raid" then
        result.showBuffReminder = not catSettings or catSettings.showBuffReminder ~= false
    else
        result.showBuffReminder = false
    end

    return result
end

---Get the effective category for a frame (its own category if split, otherwise "main")
---@param frame table
---@return string
local function GetEffectiveCategory(frame)
    if not frame.buffCategory then
        return "main"
    end
    if IsCategorySplit(frame.buffCategory) or BR.Config.HasCustomAppearance(frame.buffCategory) then
        return frame.buffCategory
    end
    return "main"
end

---Check if overlay text should be shown for a given category
---@param category? CategoryName
---@return boolean
local function ShouldShowText(category)
    if not category then
        return true
    end
    local cs = BR.profile.categorySettings and BR.profile.categorySettings[category]
    return not cs or cs.showText ~= false
end

---Calculate font size from explicit textSize
---@param scale? number
---@param textSize number
---@return number
local function GetFontSize(scale, textSize)
    return max(6, floor(textSize * (scale or 1)))
end

---Get effective icon width (falls back to iconSize for square icons)
---@param iconWidth? number Explicit width setting
---@param iconSize number Icon height (used as fallback)
---@return number width
local function GetEffectiveWidth(iconWidth, iconSize)
    return iconWidth or iconSize
end

---Get font size for a specific frame based on its effective category
---@param frame table
---@param scale? number
---@return number
local function GetFrameFontSize(frame, scale)
    local effectiveCat = GetEffectiveCategory(frame)
    local catSettings = GetCategorySettings(effectiveCat)
    return GetFontSize(scale, catSettings.textSize)
end

-- Use functions from State.lua
local FormatRemainingTime = BR.StateHelpers.FormatRemainingTime
local FormatEatingTime = BR.StateHelpers.FormatEatingTime

local GetPlayerRole = BR.BuffState.GetPlayerRole

-- Spell texture cache (mirrors spellNameCache in Core.lua).
-- Wiped after deferred init to pick up cosmetic overrides (e.g. warlock green fire)
-- that aren't available yet at login time.
local spellTextureCache = {}

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

---Resolve a spell ID to its texture, with caching. Returns nil if the API can't resolve it yet.
---@param id number
---@return number? textureID
local function GetSpellTextureCached(id)
    local cached = spellTextureCache[id]
    if cached ~= nil then
        return cached or nil
    end
    local texture
    pcall(function()
        texture = C_Spell.GetSpellTexture(id)
    end)
    spellTextureCache[id] = texture or false
    return texture
end

---Get spell texture from a single spell ID (kept for the few raw-id callers: custom-buff
---icon refresh, Glow preview). For buff defs use GetBuffIcons(buff)[1] instead so authoring
---fields like buff.icon take priority over a raw spellID lookup.
---@param spellID number
---@return number? textureID
local function GetBuffTexture(spellID)
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if not spellID then
        return nil
    end
    return GetSpellTextureCached(spellID)
end

---Resolve the static portion of an `icons` spec ({textures = ...} or {spells = ...}) into
---a list of texture IDs. Caller owns dedup.
---@param icons IconSpec?
---@param add fun(t: number?)
local function ResolveStaticIcons(icons, add)
    if not icons then
        return
    end
    if icons.spells then
        for _, id in ipairs(icons.spells) do
            add(GetSpellTextureCached(id))
        end
    elseif icons.textures then
        for _, t in ipairs(icons.textures) do
            add(t)
        end
    end
end

---Resolve the static icon list for a buff. Single source of truth for menus, list rows,
---and the in-game frame's initial texture. Cached lazily on the buff (spell textures
---sometimes return nil during early load before spell data settles, so empty results stay
---uncached and retry on next read).
---
---Resolution: `buff.icons.textures` / `buff.icons.spells` if set; else `buff.spellID`
---resolved to texture(s) as the free fallback for ordinary aura-detected buffs.
---@param buff table Any buff def (RaidBuff, SelfBuff, ConsumableBuff, CustomBuff, ...)
---@return number[] textures (may be empty)
local function GetBuffIcons(buff)
    local cached = buff._iconsCache
    if cached then
        return cached
    end
    local out = {}
    local seen = {}
    local function add(t)
        if t and not seen[t] then
            seen[t] = true
            tinsert(out, t)
        end
    end

    local icons = buff.icons
    if icons and (icons.textures or icons.spells) then
        ResolveStaticIcons(icons, add)
    elseif buff.spellID then
        local list = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
        for _, id in ipairs(list) do
            add(GetSpellTextureCached(id))
        end
    end

    if #out > 0 then
        buff._iconsCache = out
    end
    return out
end

---Apply a buff's dynamic icon spec to a state entry. Called by State.lua when an entry
---becomes visible. Function variant is computed now; byRole is applied at render time.
---@param entry table
---@param buff table
local function ApplyDynamicIcon(entry, buff)
    local icons = buff.icons
    if not icons then
        return
    end
    if icons.dynamic then
        entry.dynamicIcon = icons.dynamic()
    elseif icons.byRole then
        entry.iconByRole = icons.byRole
    end
end

---Pre-fill `_iconsCache` for every static buff after spell data has settled. Eliminates
---the first-render resolve latency on the user's first interaction; callers afterwards
---hit the cached path. Buffs whose first resolve still returns empty (cosmetic overrides
---like warlock green fire) stay uncached and retry naturally.
local function PreFillIconCaches()
    for _, buffArray in pairs(BR.BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            GetBuffIcons(buff)
        end
    end
end

---Resolve the role-dependent texture for a buff at render time. Caller has already
---verified `def.icons.byRole` is present.
---@param def table buff def
---@return number? textureID
local function ResolveRoleTexture(def)
    local role = GetPlayerRole()
    local id = role and def.icons.byRole[role]
    if id then
        return GetSpellTextureCached(id)
    end
    return GetBuffIcons(def)[1]
end

---Resolve the display texture for a buff frame from its buffDef.
---@param frame BuffFrame
---@return number? textureID
local function ResolveFrameTexture(frame)
    local def = frame.buffDef
    if not def then
        return nil
    end
    if def.icons and def.icons.byRole then
        return ResolveRoleTexture(def)
    end
    return GetBuffIcons(def)[1]
end

---Re-fetch the Burning Rush icon after spell data settles.
---The warlock green-fire cosmetic override isn't applied yet at login, so
---C_Spell.GetSpellTexture returns the orange icon initially and the green
---variant only after data loads (see commit bdeaadb). Other buffs either have
---stable textures from frame creation or resolve their icon dynamically per
---render (consumables, dynamicIcon), so a broad cache wipe would briefly flash
---the wrong icon for them.
local function RefreshBurningRushIcon()
    local frame = buffFrames.burningRush
    if not (frame and frame.icon and frame.buffDef) then
        return
    end
    local def = frame.buffDef
    spellTextureCache[def.spellID] = nil
    def._iconsCache = nil
    local texture = ResolveFrameTexture(frame)
    if texture then
        frame.icon:SetTexture(texture)
    end
end

-- Action bar button names to scan for glows
-- Reverse lookup: spellID -> buff entry (for glow fallback detection across all categories)
local glowSpellToBuff = {}

--- Register a buff's spellID(s) in the glow fallback lookup table
local function RegisterGlowBuff(buff, catName)
    local ids = AsSpellList(buff.spellID)
    for _, id in ipairs(ids) do
        if id and id ~= 0 then
            glowSpellToBuff[id] = { buff = buff, category = catName }
        end
    end
end

--- Unregister spellID(s) from the glow fallback lookup table
---@param spellID number|number[] Single spell ID or table of spell IDs
local function UnregisterGlowSpell(spellID)
    local ids = type(spellID) == "table" and spellID or { spellID }
    for _, id in ipairs(ids) do
        if id then
            glowSpellToBuff[id] = nil
        end
    end
end

for catName, category in pairs(BUFF_TABLES) do
    for _, buff in ipairs(category) do
        -- Skip if: has enchantID, customCheck, or glowMode disabled (custom buffs only)
        -- readyCheckOnly buffs are skipped unless the user overrode them to always-show
        local skipReadyCheck = buff.readyCheckOnly
        if skipReadyCheck then
            local db = BR.profile
            local overrides = db and db.readyCheckOnlyOverrides
            local overrideKey = buff.groupId or buff.key
            if overrides and overrides[overrideKey] == false then
                skipReadyCheck = false
            end
        end
        if not buff.enchantID and not buff.customCheck and not skipReadyCheck and buff.glowMode ~= "disabled" then
            RegisterGlowBuff(buff, catName)
        end
    end
end

-- Seed glowingSpells with any already-active overlay glows (covers login/reload/zone change)
local IsSpellOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
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

-- Forward declarations
local UpdateDisplay, ToggleTestMode
-- TODO: Blizzard will re-restrict aura APIs in PvP; uncomment fallback display when that happens
-- local UpdateFallbackDisplay, RenderPetEntries
local ResetLayoutSignatures

-- Reusable tables for UpdateDisplay (wiped each cycle to avoid per-call allocation)
local reusableVisibleKeys = {} ---@type table<string, boolean>
local reusableMainBuffs = {}
local reusableDetachedSink = {} -- Throw-away target for detached consumable post-processing
local sortComparator = function(a, b)
    return a.sortOrder < b.sortOrder
end

-- Local alias for glow module
local SetExpirationGlow = BR.Glow.SetExpiration

-- Per-render-cycle cache for glow settings (avoids repeated DB reads)
local expiringGlowCache = {} ---@type table<string, table>
local missingGlowCache = {} ---@type table<string, table>

-- Prefixed key lists per glow type that BuildAdvancedParams reads (hoisted to avoid per-call allocation)
local GLOW_ADVANCED_KEYS = {
    [BR.Glow.Type.Pixel] = {
        glow = { "glowPixelLines", "glowPixelFrequency", "glowPixelLength" },
        missingGlow = { "missingGlowPixelLines", "missingGlowPixelFrequency", "missingGlowPixelLength" },
    },
    [BR.Glow.Type.AutoCast] = {
        glow = { "glowAutocastParticles", "glowAutocastFrequency", "glowAutocastScale" },
        missingGlow = { "missingGlowAutocastParticles", "missingGlowAutocastFrequency", "missingGlowAutocastScale" },
    },
    [BR.Glow.Type.Border] = {
        glow = { "glowBorderFrequency" },
        missingGlow = { "missingGlowBorderFrequency" },
    },
    [BR.Glow.Type.Proc] = {
        glow = { "glowProcDuration", "glowProcStartAnim" },
        missingGlow = { "missingGlowProcDuration", "missingGlowProcStartAnim" },
    },
}

---Get cached glow settings for a category and glow kind (populated once per render cycle)
---Glow style reads from per-category overrides when useCustomGlow is enabled, otherwise from defaults.
---@param category string
---@param kind "expiring"|"missing" Which glow style to resolve
---@return table
local function GetCachedGlowSettings(category, kind)
    local cache = kind == "missing" and missingGlowCache or expiringGlowCache
    local cached = cache[category]
    if cached then
        return cached
    end

    local GetSetting = BR.Config.GetCategorySetting
    local prefix = kind == "missing" and "missingGlow" or "glow"
    local typeFallback = kind == "missing" and BR.Glow.Type.Pixel or BR.Glow.Type.AutoCast

    local typeIndex = GetSetting(category, prefix .. "Type") or typeFallback
    local color = GetSetting(category, prefix .. "Color")
    if typeIndex == BR.Glow.Type.Proc and not GetSetting(category, prefix .. "ProcUseCustomColor") then
        color = nil
    end
    local size = GetSetting(category, prefix .. "Size") or 2
    local xOff = GetSetting(category, prefix .. "XOffset") or 0
    local yOff = GetSetting(category, prefix .. "YOffset") or 0

    -- Build advanced params from effective settings (only fetch keys the resolved type needs)
    local params
    local keySet = GLOW_ADVANCED_KEYS[typeIndex]
    local keys = keySet and keySet[prefix]
    if keys then
        local src = {}
        for _, key in ipairs(keys) do
            src[key] = GetSetting(category, key)
        end
        params = BR.Glow.BuildAdvancedParams(src, typeIndex, kind == "missing" and "missingGlow" or nil)
    end

    cached = {
        typeIndex = typeIndex,
        color = color,
        size = size,
        borderSize = GetSetting(category, "borderSize") or DEFAULT_BORDER_SIZE,
        params = params,
        glowXOffset = xOff,
        glowYOffset = yOff,
    }
    cache[category] = cached
    return cached
end

-- Hide a buff frame without destroying its glow.
-- The glow overlay is a child of the frame, so frame:Hide() visually hides it and
-- pauses its OnUpdate (WoW doesn't fire OnUpdate on hidden frames). When the frame
-- is re-shown, the glow animation resumes seamlessly from where it left off.
-- SetExpirationGlow handles cleanup when a re-shown frame no longer needs a glow.
local function HideFrame(frame)
    frame:Hide()
end

---Show a frame with overlay text styling
---@param frame BuffFrame
---@param overlayText? string
---@param shouldGlow? boolean
---@param category? CategoryName
---@param cachedGlow? {typeIndex: number, color: number[], size: number}
---@return boolean true (for anyVisible chaining)
local function ShowTextFrame(frame, overlayText, shouldGlow, category, cachedGlow)
    -- Hide stackCount/overlays - ShowTextFrame can be called from fallback paths
    -- (UpdateFallbackDisplay) that don't go through RenderVisibleEntry's cleanup.
    frame.stackCount:Hide()
    if frame.statLabel then
        frame.statLabel:Hide()
    end
    if frame.badgeLabel then
        frame.badgeLabel:Hide()
    end
    if frame.qualityIcon then
        frame.qualityIcon:Hide()
    end
    if overlayText then
        frame.count:SetFont(fontPath, GetFrameFontSize(frame, OVERLAY_TEXT_SCALE), outlineFlag)
        frame.count:SetText(overlayText)
        frame.count:Show()
    else
        frame.count:Hide()
    end
    frame:Show()
    SetExpirationGlow(frame, shouldGlow or false, category, cachedGlow)
    return true
end

-- Anchor point for each growth direction (anchor is the fixed point, icons grow away from it)
local DIRECTION_ANCHORS = {
    LEFT = "RIGHT", -- grow left: anchor on right, icons expand leftward
    RIGHT = "LEFT", -- grow right: anchor on left, icons expand rightward
    UP = "BOTTOM",
    DOWN = "TOP",
    CENTER = "CENTER",
}
BR.DIRECTION_ANCHORS = DIRECTION_ANCHORS

-- Compound anchor for external-frame anchoring: combines opposite(extPoint) on cross-axis
-- with growth direction anchor on main-axis. Same-axis conflicts: growth direction wins.
local EXT_DIRECTION_ANCHORS = {
    TOP = { LEFT = "BOTTOMRIGHT", RIGHT = "BOTTOMLEFT", UP = "BOTTOM", DOWN = "TOP", CENTER = "BOTTOM" },
    BOTTOM = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT", UP = "BOTTOM", DOWN = "TOP", CENTER = "TOP" },
    LEFT = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "BOTTOMRIGHT", DOWN = "TOPRIGHT", CENTER = "RIGHT" },
    RIGHT = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "BOTTOMLEFT", DOWN = "TOPLEFT", CENTER = "LEFT" },
    CENTER = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "BOTTOM", DOWN = "TOP", CENTER = "CENTER" },
    TOPLEFT = {
        LEFT = "BOTTOMRIGHT",
        RIGHT = "BOTTOMLEFT",
        UP = "BOTTOMRIGHT",
        DOWN = "TOPRIGHT",
        CENTER = "BOTTOMRIGHT",
    },
    TOPRIGHT = {
        LEFT = "BOTTOMRIGHT",
        RIGHT = "BOTTOMLEFT",
        UP = "BOTTOMLEFT",
        DOWN = "TOPLEFT",
        CENTER = "BOTTOMLEFT",
    },
    BOTTOMLEFT = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT", UP = "BOTTOMRIGHT", DOWN = "TOPRIGHT", CENTER = "TOPRIGHT" },
    BOTTOMRIGHT = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT", UP = "BOTTOMLEFT", DOWN = "TOPLEFT", CENTER = "TOPLEFT" },
}
BR.EXT_DIRECTION_ANCHORS = EXT_DIRECTION_ANCHORS

-- Resolve an external anchor parent frame for a category (returns nil if not set or invalid)
local function ResolveAnchorParent(catKey)
    local db = BR.profile
    local catSettings = db.categorySettings and db.categorySettings[catKey]
    local frameName = catSettings and catSettings.anchorFrame
    if frameName and frameName ~= "" then
        local frame = _G[frameName]
        if frame and frame.GetCenter then
            return frame, catSettings.anchorPoint or "CENTER"
        end
    end
    return nil, nil
end
BR.Display.ResolveAnchorParent = ResolveAnchorParent

local DIRECTION_LAYOUT = {
    LEFT = { anchor = "RIGHT", xMult = -1, yMult = 0 },
    RIGHT = { anchor = "LEFT", xMult = 1, yMult = 0 },
    UP = { anchor = "BOTTOM", xMult = 0, yMult = 1 },
    DOWN = { anchor = "TOP", xMult = 0, yMult = -1 },
}

-- Create a detached container frame for an individual buff icon
local function CreateDetachedFrame(key)
    local pos = GetDetachedPosition(key)
    local frame = CreateFrame("Frame", "BuffReminders_Detached_" .. key, UIParent)
    frame:SetSize(64, 64) -- sized dynamically by PositionDetachedIcon
    frame:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    frame:EnableMouse(false)
    frame:Hide()
    return frame
end

-- Create a category frame for grouped display mode
local function CreateCategoryFrame(category)
    local db = BR.profile
    local catSettings = db.categorySettings and db.categorySettings[category] or defaults.categorySettings[category]
    local pos = catSettings.position or defaults.categorySettings[category].position
    local direction = catSettings.growDirection or defaults.defaults.growDirection or "CENTER"
    local anchor = DIRECTION_ANCHORS[direction] or "CENTER"

    local frame = CreateFrame("Frame", "BuffReminders_Category_" .. category, UIParent)
    frame:SetSize(200, 50)
    local extFrame, extPoint = ResolveAnchorParent(category)
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
        frame:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint(anchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end
    frame.category = category
    frame:EnableMouse(false)

    frame:Hide()
    return frame
end

-- Create icon and border textures on a buff frame (no positioning - call UpdateIconStyling after)
local function CreateIconTextures(frame, texture)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetDesaturated(false)
    frame.icon:SetVertexColor(1, 1, 1, 1)
    frame.icon._br_desaturated = false
    if texture then
        frame.icon:SetTexture(texture)
    end

    frame.border = frame:CreateTexture(nil, "BACKGROUND")
    frame.border:SetColorTexture(0, 0, 0, 1)
end

-- Apply icon zoom and border sizing (single source of truth for Masque vs native styling)
local function UpdateIconStyling(frame, catSettings)
    if IsMasqueActive() then
        -- Masque controls styling; hide our native border (Masque manages its own textures via ReSkin)
        frame.border:Hide()
        return
    end
    -- When Masque is loaded but disabled, hide textures it created (Backdrop, Shadow, Gloss, etc.)
    -- that linger with a default Blizzard look. Skip the loop entirely if Masque was never loaded.
    if masqueGroup then
        for _, region in next, { frame:GetRegions() } do
            if region:IsObjectType("Texture") and region ~= frame.icon and region ~= frame.border then
                region:Hide()
            end
        end
    end
    -- Restore native state (Masque changes icon anchors, border texture/draw layer/alpha when skinning)
    frame.icon:ClearAllPoints()
    frame.icon:SetAllPoints()
    frame.border:SetDrawLayer("BACKGROUND")
    frame.border:SetAlpha(1)
    frame.border:SetColorTexture(0, 0, 0, 1)
    -- Always apply base inset to crop texture edge artifacts; zoom adds on top
    local additionalZoom = (catSettings.iconZoom or DEFAULT_ICON_ZOOM) / 100
    local inset = TEXCOORD_INSET + additionalZoom
    -- Aspect-ratio-aware crop: when width ≠ height, crop the longer texture axis
    -- more so the icon isn't stretched/distorted (shows a centered slice instead)
    local iconHeight = catSettings.iconSize or 64
    local iconWidth = GetEffectiveWidth(catSettings.iconWidth, iconHeight)
    local aspectRatio = iconWidth / iconHeight
    local xInset = inset
    local yInset = inset
    if aspectRatio > 1 then
        -- Wider than tall: crop top/bottom more
        yInset = inset + (1 - 1 / aspectRatio) * (0.5 - inset)
    elseif aspectRatio < 1 then
        -- Taller than wide: crop left/right more
        xInset = inset + (1 - aspectRatio) * (0.5 - inset)
    end
    frame.icon:SetTexCoord(xInset, 1 - xInset, yInset, 1 - yInset)
    local borderSize = catSettings.borderSize or DEFAULT_BORDER_SIZE
    if borderSize > 0 then
        frame.border:ClearAllPoints()
        frame.border:SetPoint("TOPLEFT", -borderSize, borderSize)
        frame.border:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
        frame.border:Show()
    else
        frame.border:Hide()
    end
end

-- Map buff key -> consumable category (derived from buff definitions in Data/Buffs.lua)
local BUFF_KEY_TO_CATEGORY = BR.BUFF_KEY_TO_CATEGORY

-- Show the spell tooltip for a buff frame (raid/presence hover), with a
-- class-colored "Provided by" line. Gated by defaults.showBuffTooltips so
-- hover never pops a tooltip unless the user opted in. Called from the icon
-- frame itself when no click overlay covers it, and from the click overlay
-- in SecureButtons.lua when click-to-cast is on - callers pass the actual
-- hovered frame as `anchor` so the tooltip lines up with the cursor.
local function ShowBuffSpellTooltip(frame, anchor)
    local db = BR.profile
    if not db or not db.defaults or db.defaults.showBuffTooltips ~= true then
        return
    end
    local def = frame.buffDef
    if not def then
        return
    end
    local spellID = type(def.spellID) == "table" and def.spellID[1] or def.spellID
    if not spellID then
        return
    end
    GameTooltip:SetOwner(anchor or frame, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(spellID)
    if def.class then
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[def.class]) or def.class
        local r, g, b = 1, 1, 1
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[def.class]
        if c then
            r, g, b = c.r, c.g, c.b
        end
        GameTooltip:AddLine(format(L["BuffTooltip.ProvidedBy"], className), r, g, b)
    end
    GameTooltip:Show()
end
BR.Display.ShowBuffSpellTooltip = ShowBuffSpellTooltip

-- Create icon frame for a buff
local function CreateBuffFrame(buff, category)
    local parent
    if IsIconDetached(buff.key) then
        if not detachedFrames[buff.key] then
            detachedFrames[buff.key] = CreateDetachedFrame(buff.key)
        end
        parent = detachedFrames[buff.key]
    elseif category and IsCategorySplit(category) and categoryFrames[category] then
        parent = categoryFrames[category]
    else
        parent = mainFrame
    end
    local frame = CreateFrame("Frame", "BuffReminders_" .. buff.key, parent)
    frame.key = buff.key
    frame.spellIDs = buff.spellID
    frame.displayName = buff.name
    frame.buffCategory = category
    frame.buffDef = buff

    local db = BR.profile
    -- Use effective category for initial sizing (UpdateVisuals + PositionMainContainer apply final sizes)
    local effectiveCat = (category and (IsCategorySplit(category) or BR.Config.HasCustomAppearance(category)))
            and category
        or "main"
    local catSettings = GetCategorySettings(effectiveCat)
    local iconSize = catSettings.iconSize or 64
    local iconWidth = GetEffectiveWidth(catSettings.iconWidth, iconSize)
    frame:SetSize(iconWidth, iconSize)

    -- Icon + border textures
    CreateIconTextures(frame, ResolveFrameTexture(frame))

    -- Register with Masque - provide Normal texture so skins like Caith can style it
    if masqueGroup then
        masqueGroup:AddButton(frame, {
            Icon = frame.icon,
            Normal = frame.border,
        })
    end

    -- Apply initial zoom/border state (respects Masque)
    UpdateIconStyling(frame, catSettings)

    -- Count text (font size scales with icon size, updated in UpdateVisuals)
    local textColor = catSettings.textColor or { 1, 1, 1 }
    local textAlpha = catSettings.textAlpha or 1
    frame.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    do
        local cz, cx, cy = BR.TextPositions.Get("count")
        BR.TextPositions.Apply(frame.count, frame, cz, cx, cy)
    end
    frame.count:SetTextColor(textColor[1], textColor[2], textColor[3], textAlpha)
    frame.count:SetFont(fontPath, GetFontSize(1, catSettings.textSize), outlineFlag)

    -- Stack count (bottom-right by default; user-positionable via textPositions)
    frame.stackCount = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    do
        local sz, sx, sy = BR.TextPositions.Get("stackCount")
        BR.TextPositions.Apply(frame.stackCount, frame, sz, sx, sy)
    end
    frame.stackCount:Hide()

    -- Frame alpha
    frame:SetAlpha(catSettings.iconAlpha or 1)

    -- "BUFF!" text for the class that provides this buff (raid buffs only)
    frame.isPlayerBuff = (playerClass == buff.class)
    if frame.isPlayerBuff and category == "raid" then
        frame.buffText = frame:CreateFontString(nil, "OVERLAY")
        local raidCs = db.categorySettings and db.categorySettings.raid
        local bz, bx, by = BR.TextPositions.Get("buffReminder")
        BR.TextPositions.Apply(frame.buffText, frame, bz, bx, by)
        frame.buffText:SetFont(
            fontPath,
            (raidCs and raidCs.buffTextSize) or GetFontSize(0.8, catSettings.textSize),
            outlineFlag
        )
        frame.buffText:SetTextColor(textColor[1], textColor[2], textColor[3], textAlpha)
        frame.buffText:SetText(L["Overlay.Buff"])
        if raidCs and raidCs.showBuffReminder == false then
            frame.buffText:Hide()
        end
    end

    -- Always click-through (dragging is handled by anchor handles). For raid
    -- and presence frames we still want hover events so the buff tooltip can
    -- pop on mouseover when the user opts in - clicks remain disabled so the
    -- mover/anchor flow stays intact. Other categories already have their own
    -- hover paths (consumable item tooltip + targeted last-target tooltip
    -- live on the click overlay, which sits above the icon when active).
    if category == "raid" or category == "presence" then
        frame:SetMouseClickEnabled(false)
        frame:SetMouseMotionEnabled(true)
        frame:SetScript("OnEnter", function(self)
            ShowBuffSpellTooltip(self)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        frame:EnableMouse(false)
    end

    frame:Hide()
    return frame
end

-- Get or create an extra frame for expanded consumable display mode.
-- Extra frames are stored lazily in frame.extraFrames[index] and share the same
-- visual structure as the main buff frame (icon, border, stackCount, Masque).
---@param frame table The main consumable buff frame
---@param index number 1-based index for the extra frame
---@return table extra The extra frame (shown/hidden by caller)
local function GetOrCreateExtraFrame(frame, index)
    if not frame.extraFrames then
        frame.extraFrames = {}
    end
    local extra = frame.extraFrames[index]
    if extra then
        return extra
    end

    extra = CreateFrame("Frame", nil, frame:GetParent())
    extra.isExtraFrame = true
    extra.mainFrame = frame
    extra.buffCategory = frame.buffCategory
    extra.key = frame.key .. "_extra_" .. index

    local effectiveCat = GetEffectiveCategory(frame)
    local catSettings = GetCategorySettings(effectiveCat)
    local iconSize = catSettings.iconSize or 64
    local iconWidth = GetEffectiveWidth(catSettings.iconWidth, iconSize)
    extra:SetSize(iconWidth, iconSize)

    CreateIconTextures(extra, nil)

    if masqueGroup then
        masqueGroup:AddButton(extra, {
            Icon = extra.icon,
            Normal = extra.border,
        })
    end

    UpdateIconStyling(extra, catSettings)

    -- Stack count: matches main frame's per-category zone so split icons line up
    extra.stackCount = extra:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    do
        local sz, sx, sy = BR.TextPositions.Get("stackCount")
        BR.TextPositions.Apply(extra.stackCount, extra, sz, sx, sy)
    end
    extra.stackCount:Hide()

    -- Count text (for consistency, though expanded frames mainly use stackCount)
    local textColor = catSettings.textColor or { 1, 1, 1 }
    local textAlpha = catSettings.textAlpha or 1
    extra.count = extra:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    do
        local cz, cx, cy = BR.TextPositions.Get("count")
        BR.TextPositions.Apply(extra.count, extra, cz, cx, cy)
    end
    extra.count:SetTextColor(textColor[1], textColor[2], textColor[3], textAlpha)
    extra.count:SetFont(fontPath, GetFontSize(1, catSettings.textSize), outlineFlag)
    extra.count:Hide()

    extra:SetAlpha(catSettings.iconAlpha or 1)
    extra:EnableMouse(false)
    extra:Hide()

    frame.extraFrames[index] = extra
    return extra
end

-- Helper to position frames within a container using specified settings
local function PositionFramesInContainer(container, frames, iconWidth, iconHeight, spacing, direction)
    local count = #frames
    if count == 0 then
        return
    end

    local layout = DIRECTION_LAYOUT[direction]
    for i, frame in ipairs(frames) do
        frame:ClearAllPoints()
        if layout then
            local isVertical = layout.yMult ~= 0
            local step = (i - 1) * ((isVertical and iconHeight or iconWidth) + spacing)
            frame:SetPoint(layout.anchor, container, layout.anchor, layout.xMult * step, layout.yMult * step)
        else -- CENTER (horizontal)
            local totalWidth = count * iconWidth + (count - 1) * spacing
            local startX = -totalWidth / 2 + iconWidth / 2
            frame:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (iconWidth + spacing), 0)
        end
    end
end

-- Build a sorted category list by priority (cached, invalidated on config change)
local cachedSortedCategories = nil

local function InvalidateSortedCategories()
    cachedSortedCategories = nil
end

local function GetSortedCategories()
    if cachedSortedCategories then
        return cachedSortedCategories
    end
    local db = BR.profile
    local sorted = {}
    for i, category in ipairs(CATEGORIES) do
        sorted[#sorted + 1] = { name = category, index = i }
    end
    tsort(sorted, function(a, b)
        local aPri = db.categorySettings and db.categorySettings[a.name] and db.categorySettings[a.name].priority
            or defaults.categorySettings[a.name].priority
        local bPri = db.categorySettings and db.categorySettings[b.name] and db.categorySettings[b.name].priority
            or defaults.categorySettings[b.name].priority
        if aPri == bPri then
            return a.index < b.index
        end
        return aPri < bPri
    end)
    cachedSortedCategories = sorted
    return sorted
end

---Build a signature string from a list of frames (by buffKey)
---@param frames table[]
---@return string
local function BuildLayoutSignature(frames)
    if #frames == 0 then
        return ""
    end
    -- Use table.concat for efficiency; keys are short strings
    local keys = {}
    for i, frame in ipairs(frames) do
        keys[i] = (frame.buffDef and frame.buffDef.key) or frame.key or ""
    end
    return tconcat(keys, ",")
end

---Position frames with variable sizes inside the main container, centering smaller frames on the cross-axis.
---@param container table
---@param frames table[]
---@param widths number[] per-frame icon widths
---@param heights number[] per-frame icon heights
---@param spacings number[] per-frame absolute spacing values
---@param direction string grow direction
local function PositionFramesVariable(container, frames, widths, heights, spacings, direction)
    local count = #frames
    if count == 0 then
        return
    end

    -- Anchor points place frames at the center of the cross-axis edge,
    -- so smaller frames are automatically centered - no manual offset needed.
    local offset = 0
    local isVertical = direction == "UP" or direction == "DOWN"
    local layout = DIRECTION_LAYOUT[direction]
    -- Hoist container width for CENTER mode (constant across iterations)
    local containerWidth = (direction == "CENTER") and container:GetWidth() or 0

    for i, frame in ipairs(frames) do
        local mainSize = isVertical and heights[i] or widths[i]

        frame:ClearAllPoints()
        if layout then
            frame:SetPoint(layout.anchor, container, layout.anchor, layout.xMult * offset, layout.yMult * offset)
        else -- CENTER (horizontal)
            local startX = -containerWidth / 2 + offset
            frame:SetPoint("CENTER", container, "CENTER", startX + widths[i] / 2, 0)
        end

        -- Advance offset for next frame
        if i < count then
            local gap = max(spacings[i], spacings[i + 1])
            offset = offset + mainSize + gap
        end
    end
end

-- Position and size the main container frame with the given buff frames
local function PositionMainContainer(mainFrameBuffs)
    local db = BR.profile

    if #mainFrameBuffs > 0 then
        -- Skip repositioning if the same frames are visible in the same order
        local sig = BuildLayoutSignature(mainFrameBuffs)
        if sig == lastMainSignature then
            return
        end
        lastMainSignature = sig

        local direction = BR.Config.GetCategorySetting("main", "growDirection") or "CENTER"
        local isVertical = direction == "UP" or direction == "DOWN"

        -- Collect per-frame sizes and spacings based on effective category
        local widths = {}
        local heights = {}
        local spacings = {} -- absolute pixel spacing per frame
        local maxWidth = 0
        local maxHeight = 0
        local settingsCache = {} -- avoid redundant GetCategorySettings calls for same category
        for i, frame in ipairs(mainFrameBuffs) do
            local effectiveCat = GetEffectiveCategory(frame)
            local settings = settingsCache[effectiveCat]
            if not settings then
                settings = GetCategorySettings(effectiveCat)
                settingsCache[effectiveCat] = settings
            end
            local iconSize = settings.iconSize or 64
            local iconWidth = GetEffectiveWidth(settings.iconWidth, iconSize)
            widths[i] = iconWidth
            heights[i] = iconSize
            local mainDim = isVertical and iconSize or iconWidth
            spacings[i] = floor(mainDim * (settings.spacing or 0.2))
            frame:SetSize(iconWidth, iconSize)
            if iconWidth > maxWidth then
                maxWidth = iconWidth
            end
            if iconSize > maxHeight then
                maxHeight = iconSize
            end
        end

        -- Compute total main-axis extent
        local totalMain = 0
        for i = 1, #widths do
            local mainSize = isVertical and heights[i] or widths[i]
            totalMain = totalMain + mainSize
            if i < #widths then
                totalMain = totalMain + max(spacings[i], spacings[i + 1])
            end
        end

        -- Size mainFrame to fit contents
        if isVertical then
            mainFrame:SetSize(maxWidth, max(totalMain, maxHeight))
        else
            mainFrame:SetSize(max(totalMain, maxWidth), maxHeight)
        end

        -- Re-anchor based on growth direction so first icon stays at anchor position
        local anchor = DIRECTION_ANCHORS[direction] or "CENTER"
        local pos = (db.categorySettings and db.categorySettings.main and db.categorySettings.main.position)
            or db.position
            or { point = "CENTER", x = 0, y = 0 }
        mainFrame:ClearAllPoints()
        local extFrame, extPoint = ResolveAnchorParent("main")
        if extFrame then
            local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
            mainFrame:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
        else
            mainFrame:SetPoint(anchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
        end

        PositionFramesVariable(mainFrame, mainFrameBuffs, widths, heights, spacings, direction)
        mainFrame:Show()
    else
        lastMainSignature = ""
        mainFrame:Hide()
    end
end

-- Position and size a split category frame with the given buff frames
local function PositionSplitCategory(category, frames)
    local catFrame = categoryFrames[category]
    if not catFrame then
        return
    end

    if #frames > 0 then
        -- Skip repositioning if the same frames are visible in the same order
        local sig = BuildLayoutSignature(frames)
        if sig == (lastSplitSignatures[category] or "") then
            return
        end
        lastSplitSignatures[category] = sig

        local catSettings = GetCategorySettings(category)
        local direction = catSettings.growDirection or "CENTER"
        local anchor = DIRECTION_ANCHORS[direction] or "CENTER"
        local pos = catSettings.position or { point = "CENTER", x = 0, y = 0 }
        local iconSize = catSettings.iconSize or 64
        local iconWidth = GetEffectiveWidth(catSettings.iconWidth, iconSize)
        local isVertical = direction == "UP" or direction == "DOWN"
        local mainSize = isVertical and iconSize or iconWidth
        local spacing = floor(mainSize * (catSettings.spacing or 0.2))

        -- Resize individual buff frames to category's icon size
        for _, frame in ipairs(frames) do
            frame:SetSize(iconWidth, iconSize)
        end

        -- Size category frame to fit contents
        local crossSize = isVertical and iconWidth or iconSize
        local totalSize = #frames * mainSize + (#frames - 1) * spacing
        if isVertical then
            catFrame:SetSize(crossSize, max(totalSize, iconSize))
        else
            catFrame:SetSize(max(totalSize, iconWidth), crossSize)
        end

        catFrame:ClearAllPoints()
        local extFrame, extPoint = ResolveAnchorParent(category)
        if extFrame then
            local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
            catFrame:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
        else
            catFrame:SetPoint(anchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
        end

        PositionFramesInContainer(catFrame, frames, iconWidth, iconSize, spacing, direction)
        catFrame:Show()
    else
        lastSplitSignatures[category] = ""
        catFrame:Hide()
    end
end

-- Hide split category frames that have no visible buffs, and hide non-split category frames
local function PositionSplitCategories(visibleByCategory)
    for _, category in ipairs(CATEGORIES) do
        local catFrame = categoryFrames[category]
        if catFrame then
            if IsCategorySplit(category) then
                local entries = visibleByCategory[category]
                if not entries or #entries == 0 then
                    -- No visible buffs: still position (mover handles visibility)
                    PositionSplitCategory(category, {})
                end
            else
                -- Not split - hide category frame
                catFrame:Hide()
            end
        end
    end
end

-- Position a detached icon in its own container frame
local function PositionDetachedIcon(key, frame)
    local container = detachedFrames[key]
    if not container then
        return
    end

    local effectiveCat = GetEffectiveCategory(frame)
    local catSettings = GetCategorySettings(effectiveCat)
    local iconSize = catSettings.iconSize or 64
    local iconWidth = GetEffectiveWidth(catSettings.iconWidth, iconSize)

    -- Count extra frames (expanded consumables)
    local totalFrames = 1
    if frame.extraFrames then
        for _, extra in ipairs(frame.extraFrames) do
            if extra:IsShown() then
                totalFrames = totalFrames + 1
            end
        end
    end

    -- Size the container to fit all visible frames (stacked horizontally)
    local spacing = totalFrames > 1 and floor(iconWidth * (catSettings.spacing or 0.2)) or 0
    local totalWidth = totalFrames * iconWidth + (totalFrames - 1) * spacing
    container:SetSize(totalWidth, iconSize)

    -- Position at saved coordinates
    local pos = GetDetachedPosition(key)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)

    -- Anchor the icon inside the container
    frame:SetSize(iconWidth, iconSize)
    frame:ClearAllPoints()
    if totalFrames > 1 then
        frame:SetPoint("LEFT", container, "LEFT", 0, 0)
        -- Position extra frames after the main icon
        local offset = iconWidth + spacing
        for _, extra in ipairs(frame.extraFrames) do
            if extra:IsShown() then
                extra:SetSize(iconWidth, iconSize)
                extra:ClearAllPoints()
                extra:SetPoint("LEFT", container, "LEFT", offset, 0)
                offset = offset + iconWidth + spacing
            end
        end
    else
        frame:SetPoint("CENTER", container, "CENTER", 0, 0)
    end

    container:Show()
end

--- Generate fake state entries for test mode, populating BR.BuffState.entries
--- and BR.BuffState.visibleByCategory so UpdateDisplay can render via the normal pipeline.
local function GenerateTestEntries()
    assert(testModeData, "GenerateTestEntries called with nil testModeData")

    -- Reset all entries (same pattern as State.lua:Refresh)
    for _, entry in pairs(BR.BuffState.entries) do
        entry.visible = false
        entry.shouldGlow = false
        entry.countText = nil
        entry.overlayText = nil
        entry.expiringTime = nil
        entry.isEating = nil
        entry.petActions = nil
        entry.iconByRole = nil
        entry.dynamicIcon = nil
    end

    local raidIndex = 1

    for _, category in ipairs(CATEGORIES) do
        -- Per-category glow settings (same pattern as State.lua:GetCategoryGlowSettings)
        local exGlowEnabled = BR.Config.GetCategorySetting(category, "showExpirationGlow") ~= false
        local missGlowEnabled = BR.Config.GetCategorySetting(category, "showMissingGlow") ~= false
        local threshold = BR.Config.GetCategorySetting(category, "expirationThreshold") or 15
        local expiringShown = false

        local buffTable = BUFF_TABLES[category]
        for i, buff in ipairs(buffTable) do
            local settingKey = buff.groupId or buff.key
            if IsBuffEnabled(settingKey) then
                -- Get or create entry (mirrors State.lua pattern)
                local entry = BR.BuffState.entries[buff.key]
                if not entry then
                    entry = {
                        key = buff.key,
                        category = category,
                        sortOrder = i,
                        visible = false,
                        displayType = "text",
                        shouldGlow = false,
                    }
                    BR.BuffState.entries[buff.key] = entry
                end
                entry.category = category
                entry.sortOrder = i
                entry.visible = true

                if category == "raid" then
                    if threshold > 0 and not expiringShown then
                        entry.displayType = "expiring"
                        entry.countText = FormatRemainingTime(testModeData.fakeRemaining)
                        entry.shouldGlow = exGlowEnabled
                        expiringShown = true
                    else
                        entry.displayType = "count"
                        local fakeBuffed = testModeData.fakeTotal - testModeData.fakeMissing[raidIndex]
                        entry.countText = fakeBuffed .. "/" .. testModeData.fakeTotal
                        entry.shouldGlow = missGlowEnabled
                    end
                    raidIndex = raidIndex + 1
                elseif category == "pet" then
                    entry.displayType = "text"
                    entry.overlayText = buff.overlayText
                    entry.iconByRole = buff.icons and buff.icons.byRole
                    entry.shouldGlow = missGlowEnabled
                    if buff.groupId == "pets" and BR.PetHelpers then
                        local actions = BR.PetHelpers.GetPetActions(playerClass)
                        if actions and #actions > 0 then
                            entry.petActions = actions
                        end
                    end
                else
                    -- consumable, presence, targeted, self, custom
                    entry.displayType = "text"
                    entry.overlayText = buff.overlayText
                    entry.iconByRole = buff.icons and buff.icons.byRole
                    entry.shouldGlow = missGlowEnabled

                    -- Show first buff as expiring to preview expiration countdown
                    if threshold > 0 and not buff.noExpirationGlow and not expiringShown then
                        entry.displayType = "expiring"
                        entry.countText = FormatRemainingTime(testModeData.fakeRemaining)
                        entry.shouldGlow = exGlowEnabled
                        expiringShown = true
                    end
                end
            end
        end
    end

    -- Build visibleByCategory (same pattern as State.lua)
    for _, list in pairs(BR.BuffState.visibleByCategory) do
        wipe(list)
    end
    for _, entry in pairs(BR.BuffState.entries) do
        if entry.visible then
            local cat = entry.category
            if not BR.BuffState.visibleByCategory[cat] then
                BR.BuffState.visibleByCategory[cat] = {}
            end
            tinsert(BR.BuffState.visibleByCategory[cat], entry)
        end
    end

    -- Mark sorted status
    for _, list in pairs(BR.BuffState.visibleByCategory) do
        local sorted = true
        for j = 2, #list do
            if list[j].sortOrder < list[j - 1].sortOrder then
                sorted = false
                break
            end
        end
        list._sorted = sorted
    end
end

-- Toggle test mode - returns true if test mode is now ON, false if OFF
ToggleTestMode = function()
    if testMode then
        testMode = false
        testModeData = nil
        -- Clear all glows, hide test labels, and hide ALL frames (including extra frames)
        -- so UpdateDisplay starts from a clean slate. Without this, frames shown during
        -- test mode but not tracked in previouslyVisibleKeys would linger as orphans.
        for _, frame in pairs(buffFrames) do
            SetExpirationGlow(frame, false)
            frame:Hide()
            if frame.extraFrames then
                for _, extra in ipairs(frame.extraFrames) do
                    extra:Hide()
                end
            end
        end
        wipe(previouslyVisibleKeys)
        suppressSound = true -- Prevent sound spam when exiting test mode
        -- Reset layout signatures so positioning runs fresh
        lastMainSignature = ""
        wipe(lastSplitSignatures)
        UpdateDisplay()
        return false
    else
        -- Seed fake values BEFORE setting testMode = true, so that if initialization
        -- errors (e.g. random(1,0) when threshold is 0), testMode stays false and
        -- the OnUpdate handler won't call GenerateTestEntries with nil testModeData.
        local db = BR.profile
        local threshold = max(1, (db.defaults and db.defaults.expirationThreshold) or 15)
        local data = {
            fakeTotal = random(10, 20),
            fakeRemaining = random(1, threshold) * 60,
            fakeMissing = {},
        }
        for i = 1, #RaidBuffs do
            data.fakeMissing[i] = random(1, 5)
        end
        testModeData = data
        testMode = true
        BR.SecureButtons.HideAllSecureFrames()
        lastMainSignature = ""
        wipe(lastSplitSignatures)
        UpdateDisplay()
        return true
    end
end

-- Helper to hide all display frames (mainFrame, category frames, and all buff frames)
local function HideAllDisplayFrames()
    mainFrame:Hide()
    for _, category in ipairs(CATEGORIES) do
        if categoryFrames[category] then
            categoryFrames[category]:Hide()
        end
    end
    for _, container in pairs(detachedFrames) do
        container:Hide()
    end
    wipe(previouslyVisibleKeys)
    -- Reset layout signatures so next PositionMainContainer/PositionSplitCategory always
    -- runs fresh. Without this, if the signature matches a previous value, positioning
    -- returns early without calling mainFrame:Show(), leaving frames invisible.
    lastMainSignature = ""
    wipe(lastSplitSignatures)
    -- Also hide individual buff frames (so they don't reappear when mainFrame is shown by fallback)
    for _, frame in pairs(buffFrames) do
        frame:Hide()
        if frame.extraFrames then
            for _, extra in ipairs(frame.extraFrames) do
                extra:Hide()
            end
        end
    end
    -- Hide secure click overlays and action buttons (sub-icons)
    BR.SecureButtons.HideAllSecureFrames()
    -- Hide dismiss button
    HideDismissFrames()
end

-- Update the fallback display (shows tracked buffs via action bar glow during PvP/Arena)
-- Shows glow-based frames + pet frames, then collects ALL visible frames for unified positioning
-- TODO: Blizzard will re-restrict aura APIs in PvP; uncomment when fallback display is needed again
-- UpdateFallbackDisplay = function()
--     if not mainFrame then
--         return
--     end
--
--     -- Show frames for any glowing spells (skip whenNotGlowing buffs - handled in second pass)
--     local seenKeys = {}
--     local GetPlayerSpecId = BR.StateHelpers.GetPlayerSpecId
--     for spellID, _ in pairs(glowingSpells) do
--         local entry = glowSpellToBuff[spellID]
--         if entry then
--             local buff = entry.buff
--             local mode = buff.glowMode or "whenGlowing"
--             if mode == "whenGlowing" and (not buff.class or buff.class == playerClass) and not seenKeys[buff.key] then
--                 -- Skip targeted buffs when solo (they require a group target)
--                 local skipSolo = entry.category == "targeted" and GetNumGroupMembers() == 0
--                 -- Skip buffs requiring a specific spec
--                 local skipSpec = buff.requireSpecId and GetPlayerSpecId() ~= buff.requireSpecId
--                 if not skipSolo and not skipSpec then
--                     seenKeys[buff.key] = true
--                     local frame = buffFrames[buff.key]
--                     if frame and IsBuffEnabled(buff.key) then
--                         ShowTextFrame(frame, buff.overlayText)
--                     end
--                 end
--             end
--         end
--     end
--
--     -- Second pass: show whenNotGlowing buffs where NONE of their spells are glowing
--     local invertedHasGlow = {}
--     for spellID, _ in pairs(glowingSpells) do
--         local entry = glowSpellToBuff[spellID]
--         if entry and (entry.buff.glowMode == "whenNotGlowing") then
--             invertedHasGlow[entry.buff.key] = true
--         end
--     end
--     for _, entry in pairs(glowSpellToBuff) do
--         local buff = entry.buff
--         if buff.glowMode == "whenNotGlowing" and not seenKeys[buff.key] and not invertedHasGlow[buff.key] then
--             seenKeys[buff.key] = true
--             if not buff.class or buff.class == playerClass then
--                 local skipSpec = buff.requireSpecId and GetPlayerSpecId() ~= buff.requireSpecId
--                 if not skipSpec then
--                     local frame = buffFrames[buff.key]
--                     if frame and IsBuffEnabled(buff.key) then
--                         ShowTextFrame(frame, buff.overlayText)
--                     end
--                 end
--             end
--         end
--     end
--
--     -- Pet frames are non-secure and customCheck works in all contexts
--     BR.BuffState.Refresh()
--     RenderPetEntries()
--
--     -- Collect ALL visible frames (glow + pet + pet extra frames) for unified positioning
--     local shownByCategory = {}
--     local mainFrameBuffs = {}
--     for _, frame in pairs(buffFrames) do
--         if frame:IsShown() and frame.buffCategory then
--             local category = frame.buffCategory
--             if IsCategorySplit(category) then
--                 if not shownByCategory[category] then
--                     shownByCategory[category] = {}
--                 end
--                 shownByCategory[category][#shownByCategory[category] + 1] = frame
--             else
--                 mainFrameBuffs[#mainFrameBuffs + 1] = frame
--             end
--             -- Include expanded pet extra frames in the same list
--             if frame.extraFrames then
--                 for _, extra in ipairs(frame.extraFrames) do
--                     if extra:IsShown() then
--                         if IsCategorySplit(category) then
--                             shownByCategory[category][#shownByCategory[category] + 1] = extra
--                         else
--                             mainFrameBuffs[#mainFrameBuffs + 1] = extra
--                         end
--                     end
--                 end
--             end
--         end
--     end
--
--     if #mainFrameBuffs > 0 or next(shownByCategory) then
--         for category, frames in pairs(shownByCategory) do
--             PositionSplitCategory(category, frames)
--         end
--         if #mainFrameBuffs > 0 then
--             PositionMainContainer(mainFrameBuffs)
--         end
--         BR.Movers.UpdateAnchor()
--     else
--         HideAllDisplayFrames()
--     end
-- end

-- Eating icon texture ID (from State.lua, matches the eating channel aura icon)
local EATING_ICON = BR.EATING_AURA_ICON

---Apply consumable overlays (stat label top-left, badge/quality bottom-left) to a frame.
---@param frame table
---@param item table Bucket item with .statLabel, .badge, and .qualityAtlas fields
---@param fontSize number? Explicit font size (computed from icon width if nil)
local function ApplyConsumableOverlays(frame, item, fontSize)
    if not item.statLabel and not item.badge and not item.qualityAtlas then
        return
    end
    if not fontSize then
        fontSize = BR.SecureButtons.ComputeConsumableFontSize(frame:GetWidth())
    end
    local hideLabels = (BR.profile.defaults or {}).hideConsumableLabels
    if item.statLabel and not hideLabels then
        if not frame.statLabel then
            frame.statLabel = frame:CreateFontString(nil, "OVERLAY")
        end
        do
            local sz, sx, sy = BR.TextPositions.Get("statLabel")
            BR.TextPositions.Apply(frame.statLabel, frame, sz, sx, sy)
        end
        frame.statLabel:SetFont(fontPath, fontSize, outlineFlag)
        frame.statLabel:SetTextColor(1, 1, 1, 1)
        frame.statLabel:SetText(item.statLabel)
        frame.statLabel:Show()
    elseif frame.statLabel then
        frame.statLabel:Hide()
    end
    -- Quality atlas icon (crafted quality tier) - bottom-left corner
    if item.qualityAtlas then
        if not frame.qualityIcon then
            local holder = CreateFrame("Frame", nil, frame)
            holder:SetAllPoints()
            holder:SetFrameLevel(frame:GetFrameLevel() + 10)
            frame.qualityIcon = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        end
        local iconSize = frame:GetWidth()
        local qOffset = -floor(iconSize * 0.125)
        local qSize = max(14, floor(iconSize * 0.45))
        frame.qualityIcon:ClearAllPoints()
        frame.qualityIcon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", qOffset, qOffset)
        frame.qualityIcon:SetSize(qSize, qSize)
        frame.qualityIcon:SetAtlas(item.qualityAtlas)
        frame.qualityIcon:Show()
    elseif frame.qualityIcon then
        frame.qualityIcon:Hide()
    end
    -- Text badge (e.g. "F" fleeting, "H" hearty) - default middle-left; user-positionable
    if item.badge then
        local bc = BR.SecureButtons.BADGE_COLORS[item.badge]
        if bc then
            if not frame.badgeLabel then
                frame.badgeLabel = frame:CreateFontString(nil, "OVERLAY")
            end
            do
                local bz, bx, by = BR.TextPositions.Get("badge")
                BR.TextPositions.Apply(frame.badgeLabel, frame, bz, bx, by)
            end
            frame.badgeLabel:SetFont(fontPath, fontSize, outlineFlag)
            frame.badgeLabel:SetTextColor(bc.r, bc.g, bc.b, 1)
            frame.badgeLabel:SetText(item.badge)
            frame.badgeLabel:Show()
        end
    elseif frame.badgeLabel then
        frame.badgeLabel:Hide()
    end
end

---Clear consumable overlays from a frame.
---@param frame table
local function ClearConsumableOverlays(frame)
    if frame.statLabel then
        frame.statLabel:Hide()
    end
    if frame.badgeLabel then
        frame.badgeLabel:Hide()
    end
    if frame.qualityIcon then
        frame.qualityIcon:Hide()
    end
end

-- Set icon desaturation and dimming for consumable frames without bag items.
-- Tracks state to skip redundant WoW API calls on hot render paths.
local function SetIconDesaturated(icon, desaturate)
    if icon._br_desaturated == desaturate then
        return
    end
    icon._br_desaturated = desaturate
    icon:SetDesaturated(desaturate)
    if desaturate then
        icon:SetVertexColor(0.6, 0.6, 0.6, 1)
    else
        icon:SetVertexColor(1, 1, 1, 1)
    end
end

-- Reset a consumable frame's icon to its buff definition fallback and clear overlays.
local function RestoreFallbackIcon(frame)
    ClearConsumableOverlays(frame)
    local def = frame.buffDef
    local fallback = def and GetBuffIcons(def)[1]
    if fallback then
        frame.icon:SetTexture(fallback)
    end
end

-- Resolve a consumable frame's icon from bag items.
-- Returns "items" if bag items found (sets icon, quality overlay, stack count),
-- "missing" if no items but showConsumablesWithoutItems is on (icon greyed out),
-- or false if no items and setting is off.
---@param frame BuffFrame
---@return string|false result "items", "missing", or false
local function ResolveConsumableFrame(frame)
    local items = frame._cachedItems
    if items == nil then
        items = BR.SecureButtons.GetConsumableActionItems(frame.buffDef) or false
        frame._cachedItems = items
    end
    if items and items[1] then
        if items[1].icon then
            frame.icon:SetTexture(items[1].icon)
        end
        SetIconDesaturated(frame.icon, false)
        local mainSize = frame:GetWidth()
        local cFontSize = BR.SecureButtons.ComputeConsumableFontSize(mainSize)
        frame.count:Hide()
        frame.stackCount:SetFont(fontPath, cFontSize, outlineFlag)
        frame.stackCount:SetText(items[1].count)
        frame.stackCount:Show()
        ApplyConsumableOverlays(frame, items[1], cFontSize)
        return "items"
    end
    -- No items: fall back icon to buff definition
    RestoreFallbackIcon(frame)
    local defs = BR.profile.defaults or {}
    if defs.showConsumablesWithoutItems then
        if defs.showWithoutItemsOnlyOnReadyCheck and not BR.BuffState.GetReadyCheckState() then
            return false
        end
        SetIconDesaturated(frame.icon, true)
        return "missing"
    end
    return false
end

-- Render a single visible entry into its frame using the appropriate display type.
-- Returns true if the frame was shown, false if it was skipped (e.g. consumable
-- with no bag items and showConsumablesWithoutItems off).
local function RenderVisibleEntry(frame, entry)
    -- Clear consumable overlays at the start of each render (re-applied by relevant paths below)
    ClearConsumableOverlays(frame)

    -- Hide stack count by default; only the consumable-with-items path shows it
    frame.stackCount:Hide()

    -- Eating override: state provides isEating as a snapshot, so the display
    -- never reads a live flag that can change mid-cycle.
    if entry.isEating then
        SetIconDesaturated(frame.icon, false)
        frame.icon:SetTexture(EATING_ICON)
        frame._br_eating_icon = true
        if entry.eatingExpirationTime then
            -- Seed initial text, then hand off to per-frame OnUpdate for smooth countdown
            local remaining = entry.eatingExpirationTime - GetTime()
            if remaining > 0 then
                frame.count:SetFont(fontPath, GetFrameFontSize(frame), outlineFlag)
                frame.count:SetText(FormatEatingTime(remaining))
                frame.count:Show()
            else
                frame.count:Hide()
            end
            -- Per-frame OnUpdate: updates countdown text every render frame
            if not frame._br_eating_onupdate then
                local expTime = entry.eatingExpirationTime
                frame:SetScript("OnUpdate", function()
                    local rem = expTime - GetTime()
                    if rem > 0 then
                        frame.count:SetText(FormatEatingTime(rem))
                    else
                        frame.count:Hide()
                        frame:SetScript("OnUpdate", nil)
                        frame._br_eating_onupdate = nil
                    end
                end)
                frame._br_eating_onupdate = true
            end
        else
            frame.count:Hide()
        end
        frame:Show()
        SetExpirationGlow(frame, false)
        return true
    elseif frame._br_eating_icon then
        -- Transition from eating -> not eating: restore the correct consumable icon
        frame._br_eating_icon = nil
        if frame._br_eating_onupdate then
            frame:SetScript("OnUpdate", nil)
            frame._br_eating_onupdate = nil
        end
        ResolveConsumableFrame(frame)
    end

    -- Get cached glow settings for this entry's category (avoids repeated DB reads)
    local glowKind = entry.glowKindOverride or (entry.displayType == "expiring" and "expiring" or "missing")
    local cachedGlow = entry.category and GetCachedGlowSettings(entry.category, glowKind) or nil

    -- Apply dynamic icon overrides (e.g. rogue poison expiring soonest, role-based shields)
    if entry.dynamicIcon then
        frame.icon:SetTexture(entry.dynamicIcon)
    elseif entry.iconByRole and frame.buffDef then
        local texture = ResolveRoleTexture(frame.buffDef)
        if texture then
            frame.icon:SetTexture(texture)
        end
    end

    if entry.displayType == "count" or entry.displayType == "expiring" then
        if frame.buffCategory == "consumable" then
            SetIconDesaturated(frame.icon, false)
        end
        frame.count:SetFont(fontPath, GetFrameFontSize(frame), outlineFlag)
        frame.count:SetText(entry.countText or "")
        frame.count:Show()
        frame:Show()
        SetExpirationGlow(frame, entry.shouldGlow, entry.category, cachedGlow)
        -- Show consumable stat label for expiring consumables (resolve from cached items)
        if entry.displayType == "expiring" and BUFF_KEY_TO_CATEGORY[frame.key] then
            local items = frame._cachedItems
            if items == nil then
                items = BR.SecureButtons.GetConsumableActionItems(frame.buffDef) or false
                frame._cachedItems = items
            end
            if items and items[1] then
                if items[1].icon then
                    frame.icon:SetTexture(items[1].icon)
                end
                ApplyConsumableOverlays(frame, items[1])
            else
                RestoreFallbackIcon(frame)
            end
        end
    else -- "text"
        -- Consumables with bag scan support: show actual item from bags
        if BUFF_KEY_TO_CATEGORY[frame.key] then
            local result = ResolveConsumableFrame(frame)
            if result == "items" then
                frame:Show()
                SetExpirationGlow(frame, entry.shouldGlow, entry.category, cachedGlow)
            elseif result == "missing" then
                ShowTextFrame(frame, entry.overlayText, entry.shouldGlow, entry.category, cachedGlow)
            else
                if testMode then
                    ShowTextFrame(frame, entry.overlayText, entry.shouldGlow, entry.category, cachedGlow)
                else
                    return false
                end
            end
        else
            ShowTextFrame(frame, entry.overlayText, entry.shouldGlow, entry.category, cachedGlow)
        end
    end

    -- Per-category text visibility (uses buff's actual category, not effective/main)
    if not ShouldShowText(frame.buffCategory) then
        frame.count:Hide()
        frame.stackCount:Hide()
        ClearConsumableOverlays(frame)
    end
    return true
end

---Apply consumable display mode (sub-icons or expanded extra frames) to a consumable frame.
---@param frame BuffFrame
---@param entry BuffStateEntry
---@param frameList table[] List to append extra frames to (for positioning)
---@param parentFrame Frame Parent for extra frames
local function ApplyConsumableDisplayMode(frame, entry, frameList, parentFrame)
    -- Always clean up leftover extra frames first (prevents orphans on state transitions)
    if frame.extraFrames then
        for _, extra in ipairs(frame.extraFrames) do
            extra:Hide()
        end
    end

    if entry.displayType ~= "text" and entry.displayType ~= "expiring" and not entry.isEating then
        return
    end
    if not BUFF_KEY_TO_CATEGORY[frame.key] or not frame:IsShown() then
        return
    end

    local displayMode = (BR.profile.defaults or {}).consumableDisplayMode or "sub_icons"
    local items = frame._cachedItems
    if items == nil then
        items = BR.SecureButtons.GetConsumableActionItems(frame.buffDef) or false
        frame._cachedItems = items
    end

    if displayMode == "sub_icons" then
        if testMode and items and #items > 1 then
            -- Test mode: render visual-only sub-icon frames (no secure buttons)
            local effectiveCat = GetEffectiveCategory(frame)
            local catSettings = GetCategorySettings(effectiveCat)
            local consumableSettings = GetCategorySettings("consumable")
            local iconSize = catSettings.iconSize or 64
            local size = max(18, floor(iconSize * 0.45))
            local btnSpacing = max(2, floor(size * 0.2))
            local subIconSide = consumableSettings.subIconSide or "BOTTOM"
            local subIconOffset = -6
            local itemCount = #items - 1
            local isSideways = subIconSide == "LEFT" or subIconSide == "RIGHT"

            local cFontSize = BR.SecureButtons.ComputeConsumableFontSize(iconSize)
            for i = 2, #items do
                local idx = i - 2
                local extra = GetOrCreateExtraFrame(frame, i - 1)
                extra:SetParent(frame)
                extra:SetSize(size, size)
                extra.icon:SetTexture(items[i].icon)
                extra.stackCount:SetFont(fontPath, cFontSize, outlineFlag)
                extra.stackCount:SetText(items[i].count > 1 and tostring(items[i].count) or "")
                extra.stackCount:Show()
                extra.count:Hide()
                SetExpirationGlow(extra, false)
                extra:SetFrameLevel(frame:GetFrameLevel() + 4)

                extra:ClearAllPoints()
                if isSideways then
                    local maxPerCol = max(1, floor((iconSize + btnSpacing) / (size + btnSpacing)))
                    local row = idx % maxPerCol
                    local col = floor(idx / maxPerCol)
                    local thisColCount = min(maxPerCol, itemCount - col * maxPerCol)
                    local thisColHeight = thisColCount * size + (thisColCount - 1) * btnSpacing
                    local startY = (iconSize - thisColHeight) / 2
                    local yOff = -(startY + row * (size + btnSpacing))
                    if subIconSide == "LEFT" then
                        extra:SetPoint("TOPRIGHT", frame, "TOPLEFT", subIconOffset - col * (size + btnSpacing), yOff)
                    else
                        extra:SetPoint("TOPLEFT", frame, "TOPRIGHT", -subIconOffset + col * (size + btnSpacing), yOff)
                    end
                else
                    local maxPerRow = max(1, floor((iconSize + btnSpacing) / (size + btnSpacing)))
                    local col = idx % maxPerRow
                    local row = floor(idx / maxPerRow)
                    local thisRowCount = min(maxPerRow, itemCount - row * maxPerRow)
                    local thisRowWidth = thisRowCount * size + (thisRowCount - 1) * btnSpacing
                    local startX = (iconSize - thisRowWidth) / 2
                    local xOff = startX + col * (size + btnSpacing)
                    if subIconSide == "TOP" then
                        extra:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", xOff, -subIconOffset + row * (size + btnSpacing))
                    else
                        extra:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", xOff, subIconOffset - row * (size + btnSpacing))
                    end
                end

                extra:Show()
            end
        elseif not testMode then
            local cs = BR.profile.categorySettings and BR.profile.categorySettings.consumable
            local clickable = cs and cs.clickable == true
            -- Skip first item (already shown as main icon)
            BR.SecureButtons.UpdateConsumableButtons(frame, items, clickable, 2)
        end
    else
        -- Not sub_icons: hide any leftover sub-icon buttons
        BR.SecureButtons.UpdateConsumableButtons(frame, nil)
        if displayMode == "expanded" and items and #items > 1 then
            local cachedGlow = entry.category
                    and GetCachedGlowSettings(
                        entry.category,
                        entry.glowKindOverride or (entry.displayType == "expiring" and "expiring" or "missing")
                    )
                or nil
            local expandedSize = frame:GetWidth()
            local cFontSize = BR.SecureButtons.ComputeConsumableFontSize(expandedSize)
            for i = 2, #items do
                local extra = GetOrCreateExtraFrame(frame, i - 1)
                extra:SetParent(parentFrame)
                extra:SetSize(expandedSize, frame:GetHeight())
                extra.icon:SetTexture(items[i].icon)
                extra.stackCount:SetFont(fontPath, cFontSize, outlineFlag)
                extra.stackCount:SetText(items[i].count)
                extra.count:Hide()
                local showText = ShouldShowText(frame.buffCategory)
                if showText then
                    extra.stackCount:Show()
                else
                    extra.stackCount:Hide()
                end
                extra:Show()
                SetExpirationGlow(extra, entry.shouldGlow, entry.category, cachedGlow)
                -- Apply consumable overlays (clear first to handle toggle-off)
                ClearConsumableOverlays(extra)
                if showText then
                    ApplyConsumableOverlays(extra, items[i], cFontSize)
                end
                frameList[#frameList + 1] = extra
            end
        end
    end
end

---Show or hide pet name/family labels below a frame.
---Skips redundant work if the action and scale haven't changed.
---@param frame BuffFrame
---@param petAction PetAction?
local function UpdatePetLabels(frame, petAction)
    local defs = BR.profile.defaults or {}
    local showLabels = defs.petLabels ~= false
    local petClassVis = defs.petLabelClasses
    local classLabelsOff = playerClass and petClassVis and petClassVis[playerClass] == false
    if not petAction or not showLabels or classLabelsOff then
        if frame._br_pet_label_key then
            frame._br_pet_label_key = nil
            if frame._br_pet_name_text then
                frame._br_pet_name_text:Hide()
            end
            if frame._br_pet_family_text then
                frame._br_pet_family_text:Hide()
            end
            if frame._br_pet_extra_text then
                frame._br_pet_extra_text:Hide()
            end
        end
        return
    end

    -- Early out if nothing changed since last call
    local scale = defs.petLabelScale or 100
    local cacheKey = format("%s:%s:%s:%d", petAction.key, petAction.label or "", petAction.petFamily or "", scale)
    if frame._br_pet_label_key == cacheKey then
        return
    end
    frame._br_pet_label_key = cacheKey

    if not frame._br_pet_name_text then
        frame._br_pet_name_text = frame:CreateFontString(nil, "OVERLAY")
        frame._br_pet_family_text = frame:CreateFontString(nil, "OVERLAY")
        frame._br_pet_extra_text = frame:CreateFontString(nil, "OVERLAY")
    end

    local ratio = scale / 100
    local nameSize = max(7, floor(frame:GetWidth() * 0.18 * ratio))
    local familySize = max(7, floor(nameSize * 0.85))
    frame._br_pet_name_text:SetFont(fontPath, nameSize, outlineFlag)
    frame._br_pet_name_text:ClearAllPoints()
    frame._br_pet_name_text:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame._br_pet_name_text:SetText(petAction.label or "")
    frame._br_pet_name_text:SetTextColor(1, 1, 1)
    frame._br_pet_name_text:Show()

    local family = petAction.petFamily
    if family and family ~= "" then
        frame._br_pet_family_text:SetFont(fontPath, familySize, outlineFlag)
        frame._br_pet_family_text:ClearAllPoints()
        frame._br_pet_family_text:SetPoint("TOP", frame._br_pet_name_text, "BOTTOM", 0, -1)
        frame._br_pet_family_text:SetText(family)
        frame._br_pet_family_text:SetTextColor(1, 1, 1)
        frame._br_pet_family_text:Show()
    else
        frame._br_pet_family_text:Hide()
    end

    if petAction.petSpiritBeast then
        local anchor = (family and family ~= "") and frame._br_pet_family_text or frame._br_pet_name_text
        frame._br_pet_extra_text:SetFont(fontPath, familySize, outlineFlag)
        frame._br_pet_extra_text:ClearAllPoints()
        frame._br_pet_extra_text:SetPoint("TOP", anchor, "BOTTOM", 0, -1)
        frame._br_pet_extra_text:SetText(L["Pet.SpiritBeast"])
        frame._br_pet_extra_text:SetTextColor(1, 1, 1)
        frame._br_pet_extra_text:Show()
    else
        frame._br_pet_extra_text:Hide()
    end
end

local function SetupPetExtraFrame(frame, index, action, entry, cachedGlow, frameList)
    local extra = GetOrCreateExtraFrame(frame, index)
    extra:SetParent(frame:GetParent())
    extra:SetSize(frame:GetWidth(), frame:GetHeight())
    extra.icon:SetTexture(action.icon)
    extra.count:Hide()
    extra.stackCount:Hide()
    extra._br_pet_spell = action.spellName
    extra._br_pet_spec_icon = action.petSpecIcon
    UpdatePetLabels(extra, action)
    BR.SecureButtons.ReapplyPetSpecIconIfHovered(extra)
    extra:Show()
    SetExpirationGlow(extra, entry.shouldGlow, entry.category, cachedGlow)
    if frameList then
        frameList[#frameList + 1] = extra
    end
end

---Apply pet display mode to a frame: expand into extra frames or restore generic icon.
---@param frame BuffFrame
---@param entry BuffStateEntry
---@param frameList? table[] List to append extra frames to (for positioning)
local function ApplyPetDisplayMode(frame, entry, frameList)
    if not entry.petActions or #entry.petActions == 0 or not frame:IsShown() then
        frame._br_pet_spell = nil
        frame._br_pet_spec_icon = nil
        UpdatePetLabels(frame, nil)
        return
    end

    -- Hide all extras first (handles shrinking action count cleanly)
    if frame.extraFrames then
        for _, extra in ipairs(frame.extraFrames) do
            extra:Hide()
            UpdatePetLabels(extra, nil)
        end
    end

    local petMode = (BR.profile.defaults or {}).petDisplayMode or "generic"

    -- Set up main frame icon and click-to-cast target
    if petMode == "expanded" then
        local first = entry.petActions[1]
        frame.icon:SetTexture(first.icon)
        frame.count:Hide()
        frame._br_pet_spell = first.spellName
        frame._br_pet_spec_icon = first.petSpecIcon
        UpdatePetLabels(frame, first)
    else
        local gi = entry.petActions.genericIndex or 1
        local preferredAction = entry.petActions[gi]
        local texture = ResolveFrameTexture(frame)
        if texture then
            frame.icon:SetTexture(texture)
        end
        frame._br_pet_spell = preferredAction and preferredAction.spellName
        frame._br_pet_spec_icon = preferredAction and preferredAction.petSpecIcon
        UpdatePetLabels(frame, preferredAction)
    end
    BR.SecureButtons.ReapplyPetSpecIconIfHovered(frame)

    -- Show extra frames for additional actions
    local cachedGlow = entry.category and GetCachedGlowSettings(entry.category, "missing") or nil
    local extraIndex = 0
    for i, action in ipairs(entry.petActions) do
        local showAsExtra = (petMode == "expanded" and i >= 2)
            or (petMode ~= "expanded" and action.spellID == BR.PetHelpers.REVIVE_PET_ID)
        if showAsExtra then
            extraIndex = extraIndex + 1
            SetupPetExtraFrame(frame, extraIndex, action, entry, cachedGlow, frameList)
        end
    end
end

-- Render pet category entries (pet frames are non-secure and customCheck works in all contexts)
-- TODO: Blizzard will re-restrict aura APIs in PvP; uncomment when fallback display is needed again
-- RenderPetEntries = function()
--     local petEntries = BR.BuffState.visibleByCategory.pet
--     if not petEntries or #petEntries == 0 then
--         return
--     end
--     if not petEntries._sorted then
--         tsort(petEntries, function(a, b)
--             return a.sortOrder < b.sortOrder
--         end)
--     end
--     for _, entry in ipairs(petEntries) do
--         local frame = buffFrames[entry.key]
--         if frame then
--             RenderVisibleEntry(frame, entry)
--             ApplyPetDisplayMode(frame, entry)
--         end
--     end
-- end

-- ============================================================================
-- CONSUMABLE DISMISS BUTTON
-- ============================================================================

local GameTooltip = GameTooltip
local dismissButton -- small X badge overlaid on the last consumable icon
local reusableDismissFrameList = {} -- reused each cycle to avoid allocation in split mode

local function GetOrCreateDismissButton()
    if dismissButton then
        return dismissButton
    end
    local btn = CreateFrame("Button", "BuffReminders_DismissConsumables", UIParent)
    btn:SetSize(16, 16)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    bg:SetColorTexture(0, 0, 0, 0.6)

    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture([[Interface\RAIDFRAME\ReadyCheck-NotReady]])
    icon:SetAlpha(0.8)

    btn:SetScript("OnClick", function()
        BR.BuffState.SetConsumablesDismissed(true)
        UpdateDisplay()
        print("|cff00ccffBuffReminders:|r " .. L["Display.DismissConsumablesChat"])
    end)
    btn:SetScript("OnEnter", function(self)
        icon:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Display.DismissConsumables"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        icon:SetAlpha(0.8)
        GameTooltip:Hide()
    end)
    btn:SetFrameStrata("MEDIUM")
    btn:Hide()
    dismissButton = btn
    return btn
end

--- Show the dismiss badge on the top-right corner of the last consumable frame.
local function PositionDismissButton(frameList)
    -- Find the last consumable frame in the list
    local lastConsumableFrame = nil
    for i = #frameList, 1, -1 do
        local f = frameList[i]
        if f.buffCategory == "consumable" then
            lastConsumableFrame = f
            break
        end
    end
    if not lastConsumableFrame then
        return
    end

    local btn = GetOrCreateDismissButton()
    local iconSize = lastConsumableFrame:GetHeight()
    local btnSize = max(floor(iconSize * 0.3), 12)
    btn:SetSize(btnSize, btnSize)
    btn:SetParent(lastConsumableFrame)
    btn:SetFrameLevel(lastConsumableFrame:GetFrameLevel() + 10)
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", lastConsumableFrame, "TOPRIGHT", 3, 3)
    btn:Show()
end

HideDismissFrames = function()
    if dismissButton then
        dismissButton:Hide()
    end
end

-- Play per-buff sound alert when an icon first appears.
-- buffSounds is passed in from UpdateDisplay to avoid repeated BR.profile lookups.
local function TryPlayBuffSound(key, buffSounds)
    -- Resolve grouped buff keys (e.g. "beaconOfFaith" -> "beacons")
    local settingKey = buffKeyToSettingKey[key] or key
    -- Deduplicate: don't play the same group sound twice in one cycle
    if soundPlayedThisCycle[settingKey] then
        return
    end
    local soundName = buffSounds[settingKey]
    if soundName then
        local soundFile = LSM:Fetch("sound", soundName)
        if soundFile then
            PlaySoundFile(soundFile, "Master")
        end
        soundPlayedThisCycle[settingKey] = true
    end
end

-- Update the display
---@param refreshMode? "full"|"group"
UpdateDisplay = function(refreshMode)
    if not mainFrame then
        return
    end
    refreshMode = refreshMode or "full"
    local groupOnly = refreshMode == "group"

    -- Clear per-cycle caches (before early exits - fallback paths also use these)
    if not groupOnly then
        wipe(expiringGlowCache)
        wipe(missingGlowCache)
        for key in pairs(BUFF_KEY_TO_CATEGORY) do
            local frame = buffFrames[key]
            if frame then
                frame._cachedItems = nil
            end
        end
    end

    if testMode then
        -- Test mode: generate fake state entries through the normal pipeline
        GenerateTestEntries()
    else
        local isDead = UnitIsDeadOrGhost("player")
        if isDead then
            HideAllDisplayFrames()
            return
        end

        local db = BR.profile

        if select(3, GetInstanceInfo()) == DECOR_DUEL_DIFFICULTY_ID then
            HideAllDisplayFrames()
            return
        end

        if db.showOnlyInGroup and BR.BuffState.IsAlone() then
            HideAllDisplayFrames()
            return
        end

        if db.hideWhileResting and isResting then
            HideAllDisplayFrames()
            return
        end

        if db.hideInCombat and inCombat then
            HideAllDisplayFrames()
            return
        end

        if db.hideAllInVehicle and BR.BuffState.GetInVehicle() then
            HideAllDisplayFrames()
            return
        end

        if db.hideWhileMounted and IsMounted() then
            HideAllDisplayFrames()
            return
        end

        if db.hideInLegacyInstances and BR.BuffState.IsLegacyInstance() then
            HideAllDisplayFrames()
            return
        end

        local playerLevel, maxExpansionLevel = BR.BuffState.GetLevelInfo()
        if db.hideWhileLeveling and playerLevel < maxExpansionLevel then
            HideAllDisplayFrames()
            return
        end

        -- PvP/Arena and M+: aura API is restricted but we use the normal display path
        -- (State.lua treats PvP the same as M+ for aura restriction purposes)

        -- Refresh buff state
        BR.BuffState.Refresh(refreshMode)
    end

    local visibleByCategory = BR.BuffState.visibleByCategory
    local anyVisible = false

    -- Cache buffSounds once per cycle; nil when suppressed or empty (skips all sound checks)
    local buffSounds = (not testMode and not suppressSound) and BR.profile.buffSounds or nil
    if buffSounds and not next(buffSounds) then
        buffSounds = nil
    end
    wipe(soundPlayedThisCycle)

    -- Reuse module-level tables (wiped to avoid per-call allocation)
    wipe(reusableVisibleKeys)
    wipe(reusableMainBuffs)

    -- Build sorted category list by priority
    local sortedCategories = GetSortedCategories()

    for _, catEntry in ipairs(sortedCategories) do
        local category = catEntry.name
        local entries = visibleByCategory[category]

        if entries and #entries > 0 then
            if not entries._sorted then
                tsort(entries, sortComparator)
            end
            anyVisible = true

            if IsCategorySplit(category) then
                -- Render + position this split category directly
                local frames = {}
                for _, entry in ipairs(entries) do
                    local frame = buffFrames[entry.key]
                    if frame then
                        local shown = RenderVisibleEntry(frame, entry)
                        if shown then
                            if buffSounds and not previouslyVisibleKeys[entry.key] then
                                TryPlayBuffSound(entry.key, buffSounds)
                            end
                            if IsIconDetached(entry.key) then
                                PositionDetachedIcon(entry.key, frame)
                            else
                                frames[#frames + 1] = frame
                            end
                            reusableVisibleKeys[entry.key] = true
                        end
                        -- Category-specific post-processing
                        if category == "consumable" then
                            if IsIconDetached(entry.key) then
                                wipe(reusableDetachedSink)
                                ApplyConsumableDisplayMode(frame, entry, reusableDetachedSink, frame:GetParent())
                            else
                                ApplyConsumableDisplayMode(frame, entry, frames, frame:GetParent())
                            end
                        elseif category == "pet" then
                            ApplyPetDisplayMode(frame, entry, frames)
                        end
                    end
                end
                PositionSplitCategory(category, frames)
            else
                -- Render, collect for main container
                for _, entry in ipairs(entries) do
                    local frame = buffFrames[entry.key]
                    if frame then
                        local shown = RenderVisibleEntry(frame, entry)
                        if shown then
                            if buffSounds and not previouslyVisibleKeys[entry.key] then
                                TryPlayBuffSound(entry.key, buffSounds)
                            end
                            if IsIconDetached(entry.key) then
                                PositionDetachedIcon(entry.key, frame)
                            else
                                reusableMainBuffs[#reusableMainBuffs + 1] = frame
                            end
                            reusableVisibleKeys[entry.key] = true
                        end
                        -- Category-specific post-processing
                        if category == "consumable" then
                            if IsIconDetached(entry.key) then
                                wipe(reusableDetachedSink)
                                ApplyConsumableDisplayMode(frame, entry, reusableDetachedSink, frame:GetParent())
                            else
                                ApplyConsumableDisplayMode(frame, entry, reusableMainBuffs, frame:GetParent())
                            end
                        elseif category == "pet" then
                            ApplyPetDisplayMode(frame, entry, reusableMainBuffs)
                        end
                    end
                end
            end
        end
    end

    -- Selectively hide frames that were visible last cycle but aren't now
    for key in pairs(previouslyVisibleKeys) do
        if not reusableVisibleKeys[key] then
            local frame = buffFrames[key]
            if frame then
                HideFrame(frame)
                frame._cachedItems = nil
                UpdatePetLabels(frame, nil)
                if frame.extraFrames then
                    for _, extra in ipairs(frame.extraFrames) do
                        extra:Hide()
                        UpdatePetLabels(extra, nil)
                    end
                end
                -- Hide detached container when its icon is no longer visible
                if detachedFrames[key] then
                    detachedFrames[key]:Hide()
                end
            end
        end
    end
    -- Update tracking set
    wipe(previouslyVisibleKeys)
    for key in pairs(reusableVisibleKeys) do
        previouslyVisibleKeys[key] = true
    end
    suppressSound = false

    -- Consumable dismiss button: show X badge on last visible consumable icon
    local consumableEntries = not testMode and visibleByCategory["consumable"]
    local hasConsumableFrames = consumableEntries and #consumableEntries > 0
    local consumableSplit = IsCategorySplit("consumable")

    -- Position main container
    PositionMainContainer(reusableMainBuffs)

    -- Handle split category frames with no visible buffs
    PositionSplitCategories(visibleByCategory)

    -- Show dismiss badge on the last visible consumable icon
    if hasConsumableFrames then
        local frameList
        if consumableSplit then
            wipe(reusableDismissFrameList)
            for _, entry in ipairs(consumableEntries) do
                local f = buffFrames[entry.key]
                if f and f:IsShown() then
                    reusableDismissFrameList[#reusableDismissFrameList + 1] = f
                end
            end
            frameList = reusableDismissFrameList
        else
            frameList = reusableMainBuffs
        end
        PositionDismissButton(frameList)
    else
        if dismissButton then
            dismissButton:Hide()
        end
    end

    if not anyVisible then
        HideAllDisplayFrames()
    end
    BR.Movers.UpdateAnchor()

    -- Skip secure frame sync in test mode (secure frames are hidden)
    if not testMode then
        BR.SecureButtons.ScheduleSecureSync()

        -- Sync click overlays on expanded extra frames (they are created above but
        -- UpdateActionButtons is the only place that wires up their click overlays).
        if not groupOnly and not InCombatLockdown() then
            local displayMode = (BR.profile.defaults or {}).consumableDisplayMode
            if displayMode == "expanded" then
                BR.SecureButtons.UpdateActionButtons("consumable")
            end
            BR.SecureButtons.UpdateActionButtons("pet")
            BR.SecureButtons.UpdateActionButtons("custom")
        end
    end
end

-- Start update ticker
local function StartUpdates()
    if updateTicker then
        updateTicker:Cancel()
    end
    -- Slow fallback ticker for expiration text staleness (e.g. "14m" -> "13m")
    updateTicker = C_Timer.NewTicker(3, SetDirty)
    -- OnUpdate checks dirty flag with throttle
    eventFrame:SetScript("OnUpdate", function()
        if not dirty then
            return
        end
        local now = GetTime()
        if now - lastUpdateTime < MIN_UPDATE_INTERVAL then
            return
        end
        local refreshMode = dirtyMode
        dirty = false
        dirtyMode = "full"
        lastUpdateTime = now
        UpdateDisplay(refreshMode)
    end)
    -- Immediate first update
    dirty = false
    dirtyMode = "full"
    lastUpdateTime = GetTime()
    UpdateDisplay("full")
end

-- Stop update ticker (preserved for easy revert when Blizzard re-protects spells)
local function StopTicker() -- luacheck: ignore 211
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
    -- OnUpdate handler stays active so SetDirty() works during combat
end

-- Forward declaration for ReparentBuffFrames (defined after InitializeFrames)
local ReparentBuffFrames

-- Initialize main frame
local function InitializeFrames()
    mainFrame = CreateFrame("Frame", "BuffRemindersFrame", UIParent)
    mainFrame:SetSize(200, 50)

    local db = BR.profile
    local pos = (db.categorySettings and db.categorySettings.main and db.categorySettings.main.position)
        or db.position
        or { point = "CENTER", x = 0, y = 0 }
    local mainCatSettings = db.categorySettings and db.categorySettings.main
    local initDirection = (mainCatSettings and mainCatSettings.growDirection)
        or (db.defaults and db.defaults.growDirection)
        or "CENTER"
    local anchor = DIRECTION_ANCHORS[initDirection] or "CENTER"
    local extFrame, extPoint = ResolveAnchorParent("main")
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][initDirection] or anchor
        mainFrame:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
    else
        mainFrame:SetPoint(anchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end
    mainFrame:EnableMouse(false)

    -- Create category frames for grouped display mode
    for _, category in ipairs(CATEGORIES) do
        categoryFrames[category] = CreateCategoryFrame(category)
    end

    -- Pre-create detached container frames for icons detached in saved variables
    if db.detachedIcons then
        for key in pairs(db.detachedIcons) do
            detachedFrames[key] = CreateDetachedFrame(key)
        end
    end

    -- Export frame references for split modules (Movers, SecureButtons)
    BR.Display.mainFrame = mainFrame
    BR.Display.categoryFrames = categoryFrames
    BR.Display.detachedFrames = detachedFrames
    BR.Display.frames = buffFrames

    -- Create mover frames (shown when unlocked for drag positioning)
    BR.Movers.Initialize()

    -- Create buff frames for all categories (including custom, populated by BuildCustomBuffArray)
    for category, buffArray in pairs(BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            buffFrames[buff.key] = CreateBuffFrame(buff, category)
        end
    end

    -- Reparent frames based on split category settings
    ReparentBuffFrames()

    mainFrame:Hide()
end

---Create a frame for a newly added custom buff (called at runtime when adding buffs)
---@param customBuff CustomBuff
local function CreateCustomBuffFrameRuntime(customBuff)
    if not mainFrame then
        return
    end
    local frame = CreateBuffFrame(customBuff, "custom")
    buffFrames[customBuff.key] = frame
    tinsert(CustomBuffs, customBuff)
    -- Only register for glow tracking if glowMode is not disabled
    if customBuff.glowMode ~= "disabled" then
        RegisterGlowBuff(customBuff, "custom")
    end
    -- Wire up click-to-cast for the new frame
    if BR.SecureButtons then
        BR.SecureButtons.UpdateActionButtons("custom")
    end
    -- Force layout recalculation so the caller's UpdateDisplay() repositions
    ResetLayoutSignatures()
end

-- Reparent all buff frames to appropriate parent based on split/detached status
ReparentBuffFrames = function()
    for _, frame in pairs(buffFrames) do
        local key = frame.key
        local category = frame.buffCategory
        if IsIconDetached(key) then
            -- Detached: parent to its own container frame
            if not detachedFrames[key] then
                detachedFrames[key] = CreateDetachedFrame(key)
            end
            frame:SetParent(detachedFrames[key])
            frame:ClearAllPoints()
        elseif category and IsCategorySplit(category) and categoryFrames[category] then
            -- This category is split - parent to its own frame
            frame:SetParent(categoryFrames[category])
            frame:ClearAllPoints()
        else
            -- This category is in main frame
            frame:SetParent(mainFrame)
            frame:ClearAllPoints()
        end
        if frame.extraFrames then
            for _, extra in ipairs(frame.extraFrames) do
                extra:SetParent(frame:GetParent())
            end
        end
    end
end

---Look up which category a buff belongs to. Prefers the live frame's
---buffCategory, falls back to walking BUFF_TABLES (which includes the custom
---array rebuilt at runtime).
---@param key string Buff key or groupId
---@return string? category
local function GetCategoryForBuff(key)
    local frame = buffFrames[key]
    if frame and frame.buffCategory then
        return frame.buffCategory
    end
    for catName, buffArray in pairs(BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            if buff.key == key or buff.groupId == key then
                return catName
            end
        end
    end
    return nil
end

---Resolve a user-facing display name for a buff or buff group.
---Walks: live frame -> custom buffs -> BUFF_TABLES -> BuffGroups -> raw key.
---@param key string Buff key or groupId
---@return string
local function GetBuffDisplayName(key)
    local frame = buffFrames[key]
    if frame and frame.displayName then
        return frame.displayName
    end
    local db = BR.profile
    if db and db.customBuffs and db.customBuffs[key] and db.customBuffs[key].name then
        return db.customBuffs[key].name
    end
    for _, buffArray in pairs(BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            if buff.key == key and buff.name then
                return buff.name
            end
        end
    end
    local group = BR.BuffGroups and BR.BuffGroups[key]
    if group and group.displayName then
        return group.displayName
    end
    return key
end

local DETACH_OFFSET_X = 40
local DETACH_OFFSET_Y = -40

---Compute a sensible default position for a newly-detached icon: the source
---category's saved CENTER-anchored position offset by (40, -40). Falls back
---to the main frame's saved position, then to (0, 0). Keeps detached icons
---from teleporting to absolute screen center where users can't find them.
---@param key string Buff key
---@return number x, number y
local function ComputeSmartDetachPosition(key)
    local db = BR.profile
    local catSettings = db.categorySettings
    local category = GetCategoryForBuff(key)

    local sourcePos
    if category and catSettings and catSettings[category] and catSettings[category].position then
        sourcePos = catSettings[category].position
    elseif catSettings and catSettings.main and catSettings.main.position then
        sourcePos = catSettings.main.position
    end

    local x = (sourcePos and sourcePos.x or 0) + DETACH_OFFSET_X
    local y = (sourcePos and sourcePos.y or 0) + DETACH_OFFSET_Y
    return x, y
end

---Detach an individual icon from its container into its own frame.
---Initial position is offset from the source category so the icon appears
---next to where it came from (not at hidden screen center).
---@param key string Buff key
local function DetachIcon(key)
    local db = BR.profile
    if not db.detachedIcons then
        db.detachedIcons = {}
    end
    local x, y = ComputeSmartDetachPosition(key)
    db.detachedIcons[key] = { position = { x = x, y = y } }
    -- FramesReparent callback handles ResetLayoutSignatures + InvalidateSortedCategories
    -- + ReparentBuffFrames + UpdateVisuals
    BR.CallbackRegistry:TriggerEvent("FramesReparent")
end

---Reset a detached icon's position back to the smart default (source
---category + offset). Preserves any other fields on the entry.
---@param key string Buff key
local function ResetDetachedPosition(key)
    local db = BR.profile
    if not db.detachedIcons or not db.detachedIcons[key] then
        return
    end
    local x, y = ComputeSmartDetachPosition(key)
    db.detachedIcons[key].position = { x = x, y = y }
    BR.CallbackRegistry:TriggerEvent("FramesReparent")
end

---Reattach a detached icon back to its category/main container
---@param key string Buff key
local function ReattachIcon(key)
    local db = BR.profile
    if db.detachedIcons then
        db.detachedIcons[key] = nil
        if not next(db.detachedIcons) then
            db.detachedIcons = nil
        end
    end
    if detachedFrames[key] then
        detachedFrames[key]:Hide()
    end
    BR.CallbackRegistry:TriggerEvent("FramesReparent")
end

---Remove a custom buff frame (called at runtime when deleting buffs)
---@param key string
local function RemoveCustomBuffFrame(key)
    local frame = buffFrames[key]
    if frame then
        UnregisterGlowSpell(frame.spellIDs)
        -- Clean up click overlay (unregister state driver before hiding)
        if frame.clickOverlay and not InCombatLockdown() then
            UnregisterStateDriver(frame.clickOverlay, "visibility")
            frame.clickOverlay:EnableMouse(false)
            frame.clickOverlay:Hide()
            frame.clickOverlay = nil
        end
        -- Clean up action buttons
        if frame.actionButtons and not InCombatLockdown() then
            for _, btn in ipairs(frame.actionButtons) do
                UnregisterStateDriver(btn, "visibility")
                btn:Hide()
            end
            frame.actionButtons = nil
        end
        -- Clean up extra frames and their overlays (prevents orphaned secure frames)
        if frame.extraFrames and not InCombatLockdown() then
            for _, extra in ipairs(frame.extraFrames) do
                if extra.clickOverlay then
                    UnregisterStateDriver(extra.clickOverlay, "visibility")
                    extra.clickOverlay:EnableMouse(false)
                    extra.clickOverlay:Hide()
                    extra.clickOverlay = nil
                end
                extra:Hide()
            end
            frame.extraFrames = nil
        end
        frame:Hide()
        frame:SetParent(nil)
        buffFrames[key] = nil
    end
    -- Clean up detached state
    local db = BR.profile
    if db.detachedIcons then
        db.detachedIcons[key] = nil
    end
    if detachedFrames[key] then
        detachedFrames[key]:Hide()
    end
    -- Remove from BUFF_TABLES.custom array
    for i = #CustomBuffs, 1, -1 do
        if CustomBuffs[i].key == key then
            tremove(CustomBuffs, i)
            break
        end
    end
    -- Force layout recalculation so the caller's UpdateDisplay() reclaims the slot
    ResetLayoutSignatures()
end

-- Export custom buff management for Options.lua
BR.CustomBuffs = {
    CreateRuntime = CreateCustomBuffFrameRuntime,
    Remove = RemoveCustomBuffFrame,
    UpdateFrame = function(key, spellIDValue, displayName)
        local frame = buffFrames[key]
        if frame then
            -- Re-register glow lookup with new spellID (unregister old, then conditionally re-register)
            UnregisterGlowSpell(frame.spellIDs)
            local texture = GetBuffTexture(spellIDValue)
            if texture then
                frame.icon:SetTexture(texture)
            end
            frame.displayName = displayName
            frame.spellIDs = spellIDValue
            -- Rebuild array (dialog creates a new object for db.customBuffs[key], staling the old ref)
            BuildCustomBuffArray()
            local customBuff = BR.profile and BR.profile.customBuffs and BR.profile.customBuffs[key]
            if customBuff then
                -- Update frame's buffDef reference so click actions pick up new fields
                frame.buffDef = customBuff
                if customBuff.glowMode ~= "disabled" then
                    RegisterGlowBuff(customBuff, "custom")
                end
            end
            -- Refresh click-to-cast overlays with updated action fields
            if BR.SecureButtons then
                BR.SecureButtons.UpdateActionButtons("custom")
            end
        end
    end,
}

-- Update icon sizes and text (called when settings change)
local function UpdateVisuals()
    for _, frame in pairs(buffFrames) do
        -- Use effective category settings (split category or "main")
        local effectiveCat = GetEffectiveCategory(frame)
        local catSettings = GetCategorySettings(effectiveCat)
        local size = catSettings.iconSize or 64
        local width = GetEffectiveWidth(catSettings.iconWidth, size)
        frame:SetSize(width, size)
        frame.count:SetFont(fontPath, GetFrameFontSize(frame, 1), outlineFlag)

        -- Re-anchor text overlays on every VisualsRefresh so config changes
        -- take effect immediately.
        do
            local cz, cx, cy = BR.TextPositions.Get("count")
            BR.TextPositions.Apply(frame.count, frame, cz, cx, cy)
        end
        if frame.stackCount then
            local sz, sx, sy = BR.TextPositions.Get("stackCount")
            BR.TextPositions.Apply(frame.stackCount, frame, sz, sx, sy)
        end

        -- Text color and alpha
        local tc = catSettings.textColor or { 1, 1, 1 }
        local ta = catSettings.textAlpha or 1
        frame.count:SetTextColor(tc[1], tc[2], tc[3], ta)

        -- Frame alpha
        frame:SetAlpha(catSettings.iconAlpha or 1)

        -- Consumable overlay font/size + reposition (per-category zones)
        if frame.statLabel or frame.badgeLabel or frame.qualityIcon then
            local flSize = BR.SecureButtons.ComputeConsumableFontSize(size)
            if frame.statLabel then
                frame.statLabel:SetFont(fontPath, flSize, outlineFlag)
                local sz, sx, sy = BR.TextPositions.Get("statLabel")
                BR.TextPositions.Apply(frame.statLabel, frame, sz, sx, sy)
            end
            if frame.badgeLabel then
                frame.badgeLabel:SetFont(fontPath, flSize, outlineFlag)
                local bz, bx, by = BR.TextPositions.Get("badge")
                BR.TextPositions.Apply(frame.badgeLabel, frame, bz, bx, by)
            end
            if frame.qualityIcon then
                local qOffset = -floor(size * 0.125)
                local qSize = max(14, floor(size * 0.45))
                frame.qualityIcon:ClearAllPoints()
                frame.qualityIcon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", qOffset, qOffset)
                frame.qualityIcon:SetSize(qSize, qSize)
            end
        end
        if frame.buffText then
            -- Raid BUFF! text
            local raidCs = BR.profile.categorySettings and BR.profile.categorySettings.raid
            frame.buffText:SetFont(
                fontPath,
                (raidCs and raidCs.buffTextSize) or GetFrameFontSize(frame, 0.8),
                outlineFlag
            )
            frame.buffText:SetTextColor(tc[1], tc[2], tc[3], ta)
            local bz, bx, by = BR.TextPositions.Get("buffReminder")
            BR.TextPositions.Apply(frame.buffText, frame, bz, bx, by)
            -- BUFF! text: use buff's actual category (raid only)
            local showReminder = false
            if frame.buffCategory == "raid" then
                showReminder = not raidCs or raidCs.showBuffReminder ~= false
            end
            frame.buffText:SetShown(showReminder)
        end
        UpdateIconStyling(frame, catSettings)

        -- Per-category text visibility
        if not ShouldShowText(frame.buffCategory) then
            frame.count:Hide()
            ClearConsumableOverlays(frame)
        end

        -- Update extra frames (expanded consumable display mode)
        if frame.extraFrames then
            for _, extra in ipairs(frame.extraFrames) do
                extra:SetSize(width, size)
                UpdateIconStyling(extra, catSettings)
                extra:SetAlpha(catSettings.iconAlpha or 1)
            end
        end
    end
    if IsMasqueActive() then
        masqueGroup:ReSkin()
    end
    UpdateDisplay()
end

-- ============================================================================
-- CALLBACK REGISTRY SUBSCRIPTIONS
-- ============================================================================
-- Subscribe to config change events for automatic UI updates.
-- This decouples the options panel from the display system.

local CallbackRegistry = BR.CallbackRegistry

---Reset layout signatures so next UpdateDisplay forces repositioning
ResetLayoutSignatures = function()
    lastMainSignature = ""
    wipe(lastSplitSignatures)
end

-- Visual changes (icon size, zoom, border, text visibility, font)
CallbackRegistry:RegisterCallback("VisualsRefresh", function()
    ResolveFontPath()
    ResolveOutline()
    ResetLayoutSignatures()
    wipe(expiringGlowCache)
    wipe(missingGlowCache)
    UpdateVisuals()
    for _, mover in pairs(BR.Movers.GetMoverFrames()) do
        mover:UpdateSize()
    end
    for _, mover in pairs(BR.Movers.GetDetachedMoverFrames()) do
        mover:UpdateSize()
    end
end)

-- Layout changes (spacing, grow direction)
CallbackRegistry:RegisterCallback("LayoutRefresh", function()
    -- If growth direction changed, convert saved positions so frames stay in place
    BR.Movers.ConvertDirectionPositions()
    ResetLayoutSignatures()
    InvalidateSortedCategories()

    UpdateDisplay()
end)

-- Display changes (enabled buffs, visibility settings, consumable display mode)
CallbackRegistry:RegisterCallback("DisplayRefresh", function()
    ResetLayoutSignatures()
    InvalidateSortedCategories()
    UpdateDisplay()
    -- Refresh consumable action button clickability/visibility after mode changes
    if not InCombatLockdown() then
        BR.SecureButtons.UpdateActionButtons("consumable")
    end
end)

-- Visibility toggles (hide-when, show-only-in-group, pet passive)
CallbackRegistry:RegisterCallback("VisibilityRefresh", function()
    UpdateDisplay()
end)

-- Structural changes (split categories)
CallbackRegistry:RegisterCallback("FramesReparent", function()
    ResetLayoutSignatures()
    InvalidateSortedCategories()
    ReparentBuffFrames()
    UpdateVisuals()
end)

-- Masque skin change callback - restore native styling when Masque is disabled.
-- Deferred because Masque modifies button regions after firing the callback.
if masqueGroup then
    masqueGroup:RegisterCallback(function()
        C_Timer.After(0, function()
            UpdateVisuals()
            BR.Components.RefreshAll()
        end)
    end)
end

-- Export shared references for Options.lua
BR.LSM = LSM

-- Export helpers for Options.lua
BR.Helpers = {
    GetBuffSettingKey = GetBuffSettingKey,
    IsBuffEnabled = IsBuffEnabled,
    GetCategorySettings = GetCategorySettings,
    IsCategorySplit = IsCategorySplit,
    IsIconDetached = IsIconDetached,
    DetachIcon = DetachIcon,
    ReattachIcon = ReattachIcon,
    ResetDetachedPosition = ResetDetachedPosition,
    GetCategoryForBuff = GetCategoryForBuff,
    GetBuffDisplayName = GetBuffDisplayName,
    GetBuffTexture = GetBuffTexture,
    GetBuffIcons = GetBuffIcons,
    ApplyDynamicIcon = ApplyDynamicIcon,
    PreFillIconCaches = PreFillIconCaches,
    DeepCopy = function(...)
        return BR.ImportExport.DeepCopy(...)
    end,
    GetCurrentContentType = BR.StateHelpers.GetCurrentContentType,
    IsCategoryVisibleForContent = BR.StateHelpers.IsCategoryVisibleForContent,
    ValidateSpellID = ValidateSpellID,
    ValidateItemID = ValidateItemID,
    GenerateCustomBuffKey = GenerateCustomBuffKey,
    IsFontPathValid = IsFontPathValid,
    SetBuffSound = function(key, soundName)
        local db = BR.profile
        if soundName then
            if not db.buffSounds then
                db.buffSounds = {}
            end
            db.buffSounds[key] = soundName
        elseif db.buffSounds then
            db.buffSounds[key] = nil
            if not next(db.buffSounds) then
                db.buffSounds = nil
            end
        end
    end,
}

-- Toggle lock state: when unlocked, show mover frames for dragging
local function ToggleLock()
    local db = BR.profile
    db.locked = not db.locked
    if db.locked then
        BR.Movers.HideAll()
    else
        BR.Movers.UpdateAnchor()
    end
    return db.locked
end

-- Export display functions for Options.lua
BR.Display.Update = UpdateDisplay
BR.Display.ToggleTestMode = ToggleTestMode
BR.Display.ToggleLock = ToggleLock
BR.Display.UpdateVisuals = UpdateVisuals
BR.Display.UpdateActionButtons = function(category)
    return BR.SecureButtons.UpdateActionButtons(category)
end
BR.Display.IsPetDismountSuppressed = function()
    return petDismountSuppressed
end
BR.Display.IsTestMode = function()
    return testMode
end
BR.Display.ResetCategoryFramePosition = function(category, x, y)
    -- Clear any external anchor so the frame returns to default UIParent positioning
    local db = BR.profile
    if db.categorySettings and db.categorySettings[category] then
        db.categorySettings[category].anchorFrame = nil
        db.categorySettings[category].anchorPoint = nil
    end
    BR.Movers.SavePosition(category, x or 0, y or 0)
    BR.CallbackRegistry:TriggerEvent("LayoutRefresh")
end
BR.Display.IsSpellGlowing = function(spellID)
    return glowingSpells[spellID] == true
end

-- Export Masque state for Options.lua
BR.Masque = {
    IsActive = function()
        return masqueGroup ~= nil and not masqueGroup.db.Disabled
    end,
}

-- Slash command handler
local function SlashHandler(msg)
    local cmd = msg:match("^(%S*)") or ""
    cmd = cmd:lower()

    if cmd == "test" then
        ToggleTestMode()
    elseif cmd == "lock" then
        BR.profile.locked = true
        BR.Movers.HideAll()
        BR.Components.RefreshAll()
        print("|cff00ccffBuffReminders:|r " .. L["Display.FramesLocked"])
    elseif cmd == "unlock" then
        BR.profile.locked = false
        BR.Movers.UpdateAnchor()
        BR.Components.RefreshAll()
        print("|cff00ccffBuffReminders:|r " .. L["Display.FramesUnlocked"])
    elseif cmd == "minimap" then
        BR.aceDB.global.minimap.hide = not BR.aceDB.global.minimap.hide
        if BR.MinimapButton then
            if BR.aceDB.global.minimap.hide then
                BR.MinimapButton.Icon:Hide("BuffReminders")
                print("|cff00ccffBuffReminders:|r " .. L["Display.MinimapHidden"])
            else
                BR.MinimapButton.Icon:Show("BuffReminders")
                print("|cff00ccffBuffReminders:|r " .. L["Display.MinimapShown"])
            end
        end
        BR.Components.RefreshAll()
    elseif cmd == "debug" then
        BR.profile.debugMode = not BR.profile.debugMode
        if BR.profile.debugMode then
            print("|cff00ccffBuffReminders:|r " .. L["Display.DebugEnabled"])
        else
            print("|cff00ccffBuffReminders:|r " .. L["Display.DebugDisabled"])
        end
    else
        BR.Options.Toggle()
    end
end

-- Event handler
eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GROUP_FORMED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_FLAGS")
eventFrame:RegisterEvent("UNIT_CONNECTION")
eventFrame:RegisterEvent("UNIT_PHASE")
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("PET_BAR_UPDATE")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("PET_STABLE_UPDATE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UPDATE_EXPANSION_LEVEL")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")

ClearInstanceEntryState = function()
    if instanceEntryTimer then
        instanceEntryTimer:Cancel()
        instanceEntryTimer = nil
    end
    BR.BuffState.SetInstanceEntryState(false)
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_START")
end

ClearDelveEntryState = function()
    if delveEntryTimer then
        delveEntryTimer:Cancel()
        delveEntryTimer = nil
    end
    BR.BuffState.SetDelveEntryState(false)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == addonName then
        _, playerClass = UnitClass("player")
        local isFirstInstall = not BuffRemindersDB
        if not BuffRemindersDB then
            BuffRemindersDB = {}
        end

        -- ====================================================================
        -- Pre-AceDB migration: convert old formats so AceDB picks up the data
        -- ====================================================================
        if rawget(BuffRemindersDB, "_profiles") then
            -- Custom profile format -> AceDB format (rename underscore keys)
            local p = rawget(BuffRemindersDB, "_profiles")
            local pk = rawget(BuffRemindersDB, "_profileKeys")
            local g = rawget(BuffRemindersDB, "_global")
            rawset(BuffRemindersDB, "profiles", p)
            rawset(BuffRemindersDB, "profileKeys", pk)
            rawset(BuffRemindersDB, "global", g)
            rawset(BuffRemindersDB, "_profiles", nil)
            rawset(BuffRemindersDB, "_profileKeys", nil)
            rawset(BuffRemindersDB, "_global", nil)
        elseif not rawget(BuffRemindersDB, "profiles") then
            -- Old flat format -> AceDB format
            local profileData, globalData = {}, {}
            for k, v in pairs(BuffRemindersDB) do
                if k == "minimap" then
                    globalData[k] = v
                else
                    profileData[k] = v
                end
            end
            wipe(BuffRemindersDB)
            rawset(BuffRemindersDB, "profiles", { ["Default"] = profileData })
            rawset(BuffRemindersDB, "profileKeys", {})
            rawset(BuffRemindersDB, "global", globalData)
        end

        -- Build AceDB defaults (minimap is global, everything else is per-profile)
        local aceDefaults = {
            profile = {},
            global = { minimap = defaults.minimap },
        }
        for k, v in pairs(defaults) do
            if k ~= "minimap" then
                aceDefaults.profile[k] = v
            end
        end

        -- Initialize AceDB + profile proxy
        BR.Profiles.Initialize(aceDefaults)

        -- Deep copy default values for missing keys (skips 'defaults' sub-table, served by metatable)
        local function DeepCopyDefault(source, target)
            for k, v in pairs(source) do
                if k == "minimap" then -- luacheck: ignore 542
                    -- Skip: lives in AceDB global, not per-profile
                elseif k == "defaults" then
                    -- Skip value copy (served by metatable __index), but ensure the table exists
                    if target[k] == nil then
                        target[k] = {}
                    end
                elseif target[k] == nil then
                    if type(v) == "table" then
                        target[k] = {}
                        DeepCopyDefault(v, target[k])
                    else
                        target[k] = v
                    end
                elseif type(v) == "table" and type(target[k]) == "table" then
                    -- Recursively fill in missing nested keys
                    DeepCopyDefault(v, target[k])
                end
            end
        end

        -- Export functions for profile switch refresh
        BR.Display.DeepCopyDefault = DeepCopyDefault
        BR.Display.BuildCustomBuffArray = BuildCustomBuffArray

        local db = BR.profile

        -- ====================================================================
        -- Versioned migrations - each runs exactly once, tracked by dbVersion
        -- ====================================================================
        local DB_VERSION = 42

        local migrations = {
            -- [1] Consolidate all pre-versioning migrations (v2.8 -> v3.x)
            [1] = function()
                -- Ensure db.defaults exists (DeepCopyDefault hasn't run yet)
                if not db.defaults then
                    db.defaults = {}
                end

                -- Migrate from old schema to new schema (v3.0 migration)
                local isOldSchema = db.iconSize ~= nil
                    or db.spacing ~= nil
                    or db.growDirection ~= nil
                    or db.showExpirationGlow ~= nil
                if isOldSchema then
                    -- Migrate global appearance settings to defaults
                    db.defaults.iconSize = db.iconSize or defaults.defaults.iconSize
                    db.defaults.spacing = db.spacing or defaults.defaults.spacing
                    db.defaults.growDirection = db.growDirection or defaults.defaults.growDirection
                    -- Migrate global behavior settings to defaults
                    db.defaults.showExpirationGlow = db.showExpirationGlow ~= false
                    db.defaults.expirationThreshold = db.expirationThreshold or defaults.defaults.expirationThreshold
                    db.defaults.glowStyle = db.glowStyle or 1
                    -- Clean up old root-level keys
                    db.iconSize = nil
                    db.spacing = nil
                    db.growDirection = nil
                end

                -- Migrate splitCategories to categorySettings.{cat}.split
                if db.splitCategories then
                    for cat, isSplit in pairs(db.splitCategories) do
                        if not db.categorySettings then
                            db.categorySettings = {}
                        end
                        if not db.categorySettings[cat] then
                            db.categorySettings[cat] = {}
                        end
                        db.categorySettings[cat].split = isSplit
                    end
                    db.splitCategories = nil
                end

                -- Migrate old categorySettings with appearance values to use useCustomAppearance
                if isOldSchema and db.categorySettings then
                    for cat, catSettings in pairs(db.categorySettings) do
                        if cat ~= "main" and catSettings.iconSize then
                            catSettings.useCustomAppearance = catSettings.split == true
                        end
                    end
                end

                -- Migrate root-level showBuffReminder to raid category (v2.8.1 users)
                if db.showBuffReminder ~= nil then
                    if db.categorySettings and db.categorySettings.raid then
                        db.categorySettings.raid.showBuffReminder = db.showBuffReminder
                    end
                end

                -- Migrate: remove useCustomBehavior, per-category glow, consolidate showBuffReminder
                if db.categorySettings then
                    for cat, catSettings in pairs(db.categorySettings) do
                        if cat ~= "main" then
                            if cat == "raid" then
                                if catSettings.useCustomBehavior == false and catSettings.showBuffReminder == nil then
                                    catSettings.showBuffReminder = db.defaults and db.defaults.showBuffReminder ~= false
                                end
                            else
                                catSettings.showBuffReminder = nil
                            end
                            catSettings.useCustomBehavior = nil
                            catSettings.showExpirationGlow = nil
                            catSettings.expirationThreshold = nil
                            catSettings.glowStyle = nil
                        end
                    end
                end

                -- Migrate legacy root-level glow settings to defaults
                if db.showExpirationGlow ~= nil then
                    db.defaults.showExpirationGlow = db.showExpirationGlow
                    db.showExpirationGlow = nil
                end
                if db.expirationThreshold ~= nil then
                    db.defaults.expirationThreshold = db.expirationThreshold
                    db.expirationThreshold = nil
                end
                if db.glowStyle ~= nil then
                    db.defaults.glowStyle = db.glowStyle
                    db.glowStyle = nil
                end

                -- Remove showBuffReminder from defaults (now per-category raid-only)
                if db.defaults then
                    db.defaults.showBuffReminder = nil
                end
                db.showBuffReminder = nil

                -- Remove showOnlyInInstance (replaced by per-category W/S/D/R visibility toggles)
                db.showOnlyInInstance = nil

                -- Ensure categorySettings.main exists
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings.main then
                    db.categorySettings.main = {}
                end

                -- Migrate old position to categorySettings.main.position
                if db.position and not db.categorySettings.main.position then
                    db.categorySettings.main.position = {
                        point = db.position.point,
                        x = db.position.x,
                        y = db.position.y,
                    }
                end
            end,

            -- [2] Strip db.defaults keys matching code defaults (enable metatable inheritance)
            [2] = function()
                if db.defaults then
                    for key, value in pairs(db.defaults) do
                        if defaults.defaults[key] ~= nil and value == defaults.defaults[key] then
                            db.defaults[key] = nil
                        end
                    end
                end
            end,

            -- [3] Add pet category (new first-class category for pet summon reminders)
            [3] = function()
                -- Ensure categorySettings.pet exists with defaults
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings.pet then
                    db.categorySettings.pet = {}
                end
                -- Ensure categoryVisibility.pet exists
                if not db.categoryVisibility then
                    db.categoryVisibility = {}
                end
                if not db.categoryVisibility.pet then
                    db.categoryVisibility.pet = {
                        openWorld = true,
                        dungeon = true,
                        scenario = true,
                        raid = true,
                    }
                end
            end,

            -- [4] Remove useGlowFallback (glow fallback is now always enabled)
            [4] = function()
                db.useGlowFallback = nil
            end,

            -- [5] Remove vestigial db.position (now fully in categorySettings.main.position)
            [5] = function()
                if db.position then
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings.main then
                        db.categorySettings.main = {}
                    end
                    if not db.categorySettings.main.position then
                        db.categorySettings.main.position = {
                            x = db.position.x or 0,
                            y = db.position.y or 0,
                        }
                    end
                    db.position = nil
                end
            end,

            -- [6] Add sensible difficulty defaults for consumables (mythic only, no LFR)
            [6] = function()
                if not db.categoryVisibility then
                    return
                end
                local vis = db.categoryVisibility.consumable
                if not vis then
                    return
                end
                -- Add dungeon difficulty defaults (mythic only) if not already set
                if not vis.dungeonDifficulty then
                    vis.dungeonDifficulty = {
                        normal = false,
                        heroic = false,
                        mythic = true,
                        mythicPlus = false,
                        timewalking = false,
                        follower = false,
                    }
                end
                -- Add raid difficulty defaults (no LFR) if not already set
                if not vis.raidDifficulty then
                    vis.raidDifficulty = {
                        lfr = false,
                        normal = true,
                        heroic = true,
                        mythic = true,
                    }
                end
            end,

            -- [7] Rename custom buff specId -> requireSpecId (unify with built-in buff field names)
            [7] = function()
                if db.customBuffs then
                    for _, customBuff in pairs(db.customBuffs) do
                        if customBuff.specId ~= nil then
                            customBuff.requireSpecId = customBuff.specId
                            customBuff.specId = nil
                        end
                    end
                end
            end,

            -- [8] Seed pre-configured Burning Rush custom buff (disabled by default)
            [8] = function()
                if not db.customBuffs then
                    db.customBuffs = {}
                end
                local key = "burningRush"
                if not db.customBuffs[key] then
                    db.customBuffs[key] = {
                        spellID = 111400,
                        key = key,
                        name = "Burning Rush",
                        overlayText = "",
                        class = "WARLOCK",
                        showWhenPresent = true,
                    }
                end
                if not db.enabledBuffs then
                    db.enabledBuffs = {}
                end
                if db.enabledBuffs[key] == nil then
                    db.enabledBuffs[key] = false
                end
            end,

            -- [9] Fix consumable dungeon difficulty default: mythic not M+
            [9] = function()
                local vis = db.categoryVisibility and db.categoryVisibility.consumable
                if not vis or not vis.dungeonDifficulty then
                    return
                end
                local dd = vis.dungeonDifficulty
                -- Only fix if the user still has the old wrong defaults (M+ on, mythic off)
                if dd.mythicPlus == true and dd.mythic == false then
                    dd.mythic = true
                    dd.mythicPlus = false
                end
            end,

            -- [10] Clean up consumableItems (no longer user-configured; bag scanning replaces manual config)
            [10] = function()
                db.consumableItems = nil
            end,

            -- [11] Migrate showOnlyPlayerClassBuff/showOnlyPlayerMissing to buffTrackingMode
            [11] = function()
                local classBuff = db.showOnlyPlayerClassBuff
                local playerMissing = db.showOnlyPlayerMissing
                if classBuff then
                    db.buffTrackingMode = "my_buffs"
                elseif playerMissing then
                    db.buffTrackingMode = "personal"
                else
                    db.buffTrackingMode = "all"
                end
                -- Clean up old keys
                db.showOnlyPlayerClassBuff = nil
                db.showOnlyPlayerMissing = nil
            end,
            -- [12] Migrate glowStyle (1-5 color variants) to glowType + glowColor (LibCustomGlow)
            [12] = function()
                if not db.defaults then
                    return
                end
                local oldStyle = db.defaults.glowStyle
                if oldStyle ~= nil then
                    -- All old styles were atlas-based pulsing -> map to Pixel glow with the color
                    local colorMap = {
                        [1] = { 0.95, 0.57, 0.07, 1 }, -- Orange
                        [2] = { 1, 0.82, 0, 1 }, -- Gold
                        [3] = { 1, 0.8, 0, 1 }, -- Yellow
                        [4] = { 0.9, 0.9, 0.9, 1 }, -- White
                        [5] = { 1, 0.2, 0.2, 1 }, -- Red
                    }
                    db.defaults.glowType = 1 -- Pixel (closest to old atlas pulsing)
                    db.defaults.glowColor = colorMap[oldStyle] or { 0.95, 0.57, 0.07, 1 }
                    db.defaults.glowStyle = nil
                end
            end,
            -- [13] Unify consumable rebuff warning into per-category expiration glow
            [13] = function()
                if not db.defaults then
                    return
                end
                local defs = db.defaults
                local globalThreshold = defs.expirationThreshold or 15

                -- Migrate consumableRebuffWarning = false -> per-category override
                if defs.consumableRebuffWarning == false then
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings.consumable then
                        db.categorySettings.consumable = {}
                    end
                    db.categorySettings.consumable.useCustomAppearance = true
                    db.categorySettings.consumable.showExpirationGlow = false
                end

                -- Migrate consumableRebuffThreshold if different from global
                if defs.consumableRebuffThreshold ~= nil and defs.consumableRebuffThreshold ~= globalThreshold then
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings.consumable then
                        db.categorySettings.consumable = {}
                    end
                    db.categorySettings.consumable.useCustomAppearance = true
                    db.categorySettings.consumable.expirationThreshold = defs.consumableRebuffThreshold
                end

                -- Clean up old keys
                defs.consumableRebuffWarning = nil
                defs.consumableRebuffThreshold = nil
                defs.consumableRebuffColor = nil
            end,
            -- [14] Tie growDirection to useCustomAppearance (was previously tied to split)
            [14] = function()
                if not db.categorySettings then
                    return
                end
                local gd = db.defaults or {}
                for _, catSettings in pairs(db.categorySettings) do
                    -- Users who had split + custom direction but no custom appearance
                    -- would lose their direction setting without this migration
                    if
                        catSettings.split
                        and catSettings.growDirection ~= nil
                        and not catSettings.useCustomAppearance
                    then
                        catSettings.useCustomAppearance = true
                        -- Snapshot current global defaults so the category is fully independent
                        if catSettings.iconSize == nil then
                            catSettings.iconSize = gd.iconSize or 64
                        end
                        if catSettings.spacing == nil then
                            catSettings.spacing = gd.spacing or 0.2
                        end
                        if catSettings.iconZoom == nil then
                            catSettings.iconZoom = gd.iconZoom or 8
                        end
                        if catSettings.borderSize == nil then
                            catSettings.borderSize = gd.borderSize or 2
                        end
                        if catSettings.iconAlpha == nil then
                            catSettings.iconAlpha = gd.iconAlpha or 1
                        end
                        if catSettings.textAlpha == nil then
                            catSettings.textAlpha = gd.textAlpha or 1
                        end
                        if catSettings.textColor == nil and gd.textColor then
                            local tc = gd.textColor
                            catSettings.textColor = { tc[1], tc[2], tc[3] }
                        end
                    end
                end
            end,
            -- [15] Migrate invertGlow boolean to glowMode enum
            [15] = function()
                if not db.customBuffs then
                    return
                end
                for _, buff in pairs(db.customBuffs) do
                    if buff.invertGlow then
                        buff.glowMode = "whenNotGlowing"
                    end
                    buff.invertGlow = nil
                end
            end,
            -- [16] Migrate glow color: old orange default -> new yellow default,
            -- and auto-enable useCustomGlowColor for users who had a custom color
            [16] = function()
                local oldOrange = { 0.95, 0.57, 0.07, 1 }
                local newDefault = BR.Glow.DEFAULT_COLOR
                local function isOldOrange(c)
                    return c and c[1] == oldOrange[1] and c[2] == oldOrange[2] and c[3] == oldOrange[3]
                end
                if db.defaults and db.defaults.glowColor then
                    if isOldOrange(db.defaults.glowColor) then
                        db.defaults.glowColor = { newDefault[1], newDefault[2], newDefault[3], newDefault[4] }
                    else
                        db.defaults.useCustomGlowColor = true
                    end
                end
                if db.categorySettings then
                    for _, catSettings in pairs(db.categorySettings) do
                        if catSettings.glowColor then
                            if isOldOrange(catSettings.glowColor) then
                                catSettings.glowColor = { newDefault[1], newDefault[2], newDefault[3], newDefault[4] }
                            else
                                catSettings.useCustomGlowColor = true
                            end
                        end
                    end
                end
            end,

            -- [17] Migrate showOnlyOnReadyCheck from global to per-category
            [17] = function()
                if db.showOnlyOnReadyCheck then
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    for _, cat in ipairs({ "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }) do
                        if not db.categorySettings[cat] then
                            db.categorySettings[cat] = {}
                        end
                        db.categorySettings[cat].showOnlyOnReadyCheck = true
                    end
                end
                db.showOnlyOnReadyCheck = nil
                db.readyCheckDuration = nil
            end,

            -- [18] Add housing = false to existing categoryVisibility entries
            [18] = function()
                if db.categoryVisibility then
                    for _, cat in ipairs({ "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }) do
                        local vis = db.categoryVisibility[cat]
                        if vis and vis.housing == nil then
                            vis.housing = false
                        end
                    end
                end
            end,

            -- [19] Custom buffs now use per-buff loadConditions; migrate category-level custom visibility
            [19] = function()
                -- Carry over old category-level settings to each existing custom buff
                local oldVis = db.categoryVisibility and db.categoryVisibility.custom
                local oldReadyCheck = db.categorySettings
                    and db.categorySettings.custom
                    and db.categorySettings.custom.showOnlyOnReadyCheck
                if db.customBuffs then
                    for _, buff in pairs(db.customBuffs) do
                        if not buff.loadConditions then
                            -- Migrate from category visibility or use old defaults
                            local lc = {}
                            if oldVis then
                                -- Preserve user's per-content-type choices
                                for _, key in ipairs({ "openWorld", "scenario", "dungeon", "raid", "housing" }) do
                                    if oldVis[key] == false then
                                        lc[key] = false
                                    end
                                end
                                if oldVis.dungeonDifficulty then
                                    lc.dungeonDifficulty = {}
                                    for dk, dv in pairs(oldVis.dungeonDifficulty) do
                                        lc.dungeonDifficulty[dk] = dv
                                    end
                                end
                                if oldVis.raidDifficulty then
                                    lc.raidDifficulty = {}
                                    for dk, dv in pairs(oldVis.raidDifficulty) do
                                        lc.raidDifficulty[dk] = dv
                                    end
                                end
                            else
                                -- No custom visibility was set; apply old default (housing off)
                                lc.housing = false
                            end
                            if oldReadyCheck then
                                lc.readyCheckOnly = true
                            end
                            -- Only store if any value is non-default
                            if next(lc) then
                                buff.loadConditions = lc
                            end
                        end
                    end
                end
                -- Clean up category-level keys
                if db.categoryVisibility then
                    db.categoryVisibility.custom = nil
                end
                if db.categorySettings and db.categorySettings.custom then
                    db.categorySettings.custom.showOnlyOnReadyCheck = nil
                end
            end,

            -- [20] (no-op, minimap cleanup now handled by DeepCopyDefault skip)
            [20] = function() end,

            -- [21] Enable delve food by default (was opt-in, now opt-out)
            [21] = function()
                if db.enabledBuffs and db.enabledBuffs.delveFood == false then
                    db.enabledBuffs.delveFood = nil
                end
            end,

            -- [22] Default delveFoodOnly to true (show only delve food in delves)
            [22] = function()
                if db.defaults and db.defaults.delveFoodOnly == false then
                    db.defaults.delveFoodOnly = true
                end
            end,

            -- [23] Decouple zoom from base texcoord inset: subtract old base (8) from stored values
            [23] = function()
                if db.defaults and db.defaults.iconZoom then
                    db.defaults.iconZoom = max(0, db.defaults.iconZoom - 8)
                end
                if db.categorySettings then
                    for _, catSettings in pairs(db.categorySettings) do
                        if catSettings.iconZoom then
                            catSettings.iconZoom = max(0, catSettings.iconZoom - 8)
                        end
                    end
                end
            end,

            -- [24] Remove glowWhenMissing (glow is now all-or-nothing) and stale showExpirationReminder
            [24] = function()
                if db.defaults then
                    db.defaults.glowWhenMissing = nil
                    db.defaults.showExpirationReminder = nil
                end
                for _, cat in ipairs(CATEGORIES) do
                    local catSettings = db.categorySettings and db.categorySettings[cat]
                    if catSettings then
                        catSettings.glowWhenMissing = nil
                        catSettings.showExpirationReminder = nil
                    end
                end
            end,
            [25] = function()
                db.instanceEntryReminder = nil
            end,
            -- [26] Rename missingText -> overlayText on saved custom buffs
            [26] = function()
                if db.customBuffs then
                    for _, buff in pairs(db.customBuffs) do
                        if buff.missingText ~= nil and buff.overlayText == nil then
                            buff.overlayText = buff.missingText
                            buff.missingText = nil
                        end
                    end
                end
            end,
            -- [27] Per-category glow is now opt-in via useCustomGlow.
            -- Remove useCustomGlowColor (color swatch is now always active).
            -- Migrate old per-category glow keys: if a category had any glow overrides,
            -- enable useCustomGlow and keep the values; otherwise clean up.
            [27] = function()
                if db.defaults then
                    if not db.defaults.useCustomGlowColor then
                        db.defaults.glowColor = nil
                    end
                    db.defaults.useCustomGlowColor = nil
                end
                local globalDefaults = db.defaults or {}
                for _, catSettings in pairs(db.categorySettings or {}) do
                    catSettings.useCustomGlowColor = nil
                    -- Check if category had any glow overrides that differ from defaults
                    local hasOverride = false
                    if catSettings.glowType ~= nil and catSettings.glowType ~= globalDefaults.glowType then
                        hasOverride = true
                    end
                    if catSettings.glowSize ~= nil and catSettings.glowSize ~= globalDefaults.glowSize then
                        hasOverride = true
                    end
                    if catSettings.glowColor ~= nil then
                        hasOverride = true
                    end
                    if hasOverride then
                        -- Port old overrides into useCustomGlow system
                        catSettings.useCustomGlow = true
                    else
                        -- No meaningful overrides - clean up stale keys
                        catSettings.glowType = nil
                        catSettings.glowSize = nil
                        catSettings.glowColor = nil
                    end
                end
            end,
            -- [28] Add arena and bg visibility keys for existing users.
            -- Derive from their current dungeon setting; arena forced off for consumable.
            [28] = function()
                if db.categoryVisibility then
                    for cat, vis in pairs(db.categoryVisibility) do
                        if type(vis) == "table" then
                            -- Add pvp toggle, derive from dungeon setting
                            if vis.pvp == nil then
                                vis.pvp = vis.dungeon ~= false
                            end
                            -- Add pvpType sub-table for consumable (arena off)
                            if cat == "consumable" and not vis.pvpType then
                                vis.pvpType = { arena = false, bg = true }
                            end
                            -- Default hideInPvPMatch on for all categories except pet
                            if vis.hideInPvPMatch == nil then
                                vis.hideInPvPMatch = cat ~= "pet"
                            end
                        end
                    end
                end
            end,
            -- [29] Default free consumables (healthstones, permanent runes) to ready-check-only
            -- so they don't show the entire instance.
            [29] = function()
                if db.defaults and db.defaults.freeConsumableReadyCheckOnly == false then
                    db.defaults.freeConsumableReadyCheckOnly = true
                end
            end,
            -- [30] Rename freeConsumableReadyCheckOnly -> healthstoneVisibility (string mode),
            -- and clean up hideInPvPMatch from free consumable visibility.
            [30] = function()
                if db.defaults then
                    local old = db.defaults.freeConsumableReadyCheckOnly
                    if old == true then
                        db.defaults.healthstoneVisibility = "readyCheck"
                    elseif old == false then
                        db.defaults.healthstoneVisibility = "always"
                    end
                    db.defaults.freeConsumableReadyCheckOnly = nil
                    if db.defaults.freeConsumableVisibility then
                        db.defaults.freeConsumableVisibility.hideInPvPMatch = nil
                    end
                end
            end,
            -- [31] Arena consumable restriction now handled at data layer (disabledInCompetitivePvP);
            -- re-enable the arena toggle so healthstones can show via category visibility.
            [31] = function()
                local vis = db.categoryVisibility and db.categoryVisibility.consumable
                if vis and vis.pvpType and vis.pvpType.arena == false then
                    vis.pvpType.arena = true
                end
            end,

            -- [32] Remove sanguithorn tea (reverted by Blizzard)
            [32] = function()
                if db.enabledBuffs then
                    db.enabledBuffs.sanguithorn = nil
                end
                if db.rememberedConsumables then
                    for _, specMem in pairs(db.rememberedConsumables) do
                        if type(specMem) == "table" then
                            specMem.sanguithorn = nil
                        end
                    end
                end
            end,

            -- [33] Clean up stale keys that were previously removed after DeepCopyDefault
            [33] = function()
                db.hidePetWhileMounted = nil
                if db.defaults and db.defaults.textSize == 12 then
                    db.defaults.textSize = nil
                end
            end,
            [34] = function()
                -- Split glow: existing showExpirationGlow controlled both missing + expiring glows.
                -- Copy its value to the new showMissingGlow so users keep their current behavior.
                if db.defaults and db.defaults.showExpirationGlow ~= nil then
                    db.defaults.showMissingGlow = db.defaults.showExpirationGlow
                end
                if db.categorySettings then
                    for _, catSettings in pairs(db.categorySettings) do
                        if catSettings.showExpirationGlow ~= nil then
                            catSettings.showMissingGlow = catSettings.showExpirationGlow
                        end
                    end
                end
            end,
            [35] = function()
                -- Change expiring glow default from Pixel (1) to AutoCast (2).
                -- Migrate users who had the old default so they get the new one.
                if db.defaults then
                    if db.defaults.glowType == nil or db.defaults.glowType == 1 then
                        db.defaults.glowType = 2
                    end
                end
            end,
            [36] = function()
                -- textSize is now an explicit default (20) instead of auto-derived from iconSize.
                -- Materialize the computed value for users who had a non-default iconSize,
                -- so their text size doesn't jump to 20.
                if db.defaults and db.defaults.textSize == nil then
                    local iconSize = db.defaults.iconSize or 64
                    if iconSize ~= 64 then
                        db.defaults.textSize = floor(iconSize * 0.32)
                    end
                end
                if db.categorySettings then
                    for _, cs in pairs(db.categorySettings) do
                        if cs.useCustomAppearance and cs.textSize == nil then
                            local iconSize = cs.iconSize or 64
                            if iconSize ~= 64 then
                                cs.textSize = floor(iconSize * 0.32)
                            end
                        end
                    end
                end
            end,
            [37] = function()
                -- Move Burning Rush from seeded custom buff to proper self-buff
                if db.customBuffs and db.customBuffs.burningRush then
                    db.customBuffs.burningRush = nil
                end
                -- enabledBuffs.burningRush is preserved as-is (same key)

                -- Migrate soulstone readyCheckOnlyOverrides to soulstoneVisibility
                local overrides = db.readyCheckOnlyOverrides
                if overrides and overrides.soulstone == false then
                    if not db.defaults then
                        db.defaults = {}
                    end
                    db.defaults.soulstoneVisibility = "always"
                    overrides.soulstone = nil
                end
            end,
            [38] = function()
                -- Enable "show consumables without items" + "only on ready check" for all users
                if not db.defaults then
                    db.defaults = {}
                end
                db.defaults.showConsumablesWithoutItems = true
                db.defaults.showWithoutItemsOnlyOnReadyCheck = true
            end,

            [39] = function()
                -- Migrate custom buff expiration from category-level to per-buff
                -- Resolve effective threshold: category override > global default > code default (15)
                local catThreshold = 15
                if db.defaults and db.defaults.expirationThreshold then
                    catThreshold = db.defaults.expirationThreshold
                end
                if db.categorySettings and db.categorySettings.custom then
                    local catCustom = db.categorySettings.custom
                    if catCustom.expirationThreshold ~= nil then
                        catThreshold = catCustom.expirationThreshold
                    end
                    -- Clean up category-level expiration keys (no longer used for custom)
                    catCustom.expirationThreshold = nil
                    catCustom.showExpirationGlow = nil
                end
                -- Copy threshold to each existing custom buff that doesn't have one
                if db.customBuffs then
                    for _, buff in pairs(db.customBuffs) do
                        if buff.expirationThreshold == nil then
                            buff.expirationThreshold = catThreshold
                        end
                    end
                end
            end,

            -- [40] Disable druidWrongForm by default (off-by-default new buff;
            -- nested defaults don't reliably merge once a profile has its own
            -- enabledBuffs table, so write the value directly). Also drops the
            -- now-unused legacyConsumablesNoticeShown global flag (replaced by
            -- selfOnlyOutsideNoticeShown).
            [40] = function()
                if not db.enabledBuffs then
                    db.enabledBuffs = {}
                end
                if db.enabledBuffs.druidWrongForm == nil then
                    db.enabledBuffs.druidWrongForm = false
                    db.enabledBuffs.warriorWrongStance = false
                end
                if BR.aceDB and BR.aceDB.global then
                    BR.aceDB.global.legacyConsumablesNoticeShown = nil
                end
            end,

            -- [41] Fold legacy textOffsetX/Y (count) and buffTextOffsetX/Y
            -- (BUFF! reminder) into defaults.textPositions. Text positions are
            -- global only: each repositionable item has one realistic consumer
            -- (buffReminder = raid; statLabel/badge/stackCount = consumable;
            -- count is visually identical across categories), so per-category
            -- granularity was theatre.
            -- BUFF! reminder Y nudge: previously the display added a -6 base
            -- offset on top of buffTextOffsetY. The new BELOW_C zone bakes in
            -- -4, so we preserve total Y by shifting any stored buffTextOffsetY
            -- by -2 during migration.
            [41] = function()
                local function ensurePos(item, zoneFallback)
                    if not db.defaults then
                        db.defaults = {}
                    end
                    if not db.defaults.textPositions then
                        db.defaults.textPositions = {}
                    end
                    if not db.defaults.textPositions[item] then
                        db.defaults.textPositions[item] = { zone = zoneFallback, offsetX = 0, offsetY = 0 }
                    end
                    return db.defaults.textPositions[item]
                end

                -- defaults.textOffsetX/Y -> defaults.textPositions.count
                if db.defaults and (db.defaults.textOffsetX ~= nil or db.defaults.textOffsetY ~= nil) then
                    local pos = ensurePos("count", "INSIDE_C")
                    if db.defaults.textOffsetX ~= nil then
                        pos.offsetX = db.defaults.textOffsetX
                        db.defaults.textOffsetX = nil
                    end
                    if db.defaults.textOffsetY ~= nil then
                        pos.offsetY = db.defaults.textOffsetY
                        db.defaults.textOffsetY = nil
                    end
                end

                -- categorySettings.raid.buffTextOffsetX/Y -> defaults.textPositions.buffReminder
                if db.categorySettings and db.categorySettings.raid then
                    local raidCs = db.categorySettings.raid
                    if raidCs.buffTextOffsetX ~= nil or raidCs.buffTextOffsetY ~= nil then
                        local pos = ensurePos("buffReminder", "BELOW_C")
                        if raidCs.buffTextOffsetX ~= nil then
                            pos.offsetX = raidCs.buffTextOffsetX
                            raidCs.buffTextOffsetX = nil
                        end
                        if raidCs.buffTextOffsetY ~= nil then
                            pos.offsetY = raidCs.buffTextOffsetY - 2
                            raidCs.buffTextOffsetY = nil
                        end
                    end
                end

                -- Drop any per-category text-offset / textPositions data: the
                -- resolver no longer reads from there. Users with custom
                -- appearance overrides lose their per-category nudge (rare).
                if db.categorySettings then
                    for _, cs in pairs(db.categorySettings) do
                        if type(cs) == "table" then
                            cs.textOffsetX = nil
                            cs.textOffsetY = nil
                            cs.textPositions = nil
                        end
                    end
                end
            end,

            -- [42] Enable click-to-cast for targeted buffs by default.
            -- Previous default was false, so existing users inherited "off" without
            -- ever choosing it. Flip to true once; users who turn it back off after
            -- this migration are respected (migrations run once per dbVersion).
            [42] = function()
                if db.categorySettings and db.categorySettings.targeted then
                    db.categorySettings.targeted.clickable = true
                end
            end,
        }

        -- Run pending migrations
        local currentVersion = db.dbVersion or 0
        for version = currentVersion + 1, DB_VERSION do
            if migrations[version] then
                migrations[version]()
            end
        end
        db.dbVersion = DB_VERSION

        -- Deep copy defaults for non-defaults tables
        DeepCopyDefault(defaults, db)

        -- Initialize custom buffs storage and populate BUFF_TABLES.custom
        if not db.customBuffs then
            db.customBuffs = {}
        end
        BuildCustomBuffArray()

        -- Register custom buffs in glow fallback lookup (so they work in M+/combat)
        for _, customBuff in ipairs(CustomBuffs) do
            if customBuff.glowMode ~= "disabled" then
                RegisterGlowBuff(customBuff, "custom")
            end
        end

        -- Set up metatable so db.defaults inherits from code defaults
        if not db.defaults then
            db.defaults = {}
        end
        setmetatable(db.defaults, { __index = defaults.defaults })

        -- Initialize categoryVisibility with defaults for each category
        if not db.categoryVisibility then
            db.categoryVisibility = {}
        end
        for _, category in ipairs(CATEGORIES) do
            if not db.categoryVisibility[category] then
                local defaultVis = defaults.categoryVisibility[category]
                db.categoryVisibility[category] = {
                    openWorld = defaultVis and defaultVis.openWorld ~= false,
                    housing = defaultVis and defaultVis.housing == true,
                    dungeon = defaultVis and defaultVis.dungeon ~= false,
                    scenario = defaultVis and defaultVis.scenario ~= false,
                    raid = defaultVis and defaultVis.raid ~= false,
                    pvp = defaultVis and defaultVis.pvp ~= false,
                    hideInPvPMatch = defaultVis and defaultVis.hideInPvPMatch == true,
                }
            end
        end

        SLASH_BUFFREMINDERS1 = "/br"
        SLASH_BUFFREMINDERS2 = "/buffreminders"
        SlashCmdList["BUFFREMINDERS"] = SlashHandler

        -- Register with WoW's Interface Options
        local settingsPanel = CreateFrame("Frame")
        settingsPanel.name = "BuffReminders"

        local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("BuffReminders")

        local desc = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        desc:SetText(L["Display.Description"])

        local openBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
        openBtn:SetSize(150, 24)
        openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
        openBtn:SetText(L["Display.OpenOptions"])
        openBtn:SetScript("OnClick", function()
            BR.Options.Toggle()
            -- Close the WoW settings panel properly (HideUIPanel handles keyboard focus cleanup)
            if SettingsPanel then
                HideUIPanel(SettingsPanel)
            end
        end)

        local slashInfo = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        slashInfo:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -12)
        slashInfo:SetText(L["Display.SlashCommands"])

        local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
        Settings.RegisterAddOnCategory(category)

        -- Minimap button (LibDBIcon)
        local LDB = LibStub("LibDataBroker-1.1", true)
        local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
        if LDB and LDBIcon then
            local dataObj = LDB:NewDataObject("BuffReminders", {
                type = "launcher",
                label = "BuffReminders",
                icon = "Interface\\AddOns\\BuffReminders\\icon",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        BR.Options.Toggle()
                    elseif button == "RightButton" then
                        ToggleTestMode()
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine("BuffReminders")
                    tooltip:AddLine(L["Display.MinimapLeftClick"])
                    tooltip:AddLine(L["Display.MinimapRightClick"])
                    local owner = tooltip:GetOwner()
                    if owner and owner:GetParent() == Minimap then
                        tooltip:AddLine("|cFF808080/br minimap|r |cFF808080to toggle this icon|r")
                    end
                end,
            })
            LDBIcon:Register("BuffReminders", dataObj, BR.aceDB.global.minimap)
            LDBIcon:AddButtonToCompartment("BuffReminders")
            BR.MinimapButton = { Icon = LDBIcon, DataObj = dataObj }
        end

        -- Login messages
        C_Timer.After(5, function()
            if isFirstInstall then
                print("|cff00ccffBuffReminders:|r " .. L["Display.LoginFirstInstall"])
            elseif BR.profile.showLoginMessages ~= false and not BR.aceDB.global.selfOnlyOutsideNoticeShown then
                print("|cff00ccffBuffReminders:|r " .. L["Display.LoginSelfOnlyOutside"])
                BR.aceDB.global.selfOnlyOutsideNoticeShown = true
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reset consumable dismiss on instance change
        BR.BuffState.SetConsumablesDismissed(false)
        -- Invalidate caches on zone change (spec may have auto-switched on entry)
        BR.BuffState.InvalidateContentTypeCache()
        BR.BuffState.InvalidateSpellCache()
        BR.BuffState.InvalidateSpecCache()
        BR.BuffState.InvalidateOffHandCache()
        BR.BuffState.InvalidatePetCache()
        BR.BuffState.InvalidateStanceCache()
        -- Sync flags with current state (in case of reload)
        inCombat = InCombatLockdown()
        isResting = IsResting()
        BR.BuffState.SetPlayerLevel(UnitLevel("player"))
        BR.BuffState.SetMaxExpansionLevel(GetMaxLevelForPlayerExpansion())
        BR.BuffState.SetInCombat(inCombat)
        -- Detect PvP prep phase: in a PvP instance but match not yet started.
        -- Used by the `hideInPvPMatch` visibility setting to gate buff display once
        -- the match starts. Aura API is restricted for the whole BG/arena regardless.
        local _, instType = IsInInstance()
        local inPvPZone = instType == "pvp" or instType == "arena"
        local matchState = C_PvP.GetActiveMatchState()
        local isPrep = matchState ~= Enum.PvPMatchState.Engaged
        BR.BuffState.SetPvPPrepPhase(inPvPZone and isPrep)
        BR.BuffState.SetInVehicle(UnitInVehicle("player") == true)
        BR.StateHelpers.ScanEatingState()
        ResolveFontPath()
        ResolveOutline()
        if not mainFrame then
            InitializeFrames()
            -- Initialize action buttons for categories with clickable enabled
            for _, cat in ipairs(CATEGORIES) do
                local cs = BR.profile.categorySettings and BR.profile.categorySettings[cat]
                if (cs and cs.clickable) or cat == "custom" then
                    BR.SecureButtons.UpdateActionButtons(cat)
                end
            end
            -- Refresh Burning Rush icon after spell data settles (green-fire
            -- cosmetic override isn't applied yet at login).
            C_Timer.After(2, RefreshBurningRushIcon)
        end
        BR.SecureButtons.InvalidateConsumableCache()
        -- Instance entry can flip IsInGroup(2) without firing GROUP_ROSTER_UPDATE
        -- (e.g. solo dungeon entry); refresh chat-request prefix here too.
        BR.SecureButtons.RefreshChatRequestMacros()
        SeedGlowingSpells() -- Catch glows that were active before event registration
        if not inCombat then
            StartUpdates()
        end
        -- Delayed update to catch glow events that fire after reload
        C_Timer.After(0.5, SetDirty)
        -- Show showOnInstanceEntry self buffs briefly when entering a dungeon (not M+)
        C_Timer.After(1, function()
            if BR.BuffState.ShouldTriggerDungeonEntry() then
                if instanceEntryTimer then
                    instanceEntryTimer:Cancel()
                end
                BR.BuffState.SetInstanceEntryState(true)
                eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
                eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
                UpdateDisplay()
                instanceEntryTimer = C_Timer.NewTimer(30, function()
                    ClearInstanceEntryState()
                    UpdateDisplay()
                end)
            else
                ClearInstanceEntryState()
            end
            -- Show showOnInstanceEntry consumables briefly when entering a delve
            if BR.BuffState.ShouldTriggerDelveEntry() then
                if delveEntryTimer then
                    delveEntryTimer:Cancel()
                end
                BR.BuffState.SetDelveEntryState(true)
                UpdateDisplay()
                delveEntryTimer = C_Timer.NewTimer(30, function()
                    ClearDelveEntryState()
                    UpdateDisplay()
                end)
            else
                ClearDelveEntryState()
            end
        end)
        -- Refresh custom buff icons after spell data is fully loaded (talent-modified icons)
        -- and warm up the static icon cache for every buff in one pass so the next menu
        -- open / detached-icons render hits the cached path.
        C_Timer.After(1.5, function()
            PreFillIconCaches()
            for key, def in pairs(BR.profile.customBuffs or {}) do
                local frame = buffFrames[key]
                if frame and def.spellID then
                    local texture = GetBuffTexture(def.spellID)
                    if texture then
                        frame.icon:SetTexture(texture)
                    end
                end
            end
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Delves have no loading screen, so PLAYER_ENTERING_WORLD doesn't fire.
        -- GetInstanceInfo() still returns stale data when this event fires,
        -- so defer the cache invalidation + refresh.
        C_Timer.After(0.5, function()
            BR.BuffState.InvalidateContentTypeCache()
            SetDirty()
            -- Trigger delve entry for showOnInstanceEntry consumables (no loading screen on re-entry)
            -- Skip if PLAYER_ENTERING_WORLD already started a timer for this entry
            if BR.BuffState.ShouldTriggerDelveEntry() then
                if not delveEntryTimer then
                    BR.BuffState.SetDelveEntryState(true)
                    UpdateDisplay()
                    delveEntryTimer = C_Timer.NewTimer(30, function()
                        ClearDelveEntryState()
                        UpdateDisplay()
                    end)
                end
            else
                ClearDelveEntryState()
            end
        end)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "GROUP_FORMED" then
        SetDirty("group")
        -- Refresh chat-request macrotext so prefix tracks party↔raid↔instance
        -- transitions. PreClick used to rebuild the macro on each click, but the
        -- secure dispatcher could read a stale value before PreClick's write
        -- propagated, sending to the wrong channel.
        BR.SecureButtons.RefreshChatRequestMacros()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = inEncounter
        BR.BuffState.SetInCombat(inCombat)
        BR.StateHelpers.ScanEatingState()
        BR.SecureButtons.RefreshOverlaySpells()
        StartUpdates()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        BR.BuffState.SetInCombat(true)
        ClearDelveEntryState()
        SetDirty()
    elseif event == "ENCOUNTER_START" then
        inEncounter = true
        inCombat = true
        BR.BuffState.SetInCombat(true)
        ClearDelveEntryState()
        SetDirty()
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        inCombat = inCombat and InCombatLockdown()
        BR.BuffState.SetInCombat(inCombat)
        SetDirty()
    elseif event == "PLAYER_DEAD" then
        HideAllDisplayFrames()
    elseif event == "PLAYER_UNGHOST" then
        SetDirty("full")
    elseif event == "UNIT_AURA" then
        if not IsTrackedDisplayUnit(arg1) then
            return
        end
        if arg1 == "player" then
            BR.StateHelpers.UpdateEatingState(arg2)
            SetDirty("full")
        elseif arg1 == "pet" then
            SetDirty("full")
        else
            SetDirty("group")
        end
    elseif event == "UNIT_FLAGS" or event == "UNIT_CONNECTION" or event == "UNIT_PHASE" then
        if IsTrackedDisplayUnit(arg1) then
            if arg1 == "player" or arg1 == "pet" then
                SetDirty("full")
            else
                SetDirty("group")
            end
        end
    elseif event == "UNIT_PET" then
        if arg1 == "player" then
            BR.BuffState.InvalidatePetCache()
            SetDirty("full")
        end
    elseif event == "PET_BAR_UPDATE" then
        SetDirty()
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        BR.BuffState.InvalidateStanceCache()
        SetDirty()
    elseif event == "PET_STABLE_UPDATE" then
        BR.PetHelpers.InvalidatePetActions()
        SetDirty()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local mounted = IsMounted()
        if wasMounted and not mounted then
            petDismountSuppressed = true
            C_Timer.After(1.5, function()
                petDismountSuppressed = false
                SetDirty()
            end)
        end
        wasMounted = mounted
        SetDirty()
    elseif event == "PLAYER_DIFFICULTY_CHANGED" then
        BR.BuffState.InvalidateContentTypeCache()
        SetDirty()
    elseif event == "PVP_MATCH_STATE_CHANGED" then
        local state = C_PvP.GetActiveMatchState()
        -- Prep phase: anything that isn't Engaged means match isn't active.
        local isPrep = state ~= Enum.PvPMatchState.Engaged
        BR.BuffState.SetPvPPrepPhase(isPrep)
        SetDirty()
    elseif event == "PLAYER_UPDATE_RESTING" then
        isResting = IsResting()
        SetDirty()
    elseif event == "PLAYER_LEVEL_UP" then
        BR.BuffState.SetPlayerLevel(arg1)
        SetDirty()
    elseif event == "UPDATE_EXPANSION_LEVEL" then
        BR.BuffState.SetMaxExpansionLevel(GetMaxLevelForPlayerExpansion())
        SetDirty()
    elseif event == "READY_CHECK" then
        -- Cancel any existing timer
        if readyCheckTimer then
            readyCheckTimer:Cancel()
        end
        BR.BuffState.SetReadyCheckState(true)
        UpdateDisplay() -- user-facing, must be instant
        -- Start timer to reset ready check state
        readyCheckTimer = C_Timer.NewTimer(15, function()
            BR.BuffState.SetReadyCheckState(false)
            readyCheckTimer = nil
            UpdateDisplay() -- must be instant
        end)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = arg1
        glowingSpells[spellID] = true
        SetDirty()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = arg1
        glowingSpells[spellID] = nil
        SetDirty()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 ~= "player" then
            return
        end
        -- Invalidate caches when player changes spec
        BR.BuffState.InvalidateSpellCache()
        BR.BuffState.InvalidateOffHandCache()
        BR.BuffState.InvalidatePetCache()
        BR.BuffState.InvalidateStanceCache()

        BR.PetHelpers.InvalidatePetActions()
        BR.SecureButtons.InvalidateConsumableCache()
        BR.SecureButtons.RefreshOverlaySpells()
        UpdateDisplay() -- cache invalidation + immediate feedback
        -- Spells can become available shortly after spec swap; refresh once more
        C_Timer.After(0.5, function()
            if not InCombatLockdown() then
                BR.SecureButtons.RefreshOverlaySpells()
            end
            SetDirty()
        end)
    elseif event == "TRAIT_CONFIG_UPDATED" then
        -- Invalidate spell cache when talents change (within same spec)
        BR.BuffState.InvalidateSpellCache()
        BR.BuffState.InvalidatePetCache()
        BR.BuffState.InvalidateStanceCache()
        BR.PetHelpers.InvalidatePetActions()
        BR.SecureButtons.RefreshOverlaySpells()
        SetDirty()
    elseif event == "SPELLS_CHANGED" then
        -- Catch delayed spell availability after spec/talent changes (noisy event, keep cheap)
        BR.BuffState.InvalidateSpellCache()
        BR.BuffState.InvalidatePetCache()
        BR.BuffState.InvalidateStanceCache()
        BR.PetHelpers.InvalidatePetActions()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        BR.BuffState.InvalidateItemCache()
        BR.BuffState.InvalidateOffHandCache()

        SetDirty()
    elseif event == "BAG_UPDATE_DELAYED" then
        BR.BuffState.InvalidateItemCache()
        BR.SecureButtons.InvalidateConsumableCache()
        SetDirty()
        BR.SecureButtons.UpdateActionButtons("consumable")
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then
            BR.BuffState.SetInVehicle(event == "UNIT_ENTERED_VEHICLE")
            UpdateDisplay()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
        if SOULWELL_SPELL_IDS[arg3] then
            ClearInstanceEntryState()
            UpdateDisplay()
        end
    end
end)
