local _, BR = ...

-- ============================================================================
-- CHAT REQUESTS PAGE
-- ============================================================================
-- Owns the chat-request feature end-to-end: the master toggle, the per-buff
-- message table, and the reset-all action. Replaces the old toggle + dialog
-- combo (Dialogs/ChatRequest) - inline editing makes the customization
-- discoverable instead of buried behind a "Customize..." button.

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
local abs = math.abs

local ICON_SIZE = 20
local ICON_GAP = 6
local LABEL_WIDTH = 150
local ROW_GAP = 6
local MAX_INPUT_WIDTH = 320

-- The requestable buff list and the categories to refresh are derived from the
-- `chatRequestable` flag by Core/ChatRequest.lua - the single source of truth
-- shared with the runtime overlay wiring (SecureButtons).
local ChatRequest = BR.ChatRequest

-- Re-evaluate click overlays for every category that hosts a chat-requestable buff.
local function RefreshChatActions()
    for _, cat in ipairs(ChatRequest.Categories()) do
        BR.Display.UpdateActionButtons(cat)
    end
end

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })
    local contentWidth = scrollFrame:GetContentWidth()

    -- Description
    LayoutSectionNote(layout, content, L["Options.RequestBuffInChat.Desc"])

    -- Master toggle
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

    -- Per-buff message table
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

    -- Reset all
    layout:Space(4)
    local resetBtn = CreateButton(content, L["Options.ChatRequest.ResetAll"], function()
        BR.profile.chatRequestMessages = {}
        for _, holder in pairs(inputHolders) do
            holder:SetValue("")
        end
        RefreshChatActions()
    end)
    layout:Add(resetBtn, nil, COMPONENT_GAP)

    -- Anti-spam cooldown between chat requests. Straightforward polarity:
    -- checked = cooldown on (the default). Disabling it is the workaround for a
    -- client bug that silently drops chat dispatch for some players - the yellow
    -- hint below points at the fix without inverting the checkbox into a
    -- confusing "attempt to fix" toggle.
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

    -- Yellow troubleshooting hint sitting directly under the checkbox.
    local cooldownHint = LayoutSubsectionNote(layout, content, L["Options.ChatRequest.Cooldown.Hint"])
    cooldownHint:SetTextColor(1, 0.82, 0)

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.chatRequests = {
    title = L["Page.ChatRequests"],
    Build = Build,
}
