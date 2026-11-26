local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- AURA PICKER DIALOG
-- ============================================================================
-- Lists the auras on one unit with their spell IDs. Without a pick callback, a
-- click puts the spell ID or a row in a highlighted field for Ctrl+C, because an
-- addon cannot write to the clipboard. With a callback, a click returns the ID.
-- The aura enumeration throws in a restricted context, so the list does not read
-- auras there.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreateBuffIcon = BR.CreateBuffIcon
local PaintGradient = BR.PaintGradient
local SetTextColor = BR.SetThemeTextColor
local Theme = BR.Theme

local DIALOG_W = 600
local DIALOG_H = 440
local MARGIN = 16
local COLUMNS_TOP = 48
local LIST_TOP = 64
local FOOTER_H = 44
local LIST_W = DIALOG_W - MARGIN * 2
local ROW_W = LIST_W - 24
local ROW_H = 24
local HEADER_H = 22
local ICON_SIZE = 18
local ID_X = 30
local NAME_X = 100
local STACKS_W = 40
local SOURCE_W = 90
local TIME_W = 50
local COPY_W = 18
local PAGE_SIZE = 10
local PAGE_OFFSET = 4
local PAGE_FILL_ALPHA = 0.35
local COLUMN_GAP = 6
local PICKER_LEVEL = BR.Options.Constants.DIALOG_LEVEL + 40

local shell, title, scrollFrame, listContent, emptyText, hintText, copyField, allText, copyAllBtn, timeColumn
local copiedText, allString = "", ""
local hintToken = 0
local rows, headers = {}, {}
local state = { unit = "player", onPick = nil, showAll = false, selected = nil }
local COPIED_HINT_SECONDS = 2

---@param aura table
local function FormatRemaining(aura)
    if not aura.expirationTime or aura.expirationTime <= 0 then
        return ""
    end
    return BR.StateHelpers.FormatRemainingTime(aura.expirationTime - GetTime())
end

---@param copied? boolean
local function UpdateHint(copied)
    hintToken = hintToken + 1
    hintText:ClearAllPoints()
    if state.onPick then
        hintText:SetPoint("BOTTOMLEFT", MARGIN, 18)
        hintText:SetPoint("RIGHT", shell, "RIGHT", -MARGIN - 80, 0)
        hintText:SetText(L["AuraPicker.PickHint"])
        return
    end
    hintText:SetPoint("RIGHT", copyAllBtn, "LEFT", -8, 0)
    if state.showAll then
        hintText:SetPoint("BOTTOMLEFT", MARGIN, 18)
    else
        hintText:SetPoint("LEFT", copyField, "RIGHT", 8, 0)
    end
    if copied then
        hintText:SetText(L["AuraPicker.Copied"])
        local token = hintToken
        C_Timer.After(COPIED_HINT_SECONDS, function()
            if token == hintToken then
                UpdateHint()
            end
        end)
    elseif state.showAll then
        hintText:SetText(L["AuraPicker.CopyAllHint"])
    elseif state.selected then
        hintText:SetText(L["AuraPicker.SelectedHint"])
    else
        hintText:SetText(L["AuraPicker.CopyHint"])
    end
end

---An addon cannot read the clipboard, so the key press is the only sign of a copy.
---@param editBox table
local function HookCopyKey(editBox)
    editBox:HookScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            UpdateHint(true)
        end
    end)
end

local function PaintRow(row)
    local selected = row == state.selected
    if row.hover or selected then
        PaintGradient(row.bg, "HORIZONTAL", Theme.menuItem.hoverLeft, Theme.menuItem.hoverRight)
        SetTextColor(row.name, Theme.menuItem.textHover)
    else
        row.bg:SetColorTexture(0, 0, 0, 0)

        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.bar:SetWidth(2)
        BR.SetThemeColorTexture(row.bar, Theme.menuItem.selected)
        row.bar:Hide()
        SetTextColor(row.name, Theme.menuItem.text)
    end
    row.bar:SetShown(selected)
