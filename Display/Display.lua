local _, BR = ...

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
local LoadoutRules = BUFF_TABLES.loadout

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

---Rebuild BUFF_TABLES.loadout from db.loadoutReminders (preserves table identity via wipe).
---Icons are resolved live (entry.dynamicIcon each refresh, GetRuleIcon in the list)
---rather than cached onto the rule, so nothing derived leaks into SavedVariables.
local function BuildLoadoutRulesArray()
    local db = BR.profile
    -- The rule set itself changed (reload / profile switch / set rename): the cached
    -- per-rule satisfied/icon verdicts may now be keyed to stale definitions.
    BR.BuffState.InvalidateLoadoutCache()
    wipe(LoadoutRules)
    if not db or not db.loadoutReminders then
        return
    end
    local sortedKeys = {}
    for k in pairs(db.loadoutReminders) do
        sortedKeys[#sortedKeys + 1] = k
    end
    tsort(sortedKeys)
    for _, k in ipairs(sortedKeys) do
        LoadoutRules[#LoadoutRules + 1] = db.loadoutReminders[k]
    end
end

-- Get helpers from State.lua
local GetBuffSettingKey = function(buff)
    return BR.StateHelpers.GetBuffSettingKey(buff)
end
local IsBuffEnabled = function(key)
    return BR.StateHelpers.IsBuffEnabled(key)
end

-- Default settings live in Data/Defaults.lua (BR.defaults).
local defaults = BR.defaults

-- Constants
local CODE_DEFAULTS = defaults.defaults
local OVERLAY_TEXT_SCALE = 0.6 -- scale for "NO X" warning text

-- Locals
local mainFrame
local buffFrames = {}
-- Per-category index over buffFrames (category -> key -> frame), so per-category
-- consumers (SecureButtons.UpdateActionButtons runs every display cycle) don't
-- rescan the full frame table. Maintained by Register/UnregisterBuffFrame.
local buffFramesByCategory = {}
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

---Track a buff frame in both the flat table and the per-category index
---@param key string
---@param frame table
---@param category string
local function RegisterBuffFrame(key, frame, category)
    buffFrames[key] = frame
    local bucket = buffFramesByCategory[category]
    if not bucket then
        bucket = {}
        buffFramesByCategory[category] = bucket
    end
    bucket[key] = frame
end

---Remove a buff frame from both the flat table and the per-category index
---@param key string
local function UnregisterBuffFrame(key)
    local frame = buffFrames[key]
    if frame and frame.buffCategory and buffFramesByCategory[frame.buffCategory] then
        buffFramesByCategory[frame.buffCategory][key] = nil
    end
    buffFrames[key] = nil
end

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
local CATEGORIES = BR.CATEGORY_ORDER -- canonical list from Core.lua

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
    loadout = L["Category.Loadout"],
}

-- Export for Options.lua and split modules
BR.CATEGORIES = CATEGORIES
BR.CATEGORY_LABELS = CATEGORY_LABELS

-- Early init of BR.Display for split modules (populated further below and in InitializeFrames)
BR.Display = BR.Display or {}
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

---Build the effective settings table for a category with inheritance from defaults
---@param category string
---@return table A table with all effective settings for this category
local function BuildCategorySettings(category)
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

-- Memo for BuildCategorySettings: it builds a fresh ~15-field table per call but
-- is invoked per frame in render paths (font sizing, secure sync, positioning).
-- Wiped at the start of every UpdateDisplay / UpdateVisuals; every config change
-- reaches one of those through the refresh events, so reads are never stale.
-- Callers treat the returned table as read-only.
local categorySettingsCache = {} ---@type table<string, table>

---Get settings for a category with inheritance from defaults (memoized)
---@param category string
---@return table A table with all effective settings for this category
local function GetCategorySettings(category)
    local settings = categorySettingsCache[category]
    if not settings then
        settings = BuildCategorySettings(category)
        categorySettingsCache[category] = settings
    end
    return settings
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

---The count fontstring multiplexes three kinds of text: missing-buff labels ("NO X"),
---group counts ("17/20"), and live countdowns. Countdowns are duration context that
---always render; only labels and counts are governed by the per-category showText toggle.
---@param entry BuffStateEntry
---@return boolean
local function IsCountdownText(entry)
    return entry.isEating or entry.displayType == "expiring"
end

---Calculate font size from explicit textSize
---@param scale? number
---@param textSize number
---@return number
local function GetFontSize(scale, textSize)
    return max(6, floor(textSize * (scale or 1)))
end

---@class BRFontString: FontString
---@field _br_font_size number?   -- last font size applied via SetFontCached
---@field _br_font_path string?   -- last font path applied via SetFontCached
---@field _br_font_outline string? -- last outline flag applied via SetFontCached

---Apply the shared font (fontPath/outlineFlag) to a fontstring only when
---something actually changed. SetFont forces a full fontstring re-layout, and
---render paths re-apply fonts up to twice per second with unchanged values.
---@param fs BRFontString|FontString
---@param size number
local function SetFontCached(fs, size)
    if fs._br_font_size == size and fs._br_font_path == fontPath and fs._br_font_outline == outlineFlag then
        return
    end
    fs._br_font_size = size
    fs._br_font_path = fontPath
    fs._br_font_outline = outlineFlag
    fs:SetFont(fontPath, size, outlineFlag)
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

-- Icon/texture resolution lives in Display/Icons.lua (BR.Icons); aliased here for hot-path call sites.
local AsSpellList = BR.Icons.AsSpellList
local GetBuffTexture = BR.Icons.GetBuffTexture
local GetBuffIcons = BR.Icons.GetBuffIcons
local PreFillIconCaches = BR.Icons.PreFillIconCaches
local ResolveRoleTexture = BR.Icons.ResolveRoleTexture
local ResolveFrameTexture = BR.Icons.ResolveFrameTexture

---Invalidate the cached texture for a spell ID and re-resolve every buff
---frame whose def uses it. Used after spell data settles to pick up cosmetic
---overrides (e.g. warlock green fire on Burning Rush) that
---C_Spell.GetSpellTexture doesn't return at login time. Consumable frames
---paint bag-item icons per-render and don't reference these spell IDs, so
---they're left alone - no flash.
---@param spellID number
local function InvalidateBuffIconBySpellID(spellID)
    BR.Icons.InvalidateSpell(spellID)
    for _, frame in pairs(buffFrames) do
        local def = frame.buffDef
        if def and frame.icon then
            -- def.spellID is SpellID (number|number[]); match either form so
            -- a future multi-spell buff sharing this ID is also covered.
            local sid = def.spellID
            local matches = sid == spellID
            if not matches and type(sid) == "table" then
                for _, id in ipairs(sid) do
                    if id == spellID then
                        matches = true
                        break
                    end
                end
            end
            if matches then
                def._iconsCache = nil
                local texture = ResolveFrameTexture(frame)
                if texture then
                    frame.icon:SetTexture(texture)
                end
            end
        end
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
        SetFontCached(frame.count, GetFrameFontSize(frame, OVERLAY_TEXT_SCALE))
        frame.count:SetText(overlayText)
        frame.count:Show()
    else
        frame.count:Hide()
    end
    frame:Show()
    SetExpirationGlow(frame, shouldGlow or false, category, cachedGlow)
    return true
end

-- Loadout reminders render the set/talent name below the icon. It's handled like
-- the raid "BUFF!" label: created in CreateBuffFrame, positioned via the shared
-- BELOW-center "buffReminder" text zone, and refreshed in UpdateVisuals. The width
-- caps near the icon so multi-word names wrap (a too-long single word is truncated).
local SUBLABEL_WIDTH_FACTOR = 1.1
local SUBLABEL_FONT_SCALE = 0.8

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

-- Apply mouse interactivity to a buff icon frame. Icons are always click-through
-- (dragging is handled by anchor handles; click-to-cast/chat-requests live on the
-- secure overlays that float above the icon). Raid/presence frames get hover
-- events ONLY when the buff tooltip is opted in - otherwise they stay fully
-- click-through so the world beneath (camera drag, unit clicks) is reachable.
-- Re-called from UpdateVisuals so toggling showBuffTooltips takes effect live.
local function ApplyBuffFrameMouse(frame, category)
    if (category == "raid" or category == "presence") and BR.profile.defaults.showBuffTooltips == true then
        frame:SetMouseClickEnabled(false)
        frame:SetMouseMotionEnabled(true)
        frame:SetScript("OnEnter", function(self)
            ShowBuffSpellTooltip(self)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:EnableMouse(false)
    end
end

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
    SetFontCached(frame.count, GetFontSize(1, catSettings.textSize))

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

    -- Loadout reminders: the set/talent name renders below the icon, handled like
    -- the raid "BUFF!" label (same BELOW-center text zone + UpdateVisuals refresh).
    -- Text is set per render (the name is dynamic); position/font set here.
    if category == "loadout" then
        frame.subLabel = frame:CreateFontString(nil, "OVERLAY")
        frame.subLabel:SetWordWrap(true)
        frame.subLabel:SetJustifyH("CENTER")
        frame.subLabel:SetWidth(iconWidth * SUBLABEL_WIDTH_FACTOR)
        local lz, lx, ly = BR.TextPositions.Get("buffReminder")
        BR.TextPositions.Apply(frame.subLabel, frame, lz, lx, ly)
        frame.subLabel:SetFont(fontPath, GetFontSize(SUBLABEL_FONT_SCALE, catSettings.textSize), outlineFlag)
        frame.subLabel:SetTextColor(textColor[1], textColor[2], textColor[3], textAlpha)
        frame.subLabel:Hide()
    end

    ApplyBuffFrameMouse(frame, category)

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
    SetFontCached(extra.count, GetFontSize(1, catSettings.textSize))
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
        for i, frame in ipairs(mainFrameBuffs) do
            local effectiveCat = GetEffectiveCategory(frame)
            local settings = GetCategorySettings(effectiveCat)
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
        entry.subLabel = nil
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
                    -- consumable, presence, targeted, self, custom, loadout
                    entry.displayType = "text"
                    entry.overlayText = buff.overlayText
                    entry.iconByRole = buff.icons and buff.icons.byRole
                    entry.shouldGlow = missGlowEnabled

                    -- Loadout rules resolve their icon live (no persisted icons table);
                    -- the eval loop sets dynamicIcon + subLabel in real display, so mirror
                    -- that here or the test-mode preview shows a blank icon and no name.
                    if category == "loadout" then
                        entry.dynamicIcon = BR.Loadouts.GetRuleIcon(buff)
                        entry.subLabel = buff.name
                    end

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
        SetFontCached(frame.statLabel, fontSize)
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
            SetFontCached(frame.badgeLabel, fontSize)
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
        SetFontCached(frame.stackCount, cFontSize)
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
                SetFontCached(frame.count, GetFrameFontSize(frame))
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
        SetFontCached(frame.count, GetFrameFontSize(frame))
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

    -- Loadout reminders: the icon shows the "what's wrong" tag; the specific
    -- set/talent name renders below the icon via frame.subLabel (positioned/sized
    -- in CreateBuffFrame + UpdateVisuals, like the raid BUFF! label).
    if frame.subLabel then
        if entry.category == "loadout" and entry.subLabel and ShouldShowText(frame.buffCategory) then
            frame.subLabel:SetText(entry.subLabel)
            frame.subLabel:Show()
        else
            frame.subLabel:Hide()
        end
    end

    -- Per-category text visibility (uses buff's actual category, not effective/main).
    -- Countdowns always stay (see IsCountdownText); labels and counts respect the toggle.
    if not ShouldShowText(frame.buffCategory) and not IsCountdownText(entry) then
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
                SetFontCached(extra.stackCount, cFontSize)
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
                SetFontCached(extra.stackCount, cFontSize)
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

    -- Early out if nothing changed since last call. Zone + offsets are part
    -- of the key so live position edits re-anchor on the next display update.
    local scale = defs.petLabelScale or 100
    local zone, offX, offY = BR.TextPositions.Get("petLabel")
    local cacheKey = format(
        "%s:%s:%s:%d:%s:%s:%s",
        petAction.key,
        petAction.label or "",
        petAction.petFamily or "",
        scale,
        zone,
        tostring(offX),
        tostring(offY)
    )
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
    BR.TextPositions.Apply(frame._br_pet_name_text, frame, zone, offX, offY)
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
-- CONSUMABLE SNOOZE
-- ============================================================================

--- Snooze every consumable reminder until the next loading screen. Driven by the /br snooze
--- command and by right-clicking a consumable icon when consumable click-to-cast is enabled
--- (see Display/SecureButtons.lua, which neutralises the right button's item-use).
function BR.SnoozeConsumables()
    BR.BuffState.SetConsumablesDismissed(true)
    UpdateDisplay()
    print("|cff00ccffBuffReminders:|r " .. L["Display.DismissConsumablesChat"])
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
    wipe(categorySettingsCache)
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

        if BR.BuffState.GetDifficultyID() == DECOR_DUEL_DIFFICULTY_ID then
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

    -- Position main container
    PositionMainContainer(reusableMainBuffs)

    -- Handle split category frames with no visible buffs
    PositionSplitCategories(visibleByCategory)

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

-- Loadout reminders are fixed by a plain (insecure) click: equipping a gear set
-- or opening the talent UI are not protected actions out of combat, so they don't
-- need a SecureActionButton overlay like the click-to-cast categories do.
local function WireLoadoutFrameClick(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        local db = BR.profile
        local rule = db and db.loadoutReminders and db.loadoutReminders[self.key]
        if rule and rule.clickToFix then
            BR.Loadouts.ApplyFix(rule)
        end
    end)
    -- Glass mouseover highlight, matching the click-to-cast overlay (no opt-in).
    if not frame.loadoutHighlight then
        local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(frame.icon)
        highlight:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
        highlight:SetColorTexture(1, 1, 1, 0.2)
        frame.loadoutHighlight = highlight
    end
end

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
    BR.Display.framesByCategory = buffFramesByCategory

    -- Create mover frames (shown when unlocked for drag positioning)
    BR.Movers.Initialize()

    -- Create buff frames for all categories (including custom, populated by BuildCustomBuffArray)
    for category, buffArray in pairs(BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            local frame = CreateBuffFrame(buff, category)
            RegisterBuffFrame(buff.key, frame, category)
            if category == "loadout" then
                WireLoadoutFrameClick(frame)
            end
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
    RegisterBuffFrame(customBuff.key, frame, "custom")
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
        UnregisterBuffFrame(key)
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

---Create a frame for a newly added loadout rule (runtime add from the dialog).
---@param rule LoadoutRule
local function CreateLoadoutRuleFrameRuntime(rule)
    -- Drop any cached verdict for this key: an edited rule reuses its key but may
    -- now require a different set/talent/loadout (invalidate before the mainFrame guard).
    BR.BuffState.InvalidateLoadoutCache()
    if not mainFrame then
        return
    end
    local frame = CreateBuffFrame(rule, "loadout")
    RegisterBuffFrame(rule.key, frame, "loadout")
    WireLoadoutFrameClick(frame)
    tinsert(LoadoutRules, rule)
    -- Keep the runtime array in the same key order BuildLoadoutRulesArray produces
    -- on reload, so an added/edited rule's display order doesn't drift mid-session
    -- (State derives sortOrder from this array's index).
    tsort(LoadoutRules, function(a, b)
        return a.key < b.key
    end)
    ResetLayoutSignatures()
end

---Tear down a loadout rule's frame and drop it from the runtime array.
---@param key string
local function RemoveLoadoutRuleFrame(key)
    BR.BuffState.InvalidateLoadoutCache()
    local frame = buffFrames[key]
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        UnregisterBuffFrame(key)
    end
    local db = BR.profile
    if db.detachedIcons then
        db.detachedIcons[key] = nil
    end
    if detachedFrames[key] then
        detachedFrames[key]:Hide()
    end
    for i = #LoadoutRules, 1, -1 do
        if LoadoutRules[i].key == key then
            tremove(LoadoutRules, i)
            break
        end
    end
    ResetLayoutSignatures()
end

-- Export loadout-rule management for the options dialog/page.
BR.LoadoutReminders = {
    CreateRuntime = CreateLoadoutRuleFrameRuntime,
    Remove = RemoveLoadoutRuleFrame,
    RebuildArray = BuildLoadoutRulesArray,
}

-- Update icon sizes and text (called when settings change)
local function UpdateVisuals()
    wipe(categorySettingsCache)
    for _, frame in pairs(buffFrames) do
        -- Use effective category settings (split category or "main")
        local effectiveCat = GetEffectiveCategory(frame)
        local catSettings = GetCategorySettings(effectiveCat)
        local size = catSettings.iconSize or 64
        local width = GetEffectiveWidth(catSettings.iconWidth, size)
        frame:SetSize(width, size)
        SetFontCached(frame.count, GetFrameFontSize(frame, 1))

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
                SetFontCached(frame.statLabel, flSize)
                local sz, sx, sy = BR.TextPositions.Get("statLabel")
                BR.TextPositions.Apply(frame.statLabel, frame, sz, sx, sy)
            end
            if frame.badgeLabel then
                SetFontCached(frame.badgeLabel, flSize)
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
        if frame.subLabel then
            -- Loadout name label: same treatment as buffText (font / color / zone).
            frame.subLabel:SetFont(fontPath, GetFrameFontSize(frame, SUBLABEL_FONT_SCALE), outlineFlag)
            frame.subLabel:SetTextColor(tc[1], tc[2], tc[3], ta)
            frame.subLabel:SetWidth(width * SUBLABEL_WIDTH_FACTOR)
            local lz, lx, ly = BR.TextPositions.Get("buffReminder")
            BR.TextPositions.Apply(frame.subLabel, frame, lz, lx, ly)
        end
        UpdateIconStyling(frame, catSettings)

        -- Re-apply mouse state so toggling Show Buff Tooltips (raid/presence)
        -- switches between hover-enabled and fully click-through without /reload.
        ApplyBuffFrameMouse(frame, frame.buffCategory)

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
    ApplyDynamicIcon = BR.Icons.ApplyDynamicIcon,
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
-- Builders + registration helpers used by the bootstrap (Core/Bootstrap.lua)
BR.Display.BuildCustomBuffArray = BuildCustomBuffArray
BR.Display.BuildLoadoutRulesArray = BuildLoadoutRulesArray
BR.Display.RegisterGlowBuff = RegisterGlowBuff
BR.Display.SetPlayerClass = function(class)
    playerClass = class
end
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
-- Temporary diagnostic for the DK "Wrong Rune" false-positive reports. Dumps every
-- value that feeds the dkRuneMH / dkRuneOH checks so a user can paste it into an
-- issue. Intentionally not localized (throwaway developer command).
local function PrintRuneDebug()
    local PREFIX = "|cff00ccffBuffReminders rune debug:|r "
    local function line(...)
        print(PREFIX .. table.concat({ ... }, " "))
    end

    local _, class = UnitClass("player")
    line("class =", tostring(class))

    local specId = BR.StateHelpers.GetPlayerSpecId()
    local specName
    if specId then
        specName = select(2, GetSpecializationInfoByID(specId))
    end
    line("specId =", tostring(specId), "(" .. tostring(specName) .. ")")

    local hasOH = BR.BuffState.HasOffHandWeapon()
    line("HasOffHandWeapon =", tostring(hasOH), "| HasShield =", tostring(BR.BuffState.HasShield()))
    line("IsRestricted =", tostring(BR.BuffState.IsRestricted()), "(checks are suppressed when true)")

    -- Refresh so the permanent-enchant accessors reflect the current item links.
    BR.BuffState.Refresh("full")

    -- Enchant name lookup by enchantID from the runeforge table.
    local runeByEnchant = {}
    for _, rune in ipairs(BR.DK_RUNEFORGES) do
        runeByEnchant[rune.enchantID] = BR.GetSpellName(rune.spellID) or rune.key
    end
    local function enchantLabel(id)
        if not id then
            return "none"
        end
        return tostring(id) .. " (" .. (runeByEnchant[id] or "UNKNOWN - not in DK_RUNEFORGES") .. ")"
    end

    -- Raw item links + the value the addon actually parses/uses. Escape the pipe
    -- codes (| -> ||) so the link prints as copyable literal text instead of
    -- rendering as a clickable [Item Name] (which would drop the enchant payload
    -- when the user pastes the output to us).
    local function escapeLink(link)
        if not link then
            return "nil"
        end
        return (link:gsub("|", "||"))
    end
    local mhLink = GetInventoryItemLink("player", 16)
    local ohLink = GetInventoryItemLink("player", 17)
    line("MH link =", escapeLink(mhLink))
    line("OH link =", escapeLink(ohLink))
    line("MH permanent enchant =", enchantLabel(BR.BuffState.GetPermanentWeaponEnchantID(16)))
    line("OH permanent enchant =", enchantLabel(BR.BuffState.GetPermanentWeaponEnchantID(17)))

    -- Temporary weapon enchants (oils/imbues) for completeness - not used by rune check.
    local hasMain, _, _, mainID, hasOff, _, _, offID = GetWeaponEnchantInfo()
    line("temp enchant MH =", tostring(hasMain), tostring(mainID), "| OH =", tostring(hasOff), tostring(offID))

    -- Configured preference buckets for this spec.
    local prefs = BR.profile.dkRunePreferences
    local specPrefs = prefs and specId and prefs[specId]
    local function dumpBucket(name, bucket)
        if not bucket or not next(bucket) then
            line("prefs." .. name, "= (empty)")
            return
        end
        local parts = {}
        for id in pairs(bucket) do
            parts[#parts + 1] = enchantLabel(id)
        end
        line("prefs." .. name, "=", table.concat(parts, ", "))
    end
    if not specPrefs then
        line("dkRunePreferences[specId] = nil (nothing configured for this spec)")
    else
        dumpBucket("mainhand (2H)", specPrefs.mainhand)
        dumpBucket("dw_mainhand", specPrefs.dw_mainhand)
        dumpBucket("dw_offhand", specPrefs.dw_offhand)
    end

    -- Which bucket the MH check resolves to, and the verdict each check would return.
    line("MH check uses bucket:", hasOH and "dw_mainhand" or "mainhand (2H)")
    local mhEntry = BR.BuffState.entries and BR.BuffState.entries.dkRuneMH
    local ohEntry = BR.BuffState.entries and BR.BuffState.entries.dkRuneOH
    line("dkRuneMH visible =", tostring(mhEntry and mhEntry.visible))
    line("dkRuneOH visible =", tostring(ohEntry and ohEntry.visible))
end

local function SlashHandler(msg)
    local cmd = msg:match("^(%S*)") or ""
    cmd = cmd:lower()

    if cmd == "test" then
        ToggleTestMode()
    elseif cmd == "snooze" then
        BR.SnoozeConsumables()
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
    elseif cmd == "runedebug" then
        PrintRuneDebug()
    else
        BR.Options.Toggle()
    end
end

SLASH_BUFFREMINDERS1 = "/br"
SLASH_BUFFREMINDERS2 = "/buffreminders"
SlashCmdList["BUFFREMINDERS"] = SlashHandler

-- Event handler (ADDON_LOADED is owned by Core/Bootstrap.lua)
eventFrame = CreateFrame("Frame")
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
eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
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

-- Event handlers keyed by event name. Bodies are unchanged from the former
-- if/elseif dispatch; each closure keeps the same file-scope upvalue access.
local eventHandlers = {}

eventHandlers.PLAYER_ENTERING_WORLD = function()
    -- Reset consumable dismiss on instance change
    BR.BuffState.SetConsumablesDismissed(false)
    -- Invalidate caches on zone change (spec may have auto-switched on entry)
    BR.BuffState.InvalidateContentTypeCache()
    BR.BuffState.InvalidateSpellCache()
    BR.BuffState.InvalidateSpecCache()
    BR.BuffState.InvalidateOffHandCache()
    BR.BuffState.InvalidatePetCache()
    BR.BuffState.InvalidateStanceCache()
    BR.BuffState.InvalidateLoadoutCache()
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
        -- Re-resolve icons for spells with cosmetic overrides that aren't
        -- applied yet at login (e.g. warlock green fire on Burning Rush).
        -- Covers built-in self buff and custom buffs at the same spellID.
        C_Timer.After(2, function()
            for _, def in ipairs(SelfBuffs) do
                if def.key == "burningRush" then
                    InvalidateBuffIconBySpellID(def.spellID)
                    return
                end
            end
        end)
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
end

eventHandlers.ZONE_CHANGED_NEW_AREA = function()
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
end

eventHandlers.GROUP_ROSTER_UPDATE = function()
    SetDirty("group")
    -- Refresh chat-request macrotext so prefix tracks party↔raid↔instance
    -- transitions. PreClick used to rebuild the macro on each click, but the
    -- secure dispatcher could read a stale value before PreClick's write
    -- propagated, sending to the wrong channel.
    BR.SecureButtons.RefreshChatRequestMacros()
end
eventHandlers.GROUP_FORMED = eventHandlers.GROUP_ROSTER_UPDATE

eventHandlers.PLAYER_REGEN_ENABLED = function()
    inCombat = inEncounter
    BR.BuffState.SetInCombat(inCombat)
    BR.StateHelpers.ScanEatingState()
    BR.SecureButtons.RefreshOverlaySpells()
    StartUpdates()
end

eventHandlers.PLAYER_REGEN_DISABLED = function()
    inCombat = true
    BR.BuffState.SetInCombat(true)
    ClearDelveEntryState()
    SetDirty()
end

eventHandlers.ENCOUNTER_START = function()
    inEncounter = true
    inCombat = true
    BR.BuffState.SetInCombat(true)
    ClearDelveEntryState()
    SetDirty()
end

eventHandlers.ENCOUNTER_END = function()
    inEncounter = false
    inCombat = inCombat and InCombatLockdown()
    BR.BuffState.SetInCombat(inCombat)
    SetDirty()
end

eventHandlers.PLAYER_DEAD = function()
    HideAllDisplayFrames()
end

eventHandlers.PLAYER_UNGHOST = function()
    SetDirty("full")
end

eventHandlers.UNIT_AURA = function(arg1, arg2)
    if not IsTrackedDisplayUnit(arg1) then
        return
    end
    if arg1 == "player" then
        BR.StateHelpers.UpdateEatingState(arg2)
        SetDirty("full")
    elseif arg1 == "pet" then
        SetDirty("full")
    elseif BR.BuffState.GroupAuraUpdateMatters(arg1, arg2) then
        -- Group aura churn is filtered against the tracked spell set: most
        -- payloads (HoTs, procs, debuffs) can't affect the display and skip the
        -- rescan entirely. The 3s fallback ticker bounds anything the filter
        -- can't see (secret values, unrecordable instance IDs).
        SetDirty("group")
    end
end

eventHandlers.UNIT_FLAGS = function(arg1)
    if IsTrackedDisplayUnit(arg1) then
        if arg1 == "player" or arg1 == "pet" then
            SetDirty("full")
        else
            SetDirty("group")
        end
    end
end
eventHandlers.UNIT_CONNECTION = eventHandlers.UNIT_FLAGS
eventHandlers.UNIT_PHASE = eventHandlers.UNIT_FLAGS

eventHandlers.UNIT_PET = function(arg1)
    if arg1 == "player" then
        BR.BuffState.InvalidatePetCache()
        SetDirty("full")
    end
end

eventHandlers.PET_BAR_UPDATE = function()
    SetDirty()
end

eventHandlers.UPDATE_SHAPESHIFT_FORM = function()
    BR.BuffState.InvalidateStanceCache()
    SetDirty()
end
eventHandlers.UPDATE_SHAPESHIFT_FORMS = eventHandlers.UPDATE_SHAPESHIFT_FORM

eventHandlers.PET_STABLE_UPDATE = function()
    BR.PetHelpers.InvalidatePetActions()
    SetDirty()
end

eventHandlers.PLAYER_MOUNT_DISPLAY_CHANGED = function()
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
end

eventHandlers.PLAYER_DIFFICULTY_CHANGED = function()
    BR.BuffState.InvalidateContentTypeCache()
    SetDirty()
end

eventHandlers.PVP_MATCH_STATE_CHANGED = function()
    local state = C_PvP.GetActiveMatchState()
    -- Prep phase: anything that isn't Engaged means match isn't active.
    local isPrep = state ~= Enum.PvPMatchState.Engaged
    BR.BuffState.SetPvPPrepPhase(isPrep)
    SetDirty()
end

eventHandlers.PLAYER_UPDATE_RESTING = function()
    isResting = IsResting()
    SetDirty()
end

eventHandlers.PLAYER_LEVEL_UP = function(arg1)
    BR.BuffState.SetPlayerLevel(arg1)
    SetDirty()
end

eventHandlers.UPDATE_EXPANSION_LEVEL = function()
    BR.BuffState.SetMaxExpansionLevel(GetMaxLevelForPlayerExpansion())
    SetDirty()
end

eventHandlers.READY_CHECK = function()
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
end

eventHandlers.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(arg1)
    local spellID = arg1
    glowingSpells[spellID] = true
    SetDirty()
end

eventHandlers.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(arg1)
    local spellID = arg1
    glowingSpells[spellID] = nil
    SetDirty()
end

eventHandlers.PLAYER_SPECIALIZATION_CHANGED = function(arg1)
    if arg1 ~= "player" then
        return
    end
    -- Invalidate caches when player changes spec
    BR.BuffState.InvalidateSpellCache()
    BR.BuffState.InvalidateOffHandCache()
    BR.BuffState.InvalidatePetCache()
    BR.BuffState.InvalidateStanceCache()
    BR.BuffState.InvalidateLoadoutCache()

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
end

eventHandlers.TRAIT_CONFIG_UPDATED = function()
    -- Invalidate spell cache when talents change (within same spec)
    BR.BuffState.InvalidateSpellCache()
    BR.BuffState.InvalidatePetCache()
    BR.BuffState.InvalidateStanceCache()
    BR.BuffState.InvalidateLoadoutCache()
    BR.PetHelpers.InvalidatePetActions()
    BR.SecureButtons.RefreshOverlaySpells()
    SetDirty()
end

eventHandlers.SPELLS_CHANGED = function()
    -- Catch delayed spell availability after spec/talent changes (noisy event, keep cheap)
    BR.BuffState.InvalidateSpellCache()
    BR.BuffState.InvalidatePetCache()
    BR.BuffState.InvalidateStanceCache()
    BR.BuffState.InvalidateLoadoutCache()
    BR.PetHelpers.InvalidatePetActions()
end

eventHandlers.PLAYER_EQUIPMENT_CHANGED = function()
    BR.BuffState.InvalidateItemCache()
    BR.BuffState.InvalidateOffHandCache()
    BR.BuffState.InvalidateLoadoutCache()

    SetDirty()
end

eventHandlers.EQUIPMENT_SETS_CHANGED = function()
    -- A saved equipment set changed (created / equipped / renamed): re-evaluate
    -- loadout reminders. Icons may have changed too, so rebuild the rule array
    -- (BuildLoadoutRulesArray invalidates the loadout cache).
    BuildLoadoutRulesArray()
    SetDirty()
end

eventHandlers.BAG_UPDATE_DELAYED = function()
    BR.BuffState.InvalidateItemCache()
    BR.SecureButtons.InvalidateConsumableCache()
    SetDirty()
    BR.SecureButtons.UpdateActionButtons("consumable")
end

eventHandlers.UNIT_ENTERED_VEHICLE = function(arg1)
    if arg1 == "player" then
        BR.BuffState.SetInVehicle(true)
        UpdateDisplay()
    end
end
eventHandlers.UNIT_EXITED_VEHICLE = function(arg1)
    if arg1 == "player" then
        BR.BuffState.SetInVehicle(false)
        UpdateDisplay()
    end
end

eventHandlers.UNIT_SPELLCAST_SUCCEEDED = function(_, _, arg3)
    if SOULWELL_SPELL_IDS[arg3] then
        ClearInstanceEntryState()
        UpdateDisplay()
    end
end
eventHandlers.UNIT_SPELLCAST_START = eventHandlers.UNIT_SPELLCAST_SUCCEEDED

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    local handler = eventHandlers[event]
    if handler then
        handler(arg1, arg2, arg3)
    end
end)
