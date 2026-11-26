local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTIONS: Appearance and Glow
-- ============================================================================
-- Two independently-overridable sections, each headed by an Override checkbox
-- with a live state label. While a section inherits, its controls stay VISIBLE
-- and show the live global default values: the labels dim, the values stay
-- readable, because they apply.
-- If Override goes on, the addon snapshots the current effective values into
-- the category, so the display does not jump. If Override goes off, the stored
-- values stay dormant for a later re-enable.
--
-- Appearance override = useCustomAppearance; Glow override = useCustomGlow.
-- The two flags are independent (Core.lua GetCategorySetting).

local L = BR.L
local Components = BR.Components

local GetCategorySettings = BR.Helpers.GetCategorySettings

local Helpers = BR.Options.Helpers
local LayoutSectionHeader = Helpers.LayoutSectionHeader

local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local APPEARANCE_KEYS = {
    "iconSize",
    "iconWidth",
    "countTextSize",
    "missingTextSize",
    "spacing",
    "iconZoom",
    "borderSize",
    "iconAlpha",
    "textAlpha",
}

local GLOW_SNAPSHOT_KEYS = {
    "showExpirationGlow",
    "showMissingGlow",
    "glowType",
    "glowSize",
    "glowPixelLines",
    "glowPixelFrequency",
    "glowPixelLength",
    "glowAutocastParticles",
    "glowAutocastFrequency",
    "glowAutocastScale",
    "glowBorderFrequency",
    "glowProcDuration",
    "glowProcStartAnim",
    "glowProcUseCustomColor",
    "glowXOffset",
    "glowYOffset",
    "missingGlowType",
    "missingGlowSize",
    "missingGlowPixelLines",
    "missingGlowPixelFrequency",
    "missingGlowPixelLength",
    "missingGlowAutocastParticles",
    "missingGlowAutocastFrequency",
    "missingGlowAutocastScale",
    "missingGlowBorderFrequency",
    "missingGlowProcDuration",
    "missingGlowProcStartAnim",
    "missingGlowProcUseCustomColor",
    "missingGlowXOffset",
    "missingGlowYOffset",
}

---@param category string
---@param key string
---@return boolean
local function IsOverriding(category, key)
    local cs = BR.profile.categorySettings and BR.profile.categorySettings[category]
    return (cs and cs[key] == true) or false
end

---Make sure the category table exists before a snapshot writes into it.
---@param category string
---@return table
local function EnsureCategorySettings(category)
    local db = BR.profile
    if not db.categorySettings then
        ---@diagnostic disable-next-line: missing-fields
        db.categorySettings = {}
    end
    if not db.categorySettings[category] then
        db.categorySettings[category] = {}
    end
    return db.categorySettings[category]
end

