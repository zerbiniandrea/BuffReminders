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

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local strtrim = strtrim
local abs = math.abs

local ICON_SIZE = 20
local ICON_GAP = 6
local LABEL_WIDTH = 150
local ROW_GAP = 6
local MAX_INPUT_WIDTH = 320

-- Spell IDs are referenced only for icon textures here; the keys link back to
-- the buff system via BR.profile.chatRequestMessages[key].
local CHAT_REQUEST_BUFFS = {
    { key = "intellect", labelKey = "Buff.ArcaneIntellect", spellID = 1459 },
    { key = "attackPower", labelKey = "Buff.BattleShout", spellID = 6673 },
    { key = "stamina", labelKey = "Buff.PowerWordFortitude", spellID = 21562 },
    { key = "versatility", labelKey = "Buff.MarkOfTheWild", spellID = 1126 },
    { key = "skyfury", labelKey = "Buff.Skyfury", spellID = 462854 },
    { key = "bronze", labelKey = "Buff.BlessingOfTheBronze", spellID = 364342 },
    { key = "devotionAura", labelKey = "Buff.DevotionAura", spellID = 465 },
    { key = "atrophicNumbingPoison", labelKey = "Buff.AtrophicNumbingPoison", spellID = 381637 },
    { key = "soulstone", labelKey = "Buff.Soulstone", spellID = 20707 },
}

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })
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
            BR.Display.UpdateActionButtons("raid")
            BR.Display.UpdateActionButtons("presence")
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
    -- The TextInput holder anchors at COL_PADDING + ICON_SIZE + ICON_GAP, so
    -- the icon sits in the left gutter aligned with each input.
    local rowX = COL_PADDING + ICON_SIZE + ICON_GAP
    local rowsHost = CreateFrame("Frame", nil, content)
    rowsHost:SetSize(contentWidth - COL_PADDING * 2, 1)

    local availableInputWidth = contentWidth - COL_PADDING * 2 - ICON_SIZE - ICON_GAP - LABEL_WIDTH
    local inputWidth = math.min(availableInputWidth, MAX_INPUT_WIDTH)

    local rowY = 0
    local inputHolders = {}

    for _, entry in ipairs(CHAT_REQUEST_BUFFS) do
        local key = entry.key
        local holder = Components.TextInput(content, {
            label = L[entry.labelKey],
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
                BR.Display.UpdateActionButtons("raid")
                BR.Display.UpdateActionButtons("presence")
            end,
        })
        holder.editBox:SetMaxLetters(120)
        holder:SetPoint("TOPLEFT", rowsHost, "TOPLEFT", ICON_SIZE + ICON_GAP, -rowY)
        inputHolders[key] = holder

        local icon = CreateBuffIcon(rowsHost, ICON_SIZE, C_Spell.GetSpellTexture(entry.spellID))
        icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)

        rowY = rowY + ICON_SIZE + ROW_GAP
    end

    rowsHost:SetHeight(rowY)
    layout:Add(rowsHost, rowY, COMPONENT_GAP)

    -- Reset all
    layout:Space(4)
    local resetBtn = CreateButton(content, L["Options.ChatRequest.ResetAll"], function()
        BR.profile.chatRequestMessages = {}
        for key, holder in pairs(inputHolders) do
            holder:SetValue("")
            local _ = key
        end
        BR.Display.UpdateActionButtons("raid")
        BR.Display.UpdateActionButtons("presence")
    end)
    layout:Add(resetBtn, nil, COMPONENT_GAP)

    -- Troubleshooting opt-in for the rare client bug that silently drops chat
    -- dispatch in restricted contexts (M+, encounters). Inverted vs. the
    -- underlying setting: checked = fix attempt = chatRequestCooldown false.
    -- Default unchecked, so the spam-prevention cooldown stays on for the
    -- 99.99%+ of users who don't hit the bug.
    layout:Space(12)
    local fixAttemptHolder = Components.Checkbox(content, {
        label = L["Options.ChatRequest.FixAttempt"],
        get = function()
            return BR.profile.chatRequestCooldown == false
        end,
        enabled = isToggleOn,
        onChange = function(checked)
            BR.profile.chatRequestCooldown = not checked
        end,
    })
    layout:Add(fixAttemptHolder, nil, 4)

    -- Yellow inline note. Wraps to the content width minus the layout's
    -- current x-indent so it sits aligned under the checkbox, not at the
    -- page edge.
    local fixAttemptNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fixAttemptNote:SetTextColor(1, 0.82, 0)
    fixAttemptNote:SetJustifyH("LEFT")
    local noteWidth = contentWidth - layout:GetX() - COL_PADDING
    if noteWidth < 1 then
        noteWidth = 1
    end
    fixAttemptNote:SetWidth(noteWidth)
    fixAttemptNote:SetText(L["Options.ChatRequest.FixAttempt.Desc"])
    layout:AddText(fixAttemptNote, math.ceil(fixAttemptNote:GetStringHeight()), COMPONENT_GAP)

    content:SetHeight(abs(layout:GetY()) + 20)

    -- rowX is reserved for absolute-positioned children; suppress unused-var.
    local _ = rowX
end

BR.Options.Pages.chatRequests = {
    title = L["Page.ChatRequests"],
    Build = Build,
}