end

local function SetRowHover(row, hover)
    row.hover = hover
    PaintRow(row)
end

---@param row? table nil = clear the selection
---@param text? string
local function Select(row, text)
    local previous = state.selected
    state.selected = row
    if previous then
        PaintRow(previous)
    end
    copiedText = text or ""
    copyField:SetValue(copiedText)
    if row then
        PaintRow(row)
        copyField.editBox:SetFocus()
        copyField.editBox:HighlightText()
    else
        copyField.editBox:ClearFocus()
    end
    UpdateHint()
end

---A second click on the same content of the selected row deselects it.
---@param row table
---@param text string
local function ToggleSelect(row, text)
    if state.selected == row and copiedText == text then
        Select(nil)
    else
        Select(row, text)
    end
end

local function OnRowClick(row)
    local onPick = state.onPick
    if onPick then
        shell:Hide()
        onPick(row.spellID)
        return
    end
    ToggleSelect(row, tostring(row.spellID))
end

---The copy column exists only in copy mode, so the columns to its left move.
---@return number
local function TimeRightInset()
    return state.onPick and COLUMN_GAP or COPY_W + COLUMN_GAP + 2
end

---Two overlapped page outlines. The back page draws only the edges that the front
---page leaves visible, because the row behind has no solid color to mask them.
---@param parent table
---@param onClick fun()
---@return table
local function CreateCopyIcon(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(COPY_W, COPY_W)

    local box = PAGE_SIZE + PAGE_OFFSET
    local back = CreateFrame("Frame", nil, btn)
    back:SetSize(PAGE_SIZE, PAGE_SIZE)
    back:SetPoint("TOPRIGHT", btn, "CENTER", box / 2, box / 2)
    local front = CreateFrame("Frame", nil, btn)
    front:SetSize(PAGE_SIZE, PAGE_SIZE)
    front:SetPoint("BOTTOMLEFT", btn, "CENTER", -box / 2, -box / 2)

    local lines = BR.CreateRing(front, "ARTWORK", 0, 0, true)
    local fill = front:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    local function Line(point, width, height)
        local line = back:CreateTexture(nil, "ARTWORK")
        line:SetPoint(point)
        line:SetSize(width, height)
        lines[#lines + 1] = line
    end
    Line("TOPLEFT", PAGE_SIZE, 1)
    Line("TOPRIGHT", 1, PAGE_SIZE)
    Line("TOPLEFT", 1, PAGE_OFFSET)
    Line("BOTTOMRIGHT", PAGE_OFFSET, 1)

    local function Paint(c)
        for _, line in ipairs(lines) do
            BR.SetThemeColorTexture(line, c)
        end
        fill:SetColorTexture(c[1], c[2], c[3], PAGE_FILL_ALPHA)
    end
    Paint(Theme.menuItem.text)
    btn:SetScript("OnEnter", function(self)
        SetRowHover(parent, true)
        Paint(Theme.menuItem.textHover)
        BR.ShowTooltip(self, L["AuraPicker.CopyRow"])
    end)
    btn:SetScript("OnLeave", function()
        SetRowHover(parent, false)
        Paint(Theme.menuItem.text)
        BR.HideTooltip()
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function AcquireRow(index)
    local row = rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, listContent)
    row:SetSize(ROW_W, ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.icon = CreateBuffIcon(row, ICON_SIZE)
    row.icon:SetPoint("LEFT", 4, 0)

    row.id = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.id:SetPoint("LEFT", ID_X, 0)
    row.id:SetJustifyH("LEFT")

    row.copy = CreateCopyIcon(row, function()
        ToggleSelect(row, row.copyText)
    end)
    row.copy:SetPoint("RIGHT", -2, 0)

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.time:SetWidth(TIME_W)
    row.time:SetJustifyH("RIGHT")

    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("RIGHT", row.time, "LEFT", -COLUMN_GAP, 0)
    row.source:SetWidth(SOURCE_W)
    row.source:SetJustifyH("RIGHT")
    row.source:SetWordWrap(false)

    row.stacks = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.stacks:SetPoint("RIGHT", row.source, "LEFT", -COLUMN_GAP, 0)
    row.stacks:SetWidth(STACKS_W)
    row.stacks:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetPoint("RIGHT", row.stacks, "LEFT", -COLUMN_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        SetRowHover(self, true)
    end)
    row:SetScript("OnLeave", function(self)
        SetRowHover(self, false)
    end)
    row:SetScript("OnClick", OnRowClick)

    rows[index] = row
    return row
end

local function AcquireHeader(index)
    local header = headers[index]
    if header then
        return header
    end
    header = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetJustifyH("LEFT")
    headers[index] = header
    return header
end

local FILTERS = {
    { filter = "HELPFUL", label = "AuraPicker.Buffs" },
    { filter = "HARMFUL", label = "AuraPicker.Debuffs" },
}

local TABLE_COLUMNS = {
    { key = "AuraPicker.SpellID", right = true },
    { key = "AuraPicker.Name" },
    { key = "AuraPicker.Stacks", right = true },
    { key = "AuraPicker.Source" },
    { key = "AuraPicker.Time", right = true },
}

---Counts characters, not bytes, so a UTF-8 name pads to the same width.
---@param text string
---@return number
local function CharLength(text)
    return select(2, text:gsub("[^\128-\191]", ""))
end

---@param text string
---@param width number
---@param right? boolean
---@return string
local function Pad(text, width, right)
    local fill = string.rep(" ", width - CharLength(text))
    return right and fill .. text or text .. fill
end

---@class AuraPickerSection
---@field title string
---@field cells string[][]

---Formats every section as one table with shared column widths. The text sits in a
---code fence, because the columns line up only in a monospace font.
---@param sections AuraPickerSection[]
---@return string
local function FormatAllText(sections)
    local widths = {}
    for c, column in ipairs(TABLE_COLUMNS) do
        widths[c] = CharLength(L[column.key])
    end
    for _, section in ipairs(sections) do
        for _, cells in ipairs(section.cells) do
            for c, value in ipairs(cells) do
                widths[c] = math.max(widths[c], CharLength(value))
            end
        end
    end

    local function Line(cells)
        local parts = {}
        for c, column in ipairs(TABLE_COLUMNS) do
            parts[c] = Pad(cells[c], widths[c], column.right)
        end
        return (table.concat(parts, "  "):gsub("%s+$", ""))
    end

    local headerCells, ruleCells = {}, {}
    for c, column in ipairs(TABLE_COLUMNS) do
        headerCells[c] = L[column.key]
        ruleCells[c] = string.rep("-", widths[c])
    end

    local lines = { "```", (UnitName(state.unit) or state.unit) .. " (" .. state.unit .. ")" }
    for _, section in ipairs(sections) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = section.title
        if #section.cells > 0 then
            lines[#lines + 1] = Line(headerCells)
            lines[#lines + 1] = Line(ruleCells)
            for _, cells in ipairs(section.cells) do
                lines[#lines + 1] = Line(cells)
            end
        end
    end
    lines[#lines + 1] = "```"
    return table.concat(lines, "\n")
end

---@param message string
local function ShowEmpty(message)
    emptyText:SetText(message)
    emptyText:Show()
    listContent:SetHeight(1)
    allString = message
    allText:SetText(message)
end

local function Populate()
    Select(nil)
    for _, row in ipairs(rows) do
        row:Hide()
    end
    for _, header in ipairs(headers) do
        header:Hide()
    end
    scrollFrame:SetVerticalScroll(0)

    if BR.BuffState.IsRestricted() then
        ShowEmpty(L["AuraPicker.Restricted"])
        return
    end
    if not UnitExists(state.unit) then
        ShowEmpty(L["AuraPicker.NoUnit"])
        return
    end
    emptyText:Hide()

    local timeInset = TimeRightInset()
    local sections = {}
    local y, rowIndex = 0, 0
    -- Debuffs are of no use to a custom buff, so the picker lists only buffs.
    local filterCount = state.onPick and 1 or #FILTERS
    for f = 1, filterCount do
        local def = FILTERS[f]
        local header = AcquireHeader(f)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 4, -y - 4)
        y = y + HEADER_H
        local cells = {}

        local count = 0
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, state.unit, i, def.filter)
            if not ok or not aura then
                break
            end
            count = count + 1
            rowIndex = rowIndex + 1
            local row = AcquireRow(rowIndex)
            row.spellID = aura.spellId
            row.icon:SetTexture(aura.icon)
            row.id:SetText(tostring(aura.spellId))

            local name = aura.name
            local rank = C_Spell.GetSpellSubtext(aura.spellId)
            if rank and rank ~= "" then
                row.name:SetText(aura.name .. " |cff808080(" .. rank .. ")|r")
                name = name .. " (" .. rank .. ")"
            else
                row.name:SetText(aura.name)
            end
            local stacks = aura.applications or 0
            local source = aura.sourceUnit and UnitName(aura.sourceUnit) or ""
            local remaining = FormatRemaining(aura)
            row.stacks:SetText(stacks > 1 and tostring(stacks) or "")
            row.source:SetText(source)
            row.time:SetText(remaining)
            row.time:SetPoint("RIGHT", -timeInset, 0)
            row.copy:SetShown(not state.onPick)
            row.copyText = table.concat({ aura.spellId, name, stacks, source, remaining }, " | ")
            cells[#cells + 1] = {
                tostring(aura.spellId),
                name,
                tostring(stacks),
                source ~= "" and source or "-",
                remaining ~= "" and remaining or "-",
            }

            row.hover = false
            PaintRow(row)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()
            y = y + ROW_H
        end
        local headerText = L[def.label] .. " (" .. count .. ")"
        header:SetText(headerText)
        header:Show()
        sections[#sections + 1] = { title = headerText, cells = cells }
    end
    listContent:SetHeight(math.max(y, 1))
    allString = FormatAllText(sections)
    allText:SetText(allString)
end

local function ApplyView()
    scrollFrame:SetShown(not state.showAll)
    allText:SetShown(state.showAll)
    copyAllBtn:SetText(state.showAll and L["AuraPicker.ShowList"] or L["AuraPicker.CopyAll"])
    copyAllBtn:SetWidth(math.max(72, copyAllBtn.text:GetStringWidth() + 16))
    copyField:SetShown(not state.onPick and not state.showAll)
    UpdateHint()
    if state.showAll then
        allText:SetFocus()
        allText:HighlightText()
    else
        allText:ClearFocus()
    end
end

---@param parent table
---@param key string
---@param width? number nil = a left-aligned column
---@return table
local function ColumnHeader(parent, key, width)
    local column = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    column:SetText(L[key])
    if width then
        column:SetWidth(width)
        column:SetJustifyH("RIGHT")
    end
    return column
end

local function EnsureShell()
    if shell then
        return shell
    end

    shell = BR.CreatePanel("BuffRemindersAuraPicker", DIALOG_W, DIALOG_H, {
        level = PICKER_LEVEL,
        dialog = true,
    })
    -- CreateFrame returns a shown frame, and the body is built after this.
    shell:Hide()

    title = shell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    BR.ApplyTitleColor(title)
    title:SetPoint("TOP", 0, -12)
    BR.Options.Helpers.AddCloseButton(shell)

    ColumnHeader(shell, "AuraPicker.SpellID"):SetPoint("TOPLEFT", MARGIN + ID_X, -COLUMNS_TOP)
    ColumnHeader(shell, "AuraPicker.Name"):SetPoint("TOPLEFT", MARGIN + NAME_X, -COLUMNS_TOP)
    timeColumn = ColumnHeader(shell, "AuraPicker.Time", TIME_W)
    local sourceColumn = ColumnHeader(shell, "AuraPicker.Source", SOURCE_W)
    sourceColumn:SetPoint("RIGHT", timeColumn, "LEFT", -COLUMN_GAP, 0)
    ColumnHeader(shell, "AuraPicker.Stacks", STACKS_W):SetPoint("RIGHT", sourceColumn, "LEFT", -COLUMN_GAP, 0)

    scrollFrame, listContent = Components.ScrollableContainer(shell, { width = LIST_W, contentHeight = 1 })
    scrollFrame:SetPoint("TOPLEFT", MARGIN, -LIST_TOP)
    scrollFrame:SetPoint("BOTTOMLEFT", MARGIN, FOOTER_H)

    allText = Components.TextArea(shell, { width = LIST_W, height = DIALOG_H - LIST_TOP - FOOTER_H })
    allText:SetPoint("TOPLEFT", MARGIN, -LIST_TOP)
    -- Esc leaves the text view, so the list comes back before Esc closes the dialog.
    allText.editBox:SetScript("OnEscapePressed", function()
        state.showAll = false
        ApplyView()
    end)
    -- The text exists only for Ctrl+C, so typed text reverts.
    allText.editBox:HookScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(allString)
            self:HighlightText()
        end
    end)
    allText.editBox:HookScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    HookCopyKey(allText.editBox)
    allText:Hide()

    emptyText = listContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 4, -8)
    emptyText:SetWidth(LIST_W - 32)
    emptyText:SetJustifyH("LEFT")

    copyField = Components.TextInput(shell, { label = L["AuraPicker.CopyField"], labelWidth = 40, width = 200 })
    copyField:SetPoint("BOTTOMLEFT", MARGIN, 14)
    -- The field only carries the clicked text for Ctrl+C, so typed text reverts.
    copyField.editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(copiedText)
            self:HighlightText()
        end
    end)
    copyField.editBox:SetScript("OnEscapePressed", function()
        Select(nil)
    end)
    -- A click in the field places the cursor, so the field selects its text again.
    copyField.editBox:HookScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    copyField.editBox:HookScript("OnMouseUp", function(self)
        self:HighlightText()
    end)
    HookCopyKey(copyField.editBox)

    hintText = shell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetJustifyH("LEFT")

    local refreshBtn = CreateButton(shell, L["AuraPicker.Refresh"], function()
        Populate()
        ApplyView()
    end)
    refreshBtn:SetSize(72, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 12)

    copyAllBtn = CreateButton(shell, L["AuraPicker.CopyAll"], function()
        state.showAll = not state.showAll
        ApplyView()
    end)
    copyAllBtn:SetSize(72, 22)
    copyAllBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -6, 0)

    shell:SetScript("OnHide", function()
        copyField.editBox:ClearFocus()
        allText:ClearFocus()
        state.onPick = nil
    end)

    return shell
end

---@param unit? string Unit token; nil = player
---@param onPick? fun(spellID: number) nil = click puts the ID in the copy field
local function Show(unit, onPick)
    EnsureShell()
    shell:Hide()
    state.unit = unit and unit:lower() or "player"
    state.onPick = onPick
    state.showAll = false
    title:SetText(onPick and L["AuraPicker.PickTitle"] or L["AuraPicker.Title"])
    copyAllBtn:SetShown(not onPick)
    timeColumn:ClearAllPoints()
    timeColumn:SetPoint("TOPRIGHT", shell, "TOPLEFT", MARGIN + ROW_W - TimeRightInset(), -COLUMNS_TOP)
    shell:ClearAllPoints()
    shell:SetPoint("CENTER")
    Populate()
    shell:Show()
    ApplyView()
end

BR.Options.Dialogs.AuraPicker = { Show = Show }
