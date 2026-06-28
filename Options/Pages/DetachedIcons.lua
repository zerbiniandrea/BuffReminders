local _, BR = ...

-- ============================================================================
-- DETACHED ICONS PAGE
-- ============================================================================
-- Dedicated sidebar entry for managing per-buff detach state. Replaces the
-- old hidden 14x14 pin column on All Buffs so the feature has a
-- discoverable, full-page home.
--
-- Layout: search box -> "Currently detached" subsection (Reset / Reattach
-- per row) -> "Available" subsection (Detach per row, filtered to buffs not
-- already detached) -> "Reattach all" footer.
--
-- Catalog walks BR.BUFF_TABLES (incl. the runtime-rebuilt custom array) once
-- per activation and dedups by groupId so grouped buffs (beacons, paladin
-- rites, ...) collapse to a single entry keyed by groupId. Refresh re-splits
-- the cached catalog whenever something changes (search keystroke, button
-- click, page activation). Row pools rebuild visible widgets per render -
-- cheap at this row count and matches Custom.lua's pattern.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

local IsIconDetached = BR.Helpers.IsIconDetached
local DetachIcon = BR.Helpers.DetachIcon
local ReattachIcon = BR.Helpers.ReattachIcon
local ResetDetachedPosition = BR.Helpers.ResetDetachedPosition
local UpdateDisplay = BR.Display.Update

