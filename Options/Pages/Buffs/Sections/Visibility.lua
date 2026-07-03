local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Visibility
-- ============================================================================
-- Per-category content visibility (W/S/D/R + difficulty filters), the
-- hide-on-PvP-match-start toggle, and the ready-check-only toggle. Each
-- category configures its own visibility right here on its tab, rather than in
-- a separate matrix. The consumable-only "Free Consumables" sub-section lives
-- in its own file (Sections/FreeConsumables.lua) and is composed conditionally
-- by _Template.lua.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local UpdateDisplay = BR.Display.Update

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local MakeCategoryGetter = Helpers.MakeCategoryGetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile

    LayoutSectionHeader(layout, parent, L["Options.Visibility"])

    local function OnCategoryVisibilityChange()
        UpdateDisplay()
    end

    local visToggles = Components.VisibilityToggles(parent, {
        category = category,
        onChange = function()
            OnCategoryVisibilityChange()
            Components.RefreshAll()
        end,
    })
    layout:Add(visToggles, nil, SECTION_GAP)

    local hideInPvPMatchHolder = Components.Checkbox(parent, {
        label = L["Options.HidePvPMatchStart"],
        get = function()
            local vis = db.categoryVisibility and db.categoryVisibility[category]
            return vis and vis.hideInPvPMatch or false
        end,
        enabled = function()
            local vis = db.categoryVisibility and db.categoryVisibility[category]
            return not vis or vis.pvp ~= false
        end,
        disabledReason = L["DisabledReason.PvPDisabled"],
        tooltip = {
            title = L["Options.HidePvPMatchStart.Title"],
            desc = L["Options.HidePvPMatchStart.Desc"],
        },
        onChange = function(checked)
            if not db.categoryVisibility then
                db.categoryVisibility = {}
            end
            if not db.categoryVisibility[category] then
                db.categoryVisibility[category] = {
                    openWorld = true,
                    scenario = true,
                    dungeon = true,
                    raid = true,
                    housing = false,
                    pvp = true,
                    hideInPvPMatch = true,
                }
            end
            db.categoryVisibility[category].hideInPvPMatch = checked
            UpdateDisplay()
        end,
    })
    layout:Add(hideInPvPMatchHolder, nil, COMPONENT_GAP)

    local readyCheckHolder = Components.Checkbox(parent, {
        label = L["Options.ReadyCheckOnly"],
        get = MakeCategoryGetter(category, "showOnlyOnReadyCheck", false),
        tooltip = {
            title = L["Options.ReadyCheckOnly"],
            desc = L["Options.ReadyCheckOnly.Desc"],
        },
        onChange = Helpers.MakeCategorySetter(category, "showOnlyOnReadyCheck"),
    })
    layout:Add(readyCheckHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.Visibility = Build
