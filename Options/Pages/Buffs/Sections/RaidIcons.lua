local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Raid-only Icons add-ons
-- ============================================================================
-- Continues the Icons section for the raid category only: missing-count-only
-- toggle, plus the BUFF! reminder text controls (toggle, size, X/Y offsets).
-- _Template.lua composes it right after Sections.Icons when category=="raid".

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategorySetter = Helpers.MakeCategorySetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local mfloor, mmax = math.floor, math.max

-- The position writes to defaults.textPositions.buffReminder. That key is
-- global because only the raid category renders the buffReminder item.
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

    local reminderPosRow = CreateFrame("Frame", nil, parent)
    reminderPosRow:SetSize(parent:GetWidth(), 26)

    local reminderZone = Components.ZonePicker(reminderPosRow, {
        label = L["Options.TextPositions.Zone"],
        labelWidth = 70,
        get = function()
            return select(1, BR.TextPositions.Get("buffReminder"))
        end,
        enabled = showReminder,
        onChange = function(zone)
            BR.Config.Set("defaults.textPositions.buffReminder.zone", zone)
        end,
    })
    reminderZone:SetPoint("TOPLEFT", reminderPosRow, "TOPLEFT", 0, 0)

    local reminderOffsetX = Components.Slider(reminderPosRow, {
        label = L["Options.TextPositions.OffsetX.Short"],
        labelWidth = 12,
        sliderWidth = 60,
        min = -40,
        max = 40,
        get = function()
            local _, x = BR.TextPositions.Get("buffReminder")
            return x
        end,
        enabled = showReminder,
        onChange = function(val)
            BR.Config.Set("defaults.textPositions.buffReminder.offsetX", val)
        end,
    })
    reminderOffsetX:SetPoint("LEFT", reminderZone, "RIGHT", 12, 0)

    local reminderOffsetY = Components.Slider(reminderPosRow, {
        label = L["Options.TextPositions.OffsetY.Short"],
        labelWidth = 12,
        sliderWidth = 60,
        min = -40,
        max = 40,
        get = function()
            local _, _, y = BR.TextPositions.Get("buffReminder")
            return y
        end,
        enabled = showReminder,
        onChange = function(val)
            BR.Config.Set("defaults.textPositions.buffReminder.offsetY", val)
        end,
    })
    reminderOffsetY:SetPoint("LEFT", reminderOffsetX, "RIGHT", 8, 0)

    layout:Add(reminderPosRow, 26, COMPONENT_GAP)
end

BR.Options.BuffSections.RaidIcons = Build
