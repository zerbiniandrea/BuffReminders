local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- CHAT REQUESTS PAGE
-- ============================================================================
-- The request toggles and one message per requestable buff. A message field
-- shows the localized default until the player saves a custom message.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers
local Theme = BR.Theme
local ChatRequest = BR.ChatRequest

local COL_PADDING = BR.Options.Constants.COL_PADDING
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local ICON_SIZE = 20
local ICON_GAP = 6
local ROW_H = 24
local MIN_NAME_W = 140
local DOT_SIZE = 5
local DOT_GAP = 4
local LABEL_GAP = 5 -- TextInput gap between its label and its field
local GLYPH_SIZE = 16
local GLYPH_GAP = 4
local MAX_LETTERS = 120
local DOT_TEXTURE = "Interface\\AddOns\\BuffReminders\\Media\\dot.tga"

local function RefreshChatActions()
    for _, cat in ipairs(ChatRequest.Categories()) do
        BR.SecureButtons.UpdateActionButtons(cat)
    end
end

local function RequestsOn()
    return BR.profile.requestBuffInChat == true
end

-- The chat server rejects a message with an escape sequence. nil keeps the localized default.
local function CleanMessage(text, defaultText)
    text = strtrim(((text or ""):gsub("|", "")))
    if text == "" or text == defaultText then
        return nil
    end
    return text
end

-- A focused field saves on focus loss. Call before a refresh rewrites the fields, so typed text is not lost.
local function CommitFocus()
    local focus = GetCurrentKeyBoardFocus()
    if focus then
        focus:ClearFocus()
    end
