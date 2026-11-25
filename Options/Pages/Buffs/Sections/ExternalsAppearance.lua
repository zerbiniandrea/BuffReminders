local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Retail then
    return
end

-- ============================================================================
-- BUFF PAGE SECTION: Externals Appearance
-- ============================================================================
-- The whole body of the Externals tab on the Categories page. Externals are not a
-- real category: they have no categorySettings entry and no State entries. Thus
-- this section is standalone, not a _Template composition, but it follows the
-- template's section order. Blizzard controls the visibility, click-to-cast is
-- impossible on a forbidden button, and growth is container-level flow-layout
-- state with four directions only (the flow layout has no centered growth).
--
-- Icon keys follow the category convention: an Override checkbox gates them.
-- While the override is off, the keys inherit from the global defaults
-- (BR.GetExternalSetting resolves the gate) and render dimmed with the live
-- inherited values. Direction, text and tooltips have no `defaults`
-- counterpart, so they ignore the override.
--
-- This section is terminal: it owns the tab frame's height.

local L = BR.L
local Components = BR.Components

local Helpers = BR.Options.Helpers
local LayoutSectionHeader = Helpers.LayoutSectionHeader
local LayoutSectionNote = Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

-- Keys copied into the externals table when the override turns on.
local SNAPSHOT_KEYS = { "iconSize", "iconWidth", "iconZoom", "borderSize", "iconAlpha", "spacing" }

-- Room after the caster name label for the what's-new dot.
local DOT_ROOM = 14

local Settings = BR.GetExternalSettings
local Setting = BR.GetExternalSetting
local IsEnabled = BR.AreExternalsEnabled

local function IsOverriding()
    return Settings().useCustomAppearance == true
end

local function InheritedEnabled()
    return IsEnabled() and IsOverriding()
end

local function IsInheriting()
    return not IsOverriding()
end

local function IsCasterNameShown()
    return Setting("showCasterName") == true
end

local function BuildLayout(parent, layout)
    LayoutSectionHeader(layout, parent, L["Options.Layout"])
    LayoutSectionNote(layout, parent, L["Externals.AppearanceNote"])

    local dirHolder = Components.Dropdown(parent, {
        label = L["Direction.Label"],
        options = {
            { label = L["Direction.Right"], value = "RIGHT" },
            { label = L["Direction.Left"], value = "LEFT" },
            { label = L["Direction.Up"], value = "UP" },
            { label = L["Direction.Down"], value = "DOWN" },
        },
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        get = function()
            return Setting("growDirection") or "RIGHT"
        end,
        onChange = function(dir)
            BR.Config.Set("externals.growDirection", dir)
        end,
    })
    layout:Add(dirHolder, nil, COMPONENT_GAP)
end

