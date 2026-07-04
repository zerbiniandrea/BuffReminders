local _, BR = ...

-- ============================================================================
-- CATEGORIES PAGE (tab strip)
-- ============================================================================
-- One surface for per-category display configuration, replacing seven
-- near-identical sidebar pages. A tab per category hosts the same section
-- composition the old pages used (via _Template.lua); Custom and Loadout tabs
-- carry only the styling sections - their list editors live on their own
-- sidebar pages under the Buffs group.
--
-- Tab content is built lazily on first activation and cached; switching tabs
-- toggles visibility and re-syncs components via RefreshAll.

local L = BR.L
local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local TAB_CATEGORIES = BR.CATEGORY_ORDER
local TAB_STRIP_H = 26
-- How far below the content top the tab strip sits (positive magnitude, matching
-- every other page's top padding). PAGE_TOP_PADDING is negative, so negate it.
local STRIP_TOP = -PAGE_TOP_PADDING

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()

    -- Short labels keep eight tabs inside the content width.
    local tabLabels = {
        raid = L["Category.Raid"],
        presence = L["Category.Presence"],
        targeted = L["Category.Targeted"],
        self = L["Category.Self"],
        pet = L["Category.Pet"],
        consumable = L["Category.Consumable"],
        custom = L["Category.Custom"],
        loadout = L["Category.Loadout"],
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
        -- Every tab is built by the same template - it decides which sections
        -- the category gets (custom/loadout collapse to styling only). The
        -- resize hooks let CustomAppearance size the tab frame and grow the page.
        BR.Options.Pages.BuffTemplate.Build(frame, scrollFrame, cat, {
            appearancePadding = 16,
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

    -- Tab strip
    local prev, firstTab
    for _, cat in ipairs(TAB_CATEGORIES) do
        local tab = Components.Tab(content, {
            name = cat,
            label = tabLabels[cat],
            width = 40,
        })
        tab:SetScript("OnClick", function()
            Activate(cat)
        end)
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", content, "TOPLEFT", COL_PADDING, -STRIP_TOP)
            firstTab = tab
        end
        tabs[cat] = tab
        prev = tab
    end

    -- Grounding baseline spanning the full strip width; the active tab's gold
    -- underline rides on top of it (see Components.TabBaseline).
    Components.TabBaseline(content, firstTab, contentWidth - COL_PADDING * 2)

    Activate("raid")
end

BR.Options.Pages.categories = {
    title = L["Page.Categories"],
    showMasqueBanner = true,
    Build = Build,
}
