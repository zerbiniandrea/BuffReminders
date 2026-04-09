local _, BR = ...

-- ============================================================================
-- SHARED NAMESPACE
-- ============================================================================
-- This file establishes the BR namespace used by all addon files.
-- It loads first (per TOC order) so other files can access BR.* functions.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@alias CategoryName "raid"|"presence"|"targeted"|"self"|"pet"|"consumable"|"custom"

---@class CategoryPosition
---@field point string
---@field x number
---@field y number

---@class DungeonDifficulty
---@field normal? boolean
---@field heroic? boolean
---@field mythic? boolean
---@field mythicPlus? boolean
---@field timewalking? boolean
---@field follower? boolean

---@class RaidDifficulty
---@field lfr? boolean
---@field normal? boolean
---@field heroic? boolean
---@field mythic? boolean

---@class ScenarioDifficulty
---@field delves? boolean
---@field others? boolean

---@class PvPType
---@field arena? boolean
---@field bg? boolean

---@class ContentVisibility
---@field openWorld boolean
---@field dungeon boolean
---@field scenario boolean
---@field raid boolean
---@field housing boolean
---@field pvp boolean
---@field hideInPvPMatch? boolean
---@field pvpType? PvPType
---@field scenarioDifficulty? ScenarioDifficulty
---@field dungeonDifficulty? DungeonDifficulty
---@field raidDifficulty? RaidDifficulty

---@alias CategoryVisibility table<CategoryName, ContentVisibility>

---@class BuffRemindersDB
---@field dbVersion? integer

-- Component factory table (populated by Components.lua)
BR.Components = {}

-- Registry of refreshable components (for OnShow refresh pattern)
-- Components with a get() function register here automatically
BR.RefreshableComponents = {}

-- ============================================================================
-- SHARED CONSTANTS
-- ============================================================================

BR.TEXCOORD_INSET = 0.08
BR.DEFAULT_BORDER_SIZE = 2
BR.DEFAULT_ICON_ZOOM = 0 -- percentage; base crop (TEXCOORD_INSET) is always applied separately
BR.OPTIONS_BASE_SCALE = 1.2

-- ============================================================================
-- CALLBACK REGISTRY (Event System)
-- ============================================================================
-- Pub/sub system for decoupled communication between modules.
-- Based on Blizzard's CallbackRegistryMixin pattern.

local CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
CallbackRegistry:OnLoad()
CallbackRegistry:GenerateCallbackEvents({
    "SettingChanged", -- Fired when any setting changes: (settingName, newValue, oldValue)
    "DisplayRefresh", -- Fired when display needs full refresh
    "VisualsRefresh", -- Fired when visual properties (size, zoom, border) change
    "LayoutRefresh", -- Fired when layout needs recalculation (spacing, direction)
    "FramesReparent", -- Fired when frames need reparenting (split category change)
    "VisibilityRefresh", -- Fired when visibility toggles change (hide-when, show-only-in-group)
    "BuffStateChanged", -- Fired when buff state entries are recomputed
})
BR.CallbackRegistry = CallbackRegistry

-- ============================================================================
-- CONFIG SYSTEM (Event-Driven Settings)
-- ============================================================================
-- Centralized settings management with automatic callback triggering.
-- UI components call Config.Set() and interested systems subscribe to changes.
--
-- Validation: Paths are validated against registered settings. Invalid paths
-- print a warning in debug mode to catch typos early.

BR.Config = {}

-- Debug mode: set to true to print warnings for invalid config paths
BR.Config.DebugMode = false

-- ============================================================================
-- SETTINGS REGISTRY (Single Source of Truth)
-- ============================================================================
-- All valid settings defined here with their refresh types.
-- This catches typos and documents the config structure.

