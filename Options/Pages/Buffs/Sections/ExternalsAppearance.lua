local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Externals Appearance
-- ============================================================================
-- The whole body of the Externals tab on the Categories page. Externals are not a
-- real category: they have no categorySettings entry and no State entries. Thus
-- this section is standalone, not a _Template composition. No shared section
-- applies: Blizzard controls the visibility, click-to-cast is impossible on a
-- forbidden button, and growth is container-level flow-layout state with four
-- directions only (the flow layout has no centered growth).
--
-- Appearance keys follow the category convention: an Override checkbox gates them.
-- While the override is off, the keys inherit from the global defaults
-- (BR.GetExternalSetting resolves the gate) and render dimmed with the live
-- inherited values. Countdown size, direction, the swipe and the tooltip toggle
-- have no `defaults` counterpart, so they ignore the override.
--
-- This section is terminal: it owns the tab frame's height.

local L = BR.L
local Components = BR.Components

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA

local SLIDERS = {
    { key = "iconZoom", labelKey = "Appearance.Zoom", min = 0, max = 40, suffix = "%", default = 0, inherited = true },
    {
        key = "borderSize",
        labelKey = "Appearance.Border",
        min = 0,
        max = 8,
        suffix = "px",
        default = 2,
        inherited = true,
    },
    {
        key = "spacing",
        labelKey = "Appearance.Spacing",
        min = 0,
        max = 32,
        suffix = "px",
        default = 4,
        inherited = true,
    },
    { key = "durationSize", labelKey = "Externals.DurationSize", min = 8, max = 32, suffix = "px", default = 16 },
}

-- Keys copied into the externals table when the override turns on.
local SNAPSHOT_KEYS = { "iconSize", "iconWidth", "iconZoom", "borderSize", "iconAlpha", "spacing" }

local Settings = BR.GetExternalSettings
local Setting = BR.GetExternalSetting
local IsEnabled = BR.AreExternalsEnabled

local function IsOverriding()
    return Settings().useCustomAppearance == true
end

local function InheritedEnabled()
    return IsEnabled() and IsOverriding()
end

local function InheritedDisabledReason()
    if not IsEnabled() then
        return L["Externals.NoneTracked"]
    end
    return L["DisabledReason.OverrideSection"]
end

---Override checkbox + live inheritance state label, matching CustomAppearance.
local function AddOverrideRow(parent, layout)
    local holder = Components.Checkbox(parent, {
        label = L["Options.Override"],
        get = IsOverriding,
        tooltip = { title = L["Options.Override"], desc = L["Options.Override.Externals.Desc"] },
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

    local stateText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stateText:SetPoint("LEFT", holder.infoIcon or holder.label, "RIGHT", 10, 0)
    local function refreshState()
        if IsOverriding() then
            stateText:SetText(L["Options.Override.Overriding"])
            stateText:SetTextColor(1, 0.82, 0)
        else
            stateText:SetText(L["Options.Override.Inherited"])
            stateText:SetTextColor(0.55, 0.55, 0.55)
        end
    end
    refreshState()
    table.insert(BR.RefreshableComponents, { Refresh = refreshState })

    layout:Add(holder, nil, COMPONENT_GAP)
end

---Width [link] Height on one row, with AppearanceGrid's coupling semantics:
---linked = iconWidth nil (square, one value), unlinked = explicit iconWidth.
local function BuildSizeRow(parent, labelWidth)
    local function isLinked()
        return Setting("iconWidth") == nil
    end

    local row = CreateFrame("Frame", nil, parent)
    local widthHolder, heightHolder

    widthHolder = Components.Slider(row, {
        label = L["Appearance.Width"],
        labelWidth = labelWidth,
        min = 16,
        max = 128,
        step = 1,
        suffix = "px",
        enabled = InheritedEnabled,
        disabledReason = InheritedDisabledReason,
        get = function()
            return Setting("iconWidth") or Setting("iconSize") or 40
        end,
        onChange = function(value)
            BR.Config.Set(isLinked() and "externals.iconSize" or "externals.iconWidth", value)
            if heightHolder then
                heightHolder:Refresh()
            end
        end,
    })
    widthHolder:SetPoint("TOPLEFT")

    local linkBtn = Components.DimensionLink(row, {
        isLinked = isLinked,
        enabled = InheritedEnabled,
        onLink = function()
            BR.Config.Set("externals.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            BR.Config.Set("externals.iconWidth", Setting("iconSize") or 40)
            Components.RefreshAll()
        end,
    })
    linkBtn:SetPoint("LEFT", widthHolder, "RIGHT", 6, 0)

    heightHolder = Components.Slider(row, {
        label = L["Appearance.Height"],
        min = 16,
        max = 128,
        step = 1,
        suffix = "px",
        enabled = InheritedEnabled,
        disabledReason = InheritedDisabledReason,
        get = function()
            return Setting("iconSize") or 40
        end,
        onChange = function(value)
            BR.Config.Set("externals.iconSize", value)
            if widthHolder then
                widthHolder:Refresh()
            end
        end,
    })
    heightHolder:SetPoint("LEFT", linkBtn, "RIGHT", 8, 0)

    row:SetSize(widthHolder:GetWidth() + 6 + linkBtn:GetWidth() + 8 + heightHolder:GetWidth(), 20)
    return row
end

local function Build(ctx, layout)
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Externals.Appearance"])
    LayoutSectionNote(layout, parent, L["Externals.AppearanceNote"])

    AddOverrideRow(parent, layout)

    -- One shared label column so the tracks line up: "Countdown size" is far wider
    -- than "Zoom". Without the shared width, each slider fits its label to its text.
    local labels = { L["Appearance.Width"] }
    for _, spec in ipairs(SLIDERS) do
        labels[#labels + 1] = L[spec.labelKey]
    end
    local labelWidth = Components.MeasureSharedLabelWidth(labels)

    layout:Add(BuildSizeRow(parent, labelWidth), nil, COMPONENT_GAP)

    for _, spec in ipairs(SLIDERS) do
        local key, default = spec.key, spec.default
        local slider = Components.Slider(parent, {
            label = L[spec.labelKey],
            labelWidth = labelWidth,
            min = spec.min,
            max = spec.max,
            step = 1,
            suffix = spec.suffix,
            enabled = spec.inherited and InheritedEnabled or IsEnabled,
            disabledReason = spec.inherited and InheritedDisabledReason or L["Externals.NoneTracked"],
            get = function()
                return Setting(key) or default
            end,
            onChange = function(value)
                BR.Config.Set("externals." .. key, value)
            end,
        })
        layout:Add(slider, nil, COMPONENT_GAP)
    end

    local dirHolder = Components.Dropdown(parent, {
        label = L["Direction.Label"],
        labelWidth = labelWidth,
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
    layout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

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
    layout:Add(swipeHolder, nil, COMPONENT_GAP)

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

    parent:SetHeight(math.abs(layout:GetY()) + (ctx.appearancePadding or 30))
    if ctx.onAppearanceResize then
        ctx.onAppearanceResize()
    end
end

BR.Options.BuffSections.ExternalsAppearance = Build
