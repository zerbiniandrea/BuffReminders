local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- ALL BUFFS PAGE (control panel)
-- ============================================================================
-- The single surface for "what does this addon track, and which of those do I
-- use". Each static category renders in two columns as a section header, a note,
-- and the shared per-buff row factory. Custom buffs and loadout reminders keep
-- their own list-editor pages, because the user defines them in a dialog.
--
-- The Categories page owns display configuration for each category. The per-buff
-- list does not appear there.

local L = BR.L

local BUFF_TABLES = BR.BUFF_TABLES

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

-- Vertical gap between header text and the description below it. The gap must
-- keep the header descenders (g/p/y) clear of the note's caps.
local HEADER_TO_NOTE_GAP = 15
-- Vertical gap between the description and the first row checkbox below it.
-- Includes the note's own visual height plus breathing room.
local NOTE_TO_ROWS_GAP = 16
-- Rows nest under each section header, matching the indent pattern that
-- LayoutSectionHeader applies to content beneath an accent line on every
-- other page.
local ROW_INDENT = 6
-- Vertical gap between the last row of one section and the next header.
local INTER_SECTION_GAP = 10

local SECTIONS = {
    {
        category = "raid",
        titleKey = "Category.RaidBuffs",
        noteKey = "Category.RaidNote",
    },
    {
        category = "presence",
        titleKey = "Category.PresenceBuffs",
        noteKey = "Category.PresenceNote",
    },
    {
        category = "targeted",
        titleKey = "Category.TargetedBuffs",
        noteKey = "Category.TargetedNote",
    },
    {
        category = "self",
        titleKey = "Category.SelfBuffs",
        noteKey = "Category.SelfNote",
    },
    {
        category = "pet",
        titleKey = "Category.PetReminders",
        noteKey = "Category.PetNote",
    },
    {
        category = "consumable",
        titleKey = "Category.Consumables",
        noteKey = "Category.ConsumableNote",
    },
    {
        category = "utility",
        titleKey = "Category.UtilityReminders",
        noteKey = "Category.UtilityNote",
    },
}

local function CreateSectionWithNote(parent, x, y, headerText, noteText)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText(BR.TITLE_COLOR_CODE .. headerText .. "|r")

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    BR.ApplyNoteColor(note)
    note:SetPoint("TOPLEFT", x, y - HEADER_TO_NOTE_GAP)
    note:SetText(noteText)

    return y - HEADER_TO_NOTE_GAP - NOTE_TO_ROWS_GAP
end

-- Masonry: each section, in list order, goes to the shorter column. A tie goes left.
local function AssignColumns()
    local Measure = BR.Options.BuffRow.Measure
    local columns = { {}, {} }
    local heights = { 0, 0 }
    for _, section in ipairs(SECTIONS) do
        if BR.IsCategoryAvailable(section.category) then
            local col = heights[2] < heights[1] and 2 or 1
            local gap = #columns[col] > 0 and INTER_SECTION_GAP or 0
            local buffs = BUFF_TABLES[section.category] or {}
            heights[col] = heights[col] + gap + HEADER_TO_NOTE_GAP + NOTE_TO_ROWS_GAP + Measure(buffs)
            columns[col][#columns[col] + 1] = section
        end
    end
    return columns[1], columns[2]
end

local function RenderColumn(parent, x, y, sections, colWidth)
    local Render = BR.Options.BuffRow.Render
    local rowsX = x + ROW_INDENT
    -- Rows start ROW_INDENT in from the column's left edge; span the rest of
    -- the column so the "Settings" link lands on the column's right edge.
    local rowWidth = colWidth - ROW_INDENT
    for i, section in ipairs(sections) do
        y = CreateSectionWithNote(parent, x, y, L[section.titleKey], L[section.noteKey])
        y = Render(parent, rowsX, y, BUFF_TABLES[section.category] or {}, rowWidth)
        if i < #sections then
            y = y - INTER_SECTION_GAP
        end
    end
    return y
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local colWidth = math.floor((contentWidth - COL_PADDING * 3) / 2)
    local leftX = COL_PADDING
    local rightX = COL_PADDING + colWidth + COL_PADDING

    -- Match the standard page top margin so the first section header sits at
    -- the same Y as on every other page (VerticalLayout starts at PAGE_TOP_PADDING).
    local startY = PAGE_TOP_PADDING

    local leftSections, rightSections = AssignColumns()
    local leftEndY = RenderColumn(content, leftX, startY, leftSections, colWidth)
    local rightEndY = RenderColumn(content, rightX, startY, rightSections, colWidth)

    content:SetHeight(math.max(math.abs(leftEndY), math.abs(rightEndY)) + 16)
end

BR.Options.Pages.allBuffs = {
    title = L["Page.Reminders"],
    Build = Build,
}

-- Every buff with an `addedIn` cohort is a what's-new source. This is a provider,
-- not a static Register, because BUFF_TABLES.custom and BUFF_TABLES.loadout fill
-- at ADDON_LOADED, after this file loads.
BR.Options.WhatsNew.RegisterProvider(function()
    local entries = {}
    for _, arr in pairs(BUFF_TABLES) do
        for _, buff in ipairs(arr) do
            if buff.addedIn then
                entries[#entries + 1] = {
                    cohort = buff.addedIn,
                    pageId = "allBuffs",
                    key = buff.groupId or buff.key,
                }
            end
        end
    end
    return entries
end)