-- Root-level settings (path = key directly)
local RootSettings = {
    splitCategories = "FramesReparent",
    frameLocked = false, -- No refresh needed
    position = false, -- Table with x, y
    buffTrackingMode = false, -- No auto-refresh, manually calls UpdateDisplay
    showMissingCountOnly = "DisplayRefresh",
    -- Visibility toggles (routed through Config.Set → VisibilityRefresh)
    hideInCombat = "VisibilityRefresh",
    hideExpiringInCombat = "VisibilityRefresh",
    showOnlyInGroup = "VisibilityRefresh",
    hideAllInVehicle = "VisibilityRefresh",
    hideWhileMounted = "VisibilityRefresh",
    hideWhileResting = "VisibilityRefresh",
    hideInLegacyInstances = "VisibilityRefresh",
    hideWhileLeveling = "VisibilityRefresh",
    petPassiveOnlyInCombat = "VisibilityRefresh",
    bronzeHideInCombat = "VisibilityRefresh",
    requestBuffInChat = false, -- No auto-refresh, handled manually
}

-- Per-category settings (path = categorySettings.{category}.{key})
local CategorySettingKeys = {
    -- Appearance (visual properties)
    iconSize = "VisualsRefresh",
    iconWidth = "VisualsRefresh",
    iconZoom = "VisualsRefresh",
    borderSize = "VisualsRefresh",
    textSize = "VisualsRefresh",
    textOffsetX = "VisualsRefresh",
    textOffsetY = "VisualsRefresh",
    iconAlpha = "VisualsRefresh",
    textAlpha = "VisualsRefresh",
    textColor = "VisualsRefresh",
    showExpirationGlow = "DisplayRefresh",
    expirationThreshold = "DisplayRefresh",
    spacing = "LayoutRefresh",
    growDirection = "LayoutRefresh",
    subIconSide = "LayoutRefresh",
    anchorFrame = "LayoutRefresh",
    anchorPoint = "LayoutRefresh",
    -- Layout
    priority = "LayoutRefresh",
    -- Behavior
    showBuffReminder = "VisualsRefresh",
    buffTextSize = "VisualsRefresh",
    buffTextOffsetX = "VisualsRefresh",
    buffTextOffsetY = "VisualsRefresh",
    showText = "VisualsRefresh",
    -- Toggles
    useCustomAppearance = "VisualsRefresh",
    useCustomGlow = "VisualsRefresh",
    -- Per-category glow style overrides (expiring)
    glowType = "VisualsRefresh",
    glowColor = "VisualsRefresh",
    glowSize = "VisualsRefresh",
    glowPixelLines = "VisualsRefresh",
    glowPixelFrequency = "VisualsRefresh",
    glowPixelLength = "VisualsRefresh",
    glowAutocastParticles = "VisualsRefresh",
    glowAutocastFrequency = "VisualsRefresh",
    glowAutocastScale = "VisualsRefresh",
    glowBorderFrequency = "VisualsRefresh",
    glowProcDuration = "VisualsRefresh",
    glowProcStartAnim = "VisualsRefresh",
    glowProcUseCustomColor = "VisualsRefresh",
    glowXOffset = "VisualsRefresh",
    glowYOffset = "VisualsRefresh",
    -- Per-category missing glow
    showMissingGlow = "DisplayRefresh",
    missingGlowType = "VisualsRefresh",
    missingGlowColor = "VisualsRefresh",
    missingGlowSize = "VisualsRefresh",
    missingGlowPixelLines = "VisualsRefresh",
    missingGlowPixelFrequency = "VisualsRefresh",
    missingGlowPixelLength = "VisualsRefresh",
    missingGlowAutocastParticles = "VisualsRefresh",
    missingGlowAutocastFrequency = "VisualsRefresh",
    missingGlowAutocastScale = "VisualsRefresh",
    missingGlowBorderFrequency = "VisualsRefresh",
    missingGlowProcDuration = "VisualsRefresh",
    missingGlowProcStartAnim = "VisualsRefresh",
    missingGlowProcUseCustomColor = "VisualsRefresh",
    missingGlowXOffset = "VisualsRefresh",
    missingGlowYOffset = "VisualsRefresh",
    split = "FramesReparent",
    position = false, -- No auto-refresh, saved directly by movers
    clickable = false, -- No auto-refresh, handled manually via UpdateClickOverlays
    clickableHighlight = false, -- No auto-refresh, handled manually via UpdateClickOverlays
    showOnlyOnReadyCheck = "DisplayRefresh",
}

