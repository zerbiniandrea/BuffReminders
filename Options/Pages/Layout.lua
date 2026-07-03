local _, BR = ...

-- ============================================================================
-- LAYOUT PAGE
-- ============================================================================
-- The single home for everything spatial: the frame lock, the cross-category
-- stacking order (moved here from the Defaults page), one row per split
-- category (anchor frame/point + reset), one row per detached icon, and the
-- custom anchor-target list (absorbed from the old Anchor Frames page).
--
-- Structure: two static sections built once (Position frames, Stacking
-- order), then a single dynamic container that is fully rebuilt whenever
-- RefreshAll runs, so split toggles, detach changes, and anchor edits made
-- anywhere immediately reshape this page. Component holders created inside
-- the dynamic container are unregistered on teardown to keep the refresh
-- registry from accumulating dead entries.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local IsCategorySplit = BR.Helpers.IsCategorySplit
local ReattachIcon = BR.Helpers.ReattachIcon
local ResetDetachedPosition = BR.Helpers.ResetDetachedPosition

local GetCategoryLabels = BR.Options.GetCategoryLabels

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local LayoutSectionNote = Helpers.LayoutSectionNote
local GetCategorySetting = Helpers.GetCategorySetting

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local abs = math.abs
local rad = math.rad
local format = string.format
local strtrim = strtrim
local wipe = wipe

local ALL_CATEGORIES = BR.CATEGORY_ORDER

-- ============================================================================
-- STACKING ORDER (moved from the Defaults page)
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
    tsort(list, function(a, b)
        local pa, pb = GetPriority(a), GetPriority(b)
        if pa == pb then
            return declarationIndex[a] < declarationIndex[b]
        end
        return pa < pb
    end)
    return list
end

---Categories split off into their own frames, in declaration order.
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

---The combined-frame ordering list. Split categories don't appear here at
---all: they get their own rows in the Split Frames section below, so the
---relationship between "split" and "not in the stacking order" is spatial
---instead of a badge.
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

local ANCHOR_POINT_OPTIONS = {
    "TOPLEFT",
    "TOP",
    "TOPRIGHT",
    "LEFT",
    "CENTER",
    "RIGHT",
    "BOTTOMLEFT",
    "BOTTOM",
    "BOTTOMRIGHT",
}

local ROW_H = 26

