local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Layout
-- ============================================================================
-- Split-frame toggle + reset-position button. Cross-category display ordering
-- lives on the Defaults page (single ordered list across all non-split
-- categories) since priority is inherently a global decision.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local IsCategorySplit = BR.Helpers.IsCategorySplit

local UpdateVisuals = BR.Display.UpdateVisuals
local ResetCategoryFramePosition = BR.Display.ResetCategoryFramePosition

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local SetCategorySetting = Helpers.SetCategorySetting

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local defaults = BR.defaults

    LayoutSectionHeader(layout, parent, L["Options.Layout"])

    local splitHolder = Components.Checkbox(parent, {
        label = L["Options.SplitFrame"],
        get = function()
            return IsCategorySplit(category)
        end,
        tooltip = {
            title = L["Options.SplitFrame"],
            desc = L["Options.SplitFrame.Desc"],
        },
        onChange = function(checked)
            -- split is registered as FramesReparent in CategorySettingKeys, so the
            -- Set call already fires that event; we only need to redraw visuals.
            SetCategorySetting(category, "split", checked)
            UpdateVisuals()
            -- Re-evaluate dependents: resetBtn (BindEnabled) reads IsCategorySplit,
            -- and the Defaults page's Display Order list re-reads split state.
            Components.RefreshAll()
        end,
    })
    layout:Add(splitHolder, nil, COMPONENT_GAP)

    local resetBtn = CreateButton(parent, L["Options.ResetPosition"], function()
        local catDefaults = defaults.categorySettings[category]
        if catDefaults and catDefaults.position then
            ResetCategoryFramePosition(category, catDefaults.position.x, catDefaults.position.y)
        end
    end)
    resetBtn:SetPoint("LEFT", splitHolder, "RIGHT", 10, 0)
    resetBtn:BindEnabled(function()
        return IsCategorySplit(category)
    end)
    resetBtn:SetDisabledReason(L["DisabledReason.ResetPosition"])
end

BR.Options.BuffSections.Layout = Build