-- Defaults settings (path = defaults.{key})
local DefaultSettingKeys = {
    -- Appearance
    iconSize = "VisualsRefresh",
    iconWidth = "VisualsRefresh",
    iconZoom = "VisualsRefresh",
    borderSize = "VisualsRefresh",
    textSize = "VisualsRefresh",
    textOffsetX = "VisualsRefresh",
    textOffsetY = "VisualsRefresh",
    iconAlpha = "VisualsRefresh",
    textAlpha = "VisualsRefresh",
    textColor = "VisualsRefresh",
    spacing = "LayoutRefresh",
    growDirection = "LayoutRefresh",
    -- Behavior (glow is global-only, lives under defaults)
    showExpirationGlow = "DisplayRefresh",
    expirationThreshold = "DisplayRefresh",
    glowType = "VisualsRefresh",
    glowColor = "VisualsRefresh",
    glowSize = "VisualsRefresh",
    -- Advanced glow params (global-only, expiring)
    glowPixelLines = "VisualsRefresh",
    glowPixelFrequency = "VisualsRefresh",
    glowPixelLength = "VisualsRefresh",
    glowAutocastParticles = "VisualsRefresh",
    glowAutocastFrequency = "VisualsRefresh",
    glowAutocastScale = "VisualsRefresh",
    glowBorderFrequency = "VisualsRefresh",
    glowProcDuration = "VisualsRefresh",
    glowProcStartAnim = "VisualsRefresh",
    glowProcUseCustomColor = "VisualsRefresh",
    glowXOffset = "VisualsRefresh",
    glowYOffset = "VisualsRefresh",
    -- Missing glow (global-only)
    showMissingGlow = "DisplayRefresh",
    missingGlowType = "VisualsRefresh",
    missingGlowColor = "VisualsRefresh",
    missingGlowSize = "VisualsRefresh",
    missingGlowPixelLines = "VisualsRefresh",
    missingGlowPixelFrequency = "VisualsRefresh",
    missingGlowPixelLength = "VisualsRefresh",
    missingGlowAutocastParticles = "VisualsRefresh",
    missingGlowAutocastFrequency = "VisualsRefresh",
    missingGlowAutocastScale = "VisualsRefresh",
    missingGlowBorderFrequency = "VisualsRefresh",
    missingGlowProcDuration = "VisualsRefresh",
    missingGlowProcStartAnim = "VisualsRefresh",
    missingGlowProcUseCustomColor = "VisualsRefresh",
    missingGlowXOffset = "VisualsRefresh",
    missingGlowYOffset = "VisualsRefresh",
    showConsumablesWithoutItems = "DisplayRefresh",
    showWithoutItemsOnlyOnReadyCheck = "DisplayRefresh",
    delveFoodOnly = "DisplayRefresh",
    delveFoodTimer = "DisplayRefresh",
    freeConsumableMode = "DisplayRefresh",
    freeConsumableVisibility = "DisplayRefresh",
    healthstoneVisibility = "DisplayRefresh",
    healthstoneLowStock = "DisplayRefresh",
    healthstoneThreshold = "DisplayRefresh",
    soulstoneVisibility = "DisplayRefresh",
    soulstoneHideCooldown = "DisplayRefresh",
    -- Consumable display mode
    consumableDisplayMode = "DisplayRefresh",
    consumableTextScale = "VisualsRefresh",
    showConsumableTooltips = false, -- No refresh needed, read at tooltip time
    -- Pet display mode
    petDisplayMode = "DisplayRefresh",
    petLabels = "DisplayRefresh",
    petLabelScale = "DisplayRefresh",
    petSpecIconOnHover = "DisplayRefresh",
    useFelDomination = "DisplayRefresh",
    -- Font (global-only, lives under defaults)
    fontFace = "VisualsRefresh",
    position = false, -- No auto-refresh, saved directly by movers
}

-- Valid category names
local ValidCategories = {
    main = true,
    raid = true,
    presence = true,
    targeted = true,
    self = true,
    pet = true,
    consumable = true,
    custom = true,
}

-- Dynamic tables (path = {root}.{anyKey})
-- These allow any second-level key (buff names, visibility contexts, etc.)
local DynamicRoots = {
    enabledBuffs = "DisplayRefresh",
    categoryVisibility = "DisplayRefresh",
    splitCategories = "FramesReparent",
    readyCheckOnlyOverrides = "DisplayRefresh",
    detachedIcons = "FramesReparent",
}

