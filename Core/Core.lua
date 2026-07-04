local _, BR = ...

-- ============================================================================
-- SHARED NAMESPACE
-- ============================================================================
-- This file establishes the BR namespace used by all addon files.
-- It loads first (per TOC order) so other files can access BR.* functions.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@alias CategoryName "raid"|"presence"|"targeted"|"self"|"pet"|"consumable"|"custom"|"loadout"

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

-- Shared UI palette. Defined here (before Components/Options load) so every layer
-- references the same tokens instead of copy-pasting raw literals. Callers that
-- need a non-opaque variant index into [1..3] and pass their own alpha.
-- Border: the cool-biased neutral hairline used for panel chrome, dialog
-- separators, and widget borders. The slight blue tint over a flat grey reads as
-- a chosen ground against the warm gold accent (see CreatePanel).
-- Accent: the bright brand gold for active/hover/focus cues (active tabs, focused
-- borders, scale steppers). AccentMuted: the softer gold for "on"/checked fills
-- (checkmarks, linked toggles) that shouldn't shout as loud as the bright accent.
-- NOTE: these are chrome tokens only - never point a value persisted into
-- SavedVariables (e.g. glow color defaults) at them, or a palette tweak would
-- silently rewrite users' saved data.
BR.Colors = {
    Border = { 0.27, 0.27, 0.32, 1 },
    Accent = { 1, 0.82, 0, 1 },
    AccentMuted = { 0.9, 0.75, 0.2, 1 },
}

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
    outsideInstancesMode = "DisplayRefresh",
    combatMode = "DisplayRefresh",
    levelingMode = "DisplayRefresh",
    showMissingCountOnly = "DisplayRefresh",
    -- Visibility toggles (routed through Config.Set -> VisibilityRefresh)
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
    druidIgnoreTravelForm = "DisplayRefresh", -- recompute wrong-form state, then render
    requestBuffInChat = false, -- No auto-refresh, handled manually
    chatRequestCooldown = false, -- No auto-refresh, read live in PostClick + SyncSecureButtons
}

-- Per-category settings (path = categorySettings.{category}.{key})
local CategorySettingKeys = {
    -- Appearance (visual properties)
    iconSize = "VisualsRefresh",
    iconWidth = "VisualsRefresh",
    iconZoom = "VisualsRefresh",
    borderSize = "VisualsRefresh",
    textSize = "VisualsRefresh",
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
    iconAlpha = "VisualsRefresh",
    textAlpha = "VisualsRefresh",
    textColor = "VisualsRefresh",
    spacing = "LayoutRefresh",
    growDirection = "LayoutRefresh",
    -- Behavior (glow is global-only, lives under defaults)
    showExpirationGlow = "DisplayRefresh",
    expirationThreshold = "DisplayRefresh",
    preKeyThreshold = "DisplayRefresh",
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
    hideConsumableLabels = "VisualsRefresh",
    showConsumableTooltips = false, -- No refresh needed, read at tooltip time
    showBuffTooltips = "VisualsRefresh", -- Toggles raid/presence hover capture vs click-through
    hideLegacyConsumables = "DisplayRefresh",
    -- Pet display mode
    petDisplayMode = "DisplayRefresh",
    petLabels = "DisplayRefresh",
    petLabelScale = "DisplayRefresh",
    petSpecIconOnHover = "DisplayRefresh",
    useFelDomination = "DisplayRefresh",
    -- Font (global-only, lives under defaults)
    fontFace = "VisualsRefresh",
    textOutline = "VisualsRefresh",
    position = false, -- No auto-refresh, saved directly by movers
}

-- Canonical buff category list (single source of truth).
--
-- Order here is the canonical category order used everywhere it matters:
-- display stacking, the Defaults "Display Order" UI, the movers, and config
-- validation. Adding a category here automatically wires it into config-path
-- validation (ValidCategories below), the display loop (BR.CATEGORIES), the
-- reorder UI (ALL_CATEGORIES), and the Categories page tab strip -- all
-- of which derive from this list instead of repeating it. Forgetting to extend
-- one of those parallel lists is what silently breaks live config updates, so
-- there is exactly one list to maintain.
BR.CATEGORY_ORDER = { "raid", "presence", "targeted", "self", "pet", "consumable", "custom", "loadout" }

