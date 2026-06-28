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
    PANEL_HEIGHT = 690,
    SIDEBAR_WIDTH = 188,
    SIDEBAR_X = 14,
    CONTENT_TOP_OFFSET = 64, -- Y offset from panel top to content top (below header bar)
    BOTTOM_BAR_HEIGHT = 46,
    -- Used for both the page-internal x-inset (where headers + content start
    -- inside each scrollable page) and the panel chrome's right margin.
    -- 28 aligns the panel title with the sidebar button labels.
    COL_PADDING = 28,
    SECTION_SPACING = 12,
    ITEM_HEIGHT = 22,
    SCROLLBAR_WIDTH = 24,
    COMPONENT_GAP = 6, -- standard gap between components
    SECTION_GAP = 8, -- gap before/after section boundaries
    DROPDOWN_EXTRA = 8, -- extra clearance after dropdowns (menu overlay space)

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
-- SIDEBAR GROUPS / PAGE ORDER
-- ============================================================================
-- Declarative sidebar layout. Each entry: { id, titleKey, pages }.
-- Frame.lua iterates this list to render the sidebar; pages register themselves
-- on BR.Options.Pages.<id> so the IDs here must match.

BR.Options.Groups = {
    {
        -- Per-buff list surfaces: both pages iterate every tracked buff and
        -- let the user toggle something at the buff-key level (enabled vs.
        -- detached). Grouping them keeps Display Behavior reserved for the
        -- per-category pages, so that group's pattern (Defaults + one entry
        -- per render category) stays uniform.
        id = "buffs",
        titleKey = "Sidebar.Buffs",
        pages = { "allBuffs", "detachedIcons" },
    },
    {
        -- Defaults heads this group as the parent (the per-category pages
        -- inherit appearance / glow / threshold defaults from it). Built-in
        -- categories follow the same default priority order used by the
        -- Display Order section on Defaults, so the sidebar reads as the
        -- combined frame stacks top-to-bottom. Custom sits last because it's
        -- qualitatively different (user-defined entries with a list editor).
        id = "displayBehavior",
        titleKey = "Sidebar.DisplayBehavior",
        pages = { "defaults", "raid", "presence", "targeted", "self", "pet", "consumable", "custom" },
    },
    {
        -- Loadout reminders are their own feature pillar (gear sets / talents /
        -- talent loadouts - not auras), so they get a dedicated section rather
        -- than hiding at the bottom of the buff-centric Display & Behavior group.
        id = "loadouts",
        titleKey = "Sidebar.Loadouts",
        pages = { "loadout" },
    },
    {
        -- General pinned on top; remaining pages alphabetical by display name.
        id = "general",
        titleKey = "Sidebar.General",
        pages = { "general", "anchorFrames", "chatRequests", "sounds", "visibility" },
    },
    {
        id = "profiles",
        titleKey = "Sidebar.Profiles",
        pages = { "profiles" },
    },
}

-- Categories that map 1:1 to sidebar pages under the "buffs" group. Every buff
-- category has a same-named page, so this is just an identity map derived from
-- the canonical BR.CATEGORY_ORDER (Core.lua) rather than a hand-kept duplicate.
BR.Options.CategoryPages = {}
for _, cat in ipairs(BR.CATEGORY_ORDER) do
    BR.Options.CategoryPages[cat] = cat
end

-- Ordered list of the built-in (non-custom) categories that have entries in
-- BR.BUFF_TABLES. Iterating this is the right way to walk every static buff
-- without hardcoding the category set in each consumer (see SoundAlert).
-- Custom buffs live in db.customBuffs and must be iterated separately.
BR.Options.StaticCategories = { "raid", "presence", "targeted", "self", "pet", "consumable" }

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

local ceil = math.ceil
local Helpers = BR.Options.Helpers
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

-- Section header: gold text + thin gold accent line beneath, spanning the
-- content area's width. Mirrors the sidebar group header style so page
-- sections and sidebar groups read as the same visual language.
--
-- The helper also takes care of vertical rhythm so callers don't have to:
--   * Auto-insert BEFORE_HEADER_GAP before each section beyond the first.
--   * Reset layout x to COL_PADDING so the header + underline always span
--     the full content width even after the prior section indented content.
--   * Bump layout x to COL_PADDING + CONTENT_INDENT after rendering, so the
--     content that follows visually nests under the section's underline.
-- The first call on a layout skips the before-gap; the page's top margin
-- (the negative y the caller set when constructing VerticalLayout) provides
-- enough breathing room above the first section.
local SEP_OFFSET = 4
local SEP_HEIGHT = 1
local AFTER_HEADER_GAP = 8 -- between the accent line and the first content row
local BEFORE_HEADER_GAP = 16 -- between the previous section's last item and this header
local CONTENT_INDENT = 10 -- how far content nests under each section header

function Helpers.LayoutSectionHeader(layout, parent, text)
    -- Reset x first so the header + underline span the full content width,
    -- regardless of any indent the previous section applied.
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

    -- Indent content beneath this section so it visually hangs under the
    -- accent line. Callers may override by calling layout:SetX themselves
    -- after the header.
    layout:SetX(COL_PADDING + CONTENT_INDENT)

    local _ = COMPONENT_GAP
    return header
end

-- Compact gold subsection header: smaller than LayoutSectionHeader, no accent
-- line, intended for nested sub-blocks under an existing section header (e.g.
-- "Free Consumables" inside the consumable Visibility section, or "Behavior"
-- inside ItemDisplay). Pinned at the layout's current x, so the caller's
-- existing indent is preserved.
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

