local _, BR = ...

-- ============================================================================
-- VISIBILITY PAGE
-- ============================================================================
-- "What do I see?" - the global gating rules for when the panel hides plus the
-- buff tracking mode that controls which auras count as missing. Per-category
-- content visibility (W/S/D/R) lives on each category's own tab (Categories
-- page), not here.
--
-- The Hide When list folds the legacy "Show only in group" toggle in as a
-- "When alone" entry. The DB key (showOnlyInGroup) is reused as-is - checked
-- ⇔ "show only in group" ⇔ "hide when alone", semantically identical.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local UpdateDisplay = BR.Display.Update

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local LayoutSectionNote = Helpers.LayoutSectionNote
local MakeProfileGetter = Helpers.MakeProfileGetter
local MakeProfileSetter = Helpers.MakeProfileSetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local abs = math.abs

-- One declarative row per HideWhen toggle. `default` is the fallback value the
-- getter returns when the key is unset - chosen so each toggle's checked-state
-- semantics match its current DB convention (some keys default-on, some off).
-- Only the rows with extra interactivity (`enabled` predicate, `extraOnChange`
-- side effect like RefreshAll) carry those fields.
local HIDE_WHEN_ROWS = {
    {
        key = "showOnlyInGroup",
        default = true,
        labelKey = "Options.HideWhen.Alone",
        tooltipTitle = "Options.HideWhen.Alone.Title",
        tooltipDesc = "Options.HideWhen.Alone.Desc",
    },
    {
        key = "hideInCombat",
        default = false,
        labelKey = "Options.HideWhen.Combat",
        extraOnChange = function()
            Components.RefreshAll()
        end,
    },
    {
        key = "hideExpiringInCombat",
        default = true,
        labelKey = "Options.HideWhen.Expiring",
        tooltipTitle = "Options.HideWhen.Expiring.Title",
        tooltipDesc = "Options.HideWhen.Expiring.Desc",
        enabled = function()
            return BR.profile.hideInCombat ~= true
        end,
        disabledReason = "DisabledReason.ExpiringInCombat",
    },
    {
        key = "hideWhileMounted",
        default = false,
        labelKey = "Options.HideWhen.Mounted",
        tooltipTitle = "Options.HideWhen.Mounted.Title",
        tooltipDesc = "Options.HideWhen.Mounted.Desc",
    },
    {
        key = "hideAllInVehicle",
        default = false,
        labelKey = "Options.HideWhen.Vehicle",
        tooltipTitle = "Options.HideWhen.Vehicle.Title",
        tooltipDesc = "Options.HideWhen.Vehicle.Desc",
    },
    {
        key = "hideWhileResting",
        default = false,
        labelKey = "Options.HideWhen.Resting",
        tooltipTitle = "Options.HideWhen.Resting.Title",
        tooltipDesc = "Options.HideWhen.Resting.Desc",
    },
    {
        key = "hideInLegacyInstances",
        default = false,
        labelKey = "Options.HideWhen.Legacy",
        tooltipTitle = "Options.HideWhen.Legacy.Title",
        tooltipDesc = "Options.HideWhen.Legacy.Desc",
    },
    {
        key = "hideWhileLeveling",
        default = false,
        labelKey = "Options.HideWhen.Leveling",
        tooltipTitle = "Options.HideWhen.Leveling.Title",
        tooltipDesc = "Options.HideWhen.Leveling.Desc",
        extraOnChange = function()
            Components.RefreshAll()
        end,
    },
}

local function BuildHideWhenSection(content, layout)
    LayoutSectionHeader(layout, content, L["Options.HideWhen"])

    for _, row in ipairs(HIDE_WHEN_ROWS) do
        local baseSetter = MakeProfileSetter(row.key)
        local onChange = row.extraOnChange
                and function(checked)
                    baseSetter(checked)
                    row.extraOnChange()
                end
            or baseSetter

        local cfg = {
            label = L[row.labelKey],
            get = MakeProfileGetter(row.key, row.default),
            onChange = onChange,
            enabled = row.enabled,
            disabledReason = row.disabledReason and L[row.disabledReason] or nil,
        }
        if row.tooltipTitle then
            cfg.tooltip = { title = L[row.tooltipTitle], desc = L[row.tooltipDesc] }
        end
        local holder = Components.Checkbox(content, cfg)
        layout:Add(holder, nil, COMPONENT_GAP)
    end
end