-- Virtual categories: user-defined entries that live in db.customBuffs /
-- db.loadoutReminders rather than BR.BUFF_TABLES. Consumers that walk only the
-- built-in buff tables (chat requests, static-buff iteration) skip these.
BR.VIRTUAL_CATEGORIES = { custom = true, loadout = true }

-- Built-in (non-virtual) categories that have entries in BR.BUFF_TABLES, in
-- display order. Derived from BR.CATEGORY_ORDER minus the virtual categories so
-- there is still exactly one ordered list to maintain.
BR.STATIC_CATEGORIES = {}
for _, cat in ipairs(BR.CATEGORY_ORDER) do
    if not BR.VIRTUAL_CATEGORIES[cat] then
        BR.STATIC_CATEGORIES[#BR.STATIC_CATEGORIES + 1] = cat
    end
end

-- Valid category names for config paths (categorySettings.<category>.<key>).
-- Derived from BR.CATEGORY_ORDER plus "main", the shared/global frame whose
-- settings live under categorySettings.main but which is not a buff category.
local ValidCategories = { main = true }
for _, cat in ipairs(BR.CATEGORY_ORDER) do
    ValidCategories[cat] = true
end

-- Dynamic tables (path = {root}.{anyKey})
-- These allow any second-level key (buff names, visibility contexts, etc.)
local DynamicRoots = {
    enabledBuffs = "DisplayRefresh",
    categoryVisibility = "DisplayRefresh",
    splitCategories = "FramesReparent",
    readyCheckOnlyOverrides = "DisplayRefresh",
    detachedIcons = "FramesReparent",
    loadoutReminders = "DisplayRefresh",
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
        -- defaults.textPositions.<item>.<field> (zone | offsetX | offsetY)
        if segments[2] == "textPositions" and #segments == 4 then
            return true, "VisualsRefresh"
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

    -- Navigate to parent and get old value.
    --
    -- Level 1 reads through the BR.profile proxy's __index to reach the real
    -- AceDB profile sub-table (the proxy itself is an empty shell, so rawget
    -- would always miss and we'd overwrite real data via __newindex).
    --
    -- Levels 2+ use rawget so the metatable on db.defaults (which falls back
    -- to the shared code-defaults table for missing keys) doesn't make us
    -- walk into that shared table and mutate it. Writes must always land in
    -- the user's own saved table, even for nested paths like
    -- defaults.textPositions.<item>.<field>.
    local parent = db
    for i = 1, #segments - 1 do
        local key = segments[i]
        local child = (i == 1) and parent[key] or rawget(parent, key)
        if child == nil then
            child = {}
            parent[key] = child
        end
        parent = child
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

            -- See BR.Config.Set for why level 1 uses __index and levels 2+ use rawget.
            local parent = db
            for i = 1, #segments - 1 do
                local key = segments[i]
                local child = (i == 1) and parent[key] or rawget(parent, key)
                if child == nil then
                    child = {}
                    parent[key] = child
                end
                parent = child
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
    iconAlpha = true,
    textAlpha = true,
    textColor = true,
    spacing = true,
    iconZoom = true,
    borderSize = true,
    growDirection = true,
}
-- NOTE: expirationThreshold is deliberately NOT an appearance key. It is a timing/behavior
-- setting and uses the standard per-key fallback (category value if set, else defaults),
-- independent of useCustomAppearance. Stale pre-2.5 values stored while the appearance
-- flag was off are cleaned up in Migrations.lua.

-- Keys that are glow-related (inherit from defaults when useCustomGlow is false).
-- Includes the per-kind ENABLE flags: the Glow override owns both whether each
-- glow kind fires and how it looks, independent of the appearance override.
local GlowKeys = {
    showExpirationGlow = true,
    showMissingGlow = true,
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

    -- Glow keys: inherit from defaults unless useCustomGlow is true.
    -- Independent of useCustomAppearance - glow and appearance are separate
    -- override switches.
    if GlowKeys[key] then
        if not catSettings.useCustomGlow then
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

---Check if a category has custom glow enabled (independent of custom appearance)
---@param category string
---@return boolean
function BR.Config.HasCustomGlow(category)
    local db = BR.profile
    if not db or not db.categorySettings or not db.categorySettings[category] then
        return false
    end
    return db.categorySettings[category].useCustomGlow == true
end

-- ============================================================================
-- SHARED UI FACTORIES
-- ============================================================================

---Create a draggable panel with standard backdrop
---@param name string? Frame name (nil for anonymous)
---@param width number
---@param height number
---@param options? {bgColor?: table, borderColor?: table, strata?: string, level?: number, escClose?: boolean, dialog?: boolean}
---@return table
function BR.CreatePanel(name, width, height, options)
    options = options or {}
    local isDialog = options.dialog
    -- Dialogs echo the main options panel's restrained palette - dark body, gray
    -- hairline border - and rely on the soft drop shadow (below) rather than a
    -- loud gold frame to read as elevated above the content underneath. Gold is
    -- reserved for accents (active tabs), mirroring the panel's active-nav cue.
    -- Cool-biased neutrals: a slight blue tint over flat grey reads as a chosen
    -- ground against the warm gold accent (a pure mid-grey reads as unconsidered).
    local bgColor = options.bgColor or (isDialog and { 0.098, 0.098, 0.118, 1 } or { 0.09, 0.09, 0.107, 0.97 })
    local borderColor = options.borderColor or BR.Colors.Border

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
    -- Dialogs default to FULLSCREEN_DIALOG so they always sit above the main
    -- options panel (which is on DIALOG); plain panels stay on DIALOG.
    panel:SetFrameStrata(options.strata or (isDialog and "FULLSCREEN_DIALOG" or "DIALOG"))
    if options.level then
        panel:SetFrameLevel(options.level)
    end
    if isDialog then
        -- Soft drop shadow: a fine stack of rings with a smooth alpha falloff so
        -- the dialog reads as a raised card lifted off the busy content beneath
        -- it. The outermost ring is barely visible (~4%) and each inner ring
        -- darkens gradually; sublevels sit below the panel's own backdrop so the
        -- body color paints over the inner overlap.
        local SHADOW_STEPS = 6
        for i = 1, SHADOW_STEPS do
            local outset = SHADOW_STEPS - i + 1 -- 6,5,4,3,2,1 px out
            local alpha = 0.04 + (i - 1) * 0.045 -- ~0.04 (outer) -> ~0.26 (inner)
            local layer = panel:CreateTexture(nil, "BACKGROUND", nil, -9 + i)
            layer:SetPoint("TOPLEFT", -outset, outset)
            layer:SetPoint("BOTTOMRIGHT", outset, -outset)
            layer:SetColorTexture(0, 0, 0, alpha)
        end

        -- Body gradient: a faint top->bottom falloff over the flat backdrop color
        -- gives the card subtle depth instead of a dead-flat fill, while staying
        -- in the main panel's dark range. Sits above the shadow/backdrop but below
        -- the title separator (BORDER layer 0+).
        local body = panel:CreateTexture(nil, "BORDER", nil, -7)
        body:SetPoint("TOPLEFT", 2, -2)
        body:SetPoint("BOTTOMRIGHT", -2, 2)
        body:SetColorTexture(1, 1, 1, 1)
        body:SetGradient("VERTICAL", CreateColor(0.094, 0.094, 0.112, 1), CreateColor(0.130, 0.130, 0.152, 1))

        -- A thin gray separator under the title mirrors the main panel's header
        -- divider, so the dialog reads as a titled card in the same family. The
        -- title (GameFontNormalLarge, gold) sits above it; content layouts start
        -- just below. The -32 offset is load-bearing - dialogs hardcode content
        -- positions relative to it, so restyle the line but don't move it.
        local titleSep = panel:CreateTexture(nil, "BORDER", nil, 1)
        titleSep:SetPoint("TOPLEFT", 2, -32)
        titleSep:SetPoint("TOPRIGHT", -2, -32)
        titleSep:SetHeight(1)
        titleSep:SetColorTexture(unpack(BR.Colors.Border))

        -- Dialogs are modeless: ESC handled via keyboard input so closing this
        -- dialog doesn't also close the parent options panel (unlike
        -- UISpecialFrames, which closes every registered frame).
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

        panel:HookScript("OnShow", function(self)
            UIFrameFadeIn(self, 0.12, 0, 1)
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
