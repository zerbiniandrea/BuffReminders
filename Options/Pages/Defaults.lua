local _, BR = ...

-- ============================================================================
-- DEFAULTS PAGE
-- ============================================================================
-- Global appearance/behavior defaults inherited by every category unless
-- explicitly overridden. Also hosts the "Display Order" section: a single
-- ordered list across all non-split categories that drives the priority
-- field. Lives here because priority is a global decision, not a
-- per-category setting. (Detached Icons is its own sidebar page.)

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local LSM = BR.LSM
local IsFontPathValid = BR.Helpers.IsFontPathValid
local IsCategorySplit = BR.Helpers.IsCategorySplit
local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

local GetCategoryLabels = BR.Options.GetCategoryLabels

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local LayoutSectionNote = Helpers.LayoutSectionNote
local GetCategorySetting = Helpers.GetCategorySetting
local MakeDefaultsGetter = Helpers.MakeDefaultsGetter
local MakeDefaultsSetter = Helpers.MakeDefaultsSetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA
local COL_PADDING = BR.Options.Constants.COL_PADDING

local tinsert = table.insert
local tsort = table.sort
local abs = math.abs
local rad = math.rad

-- Color palette for the textured arrow buttons in Display Order. Mirrors the
-- dropdown chevron (UI/Components.lua) so the page reads as one visual family.
local ARROW_COLOR = { 0.7, 0.7, 0.7, 1 }
local ARROW_HOVER_COLOR = { 1, 0.82, 0, 1 }
local ARROW_DISABLED_COLOR = { 0.4, 0.4, 0.4, 1 }
local ARROW_BG = { 0.1, 0.1, 0.1, 0.7 }
local ARROW_BG_HOVER = { 0.2, 0.2, 0.2, 0.85 }
local ARROW_BG_DISABLED = { 0.05, 0.05, 0.05, 0.5 }
local ARROW_BORDER = { 0.3, 0.3, 0.3, 1 }
local ARROW_BORDER_DISABLED = { 0.2, 0.2, 0.2, 0.6 }

-- All categories that have a slot in defaults.categorySettings, in canonical
-- order. The Display Order section enumerates these; the list comes from
-- BR.CATEGORY_ORDER (Core.lua) so it can't drift from the rest of the addon.
local ALL_CATEGORIES = BR.CATEGORY_ORDER

local function BuildFontOptions()
    local fontList = LSM:List("font")
    local opts = { { label = L["Options.Default"], value = nil } }
    for _, name in ipairs(fontList) do
        if IsFontPathValid(LSM:Fetch("font", name)) then
            tinsert(opts, { label = name, value = name })
        end
    end
    return opts
end

-- ============================================================================
-- DISPLAY ORDER HELPERS
-- ============================================================================

---Read a category's effective priority (saved value or default).
local function GetPriority(category)
    local catDefaults = BR.defaults.categorySettings[category]
    return GetCategorySetting(category, "priority", catDefaults and catDefaults.priority or 99)
end

---Categories that participate in the combined-frame ordering, sorted by
---priority (ascending). Ties fall back to the declared ALL_CATEGORIES order
---to keep the sort stable across renders.
local function GetCombinedOrder()
    local list = {}
    for _, cat in ipairs(ALL_CATEGORIES) do
        if not IsCategorySplit(cat) then
            tinsert(list, cat)
        end
    end
    local declarationIndex = {}
    for i, cat in ipairs(ALL_CATEGORIES) do
        declarationIndex[cat] = i
    end
    tsort(list, function(a, b)
        local pa, pb = GetPriority(a), GetPriority(b)
        if pa == pb then
            return declarationIndex[a] < declarationIndex[b]
        end
        return pa < pb
    end)
    return list
end

---Categories that are split off into their own frames (no priority).
---Sorted by declaration order so the section reads consistently.
local function GetSplitList()
    local list = {}
    for _, cat in ipairs(ALL_CATEGORIES) do
        if IsCategorySplit(cat) then
            tinsert(list, cat)
        end
    end
    return list
end

---Renormalize priorities to 1..N for a given ordered list of categories.
---Writing through SetMulti fires LayoutRefresh once and avoids stale-tie
---pathology when users had collisions from the old per-category slider.
local function ApplyOrder(orderedList)
    local changes = {}
    for i, cat in ipairs(orderedList) do
        changes["categorySettings." .. cat .. ".priority"] = i
    end
    BR.Config.SetMulti(changes)
