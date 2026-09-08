local _, BR = ...

-- ============================================================================
-- CHAT REQUESTS PAGE
-- ============================================================================
-- Owns the chat-request feature end-to-end: the master toggle, the per-buff
-- message table, and the reset-all action.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreateBuffIcon = BR.CreateBuffIcon
local GetBuffIcons = BR.Helpers.GetBuffIcons

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote
local LayoutSubsectionNote = BR.Options.Helpers.LayoutSubsectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local strtrim = strtrim

local ICON_SIZE = 20
local ICON_GAP = 6
local LABEL_WIDTH = 150
local ROW_GAP = 6
local MAX_INPUT_WIDTH = 320

local ChatRequest = BR.ChatRequest

local function RefreshChatActions()
    for _, cat in ipairs(ChatRequest.Categories()) do
        BR.Display.UpdateActionButtons(cat)
    end
end

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })
    local contentWidth = scrollFrame:GetContentWidth()

    LayoutSectionNote(layout, content, L["Options.RequestBuffInChat.Desc"])

    local requestBuffHolder = Components.Checkbox(content, {
        label = L["Options.RequestBuffInChat"],
        get = function()
            return BR.profile.requestBuffInChat == true
        end,
        tooltip = {
            title = L["Options.RequestBuffInChat"],
            desc = L["Options.RequestBuffInChat.Desc"],
        },
        onChange = function(checked)
            BR.profile.requestBuffInChat = checked
            RefreshChatActions()
            Components.RefreshAll()
        end,
    })
    layout:Add(requestBuffHolder, nil, COMPONENT_GAP)

    LayoutSectionHeader(layout, content, L["ChatRequests.PerBuffMessages"])

    local function isToggleOn()
        return BR.profile.requestBuffInChat == true
    end

    -- Each row: [icon] [TextInput with embedded buff-name label].
    -- The TextInput holder anchors at ICON_SIZE + ICON_GAP within rowsHost, so
    -- the icon sits in the left gutter aligned with each input.
    local rowsHost = CreateFrame("Frame", nil, content)
    rowsHost:SetSize(contentWidth - COL_PADDING * 2, 1)

    local availableInputWidth = contentWidth - COL_PADDING * 2 - ICON_SIZE - ICON_GAP - LABEL_WIDTH
    local inputWidth = math.min(availableInputWidth, MAX_INPUT_WIDTH)

    local rowY = 0
    local inputHolders = {}

    for _, entry in ipairs(ChatRequest.Buffs()) do
        local key = entry.key
        local holder = Components.TextInput(content, {
            label = entry.name,
            labelWidth = LABEL_WIDTH,
            width = inputWidth,
            get = function()
                local custom = (BR.profile.chatRequestMessages or {})[key]
                return (custom and custom ~= "") and custom or ""
            end,
            enabled = isToggleOn,
            onChange = function(text)
                text = strtrim(text)
                if not BR.profile.chatRequestMessages then
                    BR.profile.chatRequestMessages = {}
                end
                if text == "" then
                    BR.profile.chatRequestMessages[key] = nil
                else
                    BR.profile.chatRequestMessages[key] = text
                end
                RefreshChatActions()
            end,
        })
        holder.editBox:SetMaxLetters(120)
        holder:SetPoint("TOPLEFT", rowsHost, "TOPLEFT", ICON_SIZE + ICON_GAP, -rowY)
        inputHolders[key] = holder

        local icon = CreateBuffIcon(rowsHost, ICON_SIZE, GetBuffIcons(entry)[1])
        icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)

        rowY = rowY + ICON_SIZE + ROW_GAP
    end

    rowsHost:SetHeight(rowY)
    layout:Add(rowsHost, rowY, COMPONENT_GAP)

    layout:Space(4)
    local resetBtn = CreateButton(content, L["Options.ChatRequest.ResetAll"], function()
        BR.profile.chatRequestMessages = {}
        for _, holder in pairs(inputHolders) do
            holder:SetValue("")
        end
        RefreshChatActions()
    end)
    resetBtn:BindEnabled(isToggleOn)
    layout:Add(resetBtn, nil, COMPONENT_GAP)

    -- Checked = cooldown on, which is the default. A client bug drops the chat
    -- dispatch for some players. For those players, the cooldown off is the fix.
    layout:Space(12)
    local cooldownHolder = Components.Checkbox(content, {
        label = L["Options.ChatRequest.Cooldown"],
        get = function()
            return BR.profile.chatRequestCooldown ~= false
        end,
        tooltip = {
            title = L["Options.ChatRequest.Cooldown"],
            desc = L["Options.ChatRequest.Cooldown.Desc"],
        },
        enabled = isToggleOn,
        onChange = function(checked)
            BR.Config.Set("chatRequestCooldown", checked)
        end,
    })
    layout:Add(cooldownHolder, nil, COMPONENT_GAP)

    local cooldownHint = LayoutSubsectionNote(layout, content, L["Options.ChatRequest.Cooldown.Hint"])
    cooldownHint:SetTextColor(1, 0.82, 0)

    content:SetHeight(math.abs(layout:GetY()) + 20)
end

BR.Options.Pages.chatRequests = {
    title = L["Page.ChatRequests"],
    Build = Build,
}
