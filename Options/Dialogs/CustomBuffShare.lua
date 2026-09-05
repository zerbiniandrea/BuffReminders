local _, BR = ...

-- ============================================================================
-- CUSTOM BUFF SHARE DIALOG
-- ============================================================================
-- Export one custom buff to a string, and import a string as a new entry.
-- Import decodes before it commits and shows what the string adds, because a
-- click action can carry a macro that runs on the importing player's character.
--
-- The dialog opens over the custom buff editor, so its frame level sits above
-- the shared dialog level.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local CreateBuffIcon = BR.CreateBuffIcon

local ImportExport = BR.ImportExport
local GetBuffTexture = BR.Helpers.GetBuffTexture

local DIALOG_W = 460
local MARGIN = 16
local CONTENT_W = DIALOG_W - MARGIN * 2
local LAYOUT_TOP = -42
local TEXT_AREA_H = 64
local PREVIEW_ICON = 24
local FOOTER_H = 44
local BOX_PAD = 8
local SHARE_LEVEL = BR.Options.Constants.DIALOG_LEVEL + 40

local shareDialog

local function CreateShell(titleText)
    if shareDialog then
        shareDialog:Hide()
    end

    local dialog = CreatePanel("BuffRemindersCustomBuffShare", DIALOG_W, 100, {
        level = SHARE_LEVEL,
        dialog = true,
    })
    shareDialog = dialog

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(titleText)

    BR.Options.Helpers.AddCloseButton(dialog)

    dialog.editBoxes = {}
    dialog:SetScript("OnHide", function(self)
        -- A focused edit box on a hidden frame keeps swallowing keystrokes.
        for _, editBox in ipairs(self.editBoxes) do
            editBox:ClearFocus()
        end
        if shareDialog == self then
            shareDialog = nil
        end
    end)

    return dialog, Components.VerticalLayout(dialog, { x = MARGIN, y = LAYOUT_TOP })
end

local function AddNote(dialog, layout, text)
    local note = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetWidth(CONTENT_W)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    layout:AddText(note, math.max(math.ceil(note:GetStringHeight()), 12), 8)
    return note
end

-- ============================================================================
-- IMPORT PREVIEW
-- ============================================================================

-- Same order the secure button resolves in, so the preview names what a click
-- will really do when a string carries more than one action.
local function DescribeAction(buff)
    if buff.castMacro then
        return buff.castMacro
    end
    if buff.castItemID then
        return L["CustomBuff.Action.Item"] .. " " .. buff.castItemID
    end
    if buff.castSpellID then
        return L["CustomBuff.Action.Spell"] .. " " .. buff.castSpellID
    end
    return nil
end

local function DescribeSpells(spellID)
    if type(spellID) ~= "table" then
        return tostring(spellID)
    end
    return table.concat(spellID, ", ")
end

-- The box exists only while a string decodes, so the dialog stays a paste box
-- until there is something to describe. It grows to fit: a macro of several
-- lines is exactly what the reader must see in full, so nothing here clips it.
-- Fit() returns the new height and the caller resizes the dialog around it.
local function CreatePreview(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(CONTENT_W, BOX_PAD * 2 + PREVIEW_ICON)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0, 0, 0, 0.25)
    box:SetBackdropBorderColor(unpack(BR.Colors.Border))

    local icon = CreateBuffIcon(box, PREVIEW_ICON)
    icon:SetPoint("TOPLEFT", BOX_PAD, -BOX_PAD)

    local name = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
    name:SetPoint("RIGHT", box, "RIGHT", -BOX_PAD, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local detail = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -BOX_PAD)
    detail:SetPoint("RIGHT", box, "RIGHT", -BOX_PAD, 0)
    detail:SetJustifyH("LEFT")

    local warning = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -6)
    warning:SetPoint("RIGHT", box, "RIGHT", -BOX_PAD, 0)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(0.9, 0.7, 0.3)

    local function Fit()
        local height = BOX_PAD + PREVIEW_ICON
        if detail:GetText() ~= "" then
            height = height + BOX_PAD + math.ceil(detail:GetStringHeight())
        end
        if warning:GetText() ~= "" then
            height = height + 6 + math.ceil(warning:GetStringHeight())
        end
        height = height + BOX_PAD
        box:SetHeight(height)
        return height
    end
    box.Fit = Fit
    box:Hide()

    function box:SetBuff(buff)
        local texture = GetBuffTexture(buff.spellID)
        icon:SetShown(texture ~= nil)
        if texture then
            icon:SetTexture(texture)
        end

        name:SetText(buff.name or DescribeSpells(buff.spellID))

        local lines = { L["CustomBuff.Share.Spells"] .. " " .. DescribeSpells(buff.spellID) }
        local action = DescribeAction(buff)
        if action then
            lines[#lines + 1] = L["CustomBuff.Share.Runs"] .. " " .. action
        end
        detail:SetText(table.concat(lines, "\n"))

        warning:SetText(buff.castMacro and L["CustomBuff.Share.MacroWarning"] or "")
        return Fit()
    end

    return box
end

-- ============================================================================
-- EXPORT
-- ============================================================================

local function ShowExport(key)
    local exportString, err = ImportExport.ExportCustomBuff(key)

    local dialog, layout = CreateShell(L["CustomBuff.Share.ExportTitle"])
    AddNote(dialog, layout, L["CustomBuff.Share.ExportDesc"])

    local textArea = Components.TextArea(dialog, {
        width = CONTENT_W,
        height = TEXT_AREA_H,
    })
    layout:Add(textArea, TEXT_AREA_H, 8)
    dialog.editBoxes[1] = textArea.editBox
    textArea:SetText(exportString or (L["CustomBuff.Error"] .. " " .. (err or "")))

    local closeBtn = CreateButton(dialog, L["Dialog.Close"], function()
        dialog:Hide()
    end)
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 12)

    dialog:SetHeight(-layout:GetY() + FOOTER_H)
    BR.ApplyDialogScale(dialog)
    dialog:Show()

    -- An edit box in a hidden frame takes no focus, so this must follow Show.
    textArea:SetFocus()
    textArea:HighlightText()
