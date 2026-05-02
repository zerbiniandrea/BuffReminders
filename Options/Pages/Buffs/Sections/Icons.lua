local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Icons
-- ============================================================================
-- Cross-category "Show text" toggle. Raid-only additions (missing-count-only
-- and the BUFF! reminder text knobs) live in Sections/RaidIcons.lua and are
-- composed conditionally by _Template.lua.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategorySetter = Helpers.MakeCategorySetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.Icons"])

    local showTextHolder = Components.Checkbox(parent, {
        label = L["Options.ShowText"],
        get = function()
            return GetCategorySetting(category, "showText", true) ~= false
        end,
        tooltip = {
            title = L["Options.ShowText"],
            desc = L["Options.ShowText.Desc"],
        },
        onChange = MakeCategorySetter(category, "showText"),
    })
    layout:Add(showTextHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.Icons = Build