---Check if a config path is valid
---@param segments string[] Path segments
---@return boolean isValid
---@return string|false|nil refreshType
local function ValidatePath(segments)
    if #segments == 0 then
        return false, nil
    end

    local root = segments[1]

    -- Check root-level settings (false = valid but no refresh event)
    local isRootSetting = RootSettings[root] ~= nil
    if isRootSetting then
        if #segments == 1 then
            return true, RootSettings[root]
        end
        -- position.x, position.y are valid
        if root == "position" and #segments == 2 then
            return true, nil
        end
        return false, nil
    end

    -- Check defaults.{setting}
    if root == "defaults" then
        if #segments == 1 then
            return true, nil -- Just "defaults" is valid
        end
        if #segments == 2 then
            local setting = segments[2]
            if DefaultSettingKeys[setting] ~= nil then
                return true, DefaultSettingKeys[setting]
            end
            return false, nil
        end
        return false, nil
    end

    -- Check categorySettings.{category}.{setting}
    if root == "categorySettings" then
        if #segments < 2 then
            return true, nil -- Just "categorySettings" is valid (for iteration)
        end
        local category = segments[2]
        if not ValidCategories[category] then
            return false, nil
        end
        if #segments == 2 then
            return true, nil -- Just "categorySettings.main" is valid
        end
        if #segments == 3 then
            local setting = segments[3]
            -- Check if it's a known category setting key (false = valid but no refresh)
            if CategorySettingKeys[setting] ~= nil then
                return true, CategorySettingKeys[setting]
            end
            return false, nil
        end
        return false, nil
    end

    -- Check dynamic roots (enabledBuffs.*, categoryVisibility.*, splitCategories.*)
    if DynamicRoots[root] then
        -- Any subpath is valid for dynamic roots
        return true, DynamicRoots[root]
    end

    return false, nil
end

---Check if a config path is valid and get its refresh type
---@param path string Dot-separated path
---@return boolean isValid
---@return string|false|nil refreshType
function BR.Config.IsValidPath(path)
    local segments = {}
    for segment in path:gmatch("[^.]+") do
        table.insert(segments, segment)
    end
    return ValidatePath(segments)
end