end

---Swap a category with its neighbor (delta = -1 for up, +1 for down).
local function MoveCategory(category, delta)
    local list = GetCombinedOrder()
    for i, cat in ipairs(list) do
        if cat == category then
            local j = i + delta
            if j < 1 or j > #list then
                return
            end
            list[i], list[j] = list[j], list[i]
            ApplyOrder(list)
            Components.RefreshAll()
            return
        end
    end
end

-- ============================================================================
-- DISPLAY ORDER SECTION
-- ============================================================================

local ORDER_ROW_H = 22
local ORDER_DIVIDER_H = 22
local ORDER_ARROW_W = 22
local ORDER_ARROW_H = 18
local ORDER_ARROW_GAP = 4
local ORDER_ARROW_TEX_SIZE = 10

---Build a small textured arrow button. Uses the same chevron texture +
---rotation trick the Dropdown component uses for its expand glyph, so the
---arrows render reliably across every locale (the unicode triangle glyphs
---are missing from several of the default WoW fonts).
---@param parent table
---@param direction "up"|"down"
---@param onClick fun()
local function CreateOrderArrowButton(parent, direction, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(ORDER_ARROW_W, ORDER_ARROW_H)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(ORDER_ARROW_TEX_SIZE, ORDER_ARROW_TEX_SIZE)
    arrow:SetPoint("CENTER", 0, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    -- Texture points right by default; rotate +90 for up, -90 for down.
    arrow:SetRotation(direction == "up" and rad(90) or rad(-90))

    local enabled = true

    local function UpdateVisual()
        if not enabled then
            btn:SetBackdropColor(unpack(ARROW_BG_DISABLED))
            btn:SetBackdropBorderColor(unpack(ARROW_BORDER_DISABLED))
            arrow:SetVertexColor(unpack(ARROW_DISABLED_COLOR))
        elseif btn:IsMouseOver() then
            btn:SetBackdropColor(unpack(ARROW_BG_HOVER))
            btn:SetBackdropBorderColor(unpack(ARROW_BORDER))
            arrow:SetVertexColor(unpack(ARROW_HOVER_COLOR))
        else
            btn:SetBackdropColor(unpack(ARROW_BG))
            btn:SetBackdropBorderColor(unpack(ARROW_BORDER))
            arrow:SetVertexColor(unpack(ARROW_COLOR))
        end
    end
    UpdateVisual()

    btn:SetScript("OnEnter", UpdateVisual)
    btn:SetScript("OnLeave", UpdateVisual)
    btn:SetScript("OnClick", function()
        if enabled then
            onClick()
        end
    end)

    -- Override Button:SetEnabled so callers get visual + click-gating in one
    -- call (matches the dropdown's behavior model).
    function btn:SetEnabled(e)
        enabled = e
        UpdateVisual()
    end

    return btn
end

---One row per category. Persistent (created once, repositioned on Refresh)
---so we don't leak frames when users toggle Split on/off elsewhere.
---@param parent table container Frame
---@param category string category id
local function CreateOrderRow(parent, category)
    local labels = GetCategoryLabels()
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ORDER_ROW_H)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 4, 0)
    label:SetText(labels[category] or category)

    local downBtn = CreateOrderArrowButton(row, "down", function()
        MoveCategory(category, 1)
    end)
    downBtn:SetPoint("RIGHT", -4, 0)

    local upBtn = CreateOrderArrowButton(row, "up", function()
        MoveCategory(category, -1)
    end)
    upBtn:SetPoint("RIGHT", downBtn, "LEFT", -ORDER_ARROW_GAP, 0)

    -- Badge shown for split categories instead of the arrows: makes the
    -- "this isn't in the ordering" state self-explanatory.
    local splitBadge = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    splitBadge:SetPoint("RIGHT", -4, 0)
    splitBadge:SetText(L["Options.DisplayOrder.SplitBadge"])
    splitBadge:Hide()

    function row:SetSplit(isSplit)
        if isSplit then
            upBtn:Hide()
            downBtn:Hide()
            splitBadge:Show()
            label:SetTextColor(0.55, 0.55, 0.55)
        else
            upBtn:Show()
            downBtn:Show()
            splitBadge:Hide()
            label:SetTextColor(1, 0.82, 0)
        end
    end

    function row:SetArrowEnabled(canUp, canDown)
        upBtn:SetEnabled(canUp)
        downBtn:SetEnabled(canDown)
    end

    return row
end

---Container that renders the full ordered list (combined section + split
---section). Returns the container plus a Refresh closure (registered on
---BR.RefreshableComponents so the list re-syncs whenever a component
---elsewhere flips Split state).
local function BuildDisplayOrderList(parent, contentWidth)
    -- Budget enough height for all 7 categories + the divider regardless of
    -- whether splits are present; that keeps subsequent sections anchored at
    -- a stable Y when users toggle Split on/off.
    local containerHeight = #ALL_CATEGORIES * ORDER_ROW_H + ORDER_DIVIDER_H

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(contentWidth, containerHeight)

    local rows = {}
    for _, cat in ipairs(ALL_CATEGORIES) do
        rows[cat] = CreateOrderRow(container, cat)
    end

    -- Divider between combined and split groups.
    local divider = container:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(0.4, 0.32, 0.05, 0.6)
    divider:Hide()

    local dividerLabel = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dividerLabel:SetText(L["Options.DisplayOrder.SplitGroup"])
    dividerLabel:Hide()

    local function PositionRow(cat, y)
        local row = rows[cat]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, y)
    end

    local function Refresh()
        local combined = GetCombinedOrder()
        local split = GetSplitList()

        local y = 0
        for i, cat in ipairs(combined) do
            PositionRow(cat, y)
            rows[cat]:SetSplit(false)
            rows[cat]:SetArrowEnabled(i > 1, i < #combined)
            rows[cat]:Show()
            y = y - ORDER_ROW_H
        end

        if #split > 0 then
            divider:ClearAllPoints()
            divider:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 8)
            divider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, y - 8)
            dividerLabel:ClearAllPoints()
            dividerLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y - 12)
            divider:Show()
            dividerLabel:Show()
            y = y - ORDER_DIVIDER_H

            for _, cat in ipairs(split) do
                PositionRow(cat, y)
                rows[cat]:SetSplit(true)
                rows[cat]:Show()
                y = y - ORDER_ROW_H
            end
        else
            divider:Hide()
            dividerLabel:Hide()
        end
    end

    Refresh()
    container.Refresh = Refresh
    tinsert(BR.RefreshableComponents, container)
    return container, containerHeight
