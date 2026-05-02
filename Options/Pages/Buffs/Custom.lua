local _, BR = ...

-- ============================================================================
-- CUSTOM BUFFS PAGE
-- ============================================================================
-- Wide list of user-defined custom buffs (one row per buff with: enabled
-- checkbox, icon, name, restrictions summary, edit + delete buttons + detach
-- pin). Click edit / Add New opens BR.Options.Dialogs.CustomBuff.Show — the
-- dialog is intentionally kept as the editor since it's a self-contained
-- 700-line form that doesn't simplify when inlined.
--
-- Below the list: shared category sections (Layout / CustomAppearance) so the
-- user can configure how the custom category as a whole is displayed without
-- leaving the page. Sound alerts live on the global Sounds sidebar page.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local UpdateDisplay = BR.Display.Update

local CreateDetachPin = BR.Options.Helpers.CreateDetachPin
local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote
local ResolveBuffIcons = BR.Options.Helpers.ResolveBuffIcons

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local tinsert = table.insert
local tsort = table.sort
local abs = math.abs

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

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)
    row.hover = hover

    row:SetScript("OnEnter", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0.04)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0)
    end)
    row:EnableMouse(true)

    return row
end

-- Fill the body of one row with the per-buff widgets. Right-side controls
-- are chained: delete anchors to body.RIGHT, edit anchors to delete.LEFT,
-- detach pin to edit.LEFT — so adjusting widths/gaps doesn't require
-- recomputing absolute offsets.
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
    local iconRoot = ResolveBuffIcons(nil, buff.spellID)
    local iconTex = body:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    local tex = iconRoot and iconRoot[1]
    if tex then
        iconTex:SetTexture(tex)
        iconTex:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    else
        iconTex:SetTexture(DEFAULT_ICON_TEXTURE)
    end

    -- Right-side action chain: delete → edit → detach pin
    local deleteBtn = CreateButton(body, L["Options.Delete"], onDelete)
    deleteBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    local editBtn = CreateButton(body, L["CustomBuff.EditShort"], onEdit)
    editBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    editBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -ACTION_BUTTON_GAP, 0)

    local detachPin = CreateDetachPin(body, key)
    detachPin:SetPoint("RIGHT", editBtn, "LEFT", -ACTION_BUTTON_GAP, 0)

    -- Name + restrictions: bounded between iconTex.RIGHT and detachPin.LEFT
    -- so long names truncate cleanly. Name centered when alone; stacked with
    -- restriction otherwise.
    local restrictionLine = FormatRestrictions(buff)
    local hasRestrictions = restrictionLine ~= ""
    local nameY = hasRestrictions and 6 or 0

    local nameText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, nameY)
    nameText:SetPoint("RIGHT", detachPin, "LEFT", -8, nameY)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(buff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(buff.spellID)))

    if hasRestrictions then
        local restrictText = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        restrictText:SetPoint("LEFT", iconTex, "RIGHT", 6, -6)
        restrictText:SetPoint("RIGHT", detachPin, "LEFT", -8, -6)
        restrictText:SetJustifyH("LEFT")
        restrictText:SetWordWrap(false)
        restrictText:SetText(restrictionLine)
    end
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

    LayoutSectionHeader(layout, content, L["Category.CustomBuffs"])
    LayoutSectionNote(layout, content, L["Category.CustomNote"])

    -- ====================================================================
    -- LIST CONTAINER
    -- ====================================================================
    -- listHost is anchored manually because its height changes whenever a
    -- buff is added/edited/deleted. Sections below anchor to its bottom so
    -- they reactively follow.
    --
    -- listHostX uses layout:GetX() (= COL_PADDING + CONTENT_INDENT after a
    -- LayoutSectionHeader call) so the rows nest under the section's accent
    -- line, matching the indentation pattern every other page uses for
    -- content beneath a section header.
    local listHostX = layout:GetX()
    local listHostTopY = layout:GetY()
    local listHost = CreateFrame("Frame", nil, content)
    listHost:SetWidth(contentWidth - listHostX - COL_PADDING)
    listHost:SetPoint("TOPLEFT", content, "TOPLEFT", listHostX, listHostTopY)
    listHost:SetHeight(1)

    local rowPool = {}
    local rowCount = 0
    local addBtn

    local Render -- forward decl; FillRowBody callbacks reference it

    local function AcquireRow(index)
        local row = rowPool[index]
        if not row then
            row = CreateRow(listHost)
            rowPool[index] = row
        end
        row:SetWidth(listHost:GetWidth())
        row:Show()
        return row
    end

    Render = function()
        for i = 1, rowCount do
            rowPool[i]:Hide()
        end
        rowCount = 0

        local buffs = BR.profile.customBuffs or {}

        local sortedKeys = {}
        for key in pairs(buffs) do
            tinsert(sortedKeys, key)
        end
        tsort(sortedKeys, function(a, b)
            local ba, bb = buffs[a], buffs[b]
            return (ba.name or a) < (bb.name or b)
        end)

        local y = 0
        for _, key in ipairs(sortedKeys) do
            local buff = buffs[key]
            rowCount = rowCount + 1

            local row = AcquireRow(rowCount)
            row:SetPoint("TOPLEFT", 0, y)

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
                BR.Options.Dialogs.CustomBuff.Show(key, Render)
            end, function()
                StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buff.name or key, nil, {
                    key = key,
                    refreshPanel = Render,
                })
            end)

            y = y - ROW_HEIGHT
        end

        -- Add button below the list
        if not addBtn then
            addBtn = CreateButton(listHost, L["CustomBuff.AddButton"], function()
                BR.Options.Dialogs.CustomBuff.Show(nil, Render)
            end)
            addBtn:SetSize(160, ACTION_BUTTON_HEIGHT)
        end
        addBtn:ClearAllPoints()
        addBtn:SetPoint("TOPLEFT", 0, y - 8)

        listHost:SetHeight(-y + 30)

        -- Sections below anchor to listHost.BOTTOMLEFT and reflow with it;
        -- only content height needs explicit recomputing.
        if BR.Options.Pages.custom and BR.Options.Pages.custom._UpdateContentHeight then
            BR.Options.Pages.custom._UpdateContentHeight()
        end
    end

    Render()

    -- ====================================================================
    -- SHARED CATEGORY SECTIONS (custom)
    -- ====================================================================
    -- Sub-container anchored to listHost's bottom edge. WoW frame anchors
    -- are reactive: when listHost resizes, this container follows
    -- automatically — no manual relayout needed for the sections inside.
    local sectionsContainer = CreateFrame("Frame", nil, content)
    -- Pull back to content's left edge so the section headers + accent lines
    -- inside this container span the full content width (matching every
    -- other page's section style), independent of how indented listHost is.
    sectionsContainer:SetPoint("TOPLEFT", listHost, "BOTTOMLEFT", -listHostX, -SECTION_GAP)
    sectionsContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    sectionsContainer:SetHeight(1)

    local sectionsLayout = Components.VerticalLayout(sectionsContainer, { x = COL_PADDING, y = 0 })

    -- Forward decl: CustomAppearance toggles its own footprint, so we re-run
    -- our content-height aggregation whenever the toggle flips.
    local UpdateContentHeight

    local ctx = {
        category = "custom",
        content = sectionsContainer,
        scrollFrame = scrollFrame,
        contentWidth = contentWidth,
        appearancePadding = 8,
        onAppearanceResize = function()
            if UpdateContentHeight then
                UpdateContentHeight()
            end
        end,
    }
    local Sections = BR.Options.BuffSections
    Sections.Layout(ctx, sectionsLayout)
    -- CustomAppearance owns sectionsContainer:SetHeight (collapses when its
    -- toggle is off). Must be the last section in this layout.
    Sections.CustomAppearance(ctx, sectionsLayout)

    -- Total page height = top offset + listHost + gap + sections + bottom pad.
    UpdateContentHeight = function()
        local total = abs(listHostTopY) + listHost:GetHeight() + SECTION_GAP + sectionsContainer:GetHeight() + 30
        content:SetHeight(total)
    end
    UpdateContentHeight()

    -- Re-render the list when the page becomes active so external changes
    -- (e.g. add via slash command) are reflected.
    local refreshHook = CreateFrame("Frame", nil, listHost)
    refreshHook:SetSize(1, 1)
    function refreshHook:Refresh()
        Render()
    end
    tinsert(BR.RefreshableComponents, refreshHook)

    BR.Options.Pages.custom._UpdateContentHeight = UpdateContentHeight
end

BR.Options.Pages.custom = {
    title = L["Category.CustomBuffs"],
    showMasqueBanner = true,
    Build = Build,
}
