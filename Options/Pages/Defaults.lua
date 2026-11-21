local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- DEFAULTS PAGE
-- ============================================================================
-- Global appearance and behavior defaults. Every category inherits them, but
-- a category can override them.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LSM = LibStub("LibSharedMedia-3.0")
local IsFontPathValid = BR.DisplayFonts.IsFontPathValid
local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

local LayoutSectionHeader = Helpers.LayoutSectionHeader
local LayoutSectionNote = Helpers.LayoutSectionNote
local MakeDefaultsGetter = Helpers.MakeDefaultsGetter
local MakeDefaultsSetter = Helpers.MakeDefaultsSetter

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local tinsert = table.insert

local TEXT_DD_W = 200

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

local function Build(content)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    -- The sections follow the category tabs, so a tab that inherits reads the
    -- same as its source.
    LayoutSectionNote(layout, content, L["Options.GlobalDefaults.Note"])
    layout:Space(SECTION_GAP)

    -- ========================================================================
    -- EXPIRATION
    -- ========================================================================
    LayoutSectionHeader(layout, content, L["Options.ExpirationReminder"])

    local thresholdLW = Components.MeasureSharedLabelWidth({
        L["Options.ExpirationWarning"],
        L["Options.PreKeyThreshold"],
    })

    local function formatMinutes(val)
        return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
    end

    local defThresholdHolder = Components.Slider(content, {
        label = L["Options.ExpirationWarning"],
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

    -- ========================================================================
    -- LAYOUT
    -- ========================================================================
    LayoutSectionHeader(layout, content, L["Options.Layout"])

    local defDirHolder = Components.DirectionButtons(content, {
        get = MakeDefaultsGetter("growDirection", "CENTER"),
        onChange = MakeDefaultsSetter("growDirection"),
    })
    layout:Add(defDirHolder, nil, COMPONENT_GAP)

    -- ========================================================================
    -- APPEARANCE
    -- ========================================================================
    LayoutSectionHeader(layout, content, L["Options.Appearance"])

    local function isDefDimensionsLinked()
        local db = BR.profile.defaults
        return not db or db.iconWidth == nil
    end

    local defAccess = {
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
    }

    -- One label column for both groups: the grid measures its own labels, and
    -- the text rows join that column.
    local textLabelWidth = Components.MeasureSharedLabelWidth({
        L["Appearance.Text"],
        L["Options.Font"],
        L["Options.TextOutline"],
    })

    Helpers.LayoutSubsectionHeader(layout, content, L["Options.Icons"])
    local defGrid = Components.AppearanceGrid(content, {
        get = defAccess.get,
        set = defAccess.set,
        setMulti = defAccess.setMulti,
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
        labelWidth = textLabelWidth,
        masqueCheck = IsMasqueActive,
        borderBlocked = BR.IconStyle.UsesBlizzardArt,
        borderBlockedReason = Helpers.IconStyleBorderReason,
    })
    layout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)
    local labelWidth = defGrid.labelWidth

    -- One stored value; the label names the art that the client draws.
    local blizzardStyleLabel = BR.CLIENT == BR.ClientType.Forever and L["Options.IconStyle.Forever"]
        or L["Options.IconStyle.Blizzard"]
    local iconStyleHolder = Components.Dropdown(content, {
        label = L["Options.IconStyle"],
        labelWidth = labelWidth,
        tooltip = { title = L["Options.IconStyle"], desc = L["Options.IconStyle.Desc"] },
        options = {
            { label = L["Options.IconStyle.Modern"], value = "modern" },
            { label = blizzardStyleLabel, value = "blizzard" },
        },
        width = TEXT_DD_W,
        get = MakeDefaultsGetter("iconStyle", BR.defaults.defaults.iconStyle),
        enabled = function()
            return BR.IconStyle.ARTWORK_AVAILABLE and not IsMasqueActive()
        end,
        disabledReason = function()
            if not BR.IconStyle.ARTWORK_AVAILABLE then
                return L["DisabledReason.IconStyleNoArt"]
            end
            return L["DisabledReason.IconStyleMasque"]
        end,
        onChange = function(value)
            BR.Config.Set("defaults.iconStyle", value)
            Components.RefreshAll()
        end,
    })
    layout:Add(iconStyleHolder, nil, COMPONENT_GAP)

    Helpers.LayoutSubsectionHeader(layout, content, L["Options.Text"])

    local defTextStyleHolder = Components.TextStyleRow(content, defAccess, labelWidth)
    layout:Add(defTextStyleHolder, nil, COMPONENT_GAP)

    local defFontHolder = Components.Dropdown(content, {
        label = L["Options.Font"],
        labelWidth = labelWidth,
        tooltip = { title = L["Options.Font"], desc = L["Options.AppliesEverywhere"] },
        options = BuildFontOptions(),
        width = TEXT_DD_W,
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
        labelWidth = labelWidth,
        tooltip = { title = L["Options.TextOutline"], desc = L["Options.AppliesEverywhere"] },
        options = {
            { label = L["Options.TextOutline.None"], value = "NONE" },
            { label = L["Options.TextOutline.Outline"], value = "OUTLINE" },
            { label = L["Options.TextOutline.Thick"], value = "THICKOUTLINE" },
            { label = L["Options.TextOutline.Monochrome"], value = "MONOCHROME" },
            { label = L["Options.TextOutline.OutlineMono"], value = "OUTLINE, MONOCHROME" },
            { label = L["Options.TextOutline.ThickMono"], value = "THICKOUTLINE, MONOCHROME" },
        },
        width = TEXT_DD_W,
        get = MakeDefaultsGetter("textOutline", "OUTLINE"),
        onChange = function(value)
            BR.Config.Set("defaults.textOutline", value)
            Components.RefreshAll()
        end,
    })
    layout:Add(defOutlineHolder, nil, COMPONENT_GAP)

    local slugOutlineHolder = Components.Checkbox(defOutlineHolder, {
        label = L["Options.SlugOutline"],
        tooltip = { title = L["Options.SlugOutline"], desc = L["Options.SlugOutline.Desc"] },
        get = function()
            return Helpers.GetDefaultSetting("slugOutline", true) ~= false
        end,
        enabled = function()
            local outline = Helpers.GetDefaultSetting("textOutline", "OUTLINE")
            return outline == "OUTLINE" or outline == "THICKOUTLINE"
        end,
        disabledReason = L["Options.SlugOutline.Disabled"],
        onChange = MakeDefaultsSetter("slugOutline"),
    })
    slugOutlineHolder:SetPoint("LEFT", defOutlineHolder, "RIGHT", 2, 0)

    -- ========================================================================
    -- TEXT & OVERLAYS
    -- ========================================================================
    -- The main text has no Size column: Appearance > Text sets its size.
    LayoutSectionHeader(layout, content, L["Options.TextOverlays"])

    local mainTextLW = Components.MeasureSharedLabelWidth({ L["Options.TextPositions.MainText"] })
    Helpers.LayoutTextRow(layout, content, {
        label = L["Options.TextPositions.MainText"],
        labelWidth = mainTextLW,
        tooltip = { title = L["Options.TextPositions.MainText"], desc = L["Options.TextPositions.MainText.Note"] },
        zone = {
            get = function()
                return select(1, BR.TextPositions.Get("count"))
            end,
            set = function(zone)
                BR.Config.Set("defaults.textPositions.count.zone", zone)
            end,
        },
        offsets = {
            min = -40,
            max = 40,
            getX = function()
                local _, x = BR.TextPositions.Get("count")
                return x
            end,
            setX = function(val)
                BR.Config.Set("defaults.textPositions.count.offsetX", val)
            end,
            getY = function()
                local _, _, y = BR.TextPositions.Get("count")
                return y
            end,
            setY = function(val)
                BR.Config.Set("defaults.textPositions.count.offsetY", val)
            end,
        },
    })

    -- ========================================================================
    -- GLOW
    -- ========================================================================
    LayoutSectionHeader(layout, content, L["Options.Glow"])

    local function readDefault(key, default)
        local d = BR.profile.defaults
        local value = d and d[key]
        if value == nil then
            return default
        end
        return value
    end

    -- One row per glow kind, because each kind has its own enable key. A single
    -- control for both keys hides a mixed state.
    local glowLabelWidth, glowSummaryWidth =
        Helpers.GlowColumns({ L["Options.ExpiringGlow"], L["Options.MissingGlow"] }, true)
    local glowWarning = {
        title = L["Options.GlowReminderIcons.Title"],
        desc = L["Options.GlowReminderIcons.CpuWarning"],
    }
    local function AddGlowRow(label, desc, enableKey, kind)
        Helpers.LayoutGlowRow(layout, content, {
            label = label,
            tooltip = { title = label, desc = desc },
            warningTooltip = glowWarning,
            labelWidth = glowLabelWidth,
            summaryWidth = glowSummaryWidth,
            kind = kind,
            read = readDefault,
            get = function()
                return readDefault(enableKey, true) ~= false
            end,
            set = function(checked)
                BR.Config.Set("defaults." .. enableKey, checked)
            end,
            onCustomize = function()
                BR.Options.Dialogs.Glow.Show(nil, kind)
            end,
        })
    end
    AddGlowRow(L["Options.ExpiringGlow"], L["Options.ExpiringGlow.Desc"], "showExpirationGlow", "expiring")
    AddGlowRow(L["Options.MissingGlow"], L["Options.MissingGlow.Desc"], "showMissingGlow", "missing")

    content:SetHeight(math.abs(layout:GetY()) + 20)
end

BR.Options.Pages.defaults = {
    title = L["Page.Defaults"],
    showMasqueBanner = true,
    Build = Build,
}
