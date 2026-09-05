local _, BR = ...

-- ============================================================================
-- CUSTOM BUFFS PAGE
-- ============================================================================
-- List of user-defined custom buffs, one row per buff. Add and edit open
-- BR.Options.Dialogs.CustomBuff.Show.
--
-- Built on the shared BR.Options.Helpers.ListEditor skeleton: rows flow in the
-- page's own scroll container, with no nested scroll box. This page supplies
-- only the data source (getItems) and the row content (fillRow).
--
-- Display styling for the custom category lives on the Categories page's Custom
-- tab. This page is only the entry-list editor.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local ListEditor = BR.Options.Helpers.ListEditor

local UpdateDisplay = BR.Display.Update

local GetBuffIcons = BR.Helpers.GetBuffIcons

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local tinsert = table.insert

local ROW_HEIGHT = 28
local ICON_SIZE = 20
local ACTION_BUTTON_WIDTH = 60
local ACTION_BUTTON_HEIGHT = 22
local ACTION_BUTTON_GAP = 8
local DEFAULT_ICON_TEXTURE = 134400

local function FormatRestrictions(buff)
    local parts = {}
    if buff.class then
        local localized = L["Class." .. buff.class:sub(1, 1) .. buff.class:sub(2):lower()]
        tinsert(parts, localized or buff.class)
    end
    if buff.requireItemID then
        tinsert(parts, L["CustomBuff.RequireItem"] .. " " .. buff.requireItemID)
    end
    if buff.glowMode and buff.glowMode ~= "disabled" then
        tinsert(parts, L["CustomBuff.BarGlow"] or "Bar glow")
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, " · ")
end

-- Fills one row with the per-buff widgets. The right-side controls are chained:
-- delete anchors to body.RIGHT and edit anchors to delete.LEFT. A change to a
-- width or a gap then needs no new absolute offsets.
local function FillRowBody(body, key, buff, onEdit, onDelete)
    -- The label is empty, so holderWidth is 18. The default of 200 pushes every
    -- following widget 200px to the right.
    local checkbox = Components.Checkbox(body, {
        label = "",
        holderWidth = 18,
        get = function()
            return BR.StateHelpers.IsBuffEnabled(key)
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
        end,
    })
    checkbox:SetPoint("LEFT", 0, 0)

    local iconTex = body:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    local tex = GetBuffIcons(buff)[1]
    if tex then
        iconTex:SetTexture(tex)
        iconTex:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    else
        iconTex:SetTexture(DEFAULT_ICON_TEXTURE)
    end

    local deleteBtn = CreateButton(body, L["Options.Delete"], onDelete)
    deleteBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    local editBtn = CreateButton(body, L["CustomBuff.EditShort"], onEdit)
    editBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    editBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -ACTION_BUTTON_GAP, 0)

    -- Name + restrictions: bounded between iconTex.RIGHT and editBtn.LEFT so
    -- long names truncate cleanly. Name centered when alone; stacked with
    -- restriction otherwise.
    local restrictionLine = FormatRestrictions(buff)
    local hasRestrictions = restrictionLine ~= ""
    local nameY = hasRestrictions and 6 or 0

    local nameText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, nameY)
    nameText:SetPoint("RIGHT", editBtn, "LEFT", -8, nameY)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(buff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(buff.spellID)))

    if hasRestrictions then
        local restrictText = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        restrictText:SetPoint("LEFT", iconTex, "RIGHT", 6, -6)
        restrictText:SetPoint("RIGHT", editBtn, "LEFT", -8, -6)
        restrictText:SetJustifyH("LEFT")
        restrictText:SetWordWrap(false)
        restrictText:SetText(restrictionLine)
    end
end

-- Sorted {key, buff} list of the user's custom buffs, alphabetized by name.
local function GetSortedBuffs()
    local buffs = BR.profile.customBuffs or {}
    local items = {}
    for key, buff in pairs(buffs) do
        tinsert(items, { key = key, buff = buff })
    end
    table.sort(items, function(a, b)
        return (a.buff.name or a.key) < (b.buff.name or b.key)
    end)
    return items
end

local function Build(content, scrollFrame)
    ListEditor(content, scrollFrame, {
        header = L["Category.CustomBuffs"],
        note = L["Category.CustomNote"],
        warning = L["CustomBuff.RestrictedNote"],
        addLabel = L["CustomBuff.AddButton"],
        addWidth = 160,
        onAdd = function(render)
            BR.Options.Dialogs.CustomBuff.Show(nil, render)
        end,
        secondaryButton = {
            label = L["CustomBuff.Share.Import"],
            width = 90,
            onClick = function(render)
                BR.Options.Dialogs.CustomBuffShare.ShowImport(render)
            end,
        },
        rowHeight = ROW_HEIGHT,
        emptyText = L["CustomBuff.Empty"],
        getItems = GetSortedBuffs,
        fillRow = function(row, item, render)
            local key, buff = item.key, item.buff

            -- Discard the previous body. Each render builds the row widgets again.
            if row.body then
                row.body:Hide()
                row.body:SetParent(nil)
            end
            local body = CreateFrame("Frame", nil, row)
            body:SetAllPoints()
            row.body = body

            FillRowBody(body, key, buff, function()
                BR.Options.Dialogs.CustomBuff.Show(key, render)
            end, function()
                StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buff.name or key, nil, {
                    key = key,
                    refreshPanel = render,
                })
            end)
        end,
    })
end

BR.Options.Pages.custom = {
    title = L["Category.CustomBuffs"],
    showMasqueBanner = true,
    Build = Build,
}
