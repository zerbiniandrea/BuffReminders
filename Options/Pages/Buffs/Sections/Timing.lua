local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Timing
-- ============================================================================
-- Per-category expiration threshold. This is a behavior setting, not an
-- appearance one: it uses the standard per-key fallback (category value if
-- set, else the global default) and is always editable, independent of the
-- useCustomAppearance toggle. The checkbox models the inheritance explicitly:
-- checked = no category value stored (follow Defaults), unchecked = category
-- override materialized from the current effective value.

local L = BR.L
local Components = BR.Components

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile

    local function getOwnThreshold()
        local catSettings = db.categorySettings and db.categorySettings[category]
        return catSettings and catSettings.expirationThreshold
    end

    local function getEffectiveThreshold()
        local own = getOwnThreshold()
        if own ~= nil then
            return own
        end
        return db.defaults and db.defaults.expirationThreshold or 15
    end

    LayoutSectionHeader(layout, parent, L["Options.Timing"])

    local useDefaultHolder = Components.Checkbox(parent, {
        label = L["Options.UseDefaultThreshold"],
        get = function()
            return getOwnThreshold() == nil
        end,
        tooltip = {
            title = L["Options.UseDefaultThreshold"],
            desc = L["Options.UseDefaultThreshold.Desc"],
        },
        onChange = function(checked)
            if checked then
                BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", nil)
            else
                BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", getEffectiveThreshold())
            end
            Components.RefreshAll()
        end,
    })
    layout:Add(useDefaultHolder, nil, COMPONENT_GAP)

    layout:SetX(COL_PADDING + 10)
    local thresholdHolder = Components.Slider(parent, {
        label = L["Options.Expiration"],
        labelWidth = 70,
        min = 0,
        max = 45,
        step = 5,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        get = getEffectiveThreshold,
        enabled = function()
            return getOwnThreshold() ~= nil
        end,
        disabledReason = L["DisabledReason.UseDefaultThreshold"],
        onChange = function(val)
            BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", val)
        end,
    })
    layout:Add(thresholdHolder, nil, COMPONENT_GAP)
    layout:SetX(COL_PADDING)
end

BR.Options.BuffSections.Timing = Build
