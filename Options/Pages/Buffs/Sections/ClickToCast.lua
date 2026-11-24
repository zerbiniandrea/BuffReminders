local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Interaction
-- ============================================================================
-- What the mouse does: click to cast and the options it gates, at one indent,
-- then the buff tooltips, which work without it.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategoryGetter = Helpers.MakeCategoryGetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DEPENDENT_INDENT = BR.Options.Constants.DEPENDENT_INDENT

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.Interaction"])

    local function isClickable()
        return GetCategorySetting(category, "clickable", false) == true
    end

    local clickableHolder = Components.Checkbox(parent, {
        label = L["Options.ClickToCast"],
        get = isClickable,
        tooltip = {
            title = L["Options.ClickToCast"],
            desc = L["Options.ClickToCast.DescFull"],
        },
        onChange = function(checked)
            Helpers.SetCategorySetting(category, "clickable", checked)
            BR.SecureButtons.UpdateActionButtons(category)
            Components.RefreshAll()
        end,
    })
    layout:Add(clickableHolder, nil, COMPONENT_GAP)

    local baseX = layout:GetX()
    layout:SetX(baseX + DEPENDENT_INDENT)
    local highlightHolder = Components.Checkbox(parent, {
        label = L["Options.HoverHighlight"],
        get = MakeCategoryGetter(category, "clickableHighlight", true),
        enabled = isClickable,
        disabledReason = L["DisabledReason.ClickToCast"],
        tooltip = {
            title = L["Options.HoverHighlight"],
            desc = L["Options.HoverHighlight.Desc"],
        },
        onChange = function(checked)
            Helpers.SetCategorySetting(category, "clickableHighlight", checked)
            BR.SecureButtons.UpdateActionButtons(category)
        end,
    })
    layout:Add(highlightHolder, nil, COMPONENT_GAP)

    if category == "pet" then
        local specIconHolder = Components.Checkbox(parent, {
            label = L["Options.PetSpecIcon"],
            get = function()
                return BR.Config.Get("defaults.petSpecIconOnHover")
            end,
            enabled = isClickable,
            disabledReason = L["DisabledReason.ClickToCast"],
            tooltip = {
                title = L["Options.PetSpecIcon.Title"],
                desc = L["Options.PetSpecIcon.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.petSpecIconOnHover", checked)
            end,
        })
        layout:Add(specIconHolder, nil, COMPONENT_GAP)
    end

    if category == "consumable" then
        local showTooltipsHolder = Components.Checkbox(parent, {
            label = L["Options.ShowItemTooltips"],
            get = function()
                return BR.Config.Get("defaults.showConsumableTooltips") ~= false
            end,
            enabled = isClickable,
            disabledReason = L["DisabledReason.ClickToCast"],
            tooltip = {
                title = L["Options.ShowItemTooltips"],
                desc = L["Options.ShowItemTooltips.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.showConsumableTooltips", checked)
            end,
        })
        layout:Add(showTooltipsHolder, nil, COMPONENT_GAP)
    end
    layout:SetX(baseX)

    if BR.Display.BUFF_TOOLTIP_CATEGORIES[category] then
        -- The hover tooltip works on the icon frame itself, not on the click
        -- overlay. Thus isClickable does not gate it.
        local showBuffTooltipsHolder = Components.Checkbox(parent, {
            label = L["Options.ShowBuffTooltips"],
            get = function()
                return GetCategorySetting(category, "showBuffTooltips", false) == true
            end,
            tooltip = {
                title = L["Options.ShowBuffTooltips"],
                desc = L["Options.ShowBuffTooltips.Desc"],
            },
            onChange = function(checked)
                Helpers.SetCategorySetting(category, "showBuffTooltips", checked)
            end,
        })
        layout:Add(showBuffTooltipsHolder, nil, COMPONENT_GAP)
    end
end

BR.Options.BuffSections.ClickToCast = Build