---Set a config value and trigger appropriate callbacks
---@param path string Dot-separated path like "categorySettings.main.iconSize" or "enabledBuffs.intellect"
---@param value any The new value
function BR.Config.Set(path, value)
    local db = BR.profile
    if not db then
        return
    end

    -- Parse path into segments
    local segments = {}
    for segment in path:gmatch("[^.]+") do
        table.insert(segments, segment)
    end

    if #segments == 0 then
        return
    end

    -- Validate path (debug mode only warns, doesn't block)
    local isValid, validatedRefreshType = ValidatePath(segments)
    if not isValid and BR.Config.DebugMode then
        print("|cffff6600BuffReminders:|r Invalid config path: " .. path)
    end

    -- Navigate to parent and get old value
    local parent = db
    for i = 1, #segments - 1 do
        local key = segments[i]
        if parent[key] == nil then
            parent[key] = {}
        end
        parent = parent[key]
    end

    local finalKey = segments[#segments]
    local oldValue = parent[finalKey]

    -- Don't trigger if value hasn't changed
    if oldValue == value then
        return
    end

    -- Set the new value
    parent[finalKey] = value

    -- Fire SettingChanged callback
    CallbackRegistry:TriggerEvent("SettingChanged", path, value, oldValue)

    -- Fire refresh event if the setting has one registered
    if validatedRefreshType then
        CallbackRegistry:TriggerEvent(validatedRefreshType, path)
    end
end

---Get a config value
---@param path string Dot-separated path like "main.iconSize"
---@param default? any Default value if not found
---@return any
function BR.Config.Get(path, default)
    local db = BR.profile
    if not db then
        return default
    end

    local current = db
    for segment in path:gmatch("[^.]+") do
        if type(current) ~= "table" then
            return default
        end
        current = current[segment]
        if current == nil then
            return default
        end
    end

    return current
end

---Set multiple config values at once (batched, single refresh)
---@param changes table<string, any> Map of path -> value
function BR.Config.SetMulti(changes)
    local db = BR.profile
    if not db then
        return
    end

    local refreshTypes = {}

    for path, value in pairs(changes) do
        -- Parse and set each value
        local segments = {}
        for segment in path:gmatch("[^.]+") do
            table.insert(segments, segment)
        end

        if #segments > 0 then
            -- Validate path (debug mode only warns, doesn't block)
            local isValid, validatedRefreshType = ValidatePath(segments)
            if not isValid and BR.Config.DebugMode then
                print("|cffff6600BuffReminders:|r Invalid config path: " .. path)
            end

            local parent = db
            for i = 1, #segments - 1 do
                local key = segments[i]
                if parent[key] == nil then
                    parent[key] = {}
                end
                parent = parent[key]
            end

            local finalKey = segments[#segments]
            local oldValue = parent[finalKey]

            if oldValue ~= value then
                parent[finalKey] = value
                CallbackRegistry:TriggerEvent("SettingChanged", path, value, oldValue)

                -- Collect refresh types
                if validatedRefreshType then
                    refreshTypes[validatedRefreshType] = true
                end
            end
        end
    end

    -- Fire each unique refresh type once
    for refreshType in pairs(refreshTypes) do
        CallbackRegistry:TriggerEvent(refreshType)
    end
end

-- ============================================================================
-- CATEGORY SETTING INHERITANCE
-- ============================================================================
-- Categories can inherit appearance and behavior settings from defaults,
-- or use their own custom values when useCustomAppearance/useCustomBehavior is true.

-- Keys that are appearance-related (inherit from defaults when useCustomAppearance is false)
local AppearanceKeys = {
    iconSize = true,
    iconWidth = true,
    textSize = true,
    textOffsetX = true,
    textOffsetY = true,
    iconAlpha = true,
    textAlpha = true,
    textColor = true,
    spacing = true,
    iconZoom = true,
    borderSize = true,
    growDirection = true,
    showExpirationGlow = true,
    showMissingGlow = true,
    expirationThreshold = true,
}

-- Keys that are glow-style-related (inherit from defaults when useCustomGlow is false)
local GlowKeys = {
    glowType = true,
    glowColor = true,
    glowSize = true,
    glowPixelLines = true,
    glowPixelFrequency = true,
    glowPixelLength = true,
    glowAutocastParticles = true,
    glowAutocastFrequency = true,
    glowAutocastScale = true,
    glowBorderFrequency = true,
    glowProcDuration = true,
    glowProcStartAnim = true,
    glowProcUseCustomColor = true,
    glowXOffset = true,
    glowYOffset = true,
    missingGlowType = true,
    missingGlowColor = true,
    missingGlowSize = true,
    missingGlowPixelLines = true,
    missingGlowPixelFrequency = true,
    missingGlowPixelLength = true,
    missingGlowAutocastParticles = true,
    missingGlowAutocastFrequency = true,
    missingGlowAutocastScale = true,
    missingGlowBorderFrequency = true,
    missingGlowProcDuration = true,
    missingGlowProcStartAnim = true,
    missingGlowProcUseCustomColor = true,
    missingGlowXOffset = true,
    missingGlowYOffset = true,
}

---Get a category setting with inheritance from defaults
---@param category string Category name (raid, presence, etc.)
---@param key string Setting key (iconSize, showBuffReminder, etc.)
---@return any value The effective value for this setting
function BR.Config.GetCategorySetting(category, key)
    local db = BR.profile
    if not db then
        return nil
    end

    local catSettings = db.categorySettings and db.categorySettings[category]
    if not catSettings then
        -- No category settings, fall back to defaults
        return db.defaults and db.defaults[key]
    end

    -- Check if this key uses inheritance
    if AppearanceKeys[key] then
        if not catSettings.useCustomAppearance then
            -- No custom appearance: always inherit from defaults
            return db.defaults and db.defaults[key]
        end
        -- Custom appearance: independent from defaults (callers handle nil with their own defaults)
        return catSettings[key]
    end

    -- Glow style keys: inherit from defaults unless BOTH useCustomAppearance and useCustomGlow are true
    if GlowKeys[key] then
        if not catSettings.useCustomAppearance or not catSettings.useCustomGlow then
            return db.defaults and db.defaults[key]
        end
        return catSettings[key]
    end

    -- Non-appearance keys: use category value if set, otherwise fall back to defaults
    local value = catSettings[key]
    if value ~= nil then
        return value
    end
    return db.defaults and db.defaults[key]
end

---Check if a category has custom appearance enabled
---@param category string
---@return boolean
function BR.Config.HasCustomAppearance(category)
    local db = BR.profile
    if not db or not db.categorySettings or not db.categorySettings[category] then
        return false
    end
    return db.categorySettings[category].useCustomAppearance == true
end

---Check if a category has custom glow style enabled (requires custom appearance)
---@param category string
---@return boolean
function BR.Config.HasCustomGlow(category)
    local db = BR.profile
    if not db or not db.categorySettings or not db.categorySettings[category] then
        return false
    end
    local cat = db.categorySettings[category]
    return cat.useCustomAppearance == true and cat.useCustomGlow == true
end

-- ============================================================================
-- SHARED UI FACTORIES
-- ============================================================================

---Create a draggable panel with standard backdrop
---@param name string? Frame name (nil for anonymous)
---@param width number
---@param height number
---@param options? {bgColor?: table, borderColor?: table, strata?: string, level?: number, escClose?: boolean, modal?: boolean}
---@return table
function BR.CreatePanel(name, width, height, options)
    options = options or {}
    local isModal = options.modal
    local bgColor = options.bgColor or (isModal and { 0.15, 0.15, 0.15, 0.98 } or { 0.1, 0.1, 0.1, 0.95 })
    local borderColor = options.borderColor or (isModal and { 0.5, 0.5, 0.5, 1 } or { 0.3, 0.3, 0.3, 1 })

    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetPoint("CENTER")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    panel:SetBackdropColor(unpack(bgColor))
    panel:SetBackdropBorderColor(unpack(borderColor))
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata(options.strata or "DIALOG")
    if options.level then
        panel:SetFrameLevel(options.level)
    end
    if isModal then
        -- Modal panels handle ESC via keyboard input so they close themselves
        -- without also closing parent panels (unlike UISpecialFrames which closes all)
        panel:EnableKeyboard(true)
        panel:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then
                return
            end
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    elseif options.escClose and name then
        tinsert(UISpecialFrames, name)
    end
    return panel
end

---Create a section header with yellow text
---@param parent table
---@param text string
---@param x number
---@param y number
---@return table header
---@return number newY
function BR.CreateSectionHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText("|cffffcc00" .. text .. "|r")
    return header, y - 18
end

-- ============================================================================
-- CLASS SPEC OPTIONS (for custom buff spec filtering)
-- ============================================================================
-- Built once at load time. Keyed by class token, each value is a dropdown
-- options table with { value, label } entries.

local CLASS_IDS = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

BR.CLASS_SPEC_OPTIONS = {}
for token, classID in pairs(CLASS_IDS) do
    local specs = {}
    for i = 1, 4 do
        local specID, name = GetSpecializationInfoForClassID(classID, i)
        if specID then
            table.insert(specs, { value = specID, label = name })
        end
    end
    table.sort(specs, function(a, b)
        return a.label < b.label
    end)
    local opts = { { value = nil, label = BR.L["Core.Any"] } }
    for _, spec in ipairs(specs) do
        table.insert(opts, spec)
    end
    BR.CLASS_SPEC_OPTIONS[token] = opts
end

-- ============================================================================
-- SPELL NAME CACHE
-- ============================================================================
-- Spell names are immutable for a given spellID within a session.
-- Cache them to avoid repeated C_Spell.GetSpellName API calls.

local spellNameCache = {}

---Get spell name with caching (immutable per session)
---@param spellID number
---@return string?
function BR.GetSpellName(spellID)
    local name = spellNameCache[spellID]
    if name == nil then
        name = C_Spell.GetSpellName(spellID) or false
        spellNameCache[spellID] = name
    end
    return name or nil
end

---Create a buff icon texture with standard formatting
---@param parent table
---@param size number
---@param textureID? number|string
---@return table
function BR.CreateBuffIcon(parent, size, textureID)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)
    if textureID then
        icon:SetTexture(textureID)
    end
    return icon
end