end

local function Build(content)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -16 })

    -- Global Defaults
    LayoutSectionHeader(layout, content, L["Options.GlobalDefaults"])
    LayoutSectionNote(layout, content, L["Options.GlobalDefaults.Note"])

    local function isDefDimensionsLinked()
        local db = BR.profile.defaults
        return not db or db.iconWidth == nil
    end

    local defGrid = Components.AppearanceGrid(content, {
        get = function(key, default)
            local d = BR.profile.defaults
            return d and d[key] or default
        end,
        set = function(key, value)
            BR.Config.Set("defaults." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["defaults." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isDefDimensionsLinked,
        onLink = function()
            BR.Config.Set("defaults.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local db = BR.profile.defaults
            BR.Config.Set("defaults.iconWidth", db and db.iconSize or 64)
            Components.RefreshAll()
        end,
        masqueCheck = IsMasqueActive,
    })
    layout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)

    local defFontHolder = Components.Dropdown(content, {
        label = L["Options.Font"],
        labelWidth = 50,
        options = BuildFontOptions(),
        width = 200,
        maxItems = 15,
        itemInit = function(_, itemLabel, opt)
            if opt.value then
                local path = LSM:Fetch("font", opt.value)
                if path then
                    itemLabel:SetFont(path, 12, "")
                end
            end
        end,
        get = MakeDefaultsGetter("fontFace", nil),
        onChange = MakeDefaultsSetter("fontFace"),
    })
    layout:Add(defFontHolder, nil, COMPONENT_GAP)

    local defOutlineHolder = Components.Dropdown(content, {
        label = L["Options.TextOutline"],
        labelWidth = 50,
        options = {
            { label = L["Options.TextOutline.None"], value = "NONE" },
            { label = L["Options.TextOutline.Outline"], value = "OUTLINE" },
            { label = L["Options.TextOutline.Thick"], value = "THICKOUTLINE" },
            { label = L["Options.TextOutline.Monochrome"], value = "MONOCHROME" },
            { label = L["Options.TextOutline.OutlineMono"], value = "OUTLINE, MONOCHROME" },
            { label = L["Options.TextOutline.ThickMono"], value = "THICKOUTLINE, MONOCHROME" },
        },
        width = 200,
        get = MakeDefaultsGetter("textOutline", "OUTLINE"),
        onChange = MakeDefaultsSetter("textOutline"),
    })
    layout:Add(defOutlineHolder, nil, COMPONENT_GAP)

    local defDirHolder = Components.DirectionButtons(content, {
        labelWidth = 50,
        get = MakeDefaultsGetter("growDirection", "CENTER"),
        onChange = MakeDefaultsSetter("growDirection"),
    })
    layout:Add(defDirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local defGlowHolder = Components.Checkbox(content, {
        label = L["Options.GlowReminderIcons"],
        tooltip = {
            title = L["Options.GlowReminderIcons.Title"],
            desc = L["Options.GlowReminderIcons.Desc"],
        },
        warningTooltip = {
            title = L["Options.GlowReminderIcons.Title"],
            desc = L["Options.GlowReminderIcons.CpuWarning"],
        },
        get = function()
            local d = BR.profile.defaults
            return d and (d.showExpirationGlow ~= false or d.showMissingGlow ~= false)
        end,
        onChange = function(checked)
            BR.Config.Set("defaults.showExpirationGlow", checked)
            BR.Config.Set("defaults.showMissingGlow", checked)
            Components.RefreshAll()
        end,
    })

    local glowSettingsBtn = CreateButton(content, L["Options.Customize"], function()
        BR.Options.Dialogs.Glow.Show()
    end)
    glowSettingsBtn:SetPoint("LEFT", defGlowHolder.infoIcon or defGlowHolder.label, "RIGHT", 8, 0)
    glowSettingsBtn:SetFrameLevel(defGlowHolder:GetFrameLevel() + 5)

    layout:Add(defGlowHolder, nil, COMPONENT_GAP)

    -- Expiration Reminder
    LayoutSectionHeader(layout, content, L["Options.ExpirationReminder"])

    local thresholdLW = Components.MeasureSharedLabelWidth({
        L["Options.Threshold"],
        L["Options.PreKeyThreshold"],
    })

    local function formatMinutes(val)
        return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
    end

    local defThresholdHolder = Components.Slider(content, {
        label = L["Options.Threshold"],
        labelWidth = thresholdLW,
        min = 0,
        max = 45,
        step = 5,
        get = MakeDefaultsGetter("expirationThreshold", 15),
        formatValue = formatMinutes,
        onChange = MakeDefaultsSetter("expirationThreshold"),
    })
    layout:Add(defThresholdHolder, nil, COMPONENT_GAP)

    local preKeyThresholdHolder = Components.Slider(content, {
        label = L["Options.PreKeyThreshold"],
        labelWidth = thresholdLW,
        tooltip = { title = L["Options.PreKeyThreshold"], desc = L["Options.PreKeyThreshold.Desc"] },
        min = 0,
        max = 60,
        step = 5,
        get = MakeDefaultsGetter("preKeyThreshold", 0),
        formatValue = formatMinutes,
        onChange = MakeDefaultsSetter("preKeyThreshold"),
    })
    layout:Add(preKeyThresholdHolder, nil, COMPONENT_GAP)

    -- Display Order: cross-category spatial composition. Replaces the old
    -- per-category Priority slider (which forced users to imagine the global
    -- ordering across 6 disconnected pages).
    LayoutSectionHeader(layout, content, L["Options.DisplayOrder"])
    LayoutSectionNote(layout, content, L["Options.DisplayOrder.Note"])

    local listX = layout:GetX()
    local listWidth = (content.GetWidth and content:GetWidth() or 600) - listX - COL_PADDING
    local orderList, orderHeight = BuildDisplayOrderList(content, listWidth)
    layout:Add(orderList, orderHeight, COMPONENT_GAP)

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.defaults = {
    title = L["Page.Defaults"],
    showMasqueBanner = true,
    Build = Build,
}