local function BuildTrackingSection(content, layout)
    LayoutSectionHeader(layout, content, L["Section.Tracking"])

    local trackingModeHolder = Components.Dropdown(content, {
        label = L["Options.BuffTracking"],
        width = 200,
        options = {
            {
                value = "all",
                label = L["Options.BuffTracking.All"],
                desc = L["Options.BuffTracking.All.Desc"],
            },
            {
                value = "my_buffs",
                label = L["Options.BuffTracking.MyBuffs"],
                desc = L["Options.BuffTracking.MyBuffs.Desc"],
            },
            {
                value = "personal",
                label = L["Options.BuffTracking.OnlyMine"],
                desc = L["Options.BuffTracking.OnlyMine.Desc"],
            },
            {
                value = "self_only",
                label = L["Options.BuffTracking.SelfOnly"],
                desc = L["Options.BuffTracking.SelfOnly.Desc"],
            },
            {
                value = "smart",
                label = L["Options.BuffTracking.Smart"],
                desc = L["Options.BuffTracking.Smart.Desc"],
            },
        },
        get = function()
            return BR.Config.Get("buffTrackingMode")
        end,
        tooltip = {
            title = L["Options.BuffTracking.Mode"],
            desc = L["Options.BuffTracking.Mode.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("buffTrackingMode", val)
            UpdateDisplay()
            Components.RefreshAll()
        end,
    })
    layout:Add(trackingModeHolder, nil, COMPONENT_GAP)
end

-- Per-context override dropdowns share one option list: "Default" (no override)
-- plus the narrowing modes. Overrides only ever narrow the base mode, so wider
-- modes ("all"/"smart") are intentionally omitted.
local function OverrideOptions()
    return {
        { value = "default", label = L["Options.BuffTracking.Override.Default"] },
        {
            value = "my_buffs",
            label = L["Options.BuffTracking.MyBuffs"],
            desc = L["Options.BuffTracking.MyBuffs.Desc"],
        },
        {
            value = "personal",
            label = L["Options.BuffTracking.OnlyMine"],
            desc = L["Options.BuffTracking.OnlyMine.Desc"],
        },
        {
            value = "self_only",
            label = L["Options.BuffTracking.SelfOnly"],
            desc = L["Options.BuffTracking.SelfOnly.Desc"],
        },
    }
end

local function BuildTrackingOverridesSection(content, layout)
    LayoutSectionHeader(layout, content, L["Section.TrackingOverrides"])
    LayoutSectionNote(layout, content, L["Section.TrackingOverrides.Desc"])

    -- Shared label column so all three override dropdowns line up vertically.
    local overrideLW = Components.MeasureSharedLabelWidth({
        L["Options.BuffTracking.Override.OutsideInstances"],
        L["Options.BuffTracking.Override.Combat"],
        L["Options.BuffTracking.Override.Leveling"],
    })

    local function OverrideDropdown(cfg)
        local holder = Components.Dropdown(content, {
            label = cfg.label,
            labelWidth = overrideLW,
            width = 220,
            options = OverrideOptions(),
            tooltip = cfg.tooltip,
            get = function()
                return BR.Config.Get(cfg.path)
            end,
            enabled = cfg.enabled,
            disabledReason = cfg.disabledReason,
            onChange = function(val)
                BR.Config.Set(cfg.path, val)
            end,
        })
        layout:Add(holder, nil, COMPONENT_GAP)
    end

    OverrideDropdown({
        label = L["Options.BuffTracking.Override.OutsideInstances"],
        path = "outsideInstancesMode",
        tooltip = {
            title = L["Options.BuffTracking.Override.OutsideInstances"],
            desc = L["Options.BuffTracking.Override.OutsideInstances.Desc"],
        },
    })

    OverrideDropdown({
        label = L["Options.BuffTracking.Override.Combat"],
        path = "combatMode",
        tooltip = {
            title = L["Options.BuffTracking.Override.Combat"],
            desc = L["Options.BuffTracking.Override.Combat.Desc"],
        },
        -- Narrowing in combat is moot if the whole display already hides in combat.
        enabled = function()
            return BR.profile.hideInCombat ~= true
        end,
        disabledReason = L["DisabledReason.CombatOverride"],
    })

    OverrideDropdown({
        label = L["Options.BuffTracking.Override.Leveling"],
        path = "levelingMode",
        tooltip = {
            title = L["Options.BuffTracking.Override.Leveling"],
            desc = L["Options.BuffTracking.Override.Leveling.Desc"],
        },
        -- Likewise moot if the display already hides entirely while leveling.
        enabled = function()
            return BR.profile.hideWhileLeveling ~= true
        end,
        disabledReason = L["DisabledReason.LevelingOverride"],
    })
end

local function Build(content)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    BuildHideWhenSection(content, layout)
    BuildTrackingSection(content, layout)
    BuildTrackingOverridesSection(content, layout)

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.visibility = {
    title = L["Page.Visibility"],
    Build = Build,
}
