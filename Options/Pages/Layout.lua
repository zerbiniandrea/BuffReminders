local _, BR = ...

-- ============================================================================
-- LAYOUT PAGE
-- ============================================================================
-- One surface for everything spatial, behind a tab strip: the cross-category
-- stacking order, one row per detached icon, and the custom anchor-target
-- list (its editor lives in CustomAnchors.lua). The frame lock lives in the
-- sidebar footer; anchor assignment lives in the mover coordinate popup.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local IsCategorySplit = BR.Helpers.IsCategorySplit
local ReattachIcon = BR.Helpers.ReattachIcon
local ResetDetachedPosition = BR.Helpers.ResetDetachedPosition

local GetCategoryLabels = BR.Options.GetCategoryLabels

local LayoutSectionNote = Helpers.LayoutSectionNote
local GetCategorySetting = Helpers.GetCategorySetting

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING
local SCROLLBAR_WIDTH = BR.Options.Constants.SCROLLBAR_WIDTH

local tinsert = table.insert

local ALL_CATEGORIES = BR.CATEGORY_ORDER

-- ============================================================================
-- STACKING ORDER
-- ============================================================================

local ARROW_COLOR = { 0.7, 0.7, 0.7, 1 }
local ARROW_HOVER_COLOR = BR.Colors.Accent
local ARROW_DISABLED_COLOR = { 0.4, 0.4, 0.4, 1 }
local ARROW_BG = { 0.1, 0.1, 0.1, 0.7 }
local ARROW_BG_HOVER = { 0.2, 0.2, 0.2, 0.85 }
local ARROW_BG_DISABLED = { 0.05, 0.05, 0.05, 0.5 }
local ARROW_BORDER = BR.Colors.Border
local ARROW_BORDER_DISABLED = { 0.2, 0.2, 0.2, 0.6 }

local ORDER_ROW_H = 22
local ORDER_ARROW_W = 22
local ORDER_ARROW_H = 18
local ORDER_ARROW_GAP = 4
local ORDER_ARROW_TEX_SIZE = 10

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
    table.sort(list, function(a, b)
        local pa, pb = GetPriority(a), GetPriority(b)
        if pa == pb then
            return declarationIndex[a] < declarationIndex[b]
        end
        return pa < pb
    end)
    return list
end

---Renormalize priorities to 1..N for a given ordered list of categories.
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

---Small textured arrow button (same chevron texture + rotation trick the
---Dropdown component uses, so it renders reliably across locales).
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
    arrow:SetRotation(direction == "up" and math.rad(90) or math.rad(-90))

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

    function btn:SetEnabled(e)
        enabled = e
        UpdateVisual()
    end

    return btn
end

---One persistent row per category in the stacking-order list.
local function CreateOrderRow(parent, category)
    local labels = GetCategoryLabels()
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ORDER_ROW_H)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 4, 0)
    label:SetText(labels[category] or category)
    label:SetTextColor(unpack(BR.Colors.Accent))

    local downBtn = CreateOrderArrowButton(row, "down", function()
        MoveCategory(category, 1)
    end)
    downBtn:SetPoint("RIGHT", -4, 0)

    local upBtn = CreateOrderArrowButton(row, "up", function()
        MoveCategory(category, -1)
    end)
    upBtn:SetPoint("RIGHT", downBtn, "LEFT", -ORDER_ARROW_GAP, 0)

    function row:SetArrowEnabled(canUp, canDown)
        upBtn:SetEnabled(canUp)
        downBtn:SetEnabled(canDown)
    end

    return row
end