local GetBuffIcons = BR.Helpers.GetBuffIcons
local LayoutSectionNote = Helpers.LayoutSectionNote
local LayoutSubsectionHeader = Helpers.LayoutSubsectionHeader
local GetCategoryLabels = BR.Options.GetCategoryLabels

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local COL_PADDING = BR.Options.Constants.COL_PADDING
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local tsort = table.sort
-- ASCII-only lowercase. WoW's Lua 5.1 has no UTF-8 case folding; case-
-- insensitive search therefore only matches ASCII variations. In practice
-- buff names within a single locale are stylistically consistent (the
-- localizer doesn't randomly capitalize), so this is rarely user-visible.
local lower = string.lower
local find = string.find
local format = string.format
local abs = math.abs

local ROW_HEIGHT = 26
local ICON_SIZE = 20
-- List heights + vertical gaps tuned so the page total fits within the
-- 920x640 panel's content area without a page-level scrollbar. Detached
-- stays short on the assumption most users have 0-3 detached; Available
-- gets the bulk for the search-and-detach flow. Both lists scroll
-- internally when overfull.
local DETACHED_LIST_HEIGHT = 5 * ROW_HEIGHT -- 5 rows visible
local AVAILABLE_LIST_HEIGHT = 9 * ROW_HEIGHT -- 9 rows visible
local SUBSECTION_GAP = 4 -- between subsection header and its list
local SEARCH_TO_LIST_GAP = 8 -- between search input and detached header
local LIST_TO_NEXT_GAP = 10 -- between a list and the next subsection / button
local BUTTON_W = 64
local BUTTON_H = 20
local DEFAULT_ICON_TEXTURE = 134400

-- ============================================================================
-- CATALOG
-- ============================================================================

---@class DetachedIconsPage.Entry
---@field key string Buff key or groupId (the value DetachIcon stores against)
---@field name string User-facing display name
---@field icons string[]|number[]|nil Texture list (first one rendered)
---@field categoryKey string Source category in BUFF_TABLES
---@field categoryLabel string Localized category label

---Walk every static and custom buff and produce one entry per detachable key.
---Group buffs collapse to a single entry keyed by groupId (DetachIcon stores
---detached state under the same key the display layer renders against).
---@return DetachedIconsPage.Entry[]
local function BuildCatalog()
    local catalog = {}
    local seen = {}
    local labels = GetCategoryLabels()

    for catName, buffArray in pairs(BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            local key = buff.groupId or buff.key
            if key and not seen[key] then
                seen[key] = true
                local groupInfo = buff.groupId and BuffGroups[buff.groupId]
                tinsert(catalog, {
                    key = key,
                    name = (groupInfo and groupInfo.displayName) or buff.name or key,
                    icons = GetBuffIcons(buff),
                    categoryKey = catName,
                    categoryLabel = labels[catName] or catName,
                })
            end
        end
    end

    -- Alphabetical by display name. Category is shown as a per-row badge so
    -- a global sort reads more predictably than nested category-then-name
    -- buckets when users are searching by buff name.
    tsort(catalog, function(a, b)
        return lower(a.name or "") < lower(b.name or "")
    end)
    return catalog
end

---@param entry DetachedIconsPage.Entry
---@param term string lowercased search term ("" matches everything)
local function MatchesSearch(entry, term)
    if term == "" then
        return true
    end
    return find(lower(entry.name or ""), term, 1, true) ~= nil
        or find(lower(entry.categoryLabel or ""), term, 1, true) ~= nil
end

-- ============================================================================
-- ROW WIDGETS
-- ============================================================================

local function CreateRowFrame(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)
    row:SetScript("OnEnter", function()
        hover:SetColorTexture(1, 1, 1, 0.04)
    end)
    row:SetScript("OnLeave", function()
        hover:SetColorTexture(1, 1, 1, 0)
    end)
    row:EnableMouse(true)
    return row
end

---Render one row's contents: icon + name + category badge + action buttons.
---`makeButtons` is a per-list closure that creates the right-side buttons
---and returns the leftmost one so the category label can anchor to its left.
local function FillRow(row, entry, makeButtons)
    if row.body then
        row.body:Hide()
        row.body:SetParent(nil)
    end
    local body = CreateFrame("Frame", nil, row)
    body:SetAllPoints()
    row.body = body

    local iconTex = body:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", 4, 0)
    local first = entry.icons and entry.icons[1]
    if first then
        iconTex:SetTexture(first)
        iconTex:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    else
        iconTex:SetTexture(DEFAULT_ICON_TEXTURE)
    end

    local nameText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(entry.name)

    local catText = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    catText:SetJustifyH("LEFT")
    catText:SetWordWrap(false)
    catText:SetText(entry.categoryLabel)

    local leftmost = makeButtons(body, entry)
    if leftmost then
        catText:SetPoint("RIGHT", leftmost, "LEFT", -10, 0)
    else
        catText:SetPoint("RIGHT", body, "RIGHT", -8, 0)
    end
    nameText:SetPoint("RIGHT", catText, "LEFT", -8, 0)
end

---Build a row pool tied to `scrollFrame`. Returns a `Render(entries, empty)`
---closure that hides previous rows, materializes one row per entry, and
---resizes the scroll content height to fit. `makeButtons` is invoked per
---row to build the list-specific action buttons.
local function CreateListRenderer(scrollFrame, makeButtons)
    local content = scrollFrame:GetContentFrame()
    local pool = {}
    local visibleCount = 0

    local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetJustifyH("LEFT")
    emptyText:Hide()

    local function Acquire(i)
        local row = pool[i]
        if not row then
            row = CreateRowFrame(content)
            pool[i] = row
        end
        row:SetWidth(scrollFrame:GetContentWidth())
        row:Show()
        return row
    end

    return function(entries, emptyMessage)
        for i = 1, visibleCount do
            pool[i]:Hide()
        end
        visibleCount = 0

        if #entries == 0 then
            emptyText:SetText(emptyMessage or "")
            emptyText:Show()
            scrollFrame:SetContentHeight(ROW_HEIGHT)
            return
        end
        emptyText:Hide()

        local y = 0
        for _, entry in ipairs(entries) do
            visibleCount = visibleCount + 1
            local row = Acquire(visibleCount)
            row:SetPoint("TOPLEFT", 0, y)
            FillRow(row, entry, makeButtons)
            y = y - ROW_HEIGHT
        end

        local total = -y
        if total < ROW_HEIGHT then
            total = ROW_HEIGHT
        end
        scrollFrame:SetContentHeight(total)
    end
end

-- ============================================================================
-- PAGE BUILD
-- ============================================================================

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local listWidth = contentWidth - COL_PADDING * 2

    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -16 })

    LayoutSectionNote(layout, content, L["DetachedIcons.PageNote"])

    -- State: catalog rebuilt on each page activation (see refresh hook
    -- below), search term preserved across activations within the session.
    local catalog = BuildCatalog()
    local searchTerm = ""
    local Refresh -- forward decl

    -- Search input. Hooks OnTextChanged after construction since the shared
    -- TextInput component only fires onChange on Enter / focus loss; live
    -- filtering wants every keystroke.
    local searchHolder = Components.TextInput(content, {
        label = L["DetachedIcons.Search"],
        labelWidth = 60,
        width = listWidth - 70,
    })
    layout:Add(searchHolder, nil, SEARCH_TO_LIST_GAP)
    searchHolder.editBox:SetScript("OnTextChanged", function(self)
        searchTerm = lower(self:GetText() or "")
        Refresh()
    end)

    -- "Currently detached (N)" subsection
    local detachedHeader = LayoutSubsectionHeader(layout, content, L["DetachedIcons.CurrentlyDetachedCount"])
    layout:Space(SUBSECTION_GAP)

    local detachedWrapper, detachedScroll = Components.BorderedList(content, {
        width = listWidth,
        height = DETACHED_LIST_HEIGHT,
    })
    layout:Add(detachedWrapper, DETACHED_LIST_HEIGHT, LIST_TO_NEXT_GAP)

    -- "Available" subsection
    LayoutSubsectionHeader(layout, content, L["DetachedIcons.Available"])
    layout:Space(SUBSECTION_GAP)

    local availableWrapper, availableScroll = Components.BorderedList(content, {
        width = listWidth,
        height = AVAILABLE_LIST_HEIGHT,
    })
    layout:Add(availableWrapper, AVAILABLE_LIST_HEIGHT, LIST_TO_NEXT_GAP)

    -- "Reattach all" footer
    local reattachAllBtn = CreateButton(content, L["DetachedIcons.ReattachAll"], function()
        local db = BR.profile
        if not db.detachedIcons then
            return
        end
        for key in pairs(db.detachedIcons) do
            ReattachIcon(key)
        end
        Refresh()
        UpdateDisplay()
    end)
    reattachAllBtn:SetSize(120, 22)
    layout:Add(reattachAllBtn, 22, COMPONENT_GAP)

    -- Per-list row button factories. Each returns its leftmost button so the
    -- category badge anchors correctly.
    local renderDetached = CreateListRenderer(detachedScroll, function(parent, entry)
        local reattachBtn = CreateButton(parent, L["DetachedIcons.Reattach"], function()
            ReattachIcon(entry.key)
            Refresh()
            UpdateDisplay()
        end)
        reattachBtn:SetSize(BUTTON_W, BUTTON_H)
        reattachBtn:SetPoint("RIGHT", -8, 0)

        local resetBtn = CreateButton(parent, L["DetachedIcons.ResetPos"], function()
            ResetDetachedPosition(entry.key)
        end)
        resetBtn:SetSize(BUTTON_W, BUTTON_H)
        resetBtn:SetPoint("RIGHT", reattachBtn, "LEFT", -6, 0)

        return resetBtn
    end)

    local renderAvailable = CreateListRenderer(availableScroll, function(parent, entry)
        local detachBtn = CreateButton(parent, L["DetachedIcons.Detach"], function()
            DetachIcon(entry.key)
            Refresh()
            UpdateDisplay()
        end)
        detachBtn:SetSize(BUTTON_W, BUTTON_H)
        detachBtn:SetPoint("RIGHT", -8, 0)
        return detachBtn
    end)

    Refresh = function()
        local detached, available = {}, {}
        for _, entry in ipairs(catalog) do
            if MatchesSearch(entry, searchTerm) then
                if IsIconDetached(entry.key) then
                    tinsert(detached, entry)
                else
                    tinsert(available, entry)
                end
            end
        end
        renderDetached(detached, L["DetachedIcons.NoneDetached"])
        renderAvailable(available, L["DetachedIcons.NoMatches"])

        detachedHeader:SetText(format("|cffffcc00%s|r", format(L["DetachedIcons.CurrentlyDetachedCount"], #detached)))
        reattachAllBtn:SetEnabled(#detached > 0)
    end

    Refresh()
    content:SetHeight(abs(layout:GetY()) + 20)

    -- Refresh hook: rebuild catalog (custom buffs may have changed) and
    -- re-render whenever the page is re-activated. Components.RefreshAll is
    -- called by Frame.lua on page activate.
    local refreshHook = CreateFrame("Frame", nil, content)
    refreshHook:SetSize(1, 1)
    function refreshHook:Refresh()
        catalog = BuildCatalog()
        Refresh()
    end
    tinsert(BR.RefreshableComponents, refreshHook)
end

BR.Options.Pages.detachedIcons = {
    title = L["Page.DetachedIcons"],
    Build = Build,
}