end

-- ============================================================================
-- IMPORT
-- ============================================================================

local function ShowImport(onImported)
    local dialog, layout = CreateShell(L["CustomBuff.Share.ImportTitle"])
    AddNote(dialog, layout, L["CustomBuff.Share.ImportDesc"])

    local preview = CreatePreview(dialog)
    local importBtn
    local Relayout -- set once the preview position is known

    local textArea = Components.TextArea(dialog, {
        width = CONTENT_W,
        height = TEXT_AREA_H,
        onTextChanged = function(text)
            local decoded = text ~= "" and ImportExport.DecodeCustomBuff(text) or nil
            if decoded then
                preview:SetBuff(decoded)
            end
            preview:SetShown(decoded ~= nil)
            importBtn:SetEnabled(decoded ~= nil)
            Relayout(text ~= "" and not decoded)
        end,
    })
    layout:Add(textArea, TEXT_AREA_H, 8)
    dialog.editBoxes[1] = textArea.editBox

    -- The preview and the error share the slot under the paste box, and only one
    -- of them ever occupies it. Everything above that slot is a fixed height.
    local slotY = layout:GetY()
    local baseHeight = -slotY + FOOTER_H
    layout:Add(preview, 0, 0)

    local errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    errorText:SetPoint("TOPLEFT", dialog, "TOPLEFT", MARGIN, slotY)
    errorText:SetPoint("RIGHT", dialog, "RIGHT", -MARGIN, 0)
    errorText:SetJustifyH("LEFT")
    errorText:SetTextColor(0.9, 0.4, 0.4)
    errorText:SetText(L["CustomBuff.Share.Invalid"])
    errorText:Hide()

    Relayout = function(showError)
        errorText:SetShown(showError or false)
        local slotHeight = 0
        if preview:IsShown() then
            slotHeight = preview:Fit() + BOX_PAD
        elseif errorText:IsShown() then
            slotHeight = math.ceil(errorText:GetStringHeight()) + BOX_PAD
        end
        dialog:SetHeight(baseHeight + slotHeight)
        BR.ApplyDialogScale(dialog)
    end

    importBtn = CreateButton(dialog, L["CustomBuff.Share.Import"], function()
        local key = ImportExport.ImportCustomBuff(textArea:GetText())
        if not key then
            preview:Hide()
            importBtn:SetEnabled(false)
            Relayout(true)
            return
        end
        dialog:Hide()
        BR.Display.Update()
        if onImported then
            onImported(key)
        end
    end)
    importBtn:SetSize(90, 22)
    importBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 12)
    importBtn:SetEnabled(false)
    importBtn:SetDisabledReason(L["CustomBuff.Share.ImportDisabled"])

    local cancelBtn = CreateButton(dialog, L["Dialog.Cancel"], function()
        dialog:Hide()
    end)
    cancelBtn:SetSize(90, 22)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)

    Relayout()

    dialog:Show()
    textArea:SetFocus()
end

BR.Options.Dialogs.CustomBuffShare = {
    ShowExport = ShowExport,
    ShowImport = ShowImport,
}