---The combined-frame ordering list. A split category has its own frame, so it
---does not appear here.
local function BuildDisplayOrderList(parent, contentWidth)
    -- Budget height for all categories so the sections below stay anchored
    -- when splits change.
    local containerHeight = #ALL_CATEGORIES * ORDER_ROW_H

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(contentWidth, containerHeight)

    local rows = {}
    for _, cat in ipairs(ALL_CATEGORIES) do
        rows[cat] = CreateOrderRow(container, cat)
    end

    local function PositionRow(cat, y)
        local row = rows[cat]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, y)
    end

    local function Refresh()
        local combined = GetCombinedOrder()
        local shown = {}
        local y = 0
        for i, cat in ipairs(combined) do
            PositionRow(cat, y)
            rows[cat]:SetArrowEnabled(i > 1, i < #combined)
            rows[cat]:Show()
            shown[cat] = true
            y = y - ORDER_ROW_H
        end
        for cat, row in pairs(rows) do
            if not shown[cat] then
                row:Hide()
            end
        end
    end

    Refresh()
    container.Refresh = Refresh
    tinsert(BR.RefreshableComponents, container)
    return container, containerHeight
end

-- ============================================================================
-- DETACHED ICON NAME LOOKUP
-- ============================================================================

---Display name for a detached-icon key (buff key or groupId).
local function GetDetachedDisplayName(key)
    local group = BR.BuffGroups and BR.BuffGroups[key]
    if group and group.displayName then
        return group.displayName
    end
    for _, buffs in pairs(BR.BUFF_TABLES) do
        for _, buff in ipairs(buffs) do
            if (buff.groupId or buff.key) == key then
                return buff.name or key
            end
        end
    end
    local customBuff = BR.profile.customBuffs and BR.profile.customBuffs[key]
    if customBuff then
        return customBuff.name or key
    end
    return key
end

-- ============================================================================
-- PAGE
-- ============================================================================

local ROW_H = 26
local TAB_STRIP_H = 26
-- How far below the content top the tab strip sits (positive magnitude,
-- matching every other page's top padding). PAGE_TOP_PADDING is negative.
local STRIP_TOP = -PAGE_TOP_PADDING
local TAB_BOTTOM_PADDING = 16

local TAB_IDS = { "order", "detached", "anchors" }

local function BuildOrderTab(frame, contentWidth)
    local layout = Components.VerticalLayout(frame, { x = COL_PADDING, y = PAGE_TOP_PADDING })
    LayoutSectionNote(layout, frame, L["Options.DisplayOrder.Note"])

    local listWidth = contentWidth - COL_PADDING * 2
    local orderList, orderHeight = BuildDisplayOrderList(frame, listWidth)
    layout:Add(orderList, orderHeight, COMPONENT_GAP)
    frame:SetHeight(math.abs(layout:GetY()) + TAB_BOTTOM_PADDING)
end

local function BuildDetachedTab(frame, contentWidth, onResize)
    local db = BR.profile
    local dynContent

    local function Render()
        if dynContent then
            dynContent:Hide()
            dynContent:SetParent(nil)
        end
        dynContent = CreateFrame("Frame", nil, frame)
        dynContent:SetPoint("TOPLEFT", 0, PAGE_TOP_PADDING)
        dynContent:SetWidth(contentWidth)
        local dyn = Components.VerticalLayout(dynContent, { x = COL_PADDING, y = 0 })

        local detached = db.detachedIcons or {}
        local keys = {}
        for key in pairs(detached) do
            tinsert(keys, key)
        end
        table.sort(keys, function(a, b)
            return GetDetachedDisplayName(a) < GetDetachedDisplayName(b)
        end)

        if #keys == 0 then
            local note = dynContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetText(L["Layout.NoDetached"])
            dyn:AddText(note, 14, COMPONENT_GAP)
        else
            local listWidth = contentWidth - COL_PADDING * 2
            for _, key in ipairs(keys) do
                local row = CreateFrame("Frame", nil, dynContent)
                row:SetSize(listWidth, ROW_H)

                local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                nameFS:SetPoint("LEFT", 4, 0)
                nameFS:SetWidth(180)
                nameFS:SetJustifyH("LEFT")
                nameFS:SetText(GetDetachedDisplayName(key))

                local posFS = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                posFS:SetPoint("LEFT", nameFS, "RIGHT", 8, 0)
                local pos = detached[key] and detached[key].position
                posFS:SetText(pos and string.format("%d · %d", pos.x or 0, pos.y or 0) or "")

                local returnBtn = CreateButton(row, L["DetachedIcons.Reattach"], function()
                    ReattachIcon(key)
                    BR.Display.Update()
                    Components.RefreshAll()
                end)
                returnBtn:SetPoint("RIGHT", -4, 0)

                local resetBtn = CreateButton(row, L["DetachedIcons.ResetPos"], function()
                    ResetDetachedPosition(key)
                    Components.RefreshAll()
                end)
                resetBtn:SetPoint("RIGHT", returnBtn, "LEFT", -6, 0)

                dyn:Add(row, ROW_H, 4)
            end
        end

        local dynHeight = math.abs(dyn:GetY())
        -- A frame with one anchor point and no height has an unresolved rect,
        -- and WoW does not render the subtree of an unresolved frame.
        dynContent:SetHeight(dynHeight)
        frame:SetHeight(STRIP_TOP + dynHeight + TAB_BOTTOM_PADDING)
        onResize()
    end

    -- Rebuild on RefreshAll, but only while the tab is visible. WoW frames
    -- cannot be reclaimed. Activation of this tab runs RefreshAll after the
    -- show, so a hidden rebuild is never necessary.
    tinsert(BR.RefreshableComponents, {
        Refresh = function()
            if frame:IsVisible() then
                Render()
            end
        end,
    })
    Render()
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()

    local tabLabels = {
        order = L["Options.DisplayOrder"],
        detached = L["Layout.DetachedIcons"],
        anchors = L["Page.CustomAnchors"],
    }

    local tabs = {}
    local tabFrames = {}
    local activeId

    local function UpdatePageHeight()
        local frame = activeId and tabFrames[activeId]
        if frame then
            content:SetHeight(STRIP_TOP + TAB_STRIP_H + frame:GetHeight())
        end
    end

    local function BuildTabContent(id)
        local frame = CreateFrame("Frame", nil, content)
        frame:SetPoint("TOPLEFT", 0, -(STRIP_TOP + TAB_STRIP_H))
        frame:SetSize(contentWidth, 400)

        if id == "order" then
            BuildOrderTab(frame, contentWidth)
        elseif id == "detached" then
            BuildDetachedTab(frame, contentWidth, UpdatePageHeight)
        else
            BR.Options.CustomAnchors.BuildTab(frame, contentWidth, UpdatePageHeight)
        end
        return frame
    end

    local function Activate(id)
        if activeId == id then
            return
        end
        activeId = id
        for tabId, tab in pairs(tabs) do
            tab:SetActive(tabId == id)
        end
        for _, frame in pairs(tabFrames) do
            frame:Hide()
        end
        if not tabFrames[id] then
            tabFrames[id] = BuildTabContent(id)
        end
        tabFrames[id]:Show()
        Components.RefreshAll()
        UpdatePageHeight()
    end

    -- Sticky tab strip: the parent is the scroll viewport, so the strip stays
    -- pinned while the tab body scrolls under it. The opaque mask hides the
    -- content that slides behind the strip.
    local strip = CreateFrame("Frame", nil, scrollFrame)
    strip:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -SCROLLBAR_WIDTH, 0)
    strip:SetHeight(STRIP_TOP + TAB_STRIP_H)
    strip:SetFrameLevel(content:GetFrameLevel() + 10)

    local mask = strip:CreateTexture(nil, "BACKGROUND")
    mask:SetAllPoints(strip)
    mask:SetColorTexture(0.09, 0.09, 0.107, 1)

    local prev, firstTab
    for _, id in ipairs(TAB_IDS) do
        local tab = Components.Tab(strip, {
            name = id,
            label = tabLabels[id],
            width = 40,
        })
        tab:SetScript("OnClick", function()
            Activate(id)
        end)
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", strip, "TOPLEFT", COL_PADDING, -STRIP_TOP)
            firstTab = tab
        end
        tabs[id] = tab
        prev = tab
    end

    Components.TabBaseline(strip, firstTab, contentWidth - COL_PADDING * 2)

    Activate("order")
end

BR.Options.Pages.layout = {
    title = L["Page.Layout"],
    Build = Build,
}
