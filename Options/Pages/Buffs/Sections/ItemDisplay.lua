local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Item Display (consumable category only)
-- ============================================================================
-- Hide labels, text scale, display mode (icon_only/sub_icons/expanded) with
-- live preview, sub-icon side selector, and behavior toggles.

local L = BR.L
local Components = BR.Components

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local Helpers = BR.Options.Helpers
local LayoutSectionHeader = Helpers.LayoutSectionHeader
local MakeCategoryGetter = Helpers.MakeCategoryGetter
local MakeCategorySetter = Helpers.MakeCategorySetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.ItemDisplay"])
    layout:Space(COMPONENT_GAP)

    local updateDisplayModePreview
    local updateSubIconSideVisibility
    local displayModeHolder = Components.Dropdown(parent, {
        label = L["Options.ItemDisplay"],
        get = function()
            return BR.Config.Get("defaults.consumableDisplayMode")
        end,
        options = {
            {
                value = "icon_only",
                label = L["Options.ItemDisplay.IconOnly"],
                desc = L["Options.ItemDisplay.IconOnlyDesc"],
            },
            {
                value = "sub_icons",
                label = L["Options.ItemDisplay.SubIcons"],
                desc = L["Options.ItemDisplay.SubIconsDesc"],
            },
            {
                value = "expanded",
                label = L["Options.ItemDisplay.Expanded"],
                desc = L["Options.ItemDisplay.ExpandedDesc"],
            },
        },
        tooltip = {
            title = L["Options.ItemDisplay.Mode"],
            desc = L["Options.ItemDisplay.Mode.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("defaults.consumableDisplayMode", val)
            if updateDisplayModePreview then
                updateDisplayModePreview(val)
            end
            if updateSubIconSideVisibility then
                updateSubIconSideVisibility(val)
            end
            -- The badge-on-sub-icons toggle is enabled only in sub_icons mode,
            -- so its gate must re-evaluate.
            Components.RefreshAll()
        end,
    })
    layout:Add(displayModeHolder, nil, COMPONENT_GAP)

    local P_ICON = 24
    local P_SUB = 12
    local P_BORDER = 2
    local P_GAP = 3
    local P_STEP = P_ICON + P_GAP + P_BORDER * 2
    local P_SUB_STEP = P_SUB + P_BORDER * 2
    local TEX_FLASK = { 7548898, 7548899, 7548900 }
    local TEX_FOOD = { 4672193, 1045939 }
    local TEX_OIL = 7548987

    local previewHeight = P_ICON + P_SUB + P_GAP + P_BORDER * 2
    local MODE_ICON_COUNT = { icon_only = 3, sub_icons = 3, expanded = 6 }

    local previewHolder = CreateFrame("Frame", nil, parent)
    previewHolder:SetSize(3 * P_STEP, previewHeight)
    previewHolder:SetPoint("TOPLEFT", displayModeHolder, "TOPRIGHT", 12, 0)

    local previewContainer = CreateFrame("Frame", nil, previewHolder)
    previewContainer:SetPoint("TOPLEFT", 0, 0)
    previewContainer:SetSize(6 * P_STEP, previewHeight)
    previewContainer:SetAlpha(0.7)

    local function CreatePreviewIcon(parentFrame, texture, size)
        local f = CreateFrame("Frame", nil, parentFrame)
        f:SetSize(size, size)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
        f.icon:SetTexture(texture)
        local z = TEXCOORD_INSET
        f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetColorTexture(0, 0, 0, 1)
        f.border:SetPoint("TOPLEFT", -P_BORDER, P_BORDER)
        f.border:SetPoint("BOTTOMRIGHT", P_BORDER, -P_BORDER)
        return f
    end

    local allPreviewFrames = {}

    local iconOnlyFrames = {}
    local iconOnlyTextures = { TEX_FLASK[1], TEX_FOOD[1], TEX_OIL }
    for i = 1, 3 do
        local f = CreatePreviewIcon(previewContainer, iconOnlyTextures[i], P_ICON)
        f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
        f:Hide()
        iconOnlyFrames[i] = f
        allPreviewFrames[#allPreviewFrames + 1] = f
    end

    local subIconsFrames = { mains = {}, subs = {} }
    local subVariants = { TEX_FLASK, TEX_FOOD, {} }
    for i, variants in ipairs(subVariants) do
        local mainTex = (#variants > 0) and variants[1] or TEX_OIL
        local main = CreatePreviewIcon(previewContainer, mainTex, P_ICON)
        main:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
        main:Hide()
        subIconsFrames.mains[i] = main
        allPreviewFrames[#allPreviewFrames + 1] = main
        if #variants > 1 then
            local subCount = #variants - 1
            local subRowWidth = (subCount - 1) * P_SUB_STEP + P_SUB
            local subOffsetX = (P_ICON - subRowWidth) / 2
            for j = 2, #variants do
                local sub = CreatePreviewIcon(previewContainer, variants[j], P_SUB)
                sub:SetPoint("TOPLEFT", main, "BOTTOMLEFT", subOffsetX + (j - 2) * P_SUB_STEP, -P_GAP)
                sub:Hide()
                subIconsFrames.subs[#subIconsFrames.subs + 1] = sub
                allPreviewFrames[#allPreviewFrames + 1] = sub
            end
        end
    end

    local expandedFrames = {}
    local expandedTextures = {
        TEX_FLASK[1],
        TEX_FLASK[2],
        TEX_FLASK[3],
        TEX_FOOD[1],
        TEX_FOOD[2],
        TEX_OIL,
    }
    for i = 1, 6 do
        local f = CreatePreviewIcon(previewContainer, expandedTextures[i], P_ICON)
        f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
        f:Hide()
        expandedFrames[i] = f
        allPreviewFrames[#allPreviewFrames + 1] = f
    end

    local subIconsAll = {}
    for _, f in ipairs(subIconsFrames.mains) do
        subIconsAll[#subIconsAll + 1] = f
    end
    for _, f in ipairs(subIconsFrames.subs) do
        subIconsAll[#subIconsAll + 1] = f
    end

    local MODE_FRAMES = {
        icon_only = iconOnlyFrames,
        sub_icons = subIconsAll,
        expanded = expandedFrames,
    }
    updateDisplayModePreview = function(mode)
        for _, f in ipairs(allPreviewFrames) do
            f:Hide()
        end
        local shown = MODE_FRAMES[mode]
        if shown then
            for _, f in ipairs(shown) do
                f:Show()
            end
        end
        previewHolder:SetWidth((MODE_ICON_COUNT[mode] or 3) * P_STEP)
    end

    updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode"))

    function previewHolder:Refresh()
        updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode"))
    end
    table.insert(BR.RefreshableComponents, previewHolder)

    local subIconSideHolder = Components.Dropdown(parent, {
        label = L["Options.SubIconSide"],
        labelWidth = 30,
        width = 85,
        get = MakeCategoryGetter(category, "subIconSide", "BOTTOM"),
        options = {
            { value = "BOTTOM", label = L["Options.SubIconSide.Bottom"] },
            { value = "TOP", label = L["Options.SubIconSide.Top"] },
            { value = "LEFT", label = L["Options.SubIconSide.Left"] },
            { value = "RIGHT", label = L["Options.SubIconSide.Right"] },
        },
        onChange = MakeCategorySetter(category, "subIconSide"),
    })
    subIconSideHolder:SetPoint("TOPLEFT", previewHolder, "TOPRIGHT", 12, 0)

    updateSubIconSideVisibility = function(mode)
        subIconSideHolder:SetShown(mode == "sub_icons")
    end
    updateSubIconSideVisibility(BR.Config.Get("defaults.consumableDisplayMode"))

    -- The hide-stat-labels checkbox gates the Stat label position row. Keep the
    -- checkbox directly above that row, so the dependency stays visible.
    layout:Space(SECTION_GAP)
    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.TextPositions"])

    local consumableTextScaleHolder = Components.Slider(parent, {
        label = L["Options.ConsumableTextScale"],
        min = 5,
        max = 80,
        step = 1,
        suffix = "%",
        get = function()
            return BR.Config.Get("defaults.consumableTextScale")
        end,
        tooltip = {
            title = L["Options.ConsumableTextScale.Title"],
            desc = L["Options.ConsumableTextScale.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("defaults.consumableTextScale", val)
        end,
    })
    layout:Add(consumableTextScaleHolder, nil, COMPONENT_GAP)

    local function statLabelsShown()
        return not BR.Config.Get("defaults.hideConsumableLabels")
    end

    local hideConsumableLabelsHolder = Components.Checkbox(parent, {
        label = L["Options.HideConsumableLabels"],
        get = function()
            return BR.Config.Get("defaults.hideConsumableLabels")
        end,
        tooltip = {
            title = L["Options.HideConsumableLabels.Title"],
            desc = L["Options.HideConsumableLabels.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.hideConsumableLabels", checked)
            -- Re-evaluate the stat label row's enabled gate.
            Components.RefreshAll()
        end,
    })
    layout:Add(hideConsumableLabelsHolder, nil, COMPONENT_GAP)

    local badgeOnSubIconsHolder = Components.Checkbox(parent, {
        label = L["Options.ConsumableBadgeOnSubIcons"],
        get = function()
            return BR.Config.Get("defaults.consumableBadgeOnSubIcons") == true
        end,
        enabled = function()
            return BR.Config.Get("defaults.consumableDisplayMode") == "sub_icons"
        end,
        disabledReason = L["Options.ConsumableBadgeOnSubIcons.Disabled"],
        tooltip = {
            title = L["Options.ConsumableBadgeOnSubIcons.Title"],
            desc = L["Options.ConsumableBadgeOnSubIcons.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.consumableBadgeOnSubIcons", checked)
        end,
    })
    layout:Add(badgeOnSubIconsHolder, nil, COMPONENT_GAP)

    -- One row per text item: name, placement, then size in a fixed right-hand
    -- column. The four controls only fit the page at these widths, so trim the
    -- zone dropdowns and the offset tracks before adding anything to the row.
    local ROW_ITEM_LABEL_W = 78
    local ROW_ZONE_VERTICAL_W = 92
    local ROW_ZONE_ALIGN_W = 66
    local ROW_OFFSET_TRACK_W = 48
    local ROW_SIZE_LABEL_W = 30

    local function FormatSize(val)
        return val == 0 and L["Options.Auto"] or (val .. "%")
    end

    local function buildTextItemRow(item, label, enabled)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(parent:GetWidth(), 26)

        -- Only the stat label row is gated, so only it carries a reason.
        local reason = enabled and L["DisabledReason.StatLabelsHidden"] or nil

        local picker = Components.ZonePicker(row, {
            label = label,
            labelWidth = ROW_ITEM_LABEL_W,
            verticalWidth = ROW_ZONE_VERTICAL_W,
            alignWidth = ROW_ZONE_ALIGN_W,
            enabled = enabled,
            disabledReason = reason,
            get = function()
                return select(1, BR.TextPositions.Get(item))
            end,
            onChange = function(zone)
                BR.Config.Set("defaults.textPositions." .. item .. ".zone", zone)
            end,
        })
        picker:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

        local offsetX = Components.Slider(row, {
            label = L["Options.TextPositions.OffsetX.Short"],
            labelWidth = 12,
            sliderWidth = ROW_OFFSET_TRACK_W,
            min = -40,
            max = 40,
            enabled = enabled,
            disabledReason = reason,
            get = function()
                local _, x = BR.TextPositions.Get(item)
                return x
            end,
            onChange = function(val)
                BR.Config.Set("defaults.textPositions." .. item .. ".offsetX", val)
            end,
        })
        offsetX:SetPoint("LEFT", picker, "RIGHT", 10, 0)

        local offsetY = Components.Slider(row, {
            label = L["Options.TextPositions.OffsetY.Short"],
            labelWidth = 12,
            sliderWidth = ROW_OFFSET_TRACK_W,
            min = -40,
            max = 40,
            enabled = enabled,
            disabledReason = reason,
            get = function()
                local _, _, y = BR.TextPositions.Get(item)
                return y
            end,
            onChange = function(val)
                BR.Config.Set("defaults.textPositions." .. item .. ".offsetY", val)
            end,
        })
        offsetY:SetPoint("LEFT", offsetX, "RIGHT", 8, 0)

        -- 0 is the inherit sentinel: it stores nil, so the item follows the base size.
        local size = Components.NumericStepper(row, {
            label = L["Options.TextPositions.Size"],
            labelWidth = ROW_SIZE_LABEL_W,
            min = 0,
            max = 80,
            step = 1,
            formatValue = FormatSize,
            enabled = enabled,
            disabledReason = reason,
            get = function()
                return BR.TextPositions.GetSizeOverride(item) or 0
            end,
            onChange = function(val)
                BR.Config.Set("defaults.textSizes." .. item, val > 0 and val or nil)
            end,
        })
        size:SetPoint("LEFT", offsetY, "RIGHT", 10, 0)

        layout:Add(row, 26, COMPONENT_GAP)
    end

    buildTextItemRow("statLabel", L["Options.TextPositions.StatLabel"], statLabelsShown)
    buildTextItemRow("badge", L["Options.TextPositions.Badge"])
    buildTextItemRow("stackCount", L["Options.TextPositions.StackCount"])
    Helpers.LayoutSubsectionNote(layout, parent, L["Options.TextSizes.Note"])

    -- Behavior holds the visibility and filter controls (which consumables show).
    -- Item Display holds the appearance controls (how each icon looks).
    LayoutSectionHeader(layout, parent, L["Options.Behavior"])

    local showWithoutItemsHolder = Components.Checkbox(parent, {
        label = L["Options.ShowWithoutItems"],
        get = function()
            return BR.Config.Get("defaults.showConsumablesWithoutItems") == true
        end,
        tooltip = {
            title = L["Options.ShowWithoutItems.Title"],
            desc = L["Options.ShowWithoutItems.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.showConsumablesWithoutItems", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(showWithoutItemsHolder, nil, COMPONENT_GAP)

    local SHOW_WITHOUT_INDENT = 12
    layout:SetX(layout:GetX() + SHOW_WITHOUT_INDENT)
    local readyCheckOnlyHolder = Components.Checkbox(parent, {
        label = L["Options.ShowWithoutItemsReadyCheckOnly"],
        get = function()
            return BR.Config.Get("defaults.showWithoutItemsOnlyOnReadyCheck") == true
        end,
        enabled = function()
            return BR.Config.Get("defaults.showConsumablesWithoutItems") == true
        end,
        tooltip = {
            title = L["Options.ShowWithoutItemsReadyCheckOnly.Title"],
            desc = L["Options.ShowWithoutItemsReadyCheckOnly.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.showWithoutItemsOnlyOnReadyCheck", checked)
        end,
    })
    layout:Add(readyCheckOnlyHolder, nil, COMPONENT_GAP)
    layout:SetX(layout:GetX() - SHOW_WITHOUT_INDENT)

    local delveFoodOnlyHolder = Components.Checkbox(parent, {
        label = L["Options.DelveFoodOnly"],
        get = function()
            return BR.Config.Get("defaults.delveFoodOnly") == true
        end,
        tooltip = {
            title = L["Options.DelveFoodOnly"],
            desc = L["Options.DelveFoodOnly.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.delveFoodOnly", checked)
        end,
    })
    layout:Add(delveFoodOnlyHolder, nil, COMPONENT_GAP)

    local hideLegacyHolder = Components.Checkbox(parent, {
        label = L["Options.HideLegacyConsumables"],
        get = function()
            return BR.Config.Get("defaults.hideLegacyConsumables") ~= false
        end,
        tooltip = {
            title = L["Options.HideLegacyConsumables.Title"],
            desc = L["Options.HideLegacyConsumables.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.hideLegacyConsumables", checked)
        end,
    })
    layout:Add(hideLegacyHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.ItemDisplay = Build
