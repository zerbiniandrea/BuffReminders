local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Expiration (subsection of Visibility)
-- ============================================================================
-- Per-category expiration threshold. It uses the standard per-key fallback: the
-- category value if set, else the global default, independent of the
-- useCustomAppearance toggle. The group holds one control, so its Override sits
-- on the same row: on = a category value materialized from the current
-- effective value, off = nil (follow Defaults).

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile
    local path = "categorySettings." .. category .. ".expirationThreshold"

    local function getOwnThreshold()
        local catSettings = db.categorySettings and db.categorySettings[category]
        return catSettings and catSettings.expirationThreshold
    end

    local function isOverriding()
        return getOwnThreshold() ~= nil
    end

    local function getEffectiveThreshold()
        local own = getOwnThreshold()
        if own ~= nil then
            return own
        end
        return db.defaults and db.defaults.expirationThreshold or 15
    end

    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.Expiration"])

    local thresholdHolder = Components.Slider(parent, {
        label = L["Options.ExpirationWarning"],
        min = 0,
        max = 45,
        step = 1,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        get = getEffectiveThreshold,
        enabled = isOverriding,
        inherited = function()
            return not isOverriding()
        end,
        disabledReason = L["DisabledReason.OverrideRow"],
        onChange = function(val)
            BR.Config.Set(path, val)
        end,
    })

    local overrideHolder = Components.Checkbox(parent, {
        label = L["Options.Override"],
        holderWidth = 120,
        get = isOverriding,
        tooltip = { title = L["Options.Override"], desc = L["Options.Override.Expiration.Desc"] },
        onChange = function(checked)
            BR.Config.Set(path, checked and getEffectiveThreshold() or nil)
            Components.RefreshAll()
        end,
    })
    overrideHolder:SetPoint("LEFT", thresholdHolder, "RIGHT", 12, 0)

    layout:Add(thresholdHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.Timing = Build