-- Subsection note: like LayoutSectionNote but anchors at the layout's current
-- x and right-margins to COL_PADDING from the parent edge so wrapped text
-- doesn't run past the panel. Use under a LayoutSubsectionHeader.
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
-- Anchored at COL_PADDING (full content width) so the note aligns with the
-- section header above it instead of nesting under the accent line - the
-- description reads as part of the header block, not as indented child
-- content. The layout's x cursor is preserved so subsequent controls stay
-- nested under the section.
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

    -- Pin to COL_PADDING regardless of the layout's current indent; restore
    -- the cursor afterwards so the next component continues at its prior x.
    local prevX = layout:GetX()
    layout:SetX(COL_PADDING)
    layout:AddText(note, h, COMPONENT_GAP)
    layout:SetX(prevX)
    return note
end

-- ============================================================================
-- CATEGORY SETTINGS HELPERS
-- ============================================================================
--
-- Sections constantly read `categorySettings[category].X` with nil-safe
-- fallbacks and write back through `BR.Config.Set("categorySettings." ..
-- category .. ".X", val)`. The helpers below collapse those idioms.
--
-- Important: `BR.Config.Set` already auto-creates intermediate tables on its
-- path, so the legacy `if not db.categorySettings then ... end / if not
-- db.categorySettings[category] then ... end` ensure-blocks before a Set call
-- are redundant and have been removed in favour of these helpers.
--
-- For inheritance-aware reads (where a category falls back to db.defaults
-- when useCustomAppearance is off), use `BR.Config.GetCategorySetting`
-- instead - these helpers are deliberately non-inheriting since most option
-- widgets want the literal category value.

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
--   * Profile keys live at BR.profile.<key> (e.g. hideInCombat, showOnlyInGroup).
--   * Defaults keys live at BR.profile.defaults.<key> (e.g. textOutline).
--
-- These are the right tool for the common case `get = function() return
-- BR.profile.X == true end / onChange = function(v) BR.Config.Set("X", v)
-- end` - but only when the read is a plain truthy/equality check. If the
-- onChange has side effects (UpdateDisplay, RefreshAll, custom multi-key
-- writes) keep the explicit closure so the side effects stay visible at the
-- call site.

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

-- ============================================================================
-- DIALOG SHELL HELPERS
-- ============================================================================

-- CreateDialogShell builds the boilerplate every small dialog repeats: backdrop
-- panel, title FontString, close-x button, and a VerticalLayout whose cursor
-- starts beneath the title. Callers add their content via the returned layout
-- and call shell:Finalize() to size the dialog.
--
-- opts.titleText overrides the localized title (used by Glow which appends
-- the targeted category). opts.titleColor wraps the title in a color escape.
-- opts.width defaults to DIALOG_WIDTH_NARROW; pass a Constants.DIALOG_WIDTH_*
-- to opt into a wider bucket. opts.icon (a texture path / fileID) shows a small
-- icon at the left of the header and left-aligns the title next to it, so the
-- dialog reads as a titled card; without it the title stays centered.
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
    local CreateButton = BR.CreateButton

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
        -- Header icon + left-aligned title: the icon sits in the header strip and
        -- the title hangs off its right edge, so the dialog reads as a titled card.
        local icon = dialog:CreateTexture(nil, "OVERLAY")
        icon:SetSize(C.DIALOG_ICON_SIZE, C.DIALOG_ICON_SIZE)
        -- LEFT anchor = vertical center; pin it to the 30px header strip's midpoint
        -- (top inset 2 + 15) so both the icon and the title that hangs off it sit
        -- centered in the header band.
        icon:SetPoint("LEFT", dialog, "TOPLEFT", C.DIALOG_MARGIN, -17)
        icon:SetTexture(opts.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border
        title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    else
        title:SetPoint("TOP", 0, C.DIALOG_TITLE_TOP)
    end

    local closeBtn = CreateButton(dialog, "x", function()
        dialog:Hide()
    end)
    closeBtn:SetSize(C.DIALOG_CLOSE_SIZE, C.DIALOG_CLOSE_SIZE)
    closeBtn:SetPoint("TOPRIGHT", C.DIALOG_CLOSE_INSET, C.DIALOG_CLOSE_INSET)

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

        -- Vertically center the content within the body region (below the title
        -- separator down to the bottom edge). For a single short control this
        -- centers it in the min-height body instead of pinning it to the top;
        -- for taller content it just balances the top/bottom gaps.
        local bodyCenter = (-C.DIALOG_ACCENT_OFFSET - height) / 2
        local contentCenter = (layoutTop + contentBottom) / 2
        layout:ShiftAllBy(bodyCenter - contentCenter)
    end
    return shell
end

-- SingletonDialog wraps a builder so the dialog frame is created on first show
-- and reused on subsequent shows (with Components.RefreshAll() to resync).
-- The builder receives any args passed to Show and must return the dialog frame.
--
-- Use this for dialogs whose contents only depend on profile data - they can
-- be cached and refreshed in place. Dialogs whose option lists or layout
-- depend on Show args (SoundAlert, RoguePoison) keep their own destroy/rebuild
-- pattern instead.
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

-- Thin horizontal divider used to break up unrelated blocks within a single page.
function Helpers.LayoutSeparator(layout, parent)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(0.27, 0.27, 0.32, 0.6)
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
    local L = BR.L
    categoryLabelsCache = {
        raid = L["Category.RaidBuffs"],
        presence = L["Category.PresenceBuffs"],
        targeted = L["Category.TargetedBuffs"],
        self = L["Category.SelfBuffs"],
        pet = L["Category.PetReminders"],
        consumable = L["Category.Consumables"],
        custom = L["Category.CustomBuffs"],
        loadout = L["Category.LoadoutReminders"],
    }
    return categoryLabelsCache
end

BR.Options.GetCategoryLabels = GetCategoryLabels
