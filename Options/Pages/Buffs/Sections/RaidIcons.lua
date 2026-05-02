local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Raid-only Icons add-ons
-- ============================================================================
-- Continues the Icons section for the raid category only: missing-count-only
-- toggle, plus the BUFF! reminder text controls (toggle, size, X/Y offsets).
-- Composed by _Template.lua right after Sections.Icons when category=="raid".
--
-- Lives in its own file (rather than as an `if category == "raid"` branch
-- inside Icons.lua) so the cross-category Icons section stays focused on its
-- shared concern.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategoryGetter = Helpers.MakeCategoryGetter
local MakeCategorySetter = Helpers.MakeCategorySetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local mfloor, mmax = math.floor, math.max

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local parent = ctx.content
    local defaults = BR.defaults

    local function showText()
        return GetCategorySetting("raid", "showText", true) ~= false
    end

    local missingCountHolder = Components.Checkbox(parent, {
        label = L["Options.ShowMissingCountOnly"],
        get = function()
            return BR.profile.showMissingCountOnly == true
        end,
        tooltip = {
            title = L["Options.ShowMissingCountOnly"],
            desc = L["Options.ShowMissingCountOnly.Desc"],
        },
        enabled = showText,
        onChange = function(checked)
            BR.Config.Set("showMissingCountOnly", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(missingCountHolder, nil, COMPONENT_GAP)

    local function showReminder()
        return GetCategorySetting("raid", "showBuffReminder", true) ~= false
    end

    local reminderHolder = Components.Checkbox(parent, {
        label = L["Options.ShowBuffReminderText"],
        get = showReminder,
        onChange = function(checked)
            BR.Config.Set("categorySettings.raid.showBuffReminder", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(reminderHolder, nil, COMPONENT_GAP)

    local buffTextSizeHolder = Components.NumericStepper(reminderHolder, {
        label = L["Options.Size"],
        labelWidth = 28,
        min = 6,
        max = 40,
        get = function()
            local explicit = GetCategorySetting("raid", "buffTextSize", nil)
            if explicit then
                return explicit
            end
            local textSize = GetCategorySetting("raid", "textSize", defaults.defaults.textSize)
            return mmax(6, mfloor(textSize * 0.8))
        end,
        enabled = showReminder,
        onChange = MakeCategorySetter("raid", "buffTextSize"),
    })
    buffTextSizeHolder:SetPoint("LEFT", reminderHolder, "LEFT", 210, 0)

    local buffTextOffsetXHolder = Components.Slider(parent, {
        label = L["Options.BuffTextOffsetX"],
        labelWidth = 60,
        min = -40,
        max = 40,
        get = MakeCategoryGetter("raid", "buffTextOffsetX", 0),
        enabled = showReminder,
        onChange = MakeCategorySetter("raid", "buffTextOffsetX"),
    })

    local buffTextOffsetYHolder = Components.Slider(parent, {
        label = L["Options.BuffTextOffsetY"],
        labelWidth = 60,
        min = -40,
        max = 40,
        get = MakeCategoryGetter("raid", "buffTextOffsetY", 0),
        enabled = showReminder,
        onChange = MakeCategorySetter("raid", "buffTextOffsetY"),
    })

    buffTextOffsetYHolder:SetPoint("LEFT", buffTextOffsetXHolder, "LEFT", 210, 0)
    layout:Add(buffTextOffsetXHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.RaidIcons = Build
