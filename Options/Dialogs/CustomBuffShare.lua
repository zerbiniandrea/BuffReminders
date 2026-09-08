local _, BR = ...

-- ============================================================================
-- CUSTOM BUFF SHARE DIALOG
-- ============================================================================
-- Export one custom buff to a string, and import a string as a new entry.
-- Import decodes before it commits and shows what the string adds, because a
-- click action can carry a macro that runs on the importing player's character.
--
-- The shell and both bodies are built one time and reused: a frame is never
-- destroyed, so a panel rebuilt per open would accumulate for the session. The
-- two bodies share the shell and only one of them is ever shown.
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
local BUTTON_W = 90
local BUTTON_H = 22
local SHARE_LEVEL = BR.Options.Constants.DIALOG_LEVEL + 40

local shell, shellTitle
local exportUI, importUI

-- ============================================================================
-- SHELL
-- ============================================================================

local function EnsureShell()
    if shell then
        return shell
    end

    shell = CreatePanel("BuffRemindersCustomBuffShare", DIALOG_W, 100, {
        level = SHARE_LEVEL,
        dialog = true,
    })
    -- CreateFrame returns a shown frame, and the body is built after this.
    shell:Hide()

    shellTitle = shell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    shellTitle:SetPoint("TOP", 0, -12)

    BR.Options.Helpers.AddCloseButton(shell)

    shell:SetScript("OnHide", function()
        -- A focused edit box on a hidden frame keeps swallowing keystrokes.
        if exportUI then
            exportUI.textArea:ClearFocus()
        end
        if importUI then
            importUI.textArea:ClearFocus()
        end
    end)

    return shell
end

---Show one body and hide the other. Returns the body frame.
local function ActivateBody(ui, titleText)
    shellTitle:SetText(titleText)
    if exportUI then
        exportUI.body:SetShown(ui == exportUI)
    end
    if importUI then
        importUI.body:SetShown(ui == importUI)
    end
    return ui.body
end

local function CreateBody()
    local body = CreateFrame("Frame", nil, EnsureShell())
    body:SetAllPoints()
    body:Hide()
    return body, Components.VerticalLayout(body, { x = MARGIN, y = LAYOUT_TOP })
end

local function AddNote(body, layout, text)
    local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
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

local function EnsureExportUI()
    if exportUI then
        return exportUI
    end

    local body, layout = CreateBody()
    AddNote(body, layout, L["CustomBuff.Share.ExportDesc"])

    local textArea = Components.TextArea(body, { width = CONTENT_W, height = TEXT_AREA_H })
    layout:Add(textArea, TEXT_AREA_H, 8)

    local closeBtn = CreateButton(body, L["Dialog.Close"], function()
        shell:Hide()
    end)
    closeBtn:SetSize(BUTTON_W, BUTTON_H)
    closeBtn:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -MARGIN, 12)

    exportUI = { body = body, textArea = textArea, height = -layout:GetY() + FOOTER_H }
    return exportUI
end

local function ShowExport(key)
    local exportString, err = ImportExport.ExportCustomBuff(key)

    local ui = EnsureExportUI()
    ActivateBody(ui, L["CustomBuff.Share.ExportTitle"])
    ui.textArea:SetText(exportString or (L["CustomBuff.Error"] .. " " .. (err or "")))

    shell:SetHeight(ui.height)
    BR.ApplyDialogScale(shell)
    shell:Show()

    -- An edit box in a hidden frame takes no focus, so this must follow Show.
    ui.textArea:SetFocus()
    ui.textArea:HighlightText()
end

-- ============================================================================
-- IMPORT
-- ============================================================================

local function EnsureImportUI()
    if importUI then
        return importUI
    end

    local body, layout = CreateBody()
    AddNote(body, layout, L["CustomBuff.Share.ImportDesc"])

    local ui = { body = body }

    local preview = CreatePreview(body)
    ui.preview = preview

    local textArea = Components.TextArea(body, {
        width = CONTENT_W,
        height = TEXT_AREA_H,
        onTextChanged = function(text)
            local decoded = text ~= "" and ImportExport.DecodeCustomBuff(text) or nil
            if decoded then
                preview:SetBuff(decoded)
            end
            preview:SetShown(decoded ~= nil)
            ui.importBtn:SetEnabled(decoded ~= nil)
            ui.Relayout(text ~= "" and not decoded)
        end,
    })
    layout:Add(textArea, TEXT_AREA_H, 8)
    ui.textArea = textArea

    -- The preview and the error share the slot under the paste box, and only one
    -- of them ever occupies it. Everything above that slot is a fixed height.
    local slotY = layout:GetY()
    local baseHeight = -slotY + FOOTER_H
    layout:Add(preview, 0, 0)

    local errorText = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    errorText:SetPoint("TOPLEFT", body, "TOPLEFT", MARGIN, slotY)
    errorText:SetPoint("RIGHT", body, "RIGHT", -MARGIN, 0)
    errorText:SetJustifyH("LEFT")
    errorText:SetTextColor(0.9, 0.4, 0.4)
    errorText:SetText(L["CustomBuff.Share.Invalid"])
    errorText:Hide()

    function ui.Relayout(showError)
        errorText:SetShown(showError or false)
        local slotHeight = 0
        if preview:IsShown() then
            slotHeight = preview:Fit() + BOX_PAD
        elseif errorText:IsShown() then
            slotHeight = math.ceil(errorText:GetStringHeight()) + BOX_PAD
        end
        shell:SetHeight(baseHeight + slotHeight)
        BR.ApplyDialogScale(shell)
    end

    local importBtn = CreateButton(body, L["CustomBuff.Share.Import"], function()
        local key = ImportExport.ImportCustomBuff(textArea:GetText())
        if not key then
            preview:Hide()
            ui.importBtn:SetEnabled(false)
            ui.Relayout(true)
            return
        end
        shell:Hide()
        BR.Display.Update()
        if ui.onImported then
            ui.onImported(key)
        end
    end)
    importBtn:SetSize(BUTTON_W, BUTTON_H)
    importBtn:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -MARGIN, 12)
    importBtn:SetDisabledReason(L["CustomBuff.Share.ImportDisabled"])
    ui.importBtn = importBtn

    local cancelBtn = CreateButton(body, L["Dialog.Cancel"], function()
        shell:Hide()
    end)
    cancelBtn:SetSize(BUTTON_W, BUTTON_H)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)

    importUI = ui
    return ui
end

local function ShowImport(onImported)
    local ui = EnsureImportUI()
    ActivateBody(ui, L["CustomBuff.Share.ImportTitle"])

    ui.onImported = onImported
    ui.preview:Hide()
    ui.importBtn:SetEnabled(false)
    ui.textArea:SetText("")
    ui.Relayout(false)

    shell:Show()
    ui.textArea:SetFocus()
end

BR.Options.Dialogs.CustomBuffShare = {
    ShowExport = ShowExport,
    ShowImport = ShowImport,
}
