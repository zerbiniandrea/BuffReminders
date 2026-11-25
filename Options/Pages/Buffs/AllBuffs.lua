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

local BUFF_TABLES = BR.BuffData.buffTables

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING
local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

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
-- While a search hides the notes, rows follow the header directly. The gap keeps the header descenders clear.
local HEADER_TO_ROWS_GAP = 20

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

---@class AllBuffsSection
---@field header table
---@field note table
---@field title string Lowercase section title
---@field rows BuffRowSearch[]
---@field visibleRows table[] Row frames that the current query keeps, in list order

local function CreateSection(parent, headerText, noteText)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText(BR.TITLE_COLOR_CODE .. headerText .. "|r")

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    BR.ApplyNoteColor(note)
    note:SetText(noteText)

    return header, note
end

local function HeaderToRows(searching)
    return searching and HEADER_TO_ROWS_GAP or HEADER_TO_NOTE_GAP + NOTE_TO_ROWS_GAP
end

-- Tries every split that keeps list order in each column and the first section on the left.
-- Picks the split with the shortest tallest column. A greedy fill leaves the last section unbalanced.
---@param heights number[]
---@return integer[] columns Column (1 or 2) of each entry in heights
local function AssignColumns(heights)
    local n = #heights
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

    local columns = {}
    for i = 1, n do
        local col = 1
        if i > 1 then
            col = bestMask % 2 + 1
            bestMask = math.floor(bestMask / 2)
        end
        columns[i] = col
    end
    return columns
end

-- A section title match keeps the whole section. A row kept by a term other than its name shows that term.
---@param rendered AllBuffsSection[]
---@return AllBuffsSection[] shown Sections that keep at least one row
---@return integer matches Number of kept rows
---@return boolean searching
local function FilterSections(rendered, query)
    query = query:lower():match("^%s*(.-)%s*$")
    local searching = query ~= ""
    local shown, matches = {}, 0
    for _, section in ipairs(rendered) do
        local titleHit = not searching or section.title:find(query, 1, true) ~= nil
        local visibleRows = {}
        for _, row in ipairs(section.rows) do
            local hit, hint = titleHit, nil
            if not titleHit then
                for i, term in ipairs(row.lowerTerms) do
                    if term:find(query, 1, true) then
                        hit = true
                        hint = i > 1 and row.terms[i] or nil
                        break
                    end
                end
            end
            row.frame:SetShown(hit)
            row.frame:SetMatchHint(hint)
            if hit then
                visibleRows[#visibleRows + 1] = row.frame
            end
        end
        section.visibleRows = visibleRows
        local keep = #visibleRows > 0
        section.header:SetShown(keep)
        section.note:SetShown(keep and not searching)
        if keep then
            shown[#shown + 1] = section
            matches = matches + #visibleRows
        end
    end
    return shown, matches, searching
end

---@param shown AllBuffsSection[]
---@param xs number[] Left edge of each column
---@return number height Height of the tallest column
local function PlaceSections(shown, xs, searching)
    local headerToRows = HeaderToRows(searching)
    local heights = {}
    for i, section in ipairs(shown) do
        heights[i] = headerToRows + #section.visibleRows * ITEM_HEIGHT
    end
    local columns = AssignColumns(heights)
    local ys = { PAGE_TOP_PADDING, PAGE_TOP_PADDING }
    for i, section in ipairs(shown) do
        local col = columns[i]
        local x, y = xs[col], ys[col]
        if y ~= PAGE_TOP_PADDING then
            y = y - INTER_SECTION_GAP
        end
        section.header:ClearAllPoints()
        section.header:SetPoint("TOPLEFT", x, y)
        section.note:ClearAllPoints()
        section.note:SetPoint("TOPLEFT", x, y - HEADER_TO_NOTE_GAP)
        y = y - headerToRows
        for _, frame in ipairs(section.visibleRows) do
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", x + ROW_INDENT, y)
            y = y - ITEM_HEIGHT
        end
        ys[col] = y
    end
    return math.max(-ys[1], -ys[2])
end

---@type fun(text: string): integer, boolean
local applyQuery

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local colWidth = math.floor((contentWidth - COL_PADDING * 3) / 2)
    local xs = { COL_PADDING, COL_PADDING + colWidth + COL_PADDING }

    -- Rows start ROW_INDENT in from the column's left edge; span the rest of
    -- the column so the "Settings" link lands on the column's right edge.
    local rowWidth = colWidth - ROW_INDENT
    local Render = BR.Options.BuffRow.Render
    ---@type AllBuffsSection[]
    local rendered = {}
    for _, section in ipairs(SECTIONS) do
        if BR.IsCategoryAvailable(section.category) then
            local title = L[section.titleKey]
            local header, note = CreateSection(content, title, L[section.noteKey])
            local rows = {}
            Render(content, 0, 0, BUFF_TABLES[section.category] or {}, rowWidth, rows)
            rendered[#rendered + 1] =
                { header = header, note = note, title = title:lower(), rows = rows, visibleRows = {} }
        end
    end

    local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    BR.ApplyNoteColor(emptyText)
    emptyText:SetPoint("TOPLEFT", xs[1], PAGE_TOP_PADDING)
    emptyText:SetText(L["Options.SearchEmpty"])

    -- The scroll position before a search comes back when the search clears.
    local savedScroll
    applyQuery = function(text)
        local shown, matches, searching = FilterSections(rendered, text)
        content:SetHeight(PlaceSections(shown, xs, searching) + 16)
        emptyText:SetShown(#shown == 0)
        if searching then
            savedScroll = savedScroll or scrollFrame:GetVerticalScroll()
            scrollFrame:SetVerticalScroll(0)
        elseif savedScroll then
            local restore = savedScroll
            savedScroll = nil
            -- The scroll range follows the new content height only after the next layout pass.
            C_Timer.After(0, function()
                scrollFrame:SetVerticalScroll(math.min(restore, scrollFrame:GetVerticalScrollRange() or 0))
            end)
        end
        return matches, searching
    end
    applyQuery("")
end

BR.Options.Pages.allBuffs = {
    title = L["Page.Reminders"],
    Build = Build,
    ---Filters the page. The options panel calls it from the header search box, only after Build.
    ---@param text string
    ---@return integer matches
    ---@return boolean searching
    Search = function(text)
        return applyQuery(text)
    end,
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
