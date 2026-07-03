local _, BR = ...

-- ============================================================================
-- CUSTOM BUFFS PAGE
-- ============================================================================
-- Wide list of user-defined custom buffs (one row per buff with: enabled
-- checkbox, icon, name, restrictions summary, edit + delete buttons). Click
-- edit / Add New opens BR.Options.Dialogs.CustomBuff.Show - the dialog is
-- intentionally kept as the editor since it's a self-contained 700-line form
-- that doesn't simplify when inlined.
--
-- Built on the shared BR.Options.Helpers.ListEditor skeleton (same as the
-- Loadout Reminders and Sound Alerts pages): rows flow directly in the page's
-- own scroll container (no nested scroll box) and the Add button sits above the
-- list so it stays reachable no matter how long the list grows. This page
-- supplies only what varies - the data source (getItems) and row content
-- (fillRow).
--
-- Display styling for the custom category (layout / appearance / glow) lives
-- on the Categories page's Custom tab; this page is purely the entry-list
-- editor. Sound alerts live on the global Sounds sidebar page.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local ListEditor = BR.Options.Helpers.ListEditor

local UpdateDisplay = BR.Display.Update

local GetBuffIcons = BR.Helpers.GetBuffIcons

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local tinsert = table.insert
local tsort = table.sort

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

-- Fill the body of one row with the per-buff widgets. Right-side controls
-- are chained: delete anchors to body.RIGHT, edit anchors to delete.LEFT, so
-- adjusting widths/gaps doesn't require recomputing absolute offsets.
local function FillRowBody(body, key, buff, onEdit, onDelete)
    -- Checkbox (holderWidth=18 since the label is empty; default 200 would
    -- push everything 200px to the right).
    local checkbox = Components.Checkbox(body, {
        label = "",
        holderWidth = 18,
        get = function()
            return BR.profile.enabledBuffs[key] ~= false
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
        end,
    })
    checkbox:SetPoint("LEFT", 0, 0)

    -- Buff icon
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

    -- Right-side action chain: delete -> edit
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
    tsort(items, function(a, b)
        return (a.buff.name or a.key) < (b.buff.name or b.key)
    end)
    return items
end

local function Build(content, scrollFrame)
    ListEditor(content, scrollFrame, {
        header = L["Category.CustomBuffs"],
        note = L["Category.CustomNote"],
        addLabel = L["CustomBuff.AddButton"],
        addWidth = 160,
        onAdd = function(render)
            BR.Options.Dialogs.CustomBuff.Show(nil, render)
        end,
        rowHeight = ROW_HEIGHT,
        emptyText = L["CustomBuff.Empty"],
        getItems = GetSortedBuffs,
        fillRow = function(row, item, render)
            local key, buff = item.key, item.buff

            -- Discard the previous body so we rebuild widgets from scratch
            -- (cheaper than tracking and updating each widget per render).
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
