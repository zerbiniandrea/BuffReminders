local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Click-to-Cast
-- ============================================================================
-- Click-to-cast + hover highlight. Pet-only adds the spec icon hover toggle;
-- Consumable-only adds the item-tooltips toggle.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategoryGetter = Helpers.MakeCategoryGetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.ClickToCast"])

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
            BR.Display.UpdateActionButtons(category)
            Components.RefreshAll()
        end,
    })
    layout:Add(clickableHolder, nil, 2)

    layout:SetX(COL_PADDING + 16)
    local highlightHolder = Components.Checkbox(parent, {
        label = L["Options.HoverHighlight"],
        get = MakeCategoryGetter(category, "clickableHighlight", true),
        enabled = isClickable,
        tooltip = {
            title = L["Options.HoverHighlight"],
            desc = L["Options.HoverHighlight.Desc"],
        },
        onChange = function(checked)
            Helpers.SetCategorySetting(category, "clickableHighlight", checked)
            BR.Display.UpdateActionButtons(category)
        end,
    })
    layout:Add(highlightHolder, nil, COMPONENT_GAP)

    if category == "pet" then
        local specIconHolder = Components.Checkbox(parent, {
            label = L["Options.PetSpecIcon"],
            get = function()
                return BR.Config.Get("defaults.petSpecIconOnHover", true)
            end,
            enabled = isClickable,
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
                return BR.Config.Get("defaults.showConsumableTooltips", false) ~= false
            end,
            enabled = isClickable,
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

    layout:SetX(COL_PADDING)
end

BR.Options.BuffSections.ClickToCast = Build
