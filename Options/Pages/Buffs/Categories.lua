local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- CATEGORIES PAGE (tab strip)
-- ============================================================================
-- One surface for per-category display configuration. Each tab composes its
-- sections through _Template.lua. The Custom and Loadout tabs carry only the
-- styling sections, because their list editors are separate sidebar pages.
--
-- A tab body is built on first activation and then cached. A tab switch toggles
-- visibility and re-syncs the components with RefreshAll.

local L = BR.L
local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING
local SCROLLBAR_WIDTH = BR.Options.Constants.SCROLLBAR_WIDTH

-- Externals is not in CATEGORY_ORDER - that list drives frame creation, default
-- seeding and the visibility matrix, none of which apply to a Blizzard-rendered
-- container. It is appended here so its appearance still lives where every other
-- category's does, and its tab body comes from a standalone section rather than
-- the shared template.
local EXTERNALS_TAB = "externals"
local TAB_CATEGORIES = {}
for _, cat in ipairs(BR.CATEGORY_ORDER) do
    TAB_CATEGORIES[#TAB_CATEGORIES + 1] = cat
end
TAB_CATEGORIES[#TAB_CATEGORIES + 1] = EXTERNALS_TAB

local TAB_STRIP_H = 26
local TAB_GAP = 4
local ARROW_W = 16
-- Bottom padding the terminal appearance section leaves under the tab body.
local APPEARANCE_PADDING = 16
-- How far below the content top the tab strip sits (positive magnitude, matching
-- every other page's top padding). PAGE_TOP_PADDING is negative, so negate it.
local STRIP_TOP = -PAGE_TOP_PADDING

local ARROW_IDLE = { 0.7, 0.7, 0.7, 1 }
local ARROW_DISABLED = { 0.4, 0.4, 0.4, 1 }

---@param direction number -1 scrolls left, 1 scrolls right
local function CreateScrollArrow(parent, direction, onStep)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(ARROW_W, 22)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(12, 12)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    -- The texture points right.
    if direction < 0 then
        icon:SetRotation(math.pi)
    end

    local function UpdateColor(hovered)
        if not button:IsEnabled() then
            icon:SetVertexColor(unpack(ARROW_DISABLED))
        elseif hovered then
            icon:SetVertexColor(unpack(BR.Colors.Accent))
        else
            icon:SetVertexColor(unpack(ARROW_IDLE))
        end
    end

    button:SetScript("OnEnter", function()
        UpdateColor(true)
    end)
    button:SetScript("OnLeave", function()
        UpdateColor(false)
    end)
    button:SetScript("OnEnable", function(self)
        UpdateColor(self:IsMouseOver())
    end)
    button:SetScript("OnDisable", function()
        UpdateColor(false)
    end)
    button:SetScript("OnClick", function()
        onStep(direction)
    end)
    UpdateColor(false)
    return button
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()

    local tabLabels = {
        raid = L["Category.Raid"],
        presence = L["Category.Presence"],
        targeted = L["Category.Targeted"],
        self = L["Category.Self"],
        pet = L["Category.Pet"],
        consumable = L["Category.Consumable"],
        utility = L["Category.Utility"],
        custom = L["Category.Custom"],
        loadout = L["Category.Loadout"],
        externals = L["Externals.Title"],
    }

    local tabs = {}
    local tabFrames = {}
    local activeCat

    local function UpdatePageHeight()
        local frame = activeCat and tabFrames[activeCat]
        if frame then
            content:SetHeight(STRIP_TOP + TAB_STRIP_H + frame:GetHeight())
        end
    end

    local function BuildTabContent(cat)
        local frame = CreateFrame("Frame", nil, content)
        frame:SetPoint("TOPLEFT", 0, -(STRIP_TOP + TAB_STRIP_H))
        frame:SetSize(contentWidth, 400)

        -- This section IS the tab body. It keeps the same terminal-section
        -- contract: it sizes the tab frame, then it notifies the page.
        if cat == EXTERNALS_TAB then
            local layout = Components.VerticalLayout(frame, { x = COL_PADDING, y = PAGE_TOP_PADDING })
            BR.Options.BuffSections.ExternalsAppearance({
                content = frame,
                scrollFrame = scrollFrame,
                contentWidth = contentWidth,
                appearancePadding = APPEARANCE_PADDING,
                onAppearanceResize = UpdatePageHeight,
            }, layout)
            return frame
        end

        -- The resize hooks let the template size the tab frame and grow the page.
        BR.Options.Pages.BuffTemplate.Build(frame, scrollFrame, cat, {
            appearancePadding = APPEARANCE_PADDING,
            onAppearanceResize = UpdatePageHeight,
        })
        return frame
    end

    local function Activate(cat)
        if activeCat == cat then
            return
        end
        activeCat = cat
        for c, tab in pairs(tabs) do
            tab:SetActive(c == cat)
        end
        for _, frame in pairs(tabFrames) do
            frame:Hide()
        end
        if not tabFrames[cat] then
            tabFrames[cat] = BuildTabContent(cat)
        end
        tabFrames[cat]:Show()
        Components.RefreshAll()
        UpdatePageHeight()
    end

    -- Sticky tab strip. The parent is the scroll viewport, not the scrolling
    -- content child, so the strip stays pinned to the top while the tab body
    -- scrolls under it. An opaque mask that matches the panel body hides the
    -- content behind the tabs, and the strip sits above the scroll child so it
    -- paints on top. The content child reserves STRIP_TOP + TAB_STRIP_H of top
    -- padding, so no content starts hidden under the strip. The right edge stops
    -- short by the scrollbar column, which the content is inset by, so the mask
    -- never paints over the scrollbar and never blocks its clicks.
    local strip = CreateFrame("Frame", nil, scrollFrame)
    strip:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -SCROLLBAR_WIDTH, 0)
    strip:SetHeight(STRIP_TOP + TAB_STRIP_H)
    strip:SetFrameLevel(content:GetFrameLevel() + 10)

    local mask = strip:CreateTexture(nil, "BACKGROUND")
    mask:SetAllPoints(strip)
    mask:SetColorTexture(0.09, 0.09, 0.107, 1)

    -- Translated labels can make the row wider than the strip. Then the row
    -- scrolls inside a ScrollFrame, which clips both the drawing and the clicks.
    local scroller = CreateFrame("ScrollFrame", nil, strip)
    local row = CreateFrame("Frame", nil, scroller)
    scroller:SetScrollChild(row)

    local tabLefts, tabRights = {}, {}
    local rowWidth, tabHeight = 0, 0
    for _, cat in ipairs(TAB_CATEGORIES) do
        local tab = Components.Tab(row, {
            name = cat,
            label = tabLabels[cat],
            width = 40,
        })
        if rowWidth > 0 then
            rowWidth = rowWidth + TAB_GAP
        end
        tab:SetPoint("TOPLEFT", row, "TOPLEFT", rowWidth, 0)
        tabLefts[cat] = rowWidth
        rowWidth = rowWidth + tab:GetWidth()
        tabRights[cat] = rowWidth
        tabHeight = tab:GetHeight()
        if cat == EXTERNALS_TAB then
            -- A corner badge: the tab padding is too narrow for a dot after the text.
            local dot = BR.Options.WhatsNew.AttachDot(tab.text, "externals.casterName")
            dot:ClearAllPoints()
            dot:SetSize(8, 8)
            dot:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
        end
        tabs[cat] = tab
    end
    row:SetSize(rowWidth, tabHeight)

    local stripWidth = contentWidth - COL_PADDING * 2
    local overflow = rowWidth > stripWidth
    local inset = overflow and ARROW_W or 0
    local viewWidth = stripWidth - inset * 2
    local maxScroll = math.max(0, rowWidth - viewWidth)
    scroller:SetPoint("TOPLEFT", strip, "TOPLEFT", COL_PADDING + inset, -STRIP_TOP)
    scroller:SetSize(viewWidth, tabHeight)
    Components.TabBaseline(strip, scroller, viewWidth)

    local leftArrow, rightArrow

    local function ScrollTo(offset)
        offset = math.min(math.max(offset, 0), maxScroll)
        scroller:SetHorizontalScroll(offset)
        if overflow then
            leftArrow:SetEnabled(offset > 0)
            rightArrow:SetEnabled(offset < maxScroll)
        end
    end

    local function ScrollIntoView(cat)
        local offset = scroller:GetHorizontalScroll()
        if tabLefts[cat] < offset then
            ScrollTo(tabLefts[cat])
        elseif tabRights[cat] > offset + viewWidth then
            ScrollTo(tabRights[cat] - viewWidth)
        end
    end

    -- One step brings the next clipped tab fully into view.
    local function Step(direction)
        local offset = scroller:GetHorizontalScroll()
        if direction < 0 then
            for i = #TAB_CATEGORIES, 1, -1 do
                local left = tabLefts[TAB_CATEGORIES[i]]
                if left < offset - 0.5 then
                    return ScrollTo(left)
                end
            end
        else
            for _, cat in ipairs(TAB_CATEGORIES) do
                local right = tabRights[cat]
                if right > offset + viewWidth + 0.5 then
                    return ScrollTo(right - viewWidth)
                end
            end
        end
    end

    for cat, tab in pairs(tabs) do
        tab:SetScript("OnClick", function()
            Activate(cat)
            ScrollIntoView(cat)
        end)
    end

    if overflow then
        leftArrow = CreateScrollArrow(strip, -1, Step)
        leftArrow:SetPoint("RIGHT", scroller, "LEFT", 0, 0)
        rightArrow = CreateScrollArrow(strip, 1, Step)
        rightArrow:SetPoint("LEFT", scroller, "RIGHT", 0, 0)
        scroller:EnableMouseWheel(true)
        scroller:SetScript("OnMouseWheel", function(_, delta)
            Step(-delta)
        end)
        ScrollTo(0)
    end

    Activate("raid")
end

BR.Options.Pages.categories = {
    title = L["Page.Categories"],
    showMasqueBanner = true,
    Build = Build,
}
