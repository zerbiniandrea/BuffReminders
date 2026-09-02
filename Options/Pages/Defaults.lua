local _, BR = ...

-- ============================================================================
-- DEFAULTS PAGE
-- ============================================================================
-- Global appearance and behavior defaults. Every category inherits them, but
-- a category can override them.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
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
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local tinsert = table.insert

-- Every control in the Text section ends on the same right edge. Font and
-- Outline are single dropdowns of TEXT_DD_W. The zone pair must fit the same
-- span minus its internal offsets: each nested dropdown holder insets its box
-- by 5 (Components.Dropdown), plus 8 between the two.
local TEXT_DD_W = 200
local ZONE_INTERNAL_W = 5 + 8 + 5
local ZONE_VERTICAL_W = 102
local ZONE_ALIGN_W = TEXT_DD_W - ZONE_INTERNAL_W - ZONE_VERTICAL_W

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

    LayoutSectionHeader(layout, content, L["Options.GlobalDefaults"])
    LayoutSectionNote(layout, content, L["Options.GlobalDefaults.Note"])

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
        masqueCheck = IsMasqueActive,
    })
    layout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)

    local defDirHolder = Components.DirectionButtons(content, {
        labelWidth = 50,
        get = MakeDefaultsGetter("growDirection", "CENTER"),
        onChange = MakeDefaultsSetter("growDirection"),
    })
    layout:Add(defDirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    -- One row per glow kind, because each kind has its own enable key. A single
    -- control for both keys hides a mixed state.
    local GLOW_ROWS = {
        {
            label = L["Options.ExpiringGlow"],
            desc = L["Options.ExpiringGlow.Desc"],
            enableKey = "showExpirationGlow",
            typeKey = "glowType",
            typeFallback = 2,
            kind = "expiring",
        },
        {
            label = L["Options.MissingGlow"],
            desc = L["Options.MissingGlow.Desc"],
            enableKey = "showMissingGlow",
            typeKey = "missingGlowType",
            typeFallback = 1,
            kind = "missing",
        },
    }
    -- Fixed column boundaries so the style summary and Customize button line up
    -- across rows. The label and the glow name vary in width, so a chained
    -- anchor (button -> summary -> label) scatters the buttons. Anchor both to
    -- the holder's LEFT at precomputed offsets.
    local GLOW_COL_GAP = 8
    -- Reserve the trailing warning icon (4px gap + 14px icon) that these rows
    -- render after the label, so the summary column clears it on the widest row.
    local GLOW_INFO_ICON_RESERVE = 4 + 14
    local glowLabelWidth = Components.MeasureSharedLabelWidth({
        L["Options.ExpiringGlow"],
        L["Options.MissingGlow"],
    }, "GameFontHighlightSmall", 0)
    local glowNames = {}
    for _, t in ipairs(BR.Glow.Types) do
        tinsert(glowNames, t.name)
    end
    local glowSummaryWidth = Components.MeasureSharedLabelWidth(glowNames, "GameFontDisableSmall", 0)

    for _, row in ipairs(GLOW_ROWS) do
        local rowGlowHolder = Components.Checkbox(content, {
            label = row.label,
            tooltip = { title = row.label, desc = row.desc },
            warningTooltip = {
                title = L["Options.GlowReminderIcons.Title"],
                desc = L["Options.GlowReminderIcons.CpuWarning"],
            },
            get = function()
                local d = BR.profile.defaults
                return d and d[row.enableKey] ~= false
            end,
            onChange = function(checked)
                BR.Config.Set("defaults." .. row.enableKey, checked)
                Components.RefreshAll()
            end,
        })

        local summaryX = rowGlowHolder.labelOffset + glowLabelWidth + GLOW_INFO_ICON_RESERVE + GLOW_COL_GAP
        local styleSummary = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        styleSummary:SetPoint("LEFT", rowGlowHolder, "LEFT", summaryX, 0)

        local rowCustomizeBtn = CreateButton(content, L["Options.Customize"], function()
            BR.Options.Dialogs.Glow.Show(nil, row.kind)
        end)
        rowCustomizeBtn:SetPoint("LEFT", rowGlowHolder, "LEFT", summaryX + glowSummaryWidth + GLOW_COL_GAP, 0)
        rowCustomizeBtn:SetFrameLevel(rowGlowHolder:GetFrameLevel() + 5)

        local function refreshGlowRow()
            local d = BR.profile.defaults or {}
            local typeIndex = d[row.typeKey] or row.typeFallback
            local typeInfo = BR.Glow.Types[typeIndex]
            styleSummary:SetText(typeInfo and typeInfo.name or "")
        end
        refreshGlowRow()
        tinsert(BR.RefreshableComponents, { Refresh = refreshGlowRow })

        layout:Add(rowGlowHolder, nil, COMPONENT_GAP)
    end

    -- Text size and color stay in this section, not in the geometry grid, even
    -- though a category can override them. Font, outline and position have no
    -- per-category override.
    LayoutSectionHeader(layout, content, L["Options.Text"])
    LayoutSectionNote(layout, content, L["Options.Text.Note"])

    local textLabelWidth = Components.MeasureSharedLabelWidth({
        L["Appearance.Text"],
        L["Options.Font"],
        L["Options.TextOutline"],
        L["Options.TextPositions.MainText"],
    })

    local defTextStyleHolder = Components.TextStyleRow(content, defAccess, textLabelWidth)
    layout:Add(defTextStyleHolder, nil, COMPONENT_GAP)

    local defFontHolder = Components.Dropdown(content, {
        label = L["Options.Font"],
        labelWidth = textLabelWidth,
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
        labelWidth = textLabelWidth,
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
        onChange = MakeDefaultsSetter("textOutline"),
    })
    layout:Add(defOutlineHolder, nil, COMPONENT_GAP)

    local mainTextPosRow = CreateFrame("Frame", nil, content)
    mainTextPosRow:SetSize(content:GetWidth(), 26)

    local mainTextZone = Components.ZonePicker(mainTextPosRow, {
        label = L["Options.TextPositions.MainText"],
        labelWidth = textLabelWidth,
        verticalWidth = ZONE_VERTICAL_W,
        alignWidth = ZONE_ALIGN_W,
        get = function()
            return select(1, BR.TextPositions.Get("count"))
        end,
        onChange = function(zone)
            BR.Config.Set("defaults.textPositions.count.zone", zone)
        end,
    })
    mainTextZone:SetPoint("TOPLEFT", mainTextPosRow, "TOPLEFT", 0, 0)

    local mainTextOffsetX = Components.Slider(mainTextPosRow, {
        label = L["Options.TextPositions.OffsetX.Short"],
        labelWidth = 12,
        sliderWidth = 60,
        min = -40,
        max = 40,
        get = function()
            local _, x = BR.TextPositions.Get("count")
            return x
        end,
        onChange = function(val)
            BR.Config.Set("defaults.textPositions.count.offsetX", val)
        end,
    })
    mainTextOffsetX:SetPoint("LEFT", mainTextZone, "RIGHT", 12, 0)

    local mainTextOffsetY = Components.Slider(mainTextPosRow, {
        label = L["Options.TextPositions.OffsetY.Short"],
        labelWidth = 12,
        sliderWidth = 60,
        min = -40,
        max = 40,
        get = function()
            local _, _, y = BR.TextPositions.Get("count")
            return y
        end,
        onChange = function(val)
            BR.Config.Set("defaults.textPositions.count.offsetY", val)
        end,
    })
    mainTextOffsetY:SetPoint("LEFT", mainTextOffsetX, "RIGHT", 8, 0)

    layout:Add(mainTextPosRow, 26, COMPONENT_GAP)
    LayoutSectionNote(layout, content, L["Options.TextPositions.MainText.Note"])

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

    content:SetHeight(math.abs(layout:GetY()) + 20)
end

BR.Options.Pages.defaults = {
    title = L["Page.Defaults"],
    showMasqueBanner = true,
    Build = Build,
}
