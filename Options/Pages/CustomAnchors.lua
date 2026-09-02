local _, BR = ...

-- ============================================================================
-- CUSTOM ANCHORS TAB
-- ============================================================================
-- Editor for the user's custom anchor-target list, hosted as a tab on the
-- Layout page. Frames named here become selectable in every Anchor Frame
-- dropdown.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local LayoutSectionNote = Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local strtrim = strtrim
local wipe = wipe

---Build the tab body. Every rebuild sets the frame height. BuildTab then calls
---onResize, so the page can grow or shrink the scroll content.
local function BuildTab(frame, contentWidth, onResize)
    local layout = Components.VerticalLayout(frame, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    LayoutSectionNote(layout, frame, L["Options.CustomAnchorFrames.Desc"])
    LayoutSectionNote(layout, frame, L["Options.CustomAnchorFrames.PickNote"])

    local rowWidth = contentWidth - COL_PADDING * 2

    local addRow = CreateFrame("Frame", nil, frame)
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

    local list = CreateFrame("Frame", nil, frame)
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
            local target = _G[name]
            local exists = type(target) == "table" and target.GetCenter ~= nil
            if exists then
                text:SetText(name)
            else
                -- An unresolvable name never appears in the anchor dropdowns.
                -- The marker makes that visible.
                text:SetText(name .. " |cffe0b34d!|r")
                row:EnableMouse(true)
                row:SetScript("OnEnter", function()
                    BR.ShowTooltip(row, name, L["Layout.FrameNotFound"], "ANCHOR_TOP")
                end)
                row:SetScript("OnLeave", BR.HideTooltip)
            end

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                table.remove(names, i)
                if #names == 0 then
                    db.customAnchorFrames = nil
                end
                BR.CallbackRegistry:TriggerEvent("CustomAnchorsChanged")
            end)

            table.insert(entries, row)
            entryY = entryY + 22
        end

        list:SetHeight(math.max(1, entryY))
        frame:SetHeight(math.abs(layout:GetY()) + entryY + 16)
        onResize()
    end

    addBtn = CreateButton(addRow, L["Options.Add"], function()
        local name = strtrim(addBox:GetText())
        if name == "" then
            return
        end
        addBox:SetText("")
        BR.Movers.RememberAnchorFrame(name)
    end)
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addInput, "RIGHT", 6, 0)

    -- The panel hides for the pick. It covers the middle of the screen, where the
    -- target frames are.
    local pickBtn = CreateButton(addRow, L["Mover.PickFrame"], function()
        BR.Options.Hide()
        BR.Movers.PickFrame(function(name)
            BR.Options.Show()
            if name then
                BR.Movers.RememberAnchorFrame(name)
            end
        end)
    end)
    pickBtn:SetSize(50, 22)
    pickBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

    addBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addBtn:Click()
    end)

    layout:Add(addRow, nil, COMPONENT_GAP)
    layout:Add(list, nil, COMPONENT_GAP)

    Rebuild()

    -- A name can arrive from the mover popup as well as from this tab. The list
    -- follows the data, not the button that changed it.
    BR.CallbackRegistry:RegisterCallback("CustomAnchorsChanged", Rebuild)

    -- A profile switch replaces the list, so the tab renders again on show.
    table.insert(BR.RefreshableComponents, {
        Refresh = function()
            if frame:IsVisible() then
                Rebuild()
            end
        end,
    })
end

BR.Options.CustomAnchors = {
    BuildTab = BuildTab,
}

BR.Options.WhatsNew.Register({ cohort = "6.5.1", pageId = "layout" })
