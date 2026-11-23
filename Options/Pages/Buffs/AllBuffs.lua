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
local SEARCH_TO_SECTIONS_GAP = 14
local SEARCH_DIM_ALPHA = 0.25
-- Space kept above the first match after a scroll, so its section header stays in view.
local SEARCH_SCROLL_MARGIN = 40

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

    return y - HEADER_TO_NOTE_GAP - NOTE_TO_ROWS_GAP, header, note
end

-- Tries every split that keeps list order in each column and the first section on the left.
-- Picks the split with the shortest tallest column. A greedy fill leaves the last section unbalanced.
local function AssignColumns()
    local Measure = BR.Options.BuffRow.Measure
    local sections, heights = {}, {}
    for _, section in ipairs(SECTIONS) do
        if BR.IsCategoryAvailable(section.category) then
            sections[#sections + 1] = section
            heights[#heights + 1] = HEADER_TO_NOTE_GAP + NOTE_TO_ROWS_GAP + Measure(BUFF_TABLES[section.category] or {})
        end
    end

    local n = #sections
    local bestMask, bestMax, bestDiff = 0, math.huge, math.huge
    for mask = 0, 2 ^ math.max(n - 1, 0) - 1 do
        local h, count = { 0, 0 }, { 0, 0 }
        local m = mask
        for i = 1, n do
            local col = 1
            if i > 1 then
                col = m % 2 + 1
                m = math.floor(m / 2)
            end
            h[col] = h[col] + (count[col] > 0 and INTER_SECTION_GAP or 0) + heights[i]
            count[col] = count[col] + 1
        end
        local tallest, diff = math.max(h[1], h[2]), math.abs(h[1] - h[2])
        if tallest < bestMax or (tallest == bestMax and diff < bestDiff) then
            bestMask, bestMax, bestDiff = mask, tallest, diff
        end
    end

    local columns = { {}, {} }
    for i = 1, n do
        local col = 1
        if i > 1 then
            col = bestMask % 2 + 1
            bestMask = math.floor(bestMask / 2)
        end
        columns[col][#columns[col] + 1] = sections[i]
    end
    return columns[1], columns[2]
end

local function RenderColumn(parent, x, y, sections, colWidth, rendered)
    local Render = BR.Options.BuffRow.Render
    local rowsX = x + ROW_INDENT
    -- Rows start ROW_INDENT in from the column's left edge; span the rest of
    -- the column so the "Settings" link lands on the column's right edge.
    local rowWidth = colWidth - ROW_INDENT
    for i, section in ipairs(sections) do
        local title = L[section.titleKey]
        local header, note
        y, header, note = CreateSectionWithNote(parent, x, y, title, L[section.noteKey])
        local rows = {}
        y = Render(parent, rowsX, y, BUFF_TABLES[section.category] or {}, rowWidth, rows)
        rendered[#rendered + 1] = { header = header, note = note, title = title:lower(), rows = rows }
        if i < #sections then
            y = y - INTER_SECTION_GAP
        end
    end
    return y
end

-- A section title match keeps the whole section lit. Returns the lit frames, or nil for an empty query.
local function ApplySearch(rendered, query)
    query = query:lower():match("^%s*(.-)%s*$")
    local matches = query ~= "" and {} or nil
    for _, section in ipairs(rendered) do
        local titleHit = query == "" or section.title:find(query, 1, true) ~= nil
        local anyHit = titleHit
        for _, row in ipairs(section.rows) do
            local hit = titleHit or row.text:find(query, 1, true) ~= nil
            row.frame:SetAlpha(hit and 1 or SEARCH_DIM_ALPHA)
            if hit and matches then
                matches[#matches + 1] = row.frame
            end
            anyHit = anyHit or hit
        end
        local alpha = anyHit and 1 or SEARCH_DIM_ALPHA
        section.header:SetAlpha(alpha)
        section.note:SetAlpha(alpha)
        if titleHit and matches then
            matches[#matches + 1] = section.header
        end
    end
    return matches
end

-- Scrolls only when no match is in view, so the list does not jump while the user types.
local function ScrollToMatches(scrollFrame, content, matches)
    if not matches or #matches == 0 then
        return
    end
    local contentTop = content:GetTop()
    if not contentTop then
        return
    end
    local scroll = scrollFrame:GetVerticalScroll() or 0
    local viewHeight = scrollFrame:GetHeight()
    local first = math.huge
    for _, frame in ipairs(matches) do
        local top = frame:GetTop()
        if top then
            local offset = contentTop - top
            if offset >= scroll and offset + frame:GetHeight() <= scroll + viewHeight then
                return
            end
            first = math.min(first, offset)
        end
    end
    if first == math.huge then
        return
    end
    local range = scrollFrame:GetVerticalScrollRange() or 0
    scrollFrame:SetVerticalScroll(math.max(0, math.min(range, first - SEARCH_SCROLL_MARGIN)))
end

local function CreateSearchBox(content, scrollFrame, x, y, width, rendered)
    local holder = BR.Components.TextInput(content, { labelWidth = 0, width = width })
    holder:SetPoint("TOPLEFT", x - 5, y)
    local editBox = holder.editBox

    local placeholder = editBox:GetParent():CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText(L["BuffRow.SearchPlaceholder"])

    editBox:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        placeholder:SetShown(text == "")
        ScrollToMatches(scrollFrame, content, ApplySearch(rendered, text))
    end)
    editBox:HookScript("OnEscapePressed", function(self)
        self:SetText("")
    end)
    -- The page builds once, so a kept query would dim rows on the next visit with no visible reason.
    content:HookScript("OnHide", function()
        editBox:SetText("")
    end)
    return y - holder:GetHeight() - SEARCH_TO_SECTIONS_GAP
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local colWidth = math.floor((contentWidth - COL_PADDING * 3) / 2)
    local leftX = COL_PADDING
    local rightX = COL_PADDING + colWidth + COL_PADDING

    local rendered = {}
    -- PAGE_TOP_PADDING is the standard page top margin, so the search box sits
    -- at the same Y as the first element on every other page.
    local startY = CreateSearchBox(content, scrollFrame, leftX, PAGE_TOP_PADDING, colWidth, rendered)

    local leftSections, rightSections = AssignColumns()
    local leftEndY = RenderColumn(content, leftX, startY, leftSections, colWidth, rendered)
    local rightEndY = RenderColumn(content, rightX, startY, rightSections, colWidth, rendered)

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
