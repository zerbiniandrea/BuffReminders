local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Raid text rows (raid category only)
-- ============================================================================
-- The BUFF! reminder text row of Text & overlays. Its position writes to
-- defaults.textPositions.buffReminder: that key is global, because only the raid
-- category renders the buffReminder item.

local L = BR.L
local Helpers = BR.Options.Helpers

local GetCategorySetting = Helpers.GetCategorySetting

local function Build(ctx, layout)
    local parent = ctx.content
    local defaults = BR.defaults

    local reminderOff = {
        get = function()
            return GetCategorySetting("raid", "showBuffReminder", true) == false
        end,
        set = function(off)
            BR.Config.Set("categorySettings.raid.showBuffReminder", not off)
        end,
    }

    local labelWidth = ctx.overlayLabelWidth
    Helpers.LayoutTextRow(layout, parent, {
        label = L["Options.BuffReminderText"],
        labelWidth = labelWidth,
        zone = {
            get = function()
                return select(1, BR.TextPositions.Get("buffReminder"))
            end,
            set = function(zone)
                BR.Config.Set("defaults.textPositions.buffReminder.zone", zone)
            end,
            off = reminderOff,
        },
        isOff = reminderOff.get,
        size = {
            min = 6,
            max = 40,
            suffix = "px",
            get = function()
                return BR.Config.Get("defaults.captionTextSize", defaults.defaults.captionTextSize)
            end,
            set = function(val)
                BR.Config.Set("defaults.captionTextSize", val)
            end,
        },
        offsets = {
            min = -40,
            max = 40,
            getX = function()
                local _, x = BR.TextPositions.Get("buffReminder")
                return x
            end,
            setX = function(val)
                BR.Config.Set("defaults.textPositions.buffReminder.offsetX", val)
            end,
            getY = function()
                local _, _, y = BR.TextPositions.Get("buffReminder")
                return y
            end,
            setY = function(val)
                BR.Config.Set("defaults.textPositions.buffReminder.offsetY", val)
            end,
        },
    })
end

BR.Options.BuffSections.RaidOverlays = Build
