local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Text & overlays
-- ============================================================================
-- What the icon draws: the main text (a count like 17/20, or a label like NO
-- PET), then one row per text element of the category. The per-category rows live in the raid, pet and item section files.
-- Every row starts with its label in one shared column, so no row reads as the
-- parent of the rows below it.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local GetCategorySetting = Helpers.GetCategorySetting
local MakeCategorySetter = Helpers.MakeCategorySetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local Sections = BR.Options.BuffSections

    LayoutSectionHeader(layout, parent, L["Options.TextOverlays"])

    -- Measured over every row label of every category, so the column is the same
    -- on each tab.
    ctx.overlayLabelWidth = Components.MeasureSharedLabelWidth({
        L["Options.TextPositions.MainText"],
        L["Options.BuffReminderText"],
        L["Options.PetLabels"],
        L["Options.PetLabels.Classes"],
        L["Options.ItemTextSize"],
        L["Options.TextPositions.StatLabel"],
        L["Options.TextPositions.Badge"],
        L["Options.TextPositions.StackCount"],
    })

    local function showText()
        return GetCategorySetting(category, "showText", true) ~= false
    end

    -- The main text has no position on a tab (the Defaults page sets it), so its
    -- row holds a checkbox where the other rows hold their position.
    local setShowText = MakeCategorySetter(category, "showText")
    local mainTextRow = CreateFrame("Frame", nil, parent)
    mainTextRow:SetSize(parent:GetWidth(), 22)
    local mainTextLabel = mainTextRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainTextLabel:SetPoint("LEFT", 0, 0)
    mainTextLabel:SetWidth(ctx.overlayLabelWidth)
    mainTextLabel:SetJustifyH("LEFT")
    mainTextLabel:SetText(L["Options.TextPositions.MainText"])

    local showTextHolder = Components.Checkbox(mainTextRow, {
        label = L["Options.ShowTextToggle"],
        holderWidth = Components.MeasureSharedLabelWidth({ L["Options.ShowTextToggle"] }, "GameFontHighlightSmall", 0)
            + 50,
        get = showText,
        tooltip = { title = L["Options.TextPositions.MainText"], desc = L["Options.MainText.Desc"] },
        onChange = function(checked)
            setShowText(checked)
            Components.RefreshAll()
        end,
    })
    showTextHolder:SetPoint("LEFT", mainTextRow, "LEFT", ctx.overlayLabelWidth + 5, 0)
    layout:Add(mainTextRow, 22, COMPONENT_GAP)

    if category == "raid" then
        -- Hidden, not dimmed, while the main text is off: it shares the row.
        local missingCountHolder = Components.Checkbox(parent, {
            label = L["Options.ShowMissingCountOnly"],
            get = function()
                return BR.profile.showMissingCountOnly == true
            end,
            tooltip = {
                title = L["Options.ShowMissingCountOnly"],
                desc = L["Options.ShowMissingCountOnly.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("showMissingCountOnly", checked)
            end,
        })
        missingCountHolder:SetPoint("LEFT", showTextHolder, "RIGHT", 14, 0)
        local missingCountRefresh = missingCountHolder.Refresh
        function missingCountHolder:Refresh()
            if missingCountRefresh then
                missingCountRefresh(self)
            end
            self:SetShown(showText())
        end
        missingCountHolder:Refresh()

        Sections.RaidOverlays(ctx, layout)
    elseif category == "pet" then
        Sections.PetOverlays(ctx, layout)
    elseif category == "consumable" then
        Sections.ItemOverlays(ctx, layout)
    end
end

BR.Options.BuffSections.Overlays = Build
