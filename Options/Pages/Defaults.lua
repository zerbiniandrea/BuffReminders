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
local abs = math.abs

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

    -- Glow: one independent row per glow kind (expiring / missing), each with
    -- its own enable checkbox, a live style summary, and a Customize button
    -- opening the Glow dialog on that kind. One control = one setting: the
    -- old single checkbox wrote both enable keys at once and read "on" when
    -- either was on, which made mixed states impossible to see or set here.
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
    -- across rows regardless of label / glow-name length. Both label and glow
    -- name vary in width, so chaining button -> summary -> label would scatter
    -- the buttons; anchor them to the holder's LEFT at precomputed offsets.
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

    -- Transition breadcrumb: the stacking-order editor lived here for a long
    -- time before moving to the Layout page with everything else spatial.
    layout:Space(12)
    LayoutSectionNote(layout, content, L["Options.DisplayOrder.Moved"])

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.defaults = {
    title = L["Page.Defaults"],
    showMasqueBanner = true,
    Build = Build,
}
