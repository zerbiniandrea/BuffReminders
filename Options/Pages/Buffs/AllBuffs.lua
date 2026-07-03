local _, BR = ...

-- ============================================================================
-- ALL BUFFS PAGE (control panel)
-- ============================================================================
-- The single surface for "what does this addon track and which of those am I
-- using." Renders every static category (raid / targeted / consumable on the
-- left; presence / self / pet on the right) as section header + note + the
-- shared per-buff row factory. Custom buffs stay on their own page because
-- they're user-defined and edit-via-dialog.
--
-- Per-category pages own *display* configuration only (visibility, icons,
-- click-to-cast, layout, sounds, etc.) - the per-buff list does not appear
-- there. This separation mirrors the original "Buffs" + "DisplayBehavior"
-- split that the sidebar refactor briefly lost.

local L = BR.L

local BUFF_TABLES = BR.BUFF_TABLES

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local floor = math.floor
local max = math.max
local abs = math.abs

-- Vertical gap between header text and the description below it. Needs enough
-- clearance for header descenders (g/p/y) to not clash with the note's caps.
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

local LEFT_SECTIONS = {
    {
        category = "raid",
        titleKey = "Category.RaidBuffs",
        noteKey = "Category.RaidNote",
    },
    {
        category = "targeted",
        titleKey = "Category.TargetedBuffs",
        noteKey = "Category.TargetedNote",
    },
    {
        category = "consumable",
        titleKey = "Category.Consumables",
        noteKey = "Category.ConsumableNote",
    },
}

local RIGHT_SECTIONS = {
    {
        category = "presence",
        titleKey = "Category.PresenceBuffs",
        noteKey = "Category.PresenceNote",
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
}

local function CreateSectionWithNote(parent, x, y, headerText, noteText)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText("|cffffcc00" .. headerText .. "|r")

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, y - HEADER_TO_NOTE_GAP)
    note:SetText(noteText)

    return y - HEADER_TO_NOTE_GAP - NOTE_TO_ROWS_GAP
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
    local colWidth = floor((contentWidth - COL_PADDING * 3) / 2)
    local leftX = COL_PADDING
    local rightX = COL_PADDING + colWidth + COL_PADDING

    -- Match the standard page top margin so the first section header sits at
    -- the same Y as on every other page (VerticalLayout starts at PAGE_TOP_PADDING).
    local startY = PAGE_TOP_PADDING

    local leftEndY = RenderColumn(content, leftX, startY, LEFT_SECTIONS, colWidth)
    local rightEndY = RenderColumn(content, rightX, startY, RIGHT_SECTIONS, colWidth)

    content:SetHeight(max(abs(leftEndY), abs(rightEndY)) + 16)
end

BR.Options.Pages.allBuffs = {
    title = L["Page.AllBuffs"],
    Build = Build,
}
