local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Item Display (consumable category only)
-- ============================================================================
-- Display mode (icon_only/sub_icons/expanded) with live preview and the
-- sub-icon side selector. The file also exports the consumable text rows (Text &
-- overlays) and the item filters (the Items subsection of Visibility).

local L = BR.L
local Components = BR.Components

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local Helpers = BR.Options.Helpers
local LayoutSectionHeader = Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DEPENDENT_INDENT = BR.Options.Constants.DEPENDENT_INDENT

local function Build(ctx, layout)
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.ItemDisplay"])
    layout:Space(COMPONENT_GAP)

    local updateDisplayModePreview
    local updateBadgeVisibility
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
            if updateBadgeVisibility then
                updateBadgeVisibility(val)
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
    local previewTextures = BR.ConsumableData.previewTextures
    local TEX_FLASK = previewTextures.flask
    local TEX_FOOD = previewTextures.food
    local TEX_OIL = previewTextures.oil

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

    -- Only the Sub-icons mode draws sub-icons, so its option shares the mode row
    -- and hides in the other modes.
    local badgeOnSubIconsHolder = Components.Checkbox(parent, {
        label = L["Options.ConsumableBadgeOnSubIcons"],
        get = function()
            return BR.Config.Get("defaults.consumableBadgeOnSubIcons") == true
        end,
        tooltip = {
            title = L["Options.ConsumableBadgeOnSubIcons.Title"],
            desc = L["Options.ConsumableBadgeOnSubIcons.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.consumableBadgeOnSubIcons", checked)
        end,
    })
    -- Level with the mode dropdown: the preview is taller than the row.
    badgeOnSubIconsHolder:SetPoint("LEFT", previewHolder, "TOPRIGHT", 12, -displayModeHolder:GetHeight() / 2)

    updateBadgeVisibility = function(mode)
        local subIcons = mode == "sub_icons"
        badgeOnSubIconsHolder:SetShown(subIcons and BR.ConsumableData.features.itemLabels)
    end
    updateBadgeVisibility(BR.Config.Get("defaults.consumableDisplayMode"))
    table.insert(BR.RefreshableComponents, {
        Refresh = function()
            updateBadgeVisibility(BR.Config.Get("defaults.consumableDisplayMode"))
        end,
    })
end

---Text & overlays rows for the consumable icons: base size, then one row per
---text element. Every key is global, because only this category draws them.
local function BuildOverlays(ctx, layout)
    local parent = ctx.content

    local consumableTextScaleHolder = Components.Slider(parent, {
        label = L["Options.ConsumableTextScale"],
        labelWidth = ctx.overlayLabelWidth,
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

    local labelWidth = ctx.overlayLabelWidth

    local function FormatSize(val)
        return val == 0 and L["Options.Auto"] or (val .. "%")
    end

    ---@param item string
    ---@param label string
    ---@param off? TextOffToggle
    local function TextItemRow(item, label, off)
        Helpers.LayoutTextRow(layout, parent, {
            label = label,
            labelWidth = labelWidth,
            zone = {
                get = function()
                    return select(1, BR.TextPositions.Get(item))
                end,
                set = function(zone)
                    BR.Config.Set("defaults.textPositions." .. item .. ".zone", zone)
                end,
                off = off,
            },
            isOff = off and off.get or nil,
            -- 0 is the inherit sentinel: it stores nil, so the item follows the base size.
            size = {
                min = 0,
                max = 80,
                format = FormatSize,
                get = function()
                    return BR.TextPositions.GetSizeOverride(item) or 0
                end,
                set = function(val)
                    BR.Config.Set("defaults.textSizes." .. item, val > 0 and val or nil)
                end,
            },
            offsets = {
                min = -40,
                max = 40,
                getX = function()
                    local _, x = BR.TextPositions.Get(item)
                    return x
                end,
                setX = function(val)
                    BR.Config.Set("defaults.textPositions." .. item .. ".offsetX", val)
                end,
                getY = function()
                    local _, _, y = BR.TextPositions.Get(item)
                    return y
                end,
                setY = function(val)
                    BR.Config.Set("defaults.textPositions." .. item .. ".offsetY", val)
                end,
            },
        })
    end

    if BR.ConsumableData.features.itemLabels then
        -- "Off" on the stat label row is the stored hideConsumableLabels flag.
        TextItemRow("statLabel", L["Options.TextPositions.StatLabel"], {
            get = function()
                return BR.Config.Get("defaults.hideConsumableLabels") == true
            end,
            set = function(off)
                BR.Config.Set("defaults.hideConsumableLabels", off)
            end,
        })
        TextItemRow("badge", L["Options.TextPositions.Badge"])
    end

    TextItemRow("stackCount", L["Options.TextPositions.StackCount"])
    Helpers.LayoutSubsectionNote(layout, parent, L["Options.TextSizes.Note"])
end

---Items subsection of Visibility: which consumables show.
local function BuildFilters(ctx, layout)
    local parent = ctx.content

    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.ItemFilters"])

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

    layout:SetX(layout:GetX() + DEPENDENT_INDENT)
    local readyCheckOnlyHolder = Components.Checkbox(parent, {
        label = L["Options.ShowWithoutItemsReadyCheckOnly"],
        get = function()
            return BR.Config.Get("defaults.showWithoutItemsOnlyOnReadyCheck") == true
        end,
        enabled = function()
            return BR.Config.Get("defaults.showConsumablesWithoutItems") == true
        end,
        disabledReason = L["DisabledReason.ShowWithoutItems"],
        tooltip = {
            title = L["Options.ShowWithoutItemsReadyCheckOnly.Title"],
            desc = L["Options.ShowWithoutItemsReadyCheckOnly.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.showWithoutItemsOnlyOnReadyCheck", checked)
        end,
    })
    layout:Add(readyCheckOnlyHolder, nil, COMPONENT_GAP)
    layout:SetX(layout:GetX() - DEPENDENT_INDENT)

    if BR.ConsumableData.features.delveFood then
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
    end

    if BR.ConsumableData.features.legacyItems then
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
end

BR.Options.BuffSections.ItemDisplay = Build
BR.Options.BuffSections.ItemOverlays = BuildOverlays
BR.Options.BuffSections.ConsumableFilters = BuildFilters