local function BuildAppearance(parent, layout)
    LayoutSectionHeader(layout, parent, L["Options.Appearance"])

    Helpers.AddOverrideRow(parent, layout, {
        get = IsOverriding,
        desc = L["Options.Override.Externals.Desc"],
        defaultsLink = true,
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        onChange = function(checked)
            if checked then
                -- Snapshot the effective values before the flag flips, so the
                -- display does not jump. The category nil-fill pattern does not
                -- work here: the externals keys are always seeded, so a stored
                -- value is not proof of a deliberate customization.
                local snapshot = {}
                for _, key in ipairs(SNAPSHOT_KEYS) do
                    snapshot[key] = Setting(key)
                end
                BR.Config.Set("externals.iconWidth", snapshot.iconWidth) -- nil = square
                BR.Config.SetMulti({
                    ["externals.iconSize"] = snapshot.iconSize or 40,
                    ["externals.iconZoom"] = snapshot.iconZoom or 0,
                    ["externals.borderSize"] = snapshot.borderSize or 2,
                    ["externals.iconAlpha"] = snapshot.iconAlpha or 1,
                    ["externals.spacing"] = snapshot.spacing or 4,
                })
            end
            BR.Config.Set("externals.useCustomAppearance", checked)
            Components.RefreshAll()
        end,
    })

    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.Icons"])
    local gridFrame = CreateFrame("Frame", nil, parent)
    layout:Add(gridFrame, 0)
    local grid = Components.AppearanceGrid(gridFrame, {
        get = function(key, default)
            local value = Setting(key)
            if value == nil then
                return default
            end
            return value
        end,
        set = function(key, value)
            BR.Config.Set("externals." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["externals." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = function()
            return Setting("iconWidth") == nil
        end,
        onLink = function()
            BR.Config.Set("externals.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            BR.Config.Set("externals.iconWidth", Setting("iconSize") or 40)
            Components.RefreshAll()
        end,
        enabled = InheritedEnabled,
        inherited = IsInheriting,
        disabledReason = function()
            if not IsEnabled() then
                return L["Externals.NoneTracked"]
            end
            return L["DisabledReason.OverrideSection"]
        end,
        zoomMax = 40,
    })
    gridFrame:SetSize(480, grid.height)
    layout:Space(grid.height)
end

local function BuildOverlays(parent, layout)
    LayoutSectionHeader(layout, parent, L["Options.TextOverlays"])

    local labelWidth = Components.MeasureSharedLabelWidth({
        L["Externals.Countdown"],
        L["Externals.CasterName"],
    }) + DOT_ROOM

    local _, _, countdownLast = Helpers.LayoutTextRow(layout, parent, {
        label = L["Externals.Countdown"],
        labelWidth = labelWidth,
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        size = {
            min = 8,
            max = 32,
            get = function()
                return Setting("durationSize") or 16
            end,
            set = function(value)
                BR.Config.Set("externals.durationSize", value)
            end,
        },
    })

    -- "Off" stands for showCasterName = false, so the row needs no checkbox.
    local _, sideHolder = Helpers.LayoutTextRow(layout, parent, {
        label = L["Externals.CasterName"],
        labelWidth = labelWidth,
        list = {
            options = {
                { label = L["Options.Off"], value = "OFF" },
                { label = L["Options.SubIconSide.Bottom"], value = "BOTTOM" },
                { label = L["Options.SubIconSide.Top"], value = "TOP" },
                { label = L["Options.SubIconSide.Left"], value = "LEFT" },
                { label = L["Options.SubIconSide.Right"], value = "RIGHT" },
            },
            get = function()
                if not IsCasterNameShown() then
                    return "OFF"
                end
                return Setting("casterNamePosition") or "BOTTOM"
            end,
            set = function(value)
                if value == "OFF" then
                    BR.Config.Set("externals.showCasterName", false)
                else
                    BR.Config.SetMulti({
                        ["externals.showCasterName"] = true,
                        ["externals.casterNamePosition"] = value,
                    })
                end
                Components.RefreshAll()
            end,
        },
        tooltip = { title = L["Externals.CasterName"], desc = L["Externals.CasterName.Desc"] },
        isOff = function()
            return not IsCasterNameShown()
        end,
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        size = {
            min = 6,
            max = 40,
            get = function()
                return Setting("casterNameSize") or 12
            end,
            set = function(value)
                BR.Config.Set("externals.casterNameSize", value)
            end,
        },
        offsets = {
            min = -50,
            max = 50,
            getX = function()
                return Setting("casterNameOffsetX") or 0
            end,
            setX = function(value)
                BR.Config.Set("externals.casterNameOffsetX", value)
            end,
            getY = function()
                return Setting("casterNameOffsetY") or 0
            end,
            setY = function(value)
                BR.Config.Set("externals.casterNameOffsetY", value)
            end,
        },
    })
    BR.Options.WhatsNew.AttachDot(sideHolder.label, "externals.casterName")

    -- The swipe belongs to the countdown, so it shares the countdown row.
    local swipeHolder = Components.Checkbox(parent, {
        label = L["Externals.ShowSwipe"],
        tooltip = { title = L["Externals.ShowSwipe"], desc = L["Externals.ShowSwipe.Desc"] },
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        get = function()
            return Setting("showSwipe") ~= false
        end,
        onChange = function(checked)
            BR.Config.Set("externals.showSwipe", checked)
        end,
    })
    swipeHolder:SetPoint("LEFT", countdownLast, "RIGHT", 14, 0)
end

local function BuildInteraction(parent, layout)
    LayoutSectionHeader(layout, parent, L["Options.Interaction"])

    local tooltipHolder = Components.Checkbox(parent, {
        label = L["Externals.ShowTooltips"],
        tooltip = { title = L["Externals.ShowTooltips"], desc = L["Externals.ShowTooltips.Desc"] },
        enabled = IsEnabled,
        disabledReason = L["Externals.NoneTracked"],
        get = function()
            return Setting("showTooltips") == true
        end,
        onChange = function(checked)
            BR.Config.Set("externals.showTooltips", checked)
        end,
    })
    layout:Add(tooltipHolder, nil, COMPONENT_GAP)
end

local function Build(ctx, layout)
    local parent = ctx.content

    BuildLayout(parent, layout)
    BuildAppearance(parent, layout)
    BuildOverlays(parent, layout)
    BuildInteraction(parent, layout)

    parent:SetHeight(math.abs(layout:GetY()) + (ctx.appearancePadding or 30))
    if ctx.onAppearanceResize then
        ctx.onAppearanceResize()
    end
end

BR.Options.BuffSections.ExternalsAppearance = Build

BR.Options.WhatsNew.Register({ cohort = "6.10.0", pageId = "categories", key = "externals.casterName" })
