local _, BR = ...

-- ============================================================================
-- ANCHOR FRAMES PAGE
-- ============================================================================
-- Editor for the user's custom unit-frame anchor list. BuffReminders may
-- attach detached buff icons to any frame whose global name appears here. The
-- page is intentionally narrow in scope: description, an add-row, and the
-- existing entries.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local strtrim = strtrim
local tinsert = table.insert
local tremove = table.remove
local mmax = math.max
local abs = math.abs
local wipe = wipe

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

    local contentWidth = scrollFrame:GetContentWidth()
    local rowWidth = contentWidth - COL_PADDING * 2

    LayoutSectionNote(layout, content, L["Options.CustomAnchorFrames.Desc"])

    local addRow = CreateFrame("Frame", nil, content)
    addRow:SetSize(rowWidth, 22)

    local addInput = Components.TextInput(addRow, {
        label = "",
        value = "",
        width = 220,
        labelWidth = 0,
    })
    addInput:SetPoint("LEFT", 0, 0)
    local addBox = addInput.editBox

    local addBtn

    local list = CreateFrame("Frame", nil, content)
    list:SetSize(rowWidth, 1)

    local entries = {}

    local function Rebuild()
        for _, entry in ipairs(entries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(entries)

        local db = BR.profile
        local names = db.customAnchorFrames or {}
        local entryY = 0

        for i, name in ipairs(names) do
            local row = CreateFrame("Frame", nil, list)
            row:SetSize(rowWidth, 20)
            row:SetPoint("TOPLEFT", 0, -entryY)

            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bullet:SetPoint("LEFT", 4, 0)
            bullet:SetText("-")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", bullet, "RIGHT", 4, 0)
            text:SetText(name)

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                tremove(names, i)
                if #names == 0 then
                    db.customAnchorFrames = nil
                end
                Rebuild()
            end)

            tinsert(entries, row)
            entryY = entryY + 22
        end

        list:SetHeight(mmax(1, entryY))
        content:SetHeight(abs(layout:GetY()) + entryY + 30)
    end

    addBtn = CreateButton(addRow, L["Options.Add"], function()
        local name = strtrim(addBox:GetText())
        if name == "" then
            return
        end
        local db = BR.profile
        if not db.customAnchorFrames then
            db.customAnchorFrames = {}
        end
        for _, existing in ipairs(db.customAnchorFrames) do
            if existing == name then
                addBox:SetText("")
                return
            end
        end
        tinsert(db.customAnchorFrames, name)
        addBox:SetText("")
        Rebuild()
    end)
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addInput, "RIGHT", 6, 0)

    addBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addBtn:Click()
    end)

    layout:Add(addRow, nil, COMPONENT_GAP)
    layout:Add(list, nil, COMPONENT_GAP)

    Rebuild()
end

BR.Options.Pages.anchorFrames = {
    title = L["Page.AnchorFrames"],
    Build = Build,
}
