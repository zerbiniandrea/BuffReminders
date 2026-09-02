local _, BR = ...

-- Namespace scaffold for Options/ modules. Must load before any Options/Dialogs/* or
-- Options/Pages/* file so they can populate their slots.
BR.Options = BR.Options or {}
BR.Options.Dialogs = BR.Options.Dialogs or {}
BR.Options.Pages = BR.Options.Pages or {}
BR.Options.Helpers = BR.Options.Helpers or {}

-- ============================================================================
-- SHARED CONSTANTS
-- ============================================================================

BR.Options.Constants = {
    PANEL_WIDTH = 920,
    PANEL_HEIGHT = 670,
    SIDEBAR_WIDTH = 160,
    SIDEBAR_X = 14,
    CONTENT_TOP_OFFSET = 48, -- Y offset from panel top to content top (below the single-row header bar)
    PANEL_BOTTOM_MARGIN = 14, -- breathing room between the content/sidebar and the panel's bottom edge
    -- Used for both the page-internal x-inset (where headers + content start
    -- inside each scrollable page) and the panel chrome's right margin.
    -- 28 aligns the panel title with the sidebar button labels.
    COL_PADDING = 28,
    SECTION_SPACING = 12,
    ITEM_HEIGHT = 22,
    ROW_HOVER_ALPHA = 0.04, -- white tint a list row paints under the pointer
    SCROLLBAR_WIDTH = 24,
    COMPONENT_GAP = 6, -- standard gap between components
    SECTION_GAP = 8, -- gap before/after section boundaries
    DROPDOWN_EXTRA = 8, -- extra clearance after dropdowns (menu overlay space)
    PAGE_TOP_PADDING = -16, -- y offset where each page's top VerticalLayout cursor starts

    -- Dialog shell metrics (see Helpers.CreateDialogShell). Widths bucketed by
    -- content density: NARROW for 1-3 simple controls, MEDIUM for dropdown +
    -- helpers, WIDE/ULTRA for multi-column layouts (poison/runeforge).
    DIALOG_WIDTH_NARROW = 340,
    DIALOG_WIDTH_MEDIUM = 360,
    DIALOG_WIDTH_WIDE = 520,
    DIALOG_WIDTH_ULTRA = 560,
    DIALOG_MARGIN = 16, -- inner padding for dialog content
    DIALOG_TITLE_TOP = -12, -- y offset of the dialog title FontString from TOP
    DIALOG_LAYOUT_TOP = -36, -- y offset where the content layout cursor starts
    DIALOG_ACCENT_OFFSET = 32, -- distance from top to the title separator (CreatePanel); body starts below it
    DIALOG_CLOSE_SIZE = 22, -- close-button square size
    DIALOG_CLOSE_INSET = -5, -- close-button TOPRIGHT inset (x and y)
    DIALOG_ICON_SIZE = 18, -- optional header icon square (CreateDialogShell opts.icon)
    DIALOG_MIN_HEIGHT = 80, -- floor for dialogs with very few controls
    DIALOG_LEVEL = 200, -- frame level used by all dialogs
}

-- ============================================================================
-- LOADOUT SCOPES
-- ============================================================================

-- Where a loadout rule applies, in the order the scope dropdown lists them.
-- These are player-facing content tiers. A key insert or a match start locks
-- gear and talents, so per-difficulty granularity adds nothing. Arena and
-- Battleground are separate tiers because their setups differ. Dungeon covers
-- every difficulty, including M+. Open World and Delve allow free swaps, so a
-- reminder to restore the everyday build stays usable there.
---@type { value: string, labelKey: string }[]
BR.Options.LoadoutScopes = {
    { value = "openWorld", labelKey = "Loadout.Scope.OpenWorld" },
    { value = "dungeon", labelKey = "Loadout.Scope.Dungeon" },
    { value = "delve", labelKey = "Loadout.Scope.Delve" },
    { value = "raid", labelKey = "Loadout.Scope.Raid" },
    { value = "arena", labelKey = "Loadout.Scope.Arena" },
    { value = "battleground", labelKey = "Loadout.Scope.Battleground" },
}

-- Scope to locale key, for a summary line that names one scope.
---@type table<string, string>
BR.Options.LoadoutScopeLabel = {}
for _, scope in ipairs(BR.Options.LoadoutScopes) do
    BR.Options.LoadoutScopeLabel[scope.value] = scope.labelKey
end

-- ============================================================================
-- SIDEBAR GROUPS / PAGE ORDER
-- ============================================================================
-- Declarative sidebar layout. Each entry: { id, titleKey, pages }.
-- Frame.lua iterates this list to render the sidebar; pages register themselves
-- on BR.Options.Pages.<id> so the IDs here must match.

-- Each group answers one user question:
--   Buffs & Reminders - WHAT do I track? (per-buff enable + the user editors)
--   Appearance        - HOW does it look? (global defaults + per-category overrides)
--   Display           - WHEN/WHERE does it show? (hide rules + tracking on the
--                       Visibility page, lock/order/frames on the Layout page)
--   Alerts            - HOW am I told? (sounds, chat requests)
--   Addon Settings    - the addon itself: misc meta toggles (General) + profiles
BR.Options.Groups = {
    {
        id = "buffs",
        titleKey = "Sidebar.Buffs",
        -- Externals last: the pages before it configure reminders for MISSING
        -- buffs. Externals is the inverse - the buffs the player RECEIVES.
        pages = { "allBuffs", "custom", "loadout", "externals" },
    },
    {
        id = "appearance",
        titleKey = "Sidebar.Appearance",
        pages = { "defaults", "categories" },
    },
    {
        id = "display",
        titleKey = "Sidebar.Display",
        pages = { "visibility", "layout" },
    },
    {
        id = "alerts",
        titleKey = "Sidebar.Alerts",
        pages = { "chatRequests" },
    },
    {
        id = "addonSettings",
        titleKey = "Sidebar.AddonSettings",
        pages = { "general", "profiles" },
    },
}

BR.Options.StaticCategories = BR.STATIC_CATEGORIES

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

local ceil = math.ceil
local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

-- Section header: gold text + thin gold accent line beneath, spanning the
-- content area's width.
--
-- The helper owns the vertical rhythm:
--   * It adds BEFORE_HEADER_GAP before each section after the first.
--   * It resets layout x to COL_PADDING, so the header and the accent line
--     span the full content width after a prior section indented content.
--   * It sets layout x to COL_PADDING + CONTENT_INDENT after the header, so
--     later content nests under the accent line. A caller can override this
--     with layout:SetX.
-- The first call on a layout skips the before-gap. The negative y the caller
-- gave to VerticalLayout supplies the space above the first section.
local BORDER_R, BORDER_G, BORDER_B = unpack(BR.Colors.Border)
local SEP_OFFSET = 4
local SEP_HEIGHT = 1
local AFTER_HEADER_GAP = 8 -- between the accent line and the first content row
local BEFORE_HEADER_GAP = 16 -- between the previous section's last item and this header
local CONTENT_INDENT = 10 -- how far content nests under each section header

function Helpers.LayoutSectionHeader(layout, parent, text)
    layout:SetX(COL_PADDING)

    layout._sectionCount = layout._sectionCount or 0
    if layout._sectionCount > 0 then
        layout:Space(BEFORE_HEADER_GAP)
    end
    layout._sectionCount = layout._sectionCount + 1

    local container = CreateFrame("Frame", nil, parent)

    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetWordWrap(false)
    header:SetText("|cffffcc00" .. text .. "|r")

    local headerH = ceil(header:GetStringHeight())
    if headerH < 14 then
        headerH = 14
    end

    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(SEP_HEIGHT)
    sep:SetPoint("TOPLEFT", 0, -(headerH + SEP_OFFSET))
    sep:SetPoint("TOPRIGHT", 0, -(headerH + SEP_OFFSET))
    sep:SetColorTexture(0.4, 0.32, 0.05, 0.6)

    local parentWidth = parent.GetWidth and parent:GetWidth() or 600
    local containerW = parentWidth - COL_PADDING * 2
    if containerW < 1 then
        containerW = 1
    end
    container:SetSize(containerW, headerH + SEP_OFFSET + SEP_HEIGHT)

    layout:Add(container, headerH + SEP_OFFSET + SEP_HEIGHT, AFTER_HEADER_GAP)

    layout:SetX(COL_PADDING + CONTENT_INDENT)

    return header
end

-- Compact gold subsection header: smaller than LayoutSectionHeader, no accent
-- line, for a nested sub-block under an existing section header. Pinned at the
-- layout's current x, so the caller's indent stays.
function Helpers.LayoutSubsectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetText("|cffffcc00" .. text .. "|r")
    local h = ceil(header:GetStringHeight())
    if h < 12 then
        h = 12
    end
    layout:AddText(header, h, COMPONENT_GAP)
    return header
end

-- Subsection note: like LayoutSectionNote, but it anchors at the layout's
-- current x. The right margin is COL_PADDING from the parent edge, so wrapped
-- text stays inside the panel. Use it under a LayoutSubsectionHeader.
function Helpers.LayoutSubsectionNote(layout, parent, text)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetJustifyH("LEFT")
    local parentWidth = parent.GetWidth and parent:GetWidth() or 600
    local noteWidth = parentWidth - layout:GetX() - COL_PADDING
    if noteWidth < 1 then
        noteWidth = 1
    end
    note:SetWidth(noteWidth)
    note:SetText(text)
    local h = ceil(note:GetStringHeight())
    if h < 12 then
        h = 12
    end
    layout:AddText(note, h, COMPONENT_GAP)
    return note
end

-- Section / page description text. Renders gray italic GameFontDisableSmall.
-- Anchored at COL_PADDING (full content width), so the note aligns with the
-- section header above it and does not nest under the accent line. The helper
-- keeps the layout x cursor, so later controls stay nested under the section.
function Helpers.LayoutSectionNote(layout, parent, text)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetJustifyH("LEFT")

    local parentWidth = parent.GetWidth and parent:GetWidth() or 600
    local noteWidth = parentWidth - COL_PADDING * 2
    if noteWidth < 1 then
        noteWidth = 1
    end
    note:SetWidth(noteWidth)
    note:SetText(text)

    local h = ceil(note:GetStringHeight())
    if h < 12 then
        h = 12
    end

    local prevX = layout:GetX()
    layout:SetX(COL_PADDING)
    layout:AddText(note, h, COMPONENT_GAP)
    layout:SetX(prevX)
    return note
end

-- ============================================================================
-- SHARED ROWS
-- ============================================================================

---Override checkbox plus a live inheritance state label, added to the layout.
---The wording is generic, so every override in the panel reads the same way.
---@param parent table
---@param layout table
---@param opts table Fields: get (fun(): boolean), desc (string tooltip text), onChange (fun(checked: boolean))
---@return table holder
function Helpers.AddOverrideRow(parent, layout, opts)
    local holder = Components.Checkbox(parent, {
        label = L["Options.Override"],
        get = opts.get,
        tooltip = { title = L["Options.Override"], desc = opts.desc },
        onChange = opts.onChange,
    })

    local stateText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stateText:SetPoint("LEFT", holder.infoIcon or holder.label, "RIGHT", 10, 0)
    local function refreshState()
        if opts.get() then
            stateText:SetText(L["Options.Override.Overriding"])
            stateText:SetTextColor(1, 0.82, 0)
        else
            stateText:SetText(L["Options.Override.Inherited"])
            stateText:SetTextColor(0.55, 0.55, 0.55)
        end
    end
    refreshState()
    table.insert(BR.RefreshableComponents, { Refresh = refreshState })

    layout:Add(holder, nil, COMPONENT_GAP)
    return holder
end

---A small speaker button that plays the current sound.
---@param parent table
---@param getValue fun(): string? Stored sound value
---@return table button
function Helpers.SoundPreviewButton(parent, getValue)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("chatframe-button-icon-voicechat")
    icon:SetVertexColor(0.72, 0.72, 0.76)

    button:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1)
        BR.ShowTooltip(self, L["Options.Sound.Preview"], nil, "ANCHOR_RIGHT")
    end)
    button:SetScript("OnLeave", function()
        icon:SetVertexColor(0.72, 0.72, 0.76)
        BR.HideTooltip()
    end)
    button:SetScript("OnClick", function()
        local file = BR.Sounds.Resolve(getValue())
        if file then
            PlaySoundFile(file, "Master")
        end
    end)

    return button
end

-- ============================================================================
-- LIST EDITOR
-- ============================================================================
-- Shared skeleton for the entry-list editor pages. Each page declares only its
-- row content and its data source.
-- Rows flow directly in the page's own scroll container. Do not nest a scroll
-- box inside a page. The Add button sits at the top, so it stays reachable when
-- the list grows.

local LIST_ADD_BUTTON_HEIGHT = 22
local LIST_ROW_HOVER_ALPHA = BR.Options.Constants.ROW_HOVER_ALPHA

-- Default row frame: a plain, full-width hover strip. A page that needs
-- persistent child widgets passes its own config.createRow.
local function DefaultListRow(parent)
    local row = CreateFrame("Frame", nil, parent)

    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)
    row.hover = hover

    row:SetScript("OnEnter", function(self)
        self.hover:SetColorTexture(1, 1, 1, LIST_ROW_HOVER_ALPHA)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0)
    end)
    row:EnableMouse(true)

    return row
end

---Build a list-editor page body. Returns the Render function (already invoked
---once and wired to refresh when the page is shown).
---@param content table Page content frame (scroll child)
---@param scrollFrame table Page ScrollableContainer (for GetContentWidth)
---@param config table {
---  header?     string   - section header text (omit for no header)
---  note?       string   - section note text (omit for none)
---  warning?    string   - caution note (amber) under the note (omit for none)
---  addLabel    string   - Add button label
---  addWidth?   number   - Add button width (default 160)
---  onAdd       function(render) - opens the editor dialog; pass render as its refresh cb
---  rowHeight   number   - fixed row height in px
---  emptyText   string   - placeholder shown when the list is empty
---  createRow?  function(parent)->row - row frame factory (default: plain hover strip)
---  getItems    function()->array - sorted list of opaque item objects
---  fillRow     function(row, item, render) - populate a pooled row for one item
--- }
---@return function render
function Helpers.ListEditor(content, scrollFrame, config)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    if config.header then
        Helpers.LayoutSectionHeader(layout, content, config.header)
    end
    if config.note then
        Helpers.LayoutSectionNote(layout, content, config.note)
    end
    if config.warning then
        Helpers.LayoutSectionNote(layout, content, "|cffe0b34d" .. config.warning .. "|r")
    end

    local rowHeight = config.rowHeight
    local createRow = config.createRow or DefaultListRow

    -- Add button above the list; the page's own scroll handles overflow.
    local Render -- forward decl; onAdd + fillRow callbacks reference it
    local addBtn = BR.CreateButton(content, config.addLabel, function()
        config.onAdd(Render)
    end)
    addBtn:SetSize(config.addWidth or 160, LIST_ADD_BUTTON_HEIGHT)
    layout:Add(addBtn, LIST_ADD_BUTTON_HEIGHT, SECTION_GAP)

    local listX = layout:GetX()
    local listWidth = contentWidth - listX - COL_PADDING
    local listTopY = layout:GetY()
    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT", content, "TOPLEFT", listX, listTopY)
    listContainer:SetWidth(listWidth)
    listContainer:SetHeight(1)

    local rowPool = {}
    local rowCount = 0

    local emptyText = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(config.emptyText)
    emptyText:Hide()

    local function UpdateContentHeight()
        content:SetHeight(math.abs(listTopY) + listContainer:GetHeight() + 30)
    end

    local function AcquireRow(index)
        local row = rowPool[index]
        if not row then
            row = createRow(listContainer)
            rowPool[index] = row
        end
        row:SetHeight(rowHeight)
        row:SetWidth(listWidth)
        row:ClearAllPoints()
        row:Show()
        return row
    end

    Render = function()
        for i = 1, rowCount do
            rowPool[i]:Hide()
        end
        rowCount = 0

        local items = config.getItems()

        if #items == 0 then
            emptyText:Show()
            listContainer:SetHeight(rowHeight)
            UpdateContentHeight()
            return
        end
        emptyText:Hide()

        local y = 0
        for _, item in ipairs(items) do
            rowCount = rowCount + 1
            local row = AcquireRow(rowCount)
            row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, y)
            config.fillRow(row, item, Render)
            y = y - rowHeight
        end

        listContainer:SetHeight(-y)
        UpdateContentHeight()
    end

    Render()

    -- Re-render when the page becomes active. A slash command or a dialog on
    -- another page can change the list while the page is hidden.
    local refreshHook = CreateFrame("Frame", nil, listContainer)
    refreshHook:SetSize(1, 1)
    function refreshHook:Refresh()
        Render()
    end
    table.insert(BR.RefreshableComponents, refreshHook)

    return Render
end

-- ============================================================================
-- SCOPE TAG
-- ============================================================================
-- Category pages host a few controls whose storage is global (defaults.* or
-- profile-root) even though they sit among per-category widgets. A "GLOBAL" tag
-- next to the control's label makes that scope visible.

local GLOBAL_TAG_COLOR = { 0.45, 0.7, 0.95 }

---Attach a "GLOBAL" scope tag after a component's label. Use on any category
---page control that writes defaults.* or a profile-root key.
---@param holder table Component holder exposing .label (and optionally .infoIcon)
function Helpers.AttachGlobalTag(holder)
    local anchor = holder.infoIcon or holder.label or holder
    local tag = CreateFrame("Frame", nil, holder)
    tag:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    local text = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT")
    text:SetText(L["Options.GlobalTag"])
    text:SetTextColor(GLOBAL_TAG_COLOR[1], GLOBAL_TAG_COLOR[2], GLOBAL_TAG_COLOR[3])
    tag:SetSize(text:GetStringWidth() + 2, 14)
    tag:EnableMouse(true)
    tag:SetScript("OnEnter", function()
        BR.ShowTooltip(tag, L["Options.GlobalTag.Title"], L["Options.GlobalTag.Desc"], "ANCHOR_TOP")
    end)
    tag:SetScript("OnLeave", BR.HideTooltip)
    return tag
end

-- ============================================================================
-- CATEGORY SETTINGS HELPERS
-- ============================================================================
--
-- Sections read `categorySettings[category].X` with nil-safe fallbacks and write
-- back through `BR.Config.Set("categorySettings." .. category .. ".X", val)`.
-- The helpers below collapse those idioms.
--
-- `BR.Config.Set` auto-creates the intermediate tables on its path. A Set call
-- needs no ensure-block for db.categorySettings or db.categorySettings[category].
--
-- These helpers do not inherit, because most option widgets want the literal
-- category value. For an inheritance-aware read (a category falls back to
-- db.defaults when useCustomAppearance is off), use
-- `BR.Config.GetCategorySetting`.

---Read categorySettings[category][key] with a nil-safe fallback.
function Helpers.GetCategorySetting(category, key, default)
    local cs = BR.profile.categorySettings and BR.profile.categorySettings[category]
    if not cs then
        return default
    end
    local v = cs[key]
    if v == nil then
        return default
    end
    return v
end

---Write categorySettings[category][key] via the validated config path.
function Helpers.SetCategorySetting(category, key, value)
    BR.Config.Set("categorySettings." .. category .. "." .. key, value)
end

---Build a closure suitable for a component `get =` callback.
function Helpers.MakeCategoryGetter(category, key, default)
    return function()
        return Helpers.GetCategorySetting(category, key, default)
    end
end

---Build a closure suitable for a component `onChange =` callback.
function Helpers.MakeCategorySetter(category, key)
    return function(value)
        BR.Config.Set("categorySettings." .. category .. "." .. key, value)
    end
end

-- ============================================================================
-- ROOT-PROFILE & DEFAULTS GETTERS / SETTERS
-- ============================================================================
--
-- Two more flavors of the same idiom for the other two flat-key namespaces:
--   * Profile keys live at BR.profile.<key>.
--   * Defaults keys live at BR.profile.defaults.<key>.
--
-- Use them only when the read is a plain truthy or equality check. If the
-- onChange has side effects, keep the explicit closure, so the side effects stay
-- visible at the call site.

---Read a root profile key (BR.profile[key]) with a fallback default.
function Helpers.GetProfileSetting(key, default)
    local v = BR.profile and BR.profile[key]
    if v == nil then
        return default
    end
    return v
end

function Helpers.MakeProfileGetter(key, default)
    return function()
        return Helpers.GetProfileSetting(key, default)
    end
end

function Helpers.MakeProfileSetter(key)
    return function(value)
        BR.Config.Set(key, value)
    end
end

---Read a defaults-namespaced key (BR.profile.defaults[key]) with a fallback.
function Helpers.GetDefaultSetting(key, default)
    local d = BR.profile and BR.profile.defaults
    if not d then
        return default
    end
    local v = d[key]
    if v == nil then
        return default
    end
    return v
end

function Helpers.MakeDefaultsGetter(key, default)
    return function()
        return Helpers.GetDefaultSetting(key, default)
    end
end

function Helpers.MakeDefaultsSetter(key)
    return function(value)
        BR.Config.Set("defaults." .. key, value)
    end
end

-- AddCloseButton draws the flat close-x every panel and dialog shares. Blizzard's
-- UIPanelCloseButton does not match the addon chrome, so no frame uses it.
---@param parent table
---@param onClick? function defaults to parent:Hide()
---@return table button
function Helpers.AddCloseButton(parent, onClick)
    local C = BR.Options.Constants
    local btn = BR.CreateButton(parent, "x", onClick or function()
        parent:Hide()
    end)
    btn:SetSize(C.DIALOG_CLOSE_SIZE, C.DIALOG_CLOSE_SIZE)
    btn:SetPoint("TOPRIGHT", C.DIALOG_CLOSE_INSET, C.DIALOG_CLOSE_INSET)
    return btn
end

-- ============================================================================
-- DIALOG SHELL HELPERS
-- ============================================================================

-- CreateDialogShell builds the boilerplate every small dialog repeats: backdrop
-- panel, title FontString, close-x button, and a VerticalLayout whose cursor
-- starts beneath the title. Callers add their content via the returned layout
-- and call shell:Finalize() to size the dialog.
--
-- opts.titleText overrides the localized title. opts.titleColor wraps the title
-- in a color escape. opts.width defaults to DIALOG_WIDTH_NARROW; pass a
-- Constants.DIALOG_WIDTH_* for a wider bucket. opts.icon (a texture path or
-- fileID) adds a small icon at the left of the header and left-aligns the title
-- next to it. Without opts.icon the title stays centered.
---@class DialogShell
---@field dialog table panel frame (also returned as the first table value)
---@field layout table VerticalLayout anchored under the title
---@field title table title FontString (so callers can retint or rewrite it)
---@field closeButton table x button
---@field Finalize fun(self: table, extraPadding?: number) sizes dialog:SetHeight
function Helpers.CreateDialogShell(name, titleKey, opts)
    opts = opts or {}
    local C = BR.Options.Constants
    local CreatePanel = BR.CreatePanel

    local dialog = CreatePanel(name, opts.width or C.DIALOG_WIDTH_NARROW, 1, {
        level = opts.level or C.DIALOG_LEVEL,
        strata = opts.strata,
        dialog = true,
    })

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local titleText = opts.titleText or BR.L[titleKey]
    if opts.titleColor then
        titleText = "|cff" .. opts.titleColor .. titleText .. "|r"
    end
    title:SetText(titleText)

    if opts.icon then
        local icon = dialog:CreateTexture(nil, "OVERLAY")
        icon:SetSize(C.DIALOG_ICON_SIZE, C.DIALOG_ICON_SIZE)
        -- LEFT anchor = vertical center. Pin it to the midpoint of the 30px
        -- header strip (top inset 2 + 15), so the icon and the title that hangs
        -- off it stay centered in the header band.
        icon:SetPoint("LEFT", dialog, "TOPLEFT", C.DIALOG_MARGIN, -17)
        icon:SetTexture(opts.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border
        title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    else
        title:SetPoint("TOP", 0, C.DIALOG_TITLE_TOP)
    end

    local closeBtn = Helpers.AddCloseButton(dialog)

    local layoutTop = opts.layoutY or C.DIALOG_LAYOUT_TOP
    local layout = BR.Components.VerticalLayout(dialog, {
        x = opts.layoutX or C.DIALOG_MARGIN,
        y = layoutTop,
    })

    local shell = {
        dialog = dialog,
        layout = layout,
        title = title,
        closeButton = closeBtn,
    }
    function shell:Finalize(extraPadding)
        local pad = extraPadding or C.DIALOG_MARGIN
        local contentBottom = layout:GetY()
        local height = math.max(-contentBottom + pad, C.DIALOG_MIN_HEIGHT)
        dialog:SetHeight(height)
        BR.ApplyDialogScale(dialog)

        -- Center the content in the body region: from the title separator down
        -- to the bottom edge. A single short control then sits in the middle of
        -- the min-height body, not at its top.
        local bodyCenter = (-C.DIALOG_ACCENT_OFFSET - height) / 2
        local contentCenter = (layoutTop + contentBottom) / 2
        layout:ShiftAllBy(bodyCenter - contentCenter)
    end
    return shell
end

-- SingletonDialog wraps a builder so the dialog frame is created on first show
-- and reused after that, with Components.RefreshAll() to resync. The builder
-- receives the args passed to Show and must return the dialog frame.
--
-- Use it only for a dialog whose content depends on profile data alone. A
-- dialog whose body varies per invocation must rebuild its body on each Show.
function Helpers.SingletonDialog(builder)
    local cached
    return {
        Show = function(...)
            if cached then
                BR.Components.RefreshAll()
                cached:Show()
                return cached
            end
            cached = builder(...)
            cached:Show()
            return cached
        end,
    }
end

function Helpers.LayoutSeparator(layout, parent)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 0.6)
    layout:Add(sep, 1, COMPONENT_GAP)
    sep:SetWidth((parent.GetWidth and parent:GetWidth() or 600) - 40)
end

-- ============================================================================
-- PAGE CONTEXT
-- ============================================================================

-- Shared category labels for buff pages (built lazily so BR.L is populated).
local categoryLabelsCache = nil
local function GetCategoryLabels()
    if categoryLabelsCache then
        return categoryLabelsCache
    end
    categoryLabelsCache = {
        raid = L["Category.RaidBuffs"],
        presence = L["Category.PresenceBuffs"],
        targeted = L["Category.TargetedBuffs"],
        self = L["Category.SelfBuffs"],
        pet = L["Category.PetReminders"],
        consumable = L["Category.Consumables"],
        utility = L["Category.UtilityReminders"],
        custom = L["Category.CustomBuffs"],
        loadout = L["Category.LoadoutReminders"],
    }
    return categoryLabelsCache
end

BR.Options.GetCategoryLabels = GetCategoryLabels
