local _, BR = ...

-- ============================================================================
-- DEFAULTS PAGE
-- ============================================================================
-- Global appearance/behavior defaults inherited by every category unless
-- explicitly overridden. Lifted from the old DisplayBehavior tab's
-- "Global Defaults" + "Expiration Reminder" sections.

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
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

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

    local defGlowHolder = Components.Checkbox(content, {
        label = L["Options.GlowReminderIcons"],
        tooltip = {
            title = L["Options.GlowReminderIcons.Title"],
            desc = L["Options.GlowReminderIcons.Desc"],
        },
        get = function()
            local d = BR.profile.defaults
            return d and (d.showExpirationGlow ~= false or d.showMissingGlow ~= false)
        end,
        onChange = function(checked)
            BR.Config.Set("defaults.showExpirationGlow", checked)
            BR.Config.Set("defaults.showMissingGlow", checked)
            Components.RefreshAll()
        end,
    })

    local glowSettingsBtn = CreateButton(content, L["Options.Customize"], function()
        BR.Options.Dialogs.Glow.Show()
    end)
    glowSettingsBtn:SetPoint("LEFT", defGlowHolder.label, "RIGHT", 8, 0)
    glowSettingsBtn:SetFrameLevel(defGlowHolder:GetFrameLevel() + 5)

    layout:Add(defGlowHolder, nil, COMPONENT_GAP)

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

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.defaults = {
    title = L["Page.Defaults"],
    showMasqueBanner = true,
    Build = Build,
}