local function BuildAppearance(ctx, layout)
    local category = ctx.category
    local parent = ctx.content

    local function isOverridingAppearance()
        return IsOverriding(category, "useCustomAppearance")
    end

    ---Effective value for a key: the category override when its section
    ---overrides, else the live global default (BR.Config.GetCategorySetting
    ---resolves the gate).
    local function getEffectiveValue(key, default)
        local val = BR.Config.GetCategorySetting(category, key)
        if val ~= nil then
            return val
        end
        return default
    end

    LayoutSectionHeader(layout, parent, L["Options.Appearance"])

    BR.Options.Helpers.AddOverrideRow(parent, layout, {
        get = isOverridingAppearance,
        desc = L["Options.Override.Appearance.Desc"],
        defaultsLink = true,
        onChange = function(checked)
            if checked then
                -- Snapshot the current effective values, so the override does
                -- not change the display.
                local effective = GetCategorySettings(category)
                local cs = EnsureCategorySettings(category)
                for _, key in ipairs(APPEARANCE_KEYS) do
                    if cs[key] == nil and effective[key] ~= nil then
                        cs[key] = effective[key]
                    end
                end
                if cs.textColor == nil and effective.textColor then
                    local tc = effective.textColor
                    cs.textColor = { tc[1], tc[2], tc[3] }
                end
            end
            BR.Config.Set("categorySettings." .. category .. ".useCustomAppearance", checked)
            Components.RefreshAll()
        end,
    })

    local function isDimensionsLinked()
        return getEffectiveValue("iconWidth", nil) == nil
    end

    local function isInheriting()
        return not isOverridingAppearance()
    end

    -- Shared by the geometry grid and the text size/color row below it: both are
    -- covered by this category's single appearance override.
    local catAccess = {
        get = getEffectiveValue,
        set = function(key, value)
            BR.Config.Set("categorySettings." .. category .. "." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["categorySettings." .. category .. "." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        enabled = isOverridingAppearance,
        inherited = isInheriting,
        disabledReason = L["DisabledReason.OverrideSection"],
    }

    -- One label column for both groups: the grid measures its own labels, and the
    -- text row joins that column.
    local textLabelWidth =
        Components.MeasureSharedLabelWidth({ L["Appearance.CountSize"], L["Appearance.MissingSize"] })

    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.Icons"])
    local appFrame = CreateFrame("Frame", nil, parent)
    layout:Add(appFrame, 0)
    local catGrid = Components.AppearanceGrid(appFrame, {
        get = catAccess.get,
        set = catAccess.set,
        setMulti = catAccess.setMulti,
        isLinked = isDimensionsLinked,
        onLink = function()
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local size = getEffectiveValue("iconSize", 64)
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
            Components.RefreshAll()
        end,
        enabled = isOverridingAppearance,
        inherited = isInheriting,
        disabledReason = L["DisabledReason.OverrideSection"],
        labelWidth = textLabelWidth,
        masqueCheck = IsMasqueActive,
        borderBlocked = BR.IconStyle.UsesBlizzardArt,
        borderBlockedReason = Helpers.IconStyleBorderReason,
    })
    appFrame:SetSize(480, catGrid.height)
    layout:Space(catGrid.height)

    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.Text"])
    local catTextStyleHolder = Components.TextStyleRow(parent, catAccess, catGrid.labelWidth)
    layout:Add(catTextStyleHolder, nil, COMPONENT_GAP)
    layout:Add(catTextStyleHolder.missingSize, nil, COMPONENT_GAP)
end

local function BuildGlow(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile

    local function isOverridingGlow()
        return IsOverriding(category, "useCustomGlow")
    end

    local function getEffectiveValue(key, default)
        local val = BR.Config.GetCategorySetting(category, key)
        if val ~= nil then
            return val
        end
        return default
    end

    LayoutSectionHeader(layout, parent, L["Options.Glow"])

    BR.Options.Helpers.AddOverrideRow(parent, layout, {
        get = isOverridingGlow,
        desc = L["Options.Override.Glow.Desc"],
        defaultsLink = true,
        onChange = function(checked)
            if checked then
                -- Snapshot the effective glow config (enable flags + style),
                -- so the override does not change the display.
                local cs = EnsureCategorySettings(category)
                local glowDefaults = db.defaults or {}
                for _, key in ipairs(GLOW_SNAPSHOT_KEYS) do
                    if cs[key] == nil and glowDefaults[key] ~= nil then
                        cs[key] = glowDefaults[key]
                    end
                end
                for _, colorKey in ipairs({ "glowColor", "missingGlowColor" }) do
                    if cs[colorKey] == nil and glowDefaults[colorKey] then
                        local gc = glowDefaults[colorKey]
                        cs[colorKey] = { gc[1], gc[2], gc[3], gc[4] }
                    end
                end
            end
            BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
            Components.RefreshAll()
        end,
    })

    local labelWidth, summaryWidth = Helpers.GlowColumns({
        L["Options.ExpiringGlow"],
        L["Options.MissingGlow"],
        L["Options.GlowMissingPets"],
    }, false)

    ---Pet reminders have no expiration, so the pet category gets only the missing row.
    local function AddGlowRow(labelText, enableKey, kind)
        Helpers.LayoutGlowRow(layout, parent, {
            label = labelText,
            labelWidth = labelWidth,
            summaryWidth = summaryWidth,
            kind = kind,
            read = getEffectiveValue,
            get = function()
                return getEffectiveValue(enableKey, true) ~= false
            end,
            set = function(checked)
                BR.Config.Set("categorySettings." .. category .. "." .. enableKey, checked)
            end,
            enabled = isOverridingGlow,
            disabledReason = L["DisabledReason.OverrideSection"],
            onCustomize = function()
                BR.Options.Dialogs.Glow.Show(category, kind)
            end,
        })
    end

    if category == "pet" then
        AddGlowRow(L["Options.GlowMissingPets"], "showMissingGlow", "missing")
    else
        AddGlowRow(L["Options.ExpiringGlow"], "showExpirationGlow", "expiring")
        AddGlowRow(L["Options.MissingGlow"], "showMissingGlow", "missing")
    end
end

BR.Options.BuffSections.Appearance = BuildAppearance
BR.Options.BuffSections.Glow = BuildGlow