local function Build(content, scrollFrame)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })
    local contentWidth = scrollFrame:GetContentWidth()
    local db = BR.profile

    -- ------------------------------------------------------------------
    -- Position frames (lock/unlock)
    -- ------------------------------------------------------------------
    LayoutSectionHeader(layout, content, L["Layout.PositionFrames"])
    LayoutSectionNote(layout, content, L["Layout.PositionFrames.Note"])

    local lockBtn = CreateButton(content, L["Options.Unlock"], function()
        BR.Display.ToggleLock()
        Components.RefreshAll()
    end, { title = L["Options.LockUnlock"], desc = L["Options.LockUnlock.Desc"] })
    function lockBtn:Refresh()
        self.text:SetText(BR.profile.locked and L["Options.Unlock"] or L["Options.Lock"])
    end
    lockBtn:Refresh()
    tinsert(BR.RefreshableComponents, lockBtn)
    layout:Add(lockBtn, nil, COMPONENT_GAP)

    -- ------------------------------------------------------------------
    -- Stacking order (combined frame)
    -- ------------------------------------------------------------------
    LayoutSectionHeader(layout, content, L["Options.DisplayOrder"])
    LayoutSectionNote(layout, content, L["Options.DisplayOrder.Note"])

    local listX = layout:GetX()
    local listWidth = contentWidth - listX - COL_PADDING
    local orderList, orderHeight = BuildDisplayOrderList(content, listWidth)
    layout:Add(orderList, orderHeight, COMPONENT_GAP)
    layout:SetX(COL_PADDING)

    -- ------------------------------------------------------------------
    -- Dynamic tail: Split frames / Detached icons / Anchor targets.
    -- One container, fully rebuilt on every RefreshAll.
    -- ------------------------------------------------------------------
    local staticBottomY = layout:GetY()

    local dynHost = CreateFrame("Frame", nil, content)
    dynHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, staticBottomY)
    dynHost:SetWidth(contentWidth)

    local dynContent -- current generation, replaced wholesale on rebuild
    local dynHolders = {} -- component holders to unregister on teardown

    local function TearDownDynamic()
        for _, holder in ipairs(dynHolders) do
            Components.Unregister(holder)
        end
        wipe(dynHolders)
        if dynContent then
            dynContent:Hide()
            dynContent:SetParent(nil)
            dynContent = nil
        end
    end

    local function Render()
        TearDownDynamic()
        dynContent = CreateFrame("Frame", nil, dynHost)
        dynContent:SetPoint("TOPLEFT")
        dynContent:SetWidth(contentWidth)
        local dyn = Components.VerticalLayout(dynContent, { x = COL_PADDING, y = 0 })

        local labels = GetCategoryLabels()

        -- ---- Split frames ----
        LayoutSectionHeader(dyn, dynContent, L["Layout.SplitFrames"])
        LayoutSectionNote(dyn, dynContent, L["Layout.SplitFrames.Note"])

        local splitList = GetSplitList()
        if #splitList == 0 then
            local note = dynContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetText(L["Layout.NoSplitFrames"])
            dyn:AddText(note, 14, COMPONENT_GAP)
        else
            local anchorOptions = { { label = L["Mover.NoneScreenCenter"], value = "__none" } }
            for _, name in ipairs(BR.Movers.ScanAnchorFrames()) do
                tinsert(anchorOptions, { label = name, value = name })
            end
            local pointOptions = {}
            for _, pt in ipairs(ANCHOR_POINT_OPTIONS) do
                tinsert(pointOptions, { label = pt, value = pt })
            end

            for _, cat in ipairs(splitList) do
                local row = CreateFrame("Frame", nil, dynContent)
                row:SetSize(listWidth, ROW_H)

                local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                nameFS:SetPoint("LEFT", 4, 0)
                nameFS:SetWidth(110)
                nameFS:SetJustifyH("LEFT")
                nameFS:SetText(labels[cat] or cat)

                local function getAnchorName()
                    local cs = db.categorySettings and db.categorySettings[cat]
                    return cs and cs.anchorFrame
                end

                local anchorDrop = Components.Dropdown(row, {
                    label = "",
                    labelWidth = 0,
                    width = 170,
                    options = anchorOptions,
                    get = function()
                        return getAnchorName() or "__none"
                    end,
                    tooltip = { title = L["Mover.AnchorFrame"], desc = L["Layout.AnchorFrame.Desc"] },
                    onChange = function(val)
                        local frameName = val ~= "__none" and val or nil
                        -- Mirrors the coordinate popup: write the anchor,
                        -- reset the offset to (0,0), reposition everything.
                        if not db.categorySettings then
                            db.categorySettings = {}
                        end
                        if not db.categorySettings[cat] then
                            db.categorySettings[cat] = {}
                        end
                        db.categorySettings[cat].anchorFrame = frameName
                        BR.Movers.SavePosition(cat, 0, 0)
                        BR.CallbackRegistry:TriggerEvent("LayoutRefresh")
                        Components.RefreshAll()
                    end,
                })
                anchorDrop:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)
                tinsert(dynHolders, anchorDrop)

                local pointDrop = Components.Dropdown(row, {
                    label = "",
                    labelWidth = 0,
                    width = 110,
                    options = pointOptions,
                    get = function()
                        local cs = db.categorySettings and db.categorySettings[cat]
                        return (cs and cs.anchorPoint) or "CENTER"
                    end,
                    enabled = function()
                        return getAnchorName() ~= nil
                    end,
                    disabledReason = L["DisabledReason.AnchorPoint"],
                    tooltip = { title = L["Mover.AnchorPoint"], desc = L["Layout.AnchorPoint.Desc"] },
                    onChange = function(pt)
                        BR.Config.Set("categorySettings." .. cat .. ".anchorPoint", pt)
                    end,
                })
                pointDrop:SetPoint("LEFT", anchorDrop, "RIGHT", 6, 0)
                tinsert(dynHolders, pointDrop)

                local posFS = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                posFS:SetPoint("LEFT", pointDrop, "RIGHT", 8, 0)
                local pos = db.categorySettings and db.categorySettings[cat] and db.categorySettings[cat].position
                posFS:SetText(pos and format("%d · %d", pos.x or 0, pos.y or 0) or "")

                local resetBtn = CreateButton(row, L["Options.ResetPosition"], function()
                    local catDefaults = BR.defaults.categorySettings[cat]
                    if catDefaults and catDefaults.position then
                        BR.Display.ResetCategoryFramePosition(cat, catDefaults.position.x, catDefaults.position.y)
                    end
                    Components.RefreshAll()
                end)
                resetBtn:SetPoint("RIGHT", -4, 0)

                dyn:Add(row, ROW_H, 4)
            end
        end

        -- ---- Detached icons ----
        LayoutSectionHeader(dyn, dynContent, L["Layout.DetachedIcons"])

        local detached = db.detachedIcons or {}
        local keys = {}
        for key in pairs(detached) do
            tinsert(keys, key)
        end
        tsort(keys, function(a, b)
            return GetDetachedDisplayName(a) < GetDetachedDisplayName(b)
        end)

        if #keys == 0 then
            local note = dynContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetText(L["Layout.NoDetached"])
            dyn:AddText(note, 14, COMPONENT_GAP)
        else
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
                posFS:SetText(pos and format("%d · %d", pos.x or 0, pos.y or 0) or "")

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

        -- ---- Anchor targets ----
        LayoutSectionHeader(dyn, dynContent, L["Layout.AnchorTargets"])
        LayoutSectionNote(dyn, dynContent, L["Options.CustomAnchorFrames.Desc"])

        local addRow = CreateFrame("Frame", nil, dynContent)
        addRow:SetSize(listWidth, 22)
        local addInput = Components.TextInput(addRow, {
            label = "",
            value = "",
            width = 220,
            labelWidth = 0,
        })
        addInput:SetPoint("LEFT", 0, 0)
        tinsert(dynHolders, addInput)
        local addBox = addInput.editBox

        local addBtn = CreateButton(addRow, L["Options.Add"], function()
            local name = strtrim(addBox:GetText())
            if name == "" then
                return
            end
            if not db.customAnchorFrames then
                db.customAnchorFrames = {}
            end
            for _, existing in ipairs(db.customAnchorFrames) do
                if existing == name then
                    addBox:SetText("")
                    return
                end
            end
            tinsert(db.customAnchorFrames, name)
            addBox:SetText("")
            Components.RefreshAll()
        end)
        addBtn:SetSize(50, 22)
        addBtn:SetPoint("LEFT", addInput, "RIGHT", 6, 0)
        addBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            addBtn:Click()
        end)
        dyn:Add(addRow, 22, COMPONENT_GAP)

        local names = db.customAnchorFrames or {}
        for i, name in ipairs(names) do
            local row = CreateFrame("Frame", nil, dynContent)
            row:SetSize(listWidth, 20)

            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bullet:SetPoint("LEFT", 4, 0)
            bullet:SetText("-")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", bullet, "RIGHT", 4, 0)
            local target = _G[name]
            local exists = type(target) == "table" and target.GetCenter ~= nil
            if exists then
                text:SetText(name)
            else
                -- Flag unresolvable names instead of letting them silently
                -- never show up in the anchor dropdowns.
                text:SetText(name .. " |cffe0b34d!|r")
                row:EnableMouse(true)
                row:SetScript("OnEnter", function()
                    BR.ShowTooltip(row, name, L["Layout.FrameNotFound"], "ANCHOR_TOP")
                end)
                row:SetScript("OnLeave", BR.HideTooltip)
            end

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                tremove(names, i)
                if #names == 0 then
                    db.customAnchorFrames = nil
                end
                Components.RefreshAll()
            end)

            dyn:Add(row, 20, 2)
        end

        local dynHeight = abs(dyn:GetY())
        dynHost:SetHeight(dynHeight)
        content:SetHeight(abs(staticBottomY) + dynHeight + 30)
    end

    -- Rebuild all dynamic rows on RefreshAll (split toggles, detach changes,
    -- anchor edits made elsewhere) - but only while the page is visible.
    -- RefreshAll fires from every page's onChange, WoW frames can't be
    -- reclaimed, and ActivatePage always runs RefreshAll after showing this
    -- page again, so skipping hidden rebuilds loses nothing.
    tinsert(BR.RefreshableComponents, {
        Refresh = function()
            if content:IsVisible() then
                Render()
            end
        end,
    })
    Render()
end

BR.Options.Pages.layout = {
    title = L["Page.Layout"],
    Build = Build,
}
