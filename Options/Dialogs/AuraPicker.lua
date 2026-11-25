local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- AURA PICKER DIALOG
-- ============================================================================
-- Lists the auras on one unit with their spell IDs. Without a pick callback, a
-- click puts the spell ID in a highlighted field for Ctrl+C, because an addon
-- cannot write to the clipboard. With a callback, a click returns the ID.
-- The aura enumeration throws in a restricted context, so the list does not read
-- auras there.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreateBuffIcon = BR.CreateBuffIcon
local PaintGradient = BR.PaintGradient
local SetTextColor = BR.SetThemeTextColor
local Theme = BR.Theme

local DIALOG_W = 520
local DIALOG_H = 440
local MARGIN = 16
local COLUMNS_TOP = 48
local LIST_TOP = 64
local FOOTER_H = 44
local LIST_W = DIALOG_W - MARGIN * 2
local ROW_H = 24
local HEADER_H = 22
local ICON_SIZE = 18
local ID_X = 30
local NAME_X = 100
local TIME_W = 60
local SOURCE_W = 70
local PICKER_LEVEL = BR.Options.Constants.DIALOG_LEVEL + 40

local shell, title, scrollFrame, listContent, emptyText, hintText, copyField
local copiedID = ""
local rows, headers = {}, {}
local state = { unit = "player", onPick = nil }

---@param aura table
local function FormatRemaining(aura)
    if not aura.expirationTime or aura.expirationTime <= 0 then
        return ""
    end
    return BR.StateHelpers.FormatRemainingTime(aura.expirationTime - GetTime())
end

local function OnRowClick(row)
    local spellID = row.spellID
    local onPick = state.onPick
    if onPick then
        shell:Hide()
        onPick(spellID)
        return
    end
    copiedID = tostring(spellID)
    copyField:SetValue(copiedID)
    copyField.editBox:SetFocus()
    copyField.editBox:HighlightText()
end

local function AcquireRow(index)
    local row = rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, listContent)
    row:SetSize(LIST_W - 24, ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.icon = CreateBuffIcon(row, ICON_SIZE)
    row.icon:SetPoint("LEFT", 4, 0)

    row.id = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.id:SetPoint("LEFT", ID_X, 0)
    row.id:SetJustifyH("LEFT")

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.time:SetPoint("RIGHT", -6, 0)
    row.time:SetWidth(TIME_W)
    row.time:SetJustifyH("RIGHT")

    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
    row.source:SetWidth(SOURCE_W)
    row.source:SetJustifyH("RIGHT")
    row.source:SetWordWrap(false)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetPoint("RIGHT", row.source, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        PaintGradient(self.bg, "HORIZONTAL", Theme.menuItem.hoverLeft, Theme.menuItem.hoverRight)
        SetTextColor(self.name, Theme.menuItem.textHover)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0)
        SetTextColor(self.name, Theme.menuItem.text)
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

local function Populate()
    for _, row in ipairs(rows) do
        row:Hide()
    end
    for _, header in ipairs(headers) do
        header:Hide()
    end
    scrollFrame:SetVerticalScroll(0)

    if BR.BuffState.IsRestricted() then
        emptyText:SetText(L["AuraPicker.Restricted"])
        emptyText:Show()
        listContent:SetHeight(1)
        return
    end
    if not UnitExists(state.unit) then
        emptyText:SetText(L["AuraPicker.NoUnit"])
        emptyText:Show()
        listContent:SetHeight(1)
        return
    end
    emptyText:Hide()

    local y, rowIndex = 0, 0
    -- Debuffs are of no use to a custom buff, so the picker lists only buffs.
    local filterCount = state.onPick and 1 or #FILTERS
    for f = 1, filterCount do
        local def = FILTERS[f]
        local header = AcquireHeader(f)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 4, -y - 4)
        y = y + HEADER_H

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
            local rank = C_Spell.GetSpellSubtext(aura.spellId)
            if rank and rank ~= "" then
                row.name:SetText(aura.name .. " |cff808080(" .. rank .. ")|r")
            else
                row.name:SetText(aura.name)
            end
            row.source:SetText(aura.sourceUnit and UnitName(aura.sourceUnit) or "")
            row.time:SetText(FormatRemaining(aura))
            SetTextColor(row.name, Theme.menuItem.text)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()
            y = y + ROW_H
        end
        header:SetText(L[def.label] .. " (" .. count .. ")")
        header:Show()
    end
    listContent:SetHeight(math.max(y, 1))
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

    local idColumn = shell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    idColumn:SetPoint("TOPLEFT", MARGIN + ID_X, -COLUMNS_TOP)
    idColumn:SetText(L["AuraPicker.SpellID"])
    local nameColumn = shell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    nameColumn:SetPoint("TOPLEFT", MARGIN + NAME_X, -COLUMNS_TOP)
    nameColumn:SetText(L["AuraPicker.Name"])

    scrollFrame, listContent = Components.ScrollableContainer(shell, { width = LIST_W, contentHeight = 1 })
    scrollFrame:SetPoint("TOPLEFT", MARGIN, -LIST_TOP)
    scrollFrame:SetPoint("BOTTOMLEFT", MARGIN, FOOTER_H)

    emptyText = listContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 4, -8)
    emptyText:SetWidth(LIST_W - 32)
    emptyText:SetJustifyH("LEFT")

    copyField = Components.TextInput(shell, { label = L["AuraPicker.SpellID"], width = 90 })
    copyField:SetPoint("BOTTOMLEFT", MARGIN, 14)
    -- The field only carries the clicked ID for Ctrl+C, so typed text reverts.
    copyField.editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(copiedID)
            self:HighlightText()
        end
    end)

    hintText = shell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetJustifyH("LEFT")

    local refreshBtn = CreateButton(shell, L["AuraPicker.Refresh"], Populate)
    refreshBtn:SetSize(72, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 12)

    shell:SetScript("OnHide", function()
        copyField.editBox:ClearFocus()
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
    title:SetText(onPick and L["AuraPicker.PickTitle"] or L["AuraPicker.Title"])
    copyField:SetShown(not onPick)
    copiedID = ""
    copyField:SetValue(copiedID)
    hintText:SetText(onPick and L["AuraPicker.PickHint"] or L["AuraPicker.CopyHint"])
    hintText:ClearAllPoints()
    if onPick then
        hintText:SetPoint("BOTTOMLEFT", MARGIN, 18)
    else
        hintText:SetPoint("LEFT", copyField, "RIGHT", 8, 0)
    end
    hintText:SetPoint("RIGHT", shell, "RIGHT", -MARGIN - 80, 0)
    shell:ClearAllPoints()
    shell:SetPoint("CENTER")
    Populate()
    shell:Show()
end

BR.Options.Dialogs.AuraPicker = { Show = Show }