end

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })
    local contentWidth = scrollFrame:GetContentWidth()

    Helpers.LayoutSectionNote(layout, content, L["ChatRequests.PageNote"])

    local requestsHolder = Components.Checkbox(content, {
        label = L["Options.RequestBuffInChat"],
        get = RequestsOn,
        tooltip = { title = L["Options.RequestBuffInChat"], desc = L["Options.RequestBuffInChat.Tooltip"] },
        onChange = function(checked)
            CommitFocus()
            BR.Config.Set("requestBuffInChat", checked)
            RefreshChatActions()
            Components.RefreshAll()
        end,
    })
    layout:Add(requestsHolder, nil, COMPONENT_GAP)

    -- A client bug drops the chat dispatch for some players. For those players, the cooldown off is the fix.
    local cooldownHolder = Components.Checkbox(content, {
        label = L["Options.ChatRequest.Wait"],
        get = function()
            return BR.profile.chatRequestCooldown ~= false
        end,
        tooltip = { title = L["Options.ChatRequest.Wait"], desc = L["Options.ChatRequest.Wait.Desc"] },
        enabled = RequestsOn,
        disabledReason = L["DisabledReason.ChatRequestsOff"],
        onChange = function(checked)
            CommitFocus()
            BR.Config.Set("chatRequestCooldown", checked)
        end,
    })
    layout:Add(cooldownHolder, nil, 0)
    layout:SetX(COL_PADDING + cooldownHolder.labelOffset)
    Helpers.LayoutSubsectionNote(layout, content, L["Options.ChatRequest.Cooldown.Hint"])

    layout:Space(BR.Options.Constants.BEFORE_HEADER_GAP)
    local header = Helpers.LayoutSectionHeader(layout, content, L["ChatRequests.Messages"])

    local rowsWidth = contentWidth - layout:GetX() - COL_PADDING
    local names = {}
    for _, cat in ipairs(ChatRequest.Categories()) do
        for _, def in ipairs(ChatRequest.BuffsIn(cat)) do
            names[#names + 1] = def.name
        end
    end
    local nameWidth = Components.MeasureSharedLabelWidth(names, "GameFontHighlightSmall", MIN_NAME_W)
        + DOT_GAP
        + DOT_SIZE
    local fieldWidth = rowsWidth - ICON_SIZE - ICON_GAP - nameWidth - LABEL_GAP - GLYPH_GAP - GLYPH_SIZE

    local rows = {}
    local resetAll

    local function SavedMessage(row)
        local custom = (BR.profile.chatRequestMessages or {})[row.key]
        -- Same text that ResolveMessage sends.
        custom = custom and custom:gsub("|", "")
        if custom and custom ~= "" and custom ~= row.default then
            return custom
        end
        return nil
    end

    local function PaintRow(row, isCustom)
        row.input:SetTextColor(not isCustom and Theme.editBox.defaultText or nil)
        row.dot:SetShown(isCustom)
        row.reset:SetShown(isCustom)
    end

    local function Save(row, text)
        if not BR.profile.chatRequestMessages then
            BR.profile.chatRequestMessages = {}
        end
        local before = SavedMessage(row)
        BR.profile.chatRequestMessages[row.key] = CleanMessage(text, row.default)
        local saved = SavedMessage(row)
        if saved ~= before then
            RefreshChatActions()
        end
        row.input:SetValue(saved or row.default)
        PaintRow(row, saved ~= nil)
        resetAll:Refresh()
    end

    local labels = BR.Options.GetCategoryLabels()
    for _, cat in ipairs(ChatRequest.Categories()) do
        Helpers.LayoutSubsectionHeader(layout, content, labels[cat])
        for _, def in ipairs(ChatRequest.BuffsIn(cat)) do
            local row = { key = def.key, default = ChatRequest.DefaultMessage(def.key, def.name) }
            local frame = CreateFrame("Frame", nil, content)
            frame:SetSize(rowsWidth, ROW_H)

            local icon = BR.CreateBuffIcon(frame, ICON_SIZE, BR.Icons.GetBuffIcons(def)[1])
            icon:SetPoint("LEFT", 0, 0)

            row.input = Components.TextInput(frame, {
                label = def.name,
                labelWidth = nameWidth,
                width = fieldWidth,
                get = function()
                    -- The default text and the icon can name a spell that a setting picks.
                    row.default = ChatRequest.DefaultMessage(def.key, def.name)
                    local requested = def.chatRequestSpell and def.chatRequestSpell()
                    icon:SetTexture(requested and BR.Icons.GetBuffTexture(requested) or BR.Icons.GetBuffIcons(def)[1])
                    return SavedMessage(row) or row.default
                end,
                onChange = function(text)
                    Save(row, text)
                end,
            })
            row.input:SetPoint("LEFT", ICON_SIZE + ICON_GAP, 0)
            local editBox = row.input.editBox
            editBox:SetMaxLetters(MAX_LETTERS)
            editBox:HookScript("OnTextChanged", function(_, userInput)
                if userInput then
                    PaintRow(row, CleanMessage(editBox:GetText(), row.default) ~= nil)
                end
            end)

            local nameLabel = row.input.label
            row.dot = frame:CreateTexture(nil, "ARTWORK")
            row.dot:SetSize(DOT_SIZE, DOT_SIZE)
            row.dot:SetPoint("LEFT", nameLabel, "LEFT", nameLabel:GetStringWidth() + DOT_GAP, 0)
            row.dot:SetTexture(DOT_TEXTURE)
            local dotColor = Theme.cell.changed
            row.dot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], dotColor[4] or 1)

            local reset = CreateFrame("Button", nil, frame)
            reset:SetSize(GLYPH_SIZE, GLYPH_SIZE)
            reset:SetPoint("RIGHT", 0, 0)
            reset.glyph = Helpers.AddResetGlyph(reset)
            Helpers.PaintParts(reset.glyph, Theme.cell.reset)
            reset:SetScript("OnClick", function()
                BR.HideTooltip()
                CommitFocus()
                Save(row, "")
            end)
            reset:SetScript("OnEnter", function(self)
                Helpers.PaintParts(self.glyph, Theme.cell.resetHover)
                BR.ShowTooltip(self, L["ChatRequests.Restore"]:format(row.default), nil, "ANCHOR_TOP")
            end)
            reset:SetScript("OnLeave", function(self)
                Helpers.PaintParts(self.glyph, Theme.cell.reset)
                BR.HideTooltip()
            end)
            row.reset = reset

            PaintRow(row, SavedMessage(row) ~= nil)
            rows[#rows + 1] = row
            layout:Add(frame, ROW_H, 0)
        end
    end

    local function AnyCustom()
        for _, row in ipairs(rows) do
            if SavedMessage(row) then
                return true
            end
        end
        return false
    end

    local headerRow = header:GetParent()
    resetAll = BR.CreateButton(headerRow, L["Options.ChatRequest.ResetAll"], function()
        CommitFocus()
        BR.profile.chatRequestMessages = {}
        RefreshChatActions()
        Components.RefreshAll()
    end)
    resetAll:SetHeight(18)
    resetAll:SetPoint("RIGHT", headerRow, "TOPRIGHT", 0, -7)
    resetAll:SetDisabledReason(L["DisabledReason.NoCustomMessages"])
    resetAll:BindEnabled(AnyCustom)

    local rowsRefresher = {
        Refresh = function()
            for _, row in ipairs(rows) do
                PaintRow(row, SavedMessage(row) ~= nil)
            end
        end,
    }
    tinsert(BR.RefreshableComponents, rowsRefresher)
    rowsRefresher.Refresh()

    content:SetHeight(math.abs(layout:GetY()) + 20)
end

BR.Options.Pages.chatRequests = {
    title = L["Page.ChatRequests"],
    Build = Build,
}
